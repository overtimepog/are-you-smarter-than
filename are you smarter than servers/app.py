import asyncio
import logging
import random
import string
import time
from typing import List, Optional, Tuple

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi_socketio import SocketManager
from pydantic import BaseModel, Field, validator

import uvicorn
from room_db import (
    add_or_update_player,
    add_player_to_room,
    add_room,
    delete_room,
    end_game,
    get_all_rooms,
    get_game_history,
    get_player_scores,
    get_player_statistics,
    get_room,
    increment_player_win,
    init_db,
    remove_player_from_room,
    start_game,
    update_player_score,
    update_room,
)

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = FastAPI()
sio = SocketManager(app=app)

# CORS Middleware Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Consider restricting in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the database
init_db()

# Thread-safe shared data structures
session_to_player = {}
used_room_codes = set()
used_room_codes_lock = asyncio.Lock()
session_to_player_lock = asyncio.Lock()

# Constants
MAX_ROOMS = 100
INACTIVITY_THRESHOLD = 600  # 10 minutes in seconds
CLEANUP_INTERVAL = 300      # 5 minutes in seconds

# Pydantic Models

class CreateRoomRequest(BaseModel):
    player_name: str = Field(..., min_length=1, max_length=50)
    question_goal: int = Field(10, gt=0)
    max_players: int = Field(8, gt=0)
    difficulty: str = Field('easy')
    categories: List[int] = Field(default_factory=list)

    @validator('difficulty')
    def validate_difficulty(cls, v):
        if v not in ['easy', 'medium', 'hard']:
            raise ValueError('Invalid difficulty. Must be one of: easy, medium, hard.')
        return v

    @validator('categories', each_item=True)
    def validate_categories(cls, v):
        if not isinstance(v, int) or v not in range(9, 33):
            raise ValueError('Invalid category ID. Must be an integer between 9 and 32.')
        return v

class JoinRoomRequest(BaseModel):
    room_code: str
    player_name: str = Field(..., min_length=1, max_length=50)

class LeaveRoomRequest(BaseModel):
    room_code: str
    player_name: str

class StartGameRequest(BaseModel):
    room_code: str

class EndGameRequest(BaseModel):
    room_code: str
    winners: List[str]

class SubmitAnswerRequest(BaseModel):
    room_code: str
    player_name: str
    is_correct: bool

class PostLobbyWinsRequest(BaseModel):
    player_name: str
    wins: int = Field(..., ge=0)

# Helper Functions

def generate_room_code() -> str:
    """Generate a unique 6-character room code."""
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

async def update_last_active(room_code: str):
    """Update the last active timestamp for a room."""
    logger.debug(f"Updating last active time for room {room_code}")
    await asyncio.to_thread(update_room, room_code, last_active=time.time())
    logger.debug(f"Updated last active time for room {room_code}")

async def cleanup_room(room_code: str):
    """Delete a room and remove its code from used_room_codes."""
    try:
        logger.debug(f"Attempting to delete room {room_code}")
        await asyncio.to_thread(delete_room, room_code)
        async with used_room_codes_lock:
            used_room_codes.discard(room_code)
        logger.debug(f"Room {room_code} deleted successfully")
    except Exception as e:
        logger.error(f"Failed to delete room {room_code}: {e}")

async def cleanup_dead_rooms():
    """Periodically clean up inactive or empty rooms."""
    logger.debug("Starting cleanup of dead rooms.")
    all_rooms = await asyncio.to_thread(get_all_rooms)
    current_time = time.time()
    rooms_deleted = 0

    for room in all_rooms:
        room_code = room['room_code']
        last_active = room.get('last_active', 0)
        players = room.get('players', [])
        time_since_last_active = current_time - last_active

        if time_since_last_active > INACTIVITY_THRESHOLD or not players:
            logger.debug(f"Room {room_code} is inactive or empty. Deleting...")
            await cleanup_room(room_code)
            rooms_deleted += 1

    logger.debug(f"Cleanup complete. {rooms_deleted} rooms deleted.")

async def periodic_cleanup_task():
    """Background task to periodically clean up dead rooms."""
    while True:
        await cleanup_dead_rooms()
        await asyncio.sleep(CLEANUP_INTERVAL)

def end_game_logic(room_code: str, winners: List[str]) -> Tuple[bool, str]:
    """Logic to end the game and update winners."""
    room = get_room(room_code)
    if room:
        if not room['game_started']:
            logger.debug(f"Game has not started yet for room {room_code}")
            return False, 'Game has not started yet'

        end_game(room_code, winners)

        for winner in winners:
            try:
                increment_player_win(room_code, winner)
                logger.debug(f"Incremented win for player {winner} in room {room_code}")
            except Exception as e:
                logger.error(f"Failed to increment win for player {winner} in room {room_code}: {e}")
                return False, f'Failed to increment win for player {winner}: {e}'

        logger.debug(f"Game ended successfully for room {room_code}")
        return True, 'Game ended successfully'
    else:
        logger.debug(f"Room {room_code} not found")
        return False, f'Room with code {room_code} not found'

# API Endpoints

@app.on_event("startup")
async def startup_event():
    """Startup event to initiate background tasks."""
    logger.debug("Starting background tasks.")
    asyncio.create_task(periodic_cleanup_task())

@app.get("/", response_class=HTMLResponse)
async def index():
    """Root endpoint serving a simple HTML page."""
    smiley_html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Smiley Face</title>
    </head>
    <body style="display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f0f0f0;">
        <div style="font-size: 100px;">😊</div>
    </body>
    </html>
    """
    return HTMLResponse(content=smiley_html)

@app.get("/game_room/{room_code}")
async def get_room_info(room_code: str):
    """Retrieve information about a specific game room."""
    logger.debug(f"Fetching room info for room code: {room_code}")
    room = await asyncio.to_thread(get_room, room_code)
    if room:
        players = room.get('players', [])
        logger.debug(f"Room found: {room}")
        player_scores = await asyncio.to_thread(get_player_scores, room_code)
        player_wins = {score['player_name']: score['wins'] for score in player_scores}

        return JSONResponse(content={
            'room_code': room_code,
            'host': room.get('host'),
            'players': players,
            'player_wins': player_wins,
            'question_goal': room.get('question_goal', 10),
            'max_players': room.get('max_players', 8),
            'game_started': room.get('game_started', False),
            'winners': room.get('winners', []),
            'difficulty': room.get('difficulty', 'easy'),
            'categories': room.get('categories', []),
            'last_active': room.get('last_active', time.time())
        }, status_code=200)
    logger.debug(f"Room not found for room code: {room_code}")
    raise HTTPException(status_code=404, detail=f'Room with code {room_code} not found')

@app.post("/leave_room")
async def leave_room_route(data: LeaveRoomRequest):
    """Endpoint for a player to leave a room."""
    room_code = data.room_code
    player_name = data.player_name
    logger.debug(f"Player {player_name} attempting to leave room {room_code}")

    try:
        success = await asyncio.to_thread(remove_player_from_room, room_code, player_name)
        if success:
            await update_last_active(room_code)
            room = await asyncio.to_thread(get_room, room_code)
            if room and not room['players']:
                logger.debug(f"No players left in room {room_code}. Cleaning up room.")
                await cleanup_room(room_code)
            return JSONResponse(content={'success': True, 'message': 'Player left the room'})
        logger.debug(f"Room or player not found for room code: {room_code}, player name: {player_name}")
        raise HTTPException(status_code=404, detail=f'Room with code {room_code} or player {player_name} not found')
    except Exception as e:
        logger.error(f"Failed to remove player {player_name} from room {room_code}: {e}")
        raise HTTPException(status_code=500, detail=f'Failed to leave room: {str(e)}')

@app.post("/join_room")
async def join_room_route(data: JoinRoomRequest):
    """Endpoint for a player to join a room."""
    room_code = data.room_code
    player_name = data.player_name
    logger.debug(f"Player {player_name} attempting to join room {room_code}")

    room = await asyncio.to_thread(get_room, room_code)
    if not room:
        logger.debug(f"Room not found for room code: {room_code}")
        raise HTTPException(status_code=404, detail=f'Room with code {room_code} not found')
    try:
        # Check if the player name is already taken by another player
        if player_name in room['players']:
            logger.debug(f"Player name {player_name} is already taken in room {room_code}")
            raise HTTPException(status_code=400, detail=f'Player name {player_name} is already taken in room {room_code}')

        # Allow joining if the game has ended
        if not room['game_started'] and room['winners']:
            await asyncio.to_thread(add_player_to_room, room_code, player_name)
            await update_last_active(room_code)
            player_id = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
            await sio.emit('player_joined', player_name, room=room_code)
            return JSONResponse(content={'success': True, 'player_id': player_id})

        if await asyncio.to_thread(add_player_to_room, room_code, player_name):
            await update_last_active(room_code)
            player_id = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
            logger.debug(f"Player {player_name} joined room {room_code}")
            return JSONResponse(content={'success': True, 'player_id': player_id})
    except Exception as e:
        logger.error(f"Failed to add player {player_name} to room {room_code}: {e}")
        raise HTTPException(status_code=500, detail=f'Failed to add player {player_name} to room {room_code}')

@app.post("/create_room")
async def create_room(data: CreateRoomRequest):
    """Endpoint to create a new game room."""
    logger.debug("Attempting to create a new room.")

    # Check if maximum number of rooms has been reached
    all_rooms = await asyncio.to_thread(get_all_rooms)
    if len(all_rooms) >= MAX_ROOMS:
        logger.debug("Maximum number of rooms reached. Triggering cleanup.")
        await cleanup_dead_rooms()
        all_rooms = await asyncio.to_thread(get_all_rooms)
        if len(all_rooms) >= MAX_ROOMS:
            logger.error("Maximum number of rooms still reached after cleanup.")
            raise HTTPException(status_code=503, detail='Maximum number of rooms reached. Please try again later.')

    max_attempts = 10
    attempts = 0
    room_code = generate_room_code()

    # Check for room code collisions
    async with used_room_codes_lock:
        while room_code in used_room_codes or await asyncio.to_thread(get_room, room_code):
            if attempts >= max_attempts:
                logger.error("Unable to generate a unique room code after multiple attempts.")
                raise HTTPException(status_code=500, detail='Unable to generate a unique room code after multiple attempts, please try again later.')
            logger.debug(f"Collision detected for room code {room_code}, regenerating.")
            room_code = generate_room_code()
            attempts += 1
        used_room_codes.add(room_code)

    first_player_name = data.player_name
    categories = data.categories
    try:
        await asyncio.to_thread(
            add_room,
            room_code,
            first_player_name,
            data.question_goal,
            data.max_players,
            data.difficulty,
            categories
        )
        logger.debug(f"Room created successfully with room code: {room_code}, host: {first_player_name}")
        return JSONResponse(content={'room_code': room_code, 'success': True})
    except Exception as e:
        async with used_room_codes_lock:
            used_room_codes.discard(room_code)
        logger.error(f"Failed to create room {room_code}: {e}")
        raise HTTPException(status_code=500, detail=f'Failed to create room: {str(e)}')

@app.post("/start_game")
async def start_game_route(data: StartGameRequest):
    """Endpoint to start a game in a room."""
    room_code = data.room_code
    logger.debug(f"Attempting to start game for room {room_code}")
    room = await asyncio.to_thread(get_room, room_code)
    if room:
        if room['game_started']:
            logger.debug(f"Game already started for room {room_code}")
            raise HTTPException(status_code=400, detail='Game has already started')
        try:
            await asyncio.to_thread(start_game, room_code)
            await asyncio.to_thread(update_room, room_code, game_started=True)
            logger.debug(f"Game started for room {room_code}")
            return JSONResponse(content={'success': True, 'message': 'Game started'})
        except Exception as e:
            logger.error(f"Failed to start game for room {room_code}: {e}")
            raise HTTPException(status_code=500, detail=f'Failed to start game: {str(e)}')
    logger.debug(f"Room not found for room code: {room_code}")
    raise HTTPException(status_code=404, detail=f'Room with code {room_code} not found')

@app.post("/end_game")
async def end_game_route(data: EndGameRequest):
    """Endpoint to end a game in a room."""
    room_code = data.room_code
    winners = data.winners
    if not room_code:
        raise HTTPException(status_code=400, detail='Missing room_code')

    logger.debug(f"Attempting to end game for room {room_code}")
    success, message = end_game_logic(room_code, winners)
    if success:
        return JSONResponse(content={'success': True, 'message': 'Game ended', 'winners': winners})
    else:
        raise HTTPException(status_code=400, detail=message)

@app.post("/submit_answer")
async def submit_answer(data: SubmitAnswerRequest):
    """Endpoint for players to submit their answers."""
    room_code = data.room_code
    player_name = data.player_name
    is_correct = data.is_correct

    logger.debug(f"Player {player_name} submitted answer in room {room_code}: {'correct' if is_correct else 'incorrect'}")

    try:
        room = await asyncio.to_thread(get_room, room_code)
        if not room:
            logger.debug(f"Room not found for room code: {room_code}")
            raise HTTPException(status_code=404, detail='Room not found')

        if is_correct:
            await asyncio.to_thread(update_player_score, room_code, player_name, 1, 0)
            logger.debug(f"Updated score for player {player_name} in room {room_code}")

        scores = await asyncio.to_thread(get_player_scores, room_code)
        await update_last_active(room_code)

        player_score = next((score for score in scores if score['player_name'] == player_name), None)
        if player_score and player_score['score'] >= room['question_goal']:
            logger.debug(f"Player {player_name} reached the question goal in room {room_code}")
            success, message = end_game_logic(room_code, [player_name])
            if success:
                logger.debug(f"Game ended successfully for room {room_code}")
            else:
                logger.error(f"Failed to end game for room {room_code}: {message}")
            return JSONResponse(content={
                'success': True,
                'scores': scores,
                'message': 'Answer submitted successfully',
                'game_ended': True,
                'rankings': scores
            }, status_code=200)

        return JSONResponse(content={
            'success': True,
            'scores': scores,
            'message': 'Answer submitted successfully',
            'game_ended': False
        }, status_code=200)
    except Exception as e:
        logger.error(f"Exception occurred while submitting answer: {e}")
        raise HTTPException(status_code=500, detail=f'Failed to submit answer: {str(e)}')

@app.get("/get_player_statistics/{player_name}")
async def get_player_statistics_route(player_name: str):
    """Retrieve statistics for a specific player."""
    logger.debug(f"Fetching statistics for player: {player_name}")
    stats = await asyncio.to_thread(get_player_statistics, player_name)
    logger.debug(f"Statistics fetched for player {player_name}: {stats}")
    return JSONResponse(content={'player_name': player_name, 'statistics': stats})

@app.get("/get_game_history/{room_code}")
async def get_game_history_route(room_code: str):
    """Retrieve the game history for a specific room."""
    logger.debug(f"Fetching game history for room code: {room_code}")
    history = await asyncio.to_thread(get_game_history, room_code)
    logger.debug(f"Game history fetched for room {room_code}: {history}")
    return JSONResponse(content={'room_code': room_code, 'history': history})

@app.get("/get_player_scores/{room_code}")
async def get_player_scores_route(room_code: str):
    """Retrieve the scores of all players in a specific room."""
    logger.debug(f"Fetching player scores for room code: {room_code}")
    scores = await asyncio.to_thread(get_player_scores, room_code)
    logger.debug(f"Player scores fetched for room {room_code}: {scores}")
    return JSONResponse(content={'room_code': room_code, 'scores': scores})

@app.get("/lobby_wins/{room_code}")
async def get_lobby_wins(room_code: str):
    """Retrieve player wins for the given room code."""
    logger.debug(f"Fetching player wins for room code: {room_code}")
    scores = await asyncio.to_thread(get_player_scores, room_code)
    player_wins = {score['player_name']: score['wins'] for score in scores}
    return JSONResponse(content={'room_code': room_code, 'player_wins': player_wins})

@app.post("/lobby_wins/{room_code}")
async def post_lobby_wins(room_code: str, data: PostLobbyWinsRequest):
    """Update player wins for a specific room."""
    player_name = data.player_name
    wins = data.wins

    if not player_name or wins is None:
        raise HTTPException(status_code=400, detail='Missing player_name or wins')

    try:
        await asyncio.to_thread(update_player_score, room_code, player_name, 0, wins)
        logger.debug(f"Updated wins for player {player_name} in room {room_code} to {wins}")
        return JSONResponse(content={'success': True, 'message': 'Player wins updated'})
    except Exception as e:
        logger.error(f"Failed to update wins for player {player_name} in room {room_code}: {e}")
        raise HTTPException(status_code=500, detail=f'Failed to update wins for player {player_name}')

@app.get("/get_all_rooms")
async def get_all_rooms_route():
    """Retrieve information about all active rooms."""
    all_rooms = await asyncio.to_thread(get_all_rooms)
    logger.debug(f"Fetching information for all rooms: {all_rooms}")
    return JSONResponse(content={'rooms': all_rooms})

# Socket.IO Event Handlers

@sio.on('host_view_change')
async def handle_host_view_change(sid, data: dict):
    """Handle host view changes and propagate updates to all clients in the room."""
    room_code = data.get('room_code')
    new_view = data.get('new_view')
    logger.debug(f"Received data for host_view_change: {data}")

    if not room_code or not new_view:
        logger.error("Invalid data received for host_view_change.")
        await sio.emit('error', {'message': 'Invalid data for host_view_change'}, to=sid)
        return

    logger.debug(f"Host changed view to {new_view} in room {room_code}")
    await sio.emit('update_view', {'new_view': new_view}, room=room_code)
    logger.debug(f"Emitted 'update_view' event to room {room_code}")

@sio.on('join_game')
async def handle_join_game(sid, data: dict):
    """Handle players joining a game via Socket.IO."""
    room_code = data.get('room_code')
    player_name = data.get('player_name')

    logger.debug(f"Received data for join_game: {data}")
    logger.debug(f"Player {player_name} attempting to join room {room_code} via SocketIO")

    if not room_code or not player_name:
        logger.error("Missing room_code or player_name in join_game.")
        await sio.emit('error', {'message': 'Missing room_code or player_name'}, to=sid)
        return

    room = await asyncio.to_thread(get_room, room_code)
    if room and player_name in room['players']:
        try:
            await sio.enter_room(sid, room_code)
            async with session_to_player_lock:
                session_to_player[sid] = {'room_code': room_code, 'player_name': player_name}
            await update_last_active(room_code)
            logger.debug(f"Player {player_name} successfully joined room {room_code} via SocketIO")
            await sio.emit('player_joined', player_name, room=room_code)

            # Emit updated room data to all clients in the room
            updated_room_data = await asyncio.to_thread(get_room, room_code)
            await sio.emit('room_data_updated', updated_room_data, room=room_code)
            logger.debug(f"Emitted 'room_data_updated' event with data: {updated_room_data}")
        except Exception as e:
            logger.error(f"Failed to join room {room_code}: {e}")
            await sio.emit('error', {'message': f'Failed to join room {room_code}'}, to=sid)
    else:
        logger.debug(f"Player {player_name} not found in room {room_code}")
        await sio.emit('error', {'message': f'Player {player_name} not found in room {room_code}'}, to=sid)

@sio.on('disconnect')
async def handle_disconnect(sid):
    """Handle player disconnections."""
    async with session_to_player_lock:
        player_info = session_to_player.get(sid)
        if player_info:
            room_code = player_info['room_code']
            player_name = player_info['player_name']
            logger.debug(f"Player {player_name} disconnected from room {room_code}")

            room = await asyncio.to_thread(get_room, room_code)
            if room:
                success = await asyncio.to_thread(remove_player_from_room, room_code, player_name)
                if success:
                    del session_to_player[sid]
                    await sio.emit('player_left', player_name, room=room_code)
                    await sio.emit('player_count_changed', {'count': len(room['players']) - 1}, room=room_code)
                    logger.debug(f"Player {player_name} removed from room {room_code}")

                    # If no players left, clean up the room
                    if not room['players']:
                        logger.debug(f"No players left in room {room_code}. Cleaning up room.")
                        await cleanup_room(room_code)

# Run the application
if __name__ == "__main__":
    logger.debug("API is fully booted and ready to use.")
    uvicorn.run(app, host="0.0.0.0", port=3000)