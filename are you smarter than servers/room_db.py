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
    # Add the host to player_scores immediately after room creation
    add_or_update_player(room_code, host)

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
        conn.row_factory = sqlite3.Row  # Set row_factory to sqlite3.Row
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
                # Update existing player's timestamp without resetting wins
                wins = result['wins']  # This will now work
                conn.execute('''
                    UPDATE player_scores 
                    SET timestamp = ?
                    WHERE room_code = ? AND player_name = ?
                ''', (time.time(), room_code, player_name))
                print(f"Player {player_name} rejoined the room with {wins} wins.")

def increment_player_win(conn, room_code, player_name):
    conn.execute('''
        UPDATE player_scores
        SET wins = wins + 1, timestamp = ?
        WHERE room_code = ? AND player_name = ?
    ''', (time.time(), room_code, player_name))

def update_player_score(room_code, player_name, points_to_add, wins_to_add=0):
    with closing(sqlite3.connect(DATABASE)) as conn:
        with conn:
            conn.execute('''
                UPDATE player_scores 
                SET score = score + ?, wins = wins + ?, timestamp = ?
                WHERE room_code = ? AND player_name = ?
            ''', (points_to_add, wins_to_add, time.time(), room_code, player_name))

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

        # Allow adding new player if room isn't full and (game hasn't started or game has ended)
        if len(room['players']) < room['max_players'] and (not room['game_started'] or room['winners']):
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
            winners_json = json.dumps(winners)
            conn.execute('''
                UPDATE rooms SET game_started = ?, winners = ?, last_active = ?
                WHERE room_code = ?
            ''', (False, winners_json, time.time(), room_code))
            # Increment wins for each winner using the same connection
            for winner in winners:
                increment_player_win(conn, room_code, winner)

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

    def test_add_room_includes_host_in_player_scores(self):
        add_room('room_host_test', 'host_test', 10, 4, 'easy', categories=[1, 2, 3])
        # Fetch player scores for the room
        player_scores = get_player_scores('room_host_test')
        # Verify that the host is present in player_scores
        host_score = next((player for player in player_scores if player['player_name'] == 'host_test'), None)
        self.assertIsNotNone(host_score, "Host should be present in player_scores after room creation.")
        self.assertEqual(host_score['score'], 0, "Initial score for host should be 0.")
        self.assertEqual(host_score['wins'], 0, "Initial wins for host should be 0.")

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
        self.assertEqual(player4['wins'], 1)  # Wins should be incremented
        player5 = next(player for player in scores if player['player_name'] == 'player5')
        self.assertEqual(player5['wins'], 0)  # Non-winner's wins should remain unchanged

    def test_rejoin_after_game_end(self):
        add_room('room6', 'host6', 10, 4, 'easy')
        add_player_to_room('room6', 'player6')
        start_game('room6')
        end_game('room6', ['player6'])
        success = add_player_to_room('room6', 'player7')
        self.assertTrue(success)
        room = get_room('room6')
        self.assertIn('player7', room['players'])

    def test_max_players_limit(self):
        # Updated test: Increased max_players to 3 to allow two additional players besides the host
        add_room('room7', 'host7', 10, 3, 'easy')    # Set max_players to 3
        success = add_player_to_room('room7', 'player8')
        self.assertTrue(success)                     # Should succeed
        success = add_player_to_room('room7', 'player9')
        self.assertTrue(success)                     # Should now succeed
        # Try adding beyond max capacity
        success = add_player_to_room('room7', 'player10')
        self.assertFalse(success)                    # Should fail
        room = get_room('room7')
        self.assertEqual(len(room['players']), 3)    # Expect 3 players

    def test_start_game_and_player_scores(self):
        add_room('room8', 'host8', 5, 3, 'medium')
        add_player_to_room('room8', 'player11')
        start_game('room8')
        room = get_room('room8')
        self.assertTrue(room['game_started'])
        # Ensure all players are in player_scores
        scores = get_player_scores('room8')
        player_names = [score['player_name'] for score in scores]
        self.assertIn('host8', player_names)
        self.assertIn('player11', player_names)

    def test_submit_answer_and_score_update(self):
        add_room('room9', 'host9', 3, 2, 'hard')
        add_player_to_room('room9', 'player12')
        start_game('room9')
        update_player_score('room9', 'host9', 1)
        update_player_score('room9', 'player12', 2)
        scores = get_player_scores('room9')
        host_score = next(score for score in scores if score['player_name'] == 'host9')
        player12_score = next(score for score in scores if score['player_name'] == 'player12')
        self.assertEqual(host_score['score'], 1)
        self.assertEqual(player12_score['score'], 2)

    def test_cannot_join_during_active_game(self):
        add_room('room10', 'host10', 10, 4, 'easy')
        add_player_to_room('room10', 'player13')
        start_game('room10')
        success = add_player_to_room('room10', 'player14')
        self.assertFalse(success)
        room = get_room('room10')
        self.assertNotIn('player14', room['players'])

    def test_cleanup_empty_room(self):
        add_room('room11', 'host11', 10, 4, 'easy')
        remove_player_from_room('room11', 'host11')
        room = get_room('room11')
        self.assertIsNotNone(room)  # Room still exists because we haven't implemented auto-cleanup
        # Implement cleanup logic if no players
        if not room['players']:
            delete_room('room11')
        room_after_cleanup = get_room('room11')
        self.assertIsNone(room_after_cleanup)

    def test_get_game_history(self):
        add_room('room12', 'host12', 5, 2, 'medium')
        add_player_to_room('room12', 'player15')
        start_game('room12')
        update_player_score('room12', 'host12', 3)
        update_player_score('room12', 'player15', 5)
        history = get_game_history('room12')
        self.assertEqual(len(history), 2)
        player15_history = next(entry for entry in history if entry['player_name'] == 'player15')
        self.assertEqual(player15_history['score'], 5)

    def test_get_player_statistics(self):
        add_room('room13', 'host13', 10, 3, 'hard')
        add_player_to_room('room13', 'player16')
        start_game('room13')
        update_player_score('room13', 'player16', 7)
        end_game('room13', ['player16'])
        stats = get_player_statistics('player16')
        self.assertGreaterEqual(len(stats), 1)
        latest_stat = stats[0]
        self.assertEqual(latest_stat['score'], 7)
        self.assertEqual(latest_stat['wins'], 1)  # Wins should be incremented

    def test_wins_track_per_lobby(self):
        # Create two separate rooms
        add_room('room14', 'host14', 10, 3, 'easy')
        add_room('room15', 'host15', 10, 3, 'medium')

        # Add players to room14
        add_player_to_room('room14', 'player17')
        add_player_to_room('room14', 'player18')

        # Add players to room15
        add_player_to_room('room15', 'player19')
        add_player_to_room('room15', 'player20')

        # Start and end game in room14, player17 wins
        start_game('room14')
        end_game('room14', ['player17'])

        # Start and end game in room15, player19 and player20 win
        start_game('room15')
        end_game('room15', ['player19', 'player20'])

        # Check wins in room14
        scores_room14 = get_player_scores('room14')
        player17_room14 = next(player for player in scores_room14 if player['player_name'] == 'player17')
        player18_room14 = next(player for player in scores_room14 if player['player_name'] == 'player18')
        self.assertEqual(player17_room14['wins'], 1)
        self.assertEqual(player18_room14['wins'], 0)

        # Check wins in room15
        scores_room15 = get_player_scores('room15')
        player19_room15 = next(player for player in scores_room15 if player['player_name'] == 'player19')
        player20_room15 = next(player for player in scores_room15 if player['player_name'] == 'player20')
        host15_room15 = next(player for player in scores_room15 if player['player_name'] == 'host15')
        self.assertEqual(player19_room15['wins'], 1)
        self.assertEqual(player20_room15['wins'], 1)
        self.assertEqual(host15_room15['wins'], 0)

    def test_multiple_wins_in_single_lobby(self):
        add_room('room16', 'host16', 10, 4, 'hard')
        add_player_to_room('room16', 'player21')
        add_player_to_room('room16', 'player22')
        add_player_to_room('room16', 'player23')

        # Start and end game multiple times
        start_game('room16')
        end_game('room16', ['player21'])
        start_game('room16')
        end_game('room16', ['player21', 'player22'])
        start_game('room16')
        end_game('room16', ['player23'])

        # Check wins
        scores = get_player_scores('room16')
        player21 = next(player for player in scores if player['player_name'] == 'player21')
        player22 = next(player for player in scores if player['player_name'] == 'player22')
        player23 = next(player for player in scores if player['player_name'] == 'player23')
        host16 = next(player for player in scores if player['player_name'] == 'host16')

        self.assertEqual(player21['wins'], 2)
        self.assertEqual(player22['wins'], 1)
        self.assertEqual(player23['wins'], 1)
        self.assertEqual(host16['wins'], 0)

if __name__ == '__main__':
    unittest.main()