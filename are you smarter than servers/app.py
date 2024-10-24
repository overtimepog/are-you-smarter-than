from flask import Flask, request, jsonify, render_template_string
from flask_compress import Compress
from flask_socketio import SocketIO, join_room, leave_room, emit
import random
from room_db import init_db, add_room, get_room, update_room, delete_room, get_player_scores, add_or_update_player, get_player_statistics, get_game_history, add_player_to_room, remove_player_from_room, start_game, end_game, increment_player_win
import time
import string
import uuid
import signal
import sys

app = Flask(__name__)
Compress(app)
socketio = SocketIO(app, cors_allowed_origins="*")

init_db()  # Initialize the database with the necessary tables

# Create a mapping from session IDs to player and room information
session_to_player = {}

MAX_ROOMS = 100  # Define a maximum number of rooms allowed at a time
used_room_codes = set()  # Track used room codes to avoid collisions

def generate_room_code():
    # Generate a unique room code consisting of 6 uppercase letters or digits
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

def update_last_active(room_code):
    # Update the last active timestamp for the given room to indicate activity
    update_room(room_code, last_active=time.time())
    print(f"[DEBUG] [update_last_active] Updated last active time for room {room_code}")

def cleanup_room(room_code):
    # Delete a room from the database to free up resources
    delete_room(room_code)
    used_room_codes.discard(room_code)  # Remove the room code from the set of used codes
    print(f"[DEBUG] [cleanup_room] Room {room_code} deleted from database")

@app.route('/')
def index():
    # Render a simple page with a smiley face
    smiley_html = '''
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
    '''
    return render_template_string(smiley_html)

@app.route('/game_room/<room_code>', methods=['GET'])
def get_room_info(room_code):
    # Fetch information about a specific game room
    print(f"[DEBUG] [get_room_info] Fetching room info for room code: {room_code}")
    room = get_room(room_code)
    if room:
        players = room['players']
        print(f"[DEBUG] [get_room_info] Room found: {room}")
        return jsonify({
            'room_code': room_code,
            'players': players,
            'question_goal': room['question_goal'],
            'max_players': room['max_players'],
            'game_started': room['game_started'],
            'winners': room['winners'],
            'difficulty': room['difficulty'],  # Include the correct difficulty field here
            'last_active': room['last_active']  # Correctly display the last active timestamp
        }), 200
    print(f"[DEBUG] [get_room_info] Room not found for room code: {room_code}")
    return jsonify({'success': False, 'message': f'Room with code {room_code} not found'}), 404

@app.route('/leave_room', methods=['POST'])
def leave_room_route():
    # Handle a player leaving a room
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']
    print(f"[DEBUG] [leave_room_route] Player {player_name} attempting to leave room {room_code}")

    if remove_player_from_room(room_code, player_name):
        update_last_active(room_code)  # Update last active time
        room = get_room(room_code)
        if room and not room['players']:
            cleanup_room(room_code)  # Clean up the room if no players are left
        return jsonify({'success': True, 'message': 'Player left the room'}), 200
    print(f"[DEBUG] [leave_room_route] Room or player not found for room code: {room_code}, player name: {player_name}")
    return jsonify({'success': False, 'message': f'Room with code {room_code} or player {player_name} not found'}), 404

@app.route('/join_room', methods=['POST'])
def join_room_route():
    # Handle a player attempting to join a room
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']
    print(f"[DEBUG] Player {player_name} attempting to join room {room_code}")

    room = get_room(room_code)
    if not room:
        print(f"[DEBUG] Room not found for room code: {room_code}")
        return jsonify({'success': False, 'message': f'Room with code {room_code} not found'}), 404
    if len(room['players']) >= room['max_players']:
        print(f"[DEBUG] Room {room_code} is full")
        return jsonify({'success': False, 'message': f'Room {room_code} is full'}), 403
    if player_name in room['players']:
        print(f"[DEBUG] Username {player_name} already taken in room {room_code}")
        return jsonify({'success': False, 'message': f'Username {player_name} already taken in room {room_code}'}), 403

    if add_player_to_room(room_code, player_name):
        update_last_active(room_code)  # Update last active time
        player_id = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))  # Generate a shorter, human-readable player identifier
        print(f"[DEBUG] Player {player_name} joined room {room_code}")
        return jsonify({'success': True, 'player_id': player_id}), 200

@app.route('/create_room', methods=['POST'])
def create_room():
    # Handle creating a new room
    data = request.json
    print("[DEBUG] Attempting to create a new room.")
    max_attempts = 10
    attempts = 0
    room_code = generate_room_code()

    # Validate input parameters
    question_goal = data.get('question_goal', 10)  # Default to 10 questions
    max_players = data.get('max_players', 8)       # Default to 8 players
    difficulty = data.get('difficulty', 'easy')  # Default to 'easy' if not provided
    if difficulty not in ['easy', 'medium', 'hard']:
        print("[DEBUG] Invalid difficulty provided.")
        return jsonify({'success': False, 'message': 'Invalid difficulty. It must be one of: easy, medium, hard.'}), 400
    if not isinstance(question_goal, int) or question_goal <= 0:
        print("[DEBUG] Invalid question goal provided.")
        return jsonify({'success': False, 'message': 'Invalid question goal. It must be a positive integer.'}), 400
    if not isinstance(max_players, int) or max_players <= 0:
        print("[DEBUG] Invalid max players provided.")
        return jsonify({'success': False, 'message': 'Invalid max players. It must be a positive integer.'}), 400

    # Check for room code collisions and regenerate if needed
    while room_code in used_room_codes or get_room(room_code):
        if attempts >= max_attempts:
            print("[ERROR] Maximum attempts reached while generating a unique room code.")
            return jsonify({'success': False, 'message': 'Unable to generate a unique room code after multiple attempts, please try again later.'}), 500
        room_code = generate_room_code()
        attempts += 1

    first_player_name = data.get('player_name')
    add_room(room_code, first_player_name, question_goal, max_players, difficulty)  # Add room to the database
    used_room_codes.add(room_code)  # Add the new room code to the set of used codes
    print(f"[DEBUG] Room created successfully with room code: {room_code}")

    return jsonify({'room_code': room_code, 'success': True}), 200

@app.route('/start_game', methods=['POST'])
def start_game_route():
    # Handle starting the game
    data = request.json
    room_code = data['room_code']
    print(f"[DEBUG] Attempting to start game for room {room_code}")
    room = get_room(room_code)
    if room:
        if room['game_started']:
            return jsonify({'success': False, 'message': 'Game has already started'}), 400
        start_game(room_code)
        print(f"[DEBUG] Game started for room {room_code}")
        return jsonify({'success': True, 'message': 'Game started'}), 200
    return jsonify({'success': False, 'message': f'Room with code {room_code} not found'}), 404

@app.route('/end_game', methods=['POST'])
def end_game_route():
    # Handle ending the game
    data = request.json
    room_code = data['room_code']
    winners = data.get('winners', [])
    print(f"[DEBUG] Attempting to end game for room {room_code}")
    room = get_room(room_code)
    if room:
        if not room['game_started']:
            return jsonify({'success': False, 'message': 'Game has not started yet'}), 400
        end_game(room_code, winners)
        print(f"[DEBUG] Game ended for room {room_code}")
        for winner in winners:
            increment_player_win(room_code, winner)
        return jsonify({'success': True, 'message': 'Game ended', 'winners': winners}), 200
    return jsonify({'success': False, 'message': f'Room with code {room_code} not found'}), 404

@socketio.on('join_game')
def handle_join_game(data):
    # Handle a player joining the game via SocketIO
    room_code = data['room_code']
    player_name = data['player_name']
    player_id = data['player_id']
    sid = request.sid

    room = get_room(room_code)
    if room and player_name in room['players']:
        try:
            join_room(room_code)  # Attempt to join the room via SocketIO
            session_to_player[sid] = {'room_code': room_code, 'player_name': player_name}  # Store player info
            current_players = room['players']
            update_last_active(room_code)  # Update last active time
            emit('player_joined', {'player_name': player_name, 'player_id': player_id, 'current_players': current_players}, room=room_code)
        except Exception as e:
            print(f"[ERROR] Failed to join room {room_code}: {e}")
            emit('error', {'message': f'Failed to join room {room_code}'}, to=sid)
    else:
        # Player did not join via HTTP endpoint or player_id mismatch
        leave_room(room_code)
        return

@app.route('/get_player_statistics/<player_name>', methods=['GET'])
def get_player_statistics_route(player_name):
    # Fetch statistics for a specific player
    print(f"[DEBUG] [get_player_statistics_route] Fetching statistics for player: {player_name}")
    stats = get_player_statistics(player_name)
    return jsonify({'player_name': player_name, 'statistics': stats}), 200

@app.route('/get_game_history/<room_code>', methods=['GET'])
def get_game_history_route(room_code):
    # Fetch the game history for a specific room
    print(f"[DEBUG] [get_game_history_route] Fetching game history for room code: {room_code}")
    history = get_game_history(room_code)
    return jsonify({'room_code': room_code, 'history': history}), 200

@app.route('/get_player_scores/<room_code>', methods=['GET'])
def get_player_scores_route(room_code):
    # Fetch the scores of all players in a specific room
    print(f"[DEBUG] [get_player_scores_route] Fetching player scores for room code: {room_code}")
    scores = get_player_scores(room_code)
    return jsonify({'room_code': room_code, 'scores': scores}), 200

@socketio.on('disconnect')
def handle_disconnect():
    # Handle a player disconnecting from the server
    sid = request.sid
    if sid in session_to_player:
        player_info = session_to_player[sid]
        room_code = player_info['room_code']
        player_name = player_info['player_name']

        if remove_player_from_room(room_code, player_name):
            del session_to_player[sid]  # Remove player from session mapping
            emit('player_left', player_name, room=room_code)  # Notify other players in the room

socketio.run(app, host='0.0.0.0', port=3000)
print("[DEBUG] API is fully booted and ready to use.")