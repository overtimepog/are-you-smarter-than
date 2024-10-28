import sqlite3
import time
from contextlib import closing

DATABASE = 'trivia_game.db'

def init_db():
    with open('schema.sql', 'r') as f:
        schema = f.read()
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('DROP TABLE IF EXISTS player_scores')
            conn.execute('DROP TABLE IF EXISTS rooms')
        with conn:
            conn.executescript(schema)

def add_room(room_code, host, question_goal, max_players, difficulty):
    players = [host]
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('''
                INSERT INTO rooms (room_code, host, players, game_started, question_goal, max_players, winners, last_active, creation_time, difficulty)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (room_code, host, str(players), False, question_goal, max_players, '[]', time.time(), time.time(), difficulty))

def get_room(room_code):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            room = conn.execute('SELECT * FROM rooms WHERE room_code = ?', (room_code,)).fetchone()
            if room:
                return {
                    'room_code': room[0],
                    'host': room[1],
                    'players': eval(room[2]),
                    'game_started': room[3],
                    'question_goal': room[4],
                    'max_players': room[5],
                    'winners': eval(room[6]),
                    'last_active': room[7],
                    'creation_time': room[8],
                    'difficulty': room[9]
                }
            return None

def update_room(room_code, players=None, game_started=None, winners=None, last_active=None):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            if players is not None:
                conn.execute('UPDATE rooms SET players = ? WHERE room_code = ?', (str(players), room_code))
            if game_started is not None:
                conn.execute('UPDATE rooms SET game_started = ? WHERE room_code = ?', (game_started, room_code))
            if winners is not None:
                conn.execute('UPDATE rooms SET winners = ? WHERE room_code = ?', (str(winners), room_code))
            if last_active is not None:
                conn.execute('UPDATE rooms SET last_active = ? WHERE room_code = ?', (last_active, room_code))

def add_or_update_player(room_code, player_name):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            result = conn.execute('''
                SELECT id FROM player_scores WHERE room_code = ? AND player_name = ?
            ''', (room_code, player_name)).fetchone()

            if result is None:
                conn.execute('''
                    INSERT INTO player_scores (room_code, player_name, score, wins, timestamp)
                    VALUES (?, ?, ?, ?, ?)
                ''', (room_code, player_name, 0, 0, time.time()))
            else:
                # Update existing player's timestamp
                conn.execute('''
                    UPDATE player_scores 
                    SET timestamp = ?
                    WHERE room_code = ? AND player_name = ?
                ''', (time.time(), room_code, player_name))
                print(f"Player {player_name} rejoined the room.")

def increment_player_win(room_code, player_name):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('''
                UPDATE player_scores
                SET wins = wins + 1, timestamp = ?
                WHERE room_code = ? AND player_name = ?
            ''', (time.time(), room_code, player_name))

def update_player_score(room_code, player_name, points_to_add):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('''
                UPDATE player_scores 
                SET score = score + ?, timestamp = ?
                WHERE room_code = ? AND player_name = ?
            ''', (points_to_add, time.time(), room_code, player_name))

def get_player_scores(room_code):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            scores = conn.execute('''
                SELECT player_name, score, wins FROM player_scores WHERE room_code = ?
            ''', (room_code,)).fetchall()
            return [{'player_name': score[0], 'score': score[1], 'wins': score[2]} for score in scores]

def get_player_statistics(player_name):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            stats = conn.execute('''
                SELECT room_code, score, wins, timestamp FROM player_scores WHERE player_name = ?
            ''', (player_name,)).fetchall()
            return [{'room_code': stat[0], 'score': stat[1], 'wins': stat[2], 'timestamp': stat[3]} for stat in stats]

def add_player_to_room(room_code, player_name):
    room = get_room(room_code)
    if room:
        # Allow rejoining if player was already in the room
        if player_name in room['players']:
            update_room(room_code, last_active=time.time())
            add_or_update_player(room_code, player_name)
            return True
            
        # Add new player if room isn't full and game hasn't started
        if len(room['players']) < room['max_players'] and not room['game_started']:
            room['players'].append(player_name)
            update_room(room_code, players=room['players'], last_active=time.time())
            add_or_update_player(room_code, player_name)
            return True
    return False

def remove_player_from_room(room_code, player_name):
    room = get_room(room_code)
    if room and player_name in room['players']:
        room['players'].remove(player_name)
        update_room(room_code, players=room['players'], last_active=time.time())
        return True
    return False

def end_game(room_code, winners):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            for winner in winners:
                increment_player_win(room_code, winner)
            conn.execute('''
                UPDATE rooms SET game_started = ?, winners = ?, last_active = ?
                WHERE room_code = ?
            ''', (False, str(winners), time.time(), room_code))

def delete_room(room_code):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('DELETE FROM rooms WHERE room_code = ?', (room_code,))
            conn.execute('DELETE FROM player_scores WHERE room_code = ?', (room_code,))

def get_game_history(room_code):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            history = conn.execute('''
                SELECT player_name, score, wins, timestamp
                FROM player_scores WHERE room_code = ?
            ''', (room_code,)).fetchall()
            return [{'player_name': entry[0], 'score': entry[1], 'wins': entry[2], 'timestamp': entry[3]} for entry in history]

def start_game(room_code):
    """Starts the game and ensures all players are added to player_scores."""
    room = get_room(room_code)
    if room:
        # Add all players to the player_scores table if they don't exist already
        for player_name in room['players']:
            add_or_update_player(room_code, player_name)

        with closing(sqlite3.connect(DATABASE)) as conn:
            with conn:
                conn.execute('''
                    UPDATE rooms SET game_started = ?, last_active = ?
                    WHERE room_code = ?
                ''', (True, time.time(), room_code))
