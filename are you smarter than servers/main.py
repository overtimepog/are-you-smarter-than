from flask import Flask, request, jsonify
from flask_socketio import SocketIO, join_room, leave_room, emit
import random
import string
import uuid
import threading

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

rooms = {}  # Store room data including question goals and players
rooms_lock = threading.Lock()  # Lock to prevent race conditions when accessing the rooms dictionary

def generate_room_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

@app.route('/create_room', methods=['POST'])
def create_room():
    data = request.json
    room_code = generate_room_code()
    question_goal = data.get('question_goal', 10)  # Default to 10 questions
    max_players = data.get('max_players', 8)       # Default to 8 players

    # Check for room code collisions and regenerate if needed
    with rooms_lock:
        while room_code in rooms:
            room_code = generate_room_code()

        rooms[room_code] = {
            'players': {},
            'game_started': False,
            'question_goal': question_goal,
            'max_players': max_players
        }
    return jsonify({'room_code': room_code})

@app.route('/join_room', methods=['POST'])
def join_room_route():
    data = request.json
    room_code = data['room_code']
    player_name = data['player_name']

    with rooms_lock:
        if room_code in rooms:
            if len(rooms[room_code]['players']) >= rooms[room_code]['max_players']:
                return jsonify({'success': False, 'message': 'Room is full'}), 403

            player_id = str(uuid.uuid4())  # Generate a unique player identifier
            rooms[room_code]['players'][player_name] = {
                'player_id': player_id,
                'score': 0,
                'sid': None  # Will be set when the player connects via SocketIO
            }
            return jsonify({'success': True})
    return jsonify({'success': False, 'message': 'Room not found'}), 404

@app.route('/get_players', methods=['POST'])
def get_players():
    data = request.json
    room_code = data['room_code']

    with rooms_lock:
        if room_code in rooms:
            players = list(rooms[room_code]['players'].keys())
            return jsonify({'players': players})
    return jsonify({'success': False, 'message': 'Room not found'}), 404

@socketio.on('join_game')
def handle_join_game(data):
    room_code = data['room_code']
    player_name = data['player_name']
    sid = request.sid

    with rooms_lock:
        if room_code in rooms:
            join_room(room_code)
            if player_name in rooms[room_code]['players']:
                rooms[room_code]['players'][player_name]['sid'] = sid
                emit('player_joined', player_name, room=room_code)
            else:
                # Player did not join via HTTP endpoint
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
            rooms[room_code]['game_started'] = True
            emit('game_started', room=room_code)
        else:
            return

@socketio.on('correct_answer')
def handle_correct_answer(data):
    room_code = data['room_code']
    player_name = data['player_name']

    with rooms_lock:
        if room_code in rooms and player_name in rooms[room_code]['players']:
            rooms[room_code]['players'][player_name]['score'] += 1
            current_score = rooms[room_code]['players'][player_name]['score']
            question_goal = rooms[room_code]['question_goal']

            if current_score >= question_goal:
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

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=3000)
