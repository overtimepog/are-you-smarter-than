import unittest
import sqlite3
from room_db import init_db, add_room, get_room, update_room, add_player_score, get_player_scores, get_player_statistics, get_game_history

class TestDatabaseFunctions(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Initialize the database schema
        init_db()

    def setUp(self):
        # Re-initialize the database schema to ensure a clean state for each test
        init_db()
        self.conn = sqlite3.connect('trivia_game.db')
        self.cursor = self.conn.cursor()

    def tearDown(self):
        # Close the database connection
        self.conn.close()

    def test_add_and_get_room(self):
        print("[DEBUG] Running test_add_and_get_room")
        add_room('test123', 'host1', 10, 4)
        room = get_room('test123')
        self.assertIsNotNone(room)
        self.assertEqual(room['room_code'], 'test123')
        self.assertEqual(room['host'], 'host1')

    def test_update_room(self):
        print("[DEBUG] Running test_update_room")
        add_room('test456', 'host2', 5, 3)
        update_room('test456', players=['player1', 'player2'], game_started=True)
        room = get_room('test456')
        self.assertTrue(room['game_started'])
        self.assertEqual(room['players'], ['player1', 'player2'])

    def test_add_and_get_player_score(self):
        print("[DEBUG] Running test_add_and_get_player_score")
        add_player_score('test123', 'player1', 100)
        scores = get_player_scores('test123')
        self.assertEqual(len(scores), 1)
        self.assertEqual(scores[0]['player_name'], 'player1')
        self.assertEqual(scores[0]['score'], 100)

    def test_get_player_statistics(self):
        print("[DEBUG] Running test_get_player_statistics")
        add_player_score('test123', 'player2', 150)
        stats = get_player_statistics('player2')
        self.assertEqual(len(stats), 1)
        self.assertEqual(stats[0]['score'], 150)

    def test_get_game_history(self):
        print("[DEBUG] Running test_get_game_history")
        add_player_score('test123', 'player1', 100)
        add_player_score('test123', 'player2', 150)
        add_player_score('test123', 'player3', 200)
        history = get_game_history('test123')
        self.assertEqual(len(history), 2)  # Assuming previous tests added scores
        self.assertEqual(history[-1]['player_name'], 'player3')
        self.assertEqual(history[-1]['score'], 200)

if __name__ == '__main__':
    unittest.main()
