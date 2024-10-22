from flask import Flask, request, jsonify, render_template_string
from flask_compress import Compress
from flask_socketio import SocketIO, join_room, leave_room, emit
import random
import time
import string
import uuid
import signal
import sys

app = Flask(__name__)
Compress(app)
socketio = SocketIO(app, cors_allowed_origins="*")

rooms = {}  # Store room data including question goals and players

# Create a mapping from session IDs to player and room information
session_to_player = {}

MAX_ROOMS = 100  # Define a maximum number of rooms

def generate_room_code():
    return str(uuid.uuid4())[:6]  # Generate a unique room code using a UUID

def update_last_active(room_code):
    if room_code in rooms:
        rooms[room_code]['last_active'] = time.time()

def cleanup_room(room_code):
    if room_code in rooms:
        # Delete the room
        del rooms[room_code]
        print(f"[DEBUG] Room {room_code} deleted during cleanup")

def initialize_room(room_code, host_name, question_goal, max_players):
    return {
        'host': host_name,
        'players': {},
        'game_started': False,
        'question_goal': question_goal,
        'max_players': max_players,
        'winners': [],
        'last_active': time.time(),
        'creation_time': time.time()
    }

@app.route('/')
def index():
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
    print(f"[DEBUG] Fetching room info for room code: {room_code}")
    room = rooms.get(room_code)
    if room:
        players = list(room['players'].keys())
        print(f"[DEBUG] Room found: {room}")
        return jsonify({
            'room_code': room_code,
            'players': players,
            'question_goal': room['question_goal'],
            'max_players': room['max_players'],
            'game_started': room['game_started'],
            'winners': room['winners']
        }), 200
    print(f"[DEBUG] Room not found for room code: {room_code}")
    return jsonify({'success': False, 'message': f'Room with code {room_code} not found'}), 404

@app.route('/leave_room', methods=['POST'])
def leave_room_route():
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']
    print(f"[DEBUG] Player {player_name} attempting to leave room {room_code}")

    if room_code in rooms and player_name in rooms[room_code]['players']:
        player_sid = rooms[room_code]['players'][player_name]['sid']
        if player_sid in session_to_player:
            del session_to_player[player_sid]
        del rooms[room_code]['players'][player_name]
        update_last_active(room_code)  # Update last active time
        if not rooms[room_code]['players']:
            cleanup_room(room_code)  # Use structured cleanup process
        return jsonify({'success': True, 'message': 'Player left the room'}), 200
    print(f"[DEBUG] Room or player not found for room code: {room_code}, player name: {player_name}")
    return jsonify({'success': False, 'message': f'Room with code {room_code} or player {player_name} not found'}), 404

@app.route('/join_room', methods=['POST'])
def join_room_route():
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']
    print(f"[DEBUG] Player {player_name} attempting to join room {room_code}")

    if room_code in rooms:
        if player_name in rooms[room_code]['players']:
            print(f"[DEBUG] Username {player_name} already taken in room {room_code}")
            return jsonify({'success': False, 'message': f'Username {player_name} already taken in room {room_code}'}), 403

        if len(rooms[room_code]['players']) >= rooms[room_code]['max_players']:
            print(f"[DEBUG] Room {room_code} is full")
            return jsonify({'success': False, 'message': f'Room {room_code} is full'}), 403

        player_id = str(uuid.uuid4())  # Generate a unique player identifier
        rooms[room_code]['players'][player_name] = {
            'player_id': player_id,
            'score': 0,
            'sid': ""  # Initialize 'sid' with an empty string to avoid inconsistencies
        }
        update_last_active(room_code)  # Update last active time
        print(f"[DEBUG] Player {player_name} joined room {room_code}")
        return jsonify({'success': True, 'player_id': player_id}), 200
    print(f"[DEBUG] Room not found for room code: {room_code}")
    return jsonify({'success': False, 'message': f'Room with code {room_code} not found'}), 404

@app.route('/create_room', methods=['POST'])
def create_room():
    data = request.json
    print("[DEBUG] Attempting to create a new room.")
    max_attempts = 10
    attempts = 0
    room_code = generate_room_code()

    # Validate input parameters
    question_goal = data.get('question_goal', 10)  # Default to 10 questions
    max_players = data.get('max_players', 8)       # Default to 8 players
    if not isinstance(question_goal, int) or question_goal <= 0:
        print("[DEBUG] Invalid question goal provided.")
        return jsonify({'success': False, 'message': 'Invalid question goal. It must be a positive integer.'}), 400
    if not isinstance(max_players, int) or max_players <= 0:
        print("[DEBUG] Invalid max players provided.")
        return jsonify({'success': False, 'message': 'Invalid max players. It must be a positive integer.'}), 400

    # Check for room code collisions and regenerate if needed
    while room_code in rooms:
        if attempts >= max_attempts:
            print("[ERROR] Maximum attempts reached while generating a unique room code.")
            return jsonify({'success': False, 'message': 'Unable to generate a unique room code after multiple attempts, please try again later.'}), 500
        room_code = generate_room_code()
        attempts += 1

    first_player_name = data.get('player_name')
    rooms[room_code] = initialize_room(room_code, first_player_name, question_goal, max_players)
    print(f"[DEBUG] Room data before adding first player: {rooms[room_code]}, host: {first_player_name}")
    rooms[room_code]['players'][first_player_name] = {
        'player_id': str(uuid.uuid4()),
        'score': 0,
        'sid': ""  # Initialize 'sid' with an empty string to avoid inconsistencies
    }
    update_last_active(room_code)  # Update last active time
    print(f"[DEBUG] Room data after adding first player: {rooms[room_code]}, host: {first_player_name}")
    print(f"[DEBUG] Room created successfully with room code: {room_code}")

    return jsonify({'room_code': room_code, 'success': True}), 200

@socketio.on('join_game')
def handle_join_game(data):
    room_code = data['room_code']
    player_name = data['player_name']
    player_id = data['player_id']
    sid = request.sid

    if room_code in rooms:
        if player_name in rooms[room_code]['players'] and rooms[room_code]['players'][player_name]['player_id'] == player_id:
            join_room(room_code)
            rooms[room_code]['players'][player_name]['sid'] = sid
            session_to_player[sid] = {'room_code': room_code, 'player_name': player_name}
            current_players = list(rooms[room_code]['players'].keys())
            update_last_active(room_code)  # Update last active time
            emit('player_joined', {'player_name': player_name, 'player_id': player_id, 'current_players': current_players}, room=room_code)
        else:
            # Player did not join via HTTP endpoint or player_id mismatch
            leave_room(room_code)
            return
    else:
        # Room does not exist
        leave_room(room_code)
        return

@app.route('/submit_answer', methods=['POST'])
def submit_answer():
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']
    correct = data['correct']
    print(f"[DEBUG] Player {player_name} submitted answer for room {room_code}. Correct: {correct}")

    if room_code in rooms and player_name in rooms[room_code]['players']:
        player = rooms[room_code]['players'][player_name]
        if correct:
            player['score'] += 1
            print(f"[DEBUG] Player {player_name} score updated to {player['score']}")

        update_last_active(room_code)  # Update last active time

        # Check if the game has ended
        if player['score'] >= rooms[room_code]['question_goal']:
            rooms[room_code]['winners'].append(player_name)
            print(f"[DEBUG] Player {player_name} won the game in room {room_code}")
            # Broadcast game end and rankings to all players
            rankings = sorted(rooms[room_code]['players'].items(), key=lambda x: x[1]['score'], reverse=True)
            emit('game_ended', {'winners': rooms[room_code]['winners'], 'rankings': rankings}, room=room_code)
            return jsonify({'game_ended': True, 'rankings': [{'player_name': player, 'score': score['score']} for player, score in rankings]}), 200

    return jsonify({'game_ended': False}), 200

@socketio.on('disconnect')
def handle_disconnect():
    sid = request.sid
    if sid in session_to_player:
        player_info = session_to_player[sid]
        room_code = player_info['room_code']
        player_name = player_info['player_name']

        if room_code in rooms and player_name in rooms[room_code]['players']:
            del rooms[room_code]['players'][player_name]
            del session_to_player[sid]
            emit('player_left', player_name, room=room_code)

def cleanup_rooms():
    current_time = time.time()
    room_count = len(rooms)
    for room_code in list(rooms.keys()):
        room = rooms[room_code]
        players_count = len(room['players'])
        last_active = room['last_active']
        creation_time = room['creation_time']

        if (room_count > MAX_ROOMS or current_time - last_active > 12 * 3600):
            print(f"[DEBUG] Evaluating room {room_code} for cleanup. Room count: {room_count}, Players count: {players_count}, Last active: {last_active}, Creation time: {creation_time}")
            if players_count == 1:
                player_name = list(room['players'].keys())[0]
                if current_time - creation_time > 3 * 3600 and current_time - last_active > 1800:
                    print(f"[DEBUG] Cleaning up room {room_code} due to inactivity. Player: {player_name}")
                    cleanup_room(room_code)
                    room_count -= 1
            elif players_count == 0:
                print(f"[DEBUG] Cleaning up empty room {room_code}")
                cleanup_room(room_code)
                room_count -= 1

# Schedule the cleanup_rooms function to be called manually every hour using SocketIO event
@socketio.on('cleanup_rooms_event')
def handle_cleanup_rooms_event():
    cleanup_rooms()

def graceful_shutdown(*args):
    print("[DEBUG] Shutting down server...")
    socketio.stop()
    sys.exit(0)

signal.signal(signal.SIGINT, graceful_shutdown)
signal.signal(signal.SIGTERM, graceful_shutdown)

socketio.run(app, host='0.0.0.0', port=3000)
print("[DEBUG] API is fully booted and ready to use.")
