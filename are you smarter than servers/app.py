from flask import Flask, request, jsonify, render_template_string
from flask_socketio import SocketIO, join_room, leave_room, emit
import random
import time
import threading
import string
import uuid
import threading

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

rooms = {}  # Store room data including question goals and players
rooms_lock = threading.Lock()  # Lock to prevent race conditions when accessing the rooms dictionary

def generate_room_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

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
    print(f"[DEBUG] Room Info: {rooms.get(room_code)}")
    with rooms_lock:
        room = rooms.get(room_code)
        if room:
            players = list(room['players'].keys())
            return jsonify({
                'room_code': room_code,
                'players': players,
                'question_goal': room['question_goal'],
                'max_players': room['max_players'],
                'game_started': room['game_started'],
                'winners': room['winners']
            }), 200
    return jsonify({'success': False, 'message': 'Room not found'}), 404

@app.route('/leave_room', methods=['POST'])
def leave_room_route():
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']

    with rooms_lock:
        if room_code in rooms and player_name in rooms[room_code]['players']:
            del rooms[room_code]['players'][player_name]
            rooms[room_code]['last_active'] = time.time()  # Update last active time when a player leaves
            if not rooms[room_code]['players']:
                del rooms[room_code]  # Delete room if no players are left
            return jsonify({'success': True, 'message': 'Player left the room'}), 200
    print(f"[DEBUG] Room or player not found for room code: {room_code}, player name: {player_name}")

@app.route('/create_room', methods=['POST'])
def create_room():
    data = request.json
    print("[DEBUG] Attempting to create a new room.")
    room_code = generate_room_code()
    question_goal = data.get('question_goal', 10)  # Default to 10 questions
    max_players = data.get('max_players', 8)       # Default to 8 players

    # Check for room code collisions and regenerate if needed
    with rooms_lock:
        while room_code in rooms:
            room_code = generate_room_code()

        first_player_name = data.get('player_name')
        rooms[room_code] = {
            'host': first_player_name,
            'players': {},
            'game_started': False,
            'question_goal': question_goal,
            'max_players': max_players,
            'winners': [],
            'last_active': time.time()
        }
    rooms[room_code]['players'][first_player_name] = {
        'player_id': str(uuid.uuid4()),
        'score': 0,
        'sid': None
    }
    print(f"[DEBUG] Room created successfully with room code: {room_code}")
    return jsonify({'room_code': room_code, 'success': True}), 200

@app.route('/join_room', methods=['POST'])
def join_room_route():
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']

    with rooms_lock:
        if room_code in rooms:
            if player_name in rooms[room_code]['players']:
                return jsonify({'success': False, 'message': 'Username already taken'}), 403

            if len(rooms[room_code]['players']) >= rooms[room_code]['max_players']:
                return jsonify({'success': False, 'message': 'Room is full'}), 403

            player_id = str(uuid.uuid4())  # Generate a unique player identifier
            rooms[room_code]['players'][player_name] = {
                'player_id': player_id,
                'score': 0,
                'sid': None  # Will be set when the player connects via SocketIO
            }
            rooms[room_code]['last_active'] = time.time()  # Update last active time when a player joins
            return jsonify({'success': True, 'player_id': player_id}), 200
    return jsonify({'success': False, 'message': 'Room not found'}), 404

@app.route('/submit_answer', methods=['POST'])
def submit_answer():
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']
    correct = data['correct']

    with rooms_lock:
        if room_code in rooms and player_name in rooms[room_code]['players']:
            player = rooms[room_code]['players'][player_name]
            if correct:
                player['score'] += 1

            # Check if the game has ended
            if player['score'] >= rooms[room_code]['question_goal']:
                rooms[room_code]['winners'].append(player_name)
                return jsonify({'game_ended': True}), 200

    return jsonify({'game_ended': False}), 200
def get_players():
    data = request.json
    room_code = data['room_code']

    with rooms_lock:
        if room_code in rooms:
            players = list(rooms[room_code]['players'].keys())
            return jsonify({'players': players, 'winners': rooms[room_code]['winners']})
    return jsonify({'success': False, 'message': 'Room not found'}), 404

@socketio.on('join_game')
def handle_join_game(data):
    room_code = data['room_code']
    player_name = data['player_name']
    player_id = data['player_id']
    sid = request.sid

    with rooms_lock:
        if room_code in rooms:
            if player_name in rooms[room_code]['players'] and rooms[room_code]['players'][player_name]['player_id'] == player_id:
                join_room(room_code)
                rooms[room_code]['players'][player_name]['sid'] = sid
                emit('player_joined', player_name, room=room_code)
            else:
                # Player did not join via HTTP endpoint or player_id mismatch
                leave_room(room_code)
                return
        else:
            # Room does not exist
            leave_room(room_code)
            return

@socketio.on('start_game')
def handle_start_game(data):
    room_code = data['room_code']

    with rooms_lock:
        if room_code in rooms:
            if data['player_name'] == rooms[room_code]['host']:
                rooms[room_code]['game_started'] = True
            emit('game_started', room=room_code)
        else:
            return

@socketio.on('correct_answer')
def handle_correct_answer(data):
    room_code = data['room_code']
    player_name = data['player_name']
    player_id = data['player_id']

    with rooms_lock:
        if room_code in rooms and player_name in rooms[room_code]['players']:
            # Verify the player_id matches the stored player_id and session ID matches
            player = rooms[room_code]['players'][player_name]
            if player['player_id'] == player_id and player['sid'] == request.sid:
                player['score'] += 1
                current_score = player['score']
                question_goal = rooms[room_code]['question_goal']

                if current_score >= question_goal:
                    rooms[room_code]['winners'].append(player_name)
                    emit('game_won', player_name, room=room_code)
                else:
                    emit('player_correct', {'player': player_name, 'score': current_score}, room=room_code)

@socketio.on('disconnect')
def handle_disconnect():
    sid = request.sid
    with rooms_lock:
        for room_code, room in rooms.items():
            for player_name in list(room['players']):
                if sid == room['players'][player_name]['sid']:
                    del room['players'][player_name]
                    emit('player_left', player_name, room=room_code)
                    break
                
def generate_room_code():
    return ''.join(random.choices(string.ascii_uppercase, k=6))

def cleanup_rooms():
    while True:
        with rooms_lock:
            current_time = time.time()
            for room_code in list(rooms.keys()):
                room = rooms[room_code]
                if (not room['players'] or (current_time - room['last_active'] > 3 * 3600)):
                    del rooms[room_code]
        time.sleep(3600)  # Check every hour

cleanup_thread = threading.Thread(target=cleanup_rooms, daemon=True)
cleanup_thread.start()
socketio.run(app, host='0.0.0.0', port=3000)
print("[DEBUG] API is fully booted and ready to use.")
