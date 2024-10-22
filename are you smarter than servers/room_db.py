import sqlite3
import time
from contextlib import closing

DATABASE = 'trivia_game.db'

def init_db():
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS rooms (
                    room_code TEXT PRIMARY KEY,
                    host TEXT,
                    players TEXT,
                    game_started BOOLEAN,
                    question_goal INTEGER,
                    max_players INTEGER,
                    winners TEXT,
                    last_active REAL,
                    creation_time REAL
                )
            ''')

def add_room(room_code, host, question_goal, max_players):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('''
                INSERT INTO rooms (room_code, host, players, game_started, question_goal, max_players, winners, last_active, creation_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (room_code, host, '{}', False, question_goal, max_players, '[]', time.time(), time.time()))

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
                    'creation_time': room[8]
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

def get_all_rooms():
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            rooms = conn.execute('SELECT room_code FROM rooms').fetchall()
            return [room[0] for room in rooms]
def delete_room(room_code):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('DELETE FROM rooms WHERE room_code = ?', (room_code,))