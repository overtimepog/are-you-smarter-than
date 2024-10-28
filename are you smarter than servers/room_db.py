import sqlite3
import time
import json
import unittest
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

def add_room(room_code, host, question_goal, max_players, difficulty, categories=None):
    players = [host]
    categories_json = json.dumps(categories if categories is not None else [])
    players_json = json.dumps(players)
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('''
                INSERT INTO rooms (
                    room_code, host, players, game_started, question_goal, max_players, winners,
                    difficulty, categories, last_active, creation_time
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                room_code, host, players_json, False, question_goal, max_players, '[]',
                difficulty, categories_json, time.time(), time.time()
            ))

def get_room(room_code):
    with closing(sqlite3.connect(DATABASE)) as conn:
        conn.row_factory = sqlite3.Row
        with conn:
            room = conn.execute('SELECT * FROM rooms WHERE room_code = ?', (room_code,)).fetchone()
            if room:
                return {
                    'room_code': room['room_code'],
                    'host': room['host'],
                    'players': json.loads(room['players']) if room['players'] else [],
                    'game_started': bool(room['game_started']),
                    'question_goal': room['question_goal'],
                    'max_players': room['max_players'],
                    'winners': json.loads(room['winners']) if room['winners'] else [],
                    'difficulty': room['difficulty'],
                    'categories': json.loads(room['categories']) if room['categories'] else [],
                    'last_active': room['last_active'],
                    'creation_time': room['creation_time'],
                }
            return None

def get_all_rooms():
    with closing(sqlite3.connect(DATABASE)) as conn:
        conn.row_factory = sqlite3.Row
        with conn:
            rooms = conn.execute('SELECT * FROM rooms').fetchall()
            return [{
                'room_code': room['room_code'],
                'host': room['host'],
                'players': json.loads(room['players']) if room['players'] else [],
                'game_started': bool(room['game_started']),
                'question_goal': room['question_goal'],
                'max_players': room['max_players'],
                'winners': json.loads(room['winners']) if room['winners'] else [],
                'difficulty': room['difficulty'],
                'categories': json.loads(room['categories']) if room['categories'] else [],
                'last_active': room['last_active'],
                'creation_time': room['creation_time'],
            } for room in rooms]

def update_room(room_code, players=None, game_started=None, winners=None, last_active=None):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            if players is not None:
                players_json = json.dumps(players)
                conn.execute('UPDATE rooms SET players = ? WHERE room_code = ?', (players_json, room_code))
            if game_started is not None:
                conn.execute('UPDATE rooms SET game_started = ? WHERE room_code = ?', (game_started, room_code))
            if winners is not None:
                winners_json = json.dumps(winners)
                conn.execute('UPDATE rooms SET winners = ? WHERE room_code = ?', (winners_json, room_code))
            if last_active is not None:
                conn.execute('UPDATE rooms SET last_active = ? WHERE room_code = ?', (last_active, room_code))

def add_or_update_player(room_code, player_name):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            result = conn.execute('''
                SELECT id, wins FROM player_scores WHERE room_code = ? AND player_name = ?
            ''', (room_code, player_name)).fetchone()

            if result is None:
                conn.execute('''
                    INSERT INTO player_scores (room_code, player_name, score, wins, timestamp)
                    VALUES (?, ?, ?, ?, ?)
                ''', (room_code, player_name, 0, 0, time.time()))
            else:
                # Update existing player's timestamp and ensure wins are tracked
                wins = result['wins']
                conn.execute('''
                    UPDATE player_scores 
                    SET timestamp = ?, wins = ?
                    WHERE room_code = ? AND player_name = ?
                ''', (time.time(), wins, room_code, player_name))
                print(f"Player {player_name} rejoined the room with {wins} wins.")

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
                increment_player_win(room_code, winner)  # Increment wins for each winner
            winners_json = json.dumps(winners)
            conn.execute('''
                UPDATE rooms SET game_started = ?, winners = ?, last_active = ?
                WHERE room_code = ?
            ''', (False, winners_json, time.time(), room_code))

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

# Unit tests
class TestTriviaGameDatabase(unittest.TestCase):
    def setUp(self):
        init_db()

    def test_add_and_get_room(self):
        add_room('room1', 'host1', 10, 4, 'easy', categories=[9, 10, 11])
        room = get_room('room1')
        self.assertIsNotNone(room)
        self.assertEqual(room['room_code'], 'room1')
        self.assertEqual(room['host'], 'host1')
        self.assertEqual(room['question_goal'], 10)
        self.assertEqual(room['max_players'], 4)
        self.assertEqual(room['difficulty'], 'easy')
        self.assertEqual(room['categories'], [9, 10, 11])

    def test_get_all_rooms(self):
        add_room('room1', 'host1', 10, 4, 'easy', categories=[9, 10])
        add_room('room2', 'host2', 15, 5, 'medium', categories=[11, 12])
        rooms = get_all_rooms()
        self.assertEqual(len(rooms), 2)
        room_codes = [room['room_code'] for room in rooms]
        self.assertIn('room1', room_codes)
        self.assertIn('room2', room_codes)

    def test_add_player_to_room(self):
        add_room('room2', 'host2', 15, 3, 'medium')
        success = add_player_to_room('room2', 'player1')
        self.assertTrue(success)
        room = get_room('room2')
        self.assertIn('player1', room['players'])

    def test_remove_player_from_room(self):
        add_room('room3', 'host3', 5, 2, 'hard')
        add_player_to_room('room3', 'player2')
        success = remove_player_from_room('room3', 'player2')
        self.assertTrue(success)
        room = get_room('room3')
        self.assertNotIn('player2', room['players'])

    def test_update_player_score(self):
        add_room('room4', 'host4', 20, 5, 'easy')
        add_player_to_room('room4', 'player3')
        update_player_score('room4', 'player3', 10)
        scores = get_player_scores('room4')
        self.assertEqual(scores[0]['score'], 10)

    def test_end_game(self):
        add_room('room5', 'host5', 25, 4, 'medium')
        add_player_to_room('room5', 'player4')
        add_player_to_room('room5', 'player5')
        end_game('room5', ['player4'])
        room = get_room('room5')
        self.assertFalse(room['game_started'])
        self.assertEqual(room['winners'], ['player4'])
        scores = get_player_scores('room5')
        player4 = next(player for player in scores if player['player_name'] == 'player4')
        self.assertEqual(player4['wins'], 1)

if __name__ == '__main__':
    unittest.main()
