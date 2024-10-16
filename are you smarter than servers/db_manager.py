# db_manager.py

import sqlite3
import os
from typing import List, Optional

class DBManager:
    def __init__(self, db_file: str):
        """Initialize the database manager with the given SQLite database file."""
        self.db_file = db_file
        self._initialize_db()

    def _initialize_db(self):
        """Create the database and initialize the connection."""
        db_exists = os.path.exists(self.db_file)
        self.connection = sqlite3.connect(self.db_file, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row  # Enable named access to columns
        self.cursor = self.connection.cursor()
        if not db_exists:
            print(f"Creating new database at {self.db_file}")
            self._create_tables()
        else:
            print(f"Database found at {self.db_file}, connected.")

    def _create_tables(self):
        """Create tables from schema.sql if they don't already exist."""
        with open('schema.sql', 'r') as f:
            schema = f.read()

        # Execute each statement separately to avoid issues
        statements = schema.strip().split(";")
        for statement in statements:
            if statement.strip():
                try:
                    self.cursor.execute(statement)
                except sqlite3.OperationalError as e:
                    print(f"Skipping table creation: {e}")
        self.connection.commit()

    def add_player(self, username: str, device_token: str) -> bool:
        """Add a new player to the database."""
        if not username or not isinstance(username, str):
            print("Invalid username provided.")
            return False
        try:
            self.cursor.execute(
                "INSERT INTO players (username, device_token) VALUES (?, ?)",
                (username, device_token)
            )
            self.connection.commit()
            return True
        except sqlite3.IntegrityError as e:
            print(f"Error adding player: {e}")
            return False

    def get_player(self, username: str) -> Optional[sqlite3.Row]:
        """Retrieve a player's information by username."""
        self.cursor.execute("SELECT * FROM players WHERE username = ?", (username,))
        return self.cursor.fetchone()

    def get_player_by_device_token(self, device_token: str) -> Optional[sqlite3.Row]:
        """Retrieve a player's information by device token."""
        self.cursor.execute("SELECT * FROM players WHERE device_token = ?", (device_token,))
        return self.cursor.fetchone()

    def get_player_by_id(self, player_id: int) -> Optional[sqlite3.Row]:
        """Retrieve a player's information by ID."""
        self.cursor.execute("SELECT * FROM players WHERE id = ?", (player_id,))
        return self.cursor.fetchone()

    def update_crowns(self, player_id: int, crowns: int) -> None:
        """Update the number of crowns for a player."""
        try:
            self.cursor.execute("UPDATE players SET crowns = ? WHERE id = ?", (crowns, player_id))
            self.connection.commit()
        except sqlite3.Error as e:
            print(f"Error updating crowns: {e}")

    def create_game(self, player1_id: int, player2_id: int) -> int:
        """Create a new game and return the game ID."""
        try:
            self.cursor.execute(
                "INSERT INTO games (player1_id, player2_id) VALUES (?, ?)",
                (player1_id, player2_id)
            )
            self.connection.commit()
            return self.cursor.lastrowid
        except sqlite3.Error as e:
            print(f"Error creating game: {e}")
            return -1

    def update_winner(self, game_id: int, winner_id: int) -> None:
        """Update the winner of a game."""
        try:
            self.cursor.execute(
                "UPDATE games SET winner_id = ?, end_time = CURRENT_TIMESTAMP WHERE id = ?",
                (winner_id, game_id)
            )
            self.connection.commit()
        except sqlite3.Error as e:
            print(f"Error updating winner: {e}")

    def get_game(self, game_id: int) -> Optional[sqlite3.Row]:
        """Retrieve a game by its ID."""
        self.cursor.execute("SELECT * FROM games WHERE id = ?", (game_id,))
        return self.cursor.fetchone()

    def add_game_progress(
        self, game_id: int, player_id: int, question_id: int, 
        selected_answer: str, is_correct: bool
    ) -> None:
        """Add a player's progress for a specific game."""
        try:
            self.cursor.execute(
                """
                INSERT INTO game_progress (
                    game_id, player_id, question_id, selected_answer, 
                    is_correct
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (game_id, player_id, question_id, selected_answer, int(is_correct))
            )
            self.connection.commit()
        except sqlite3.Error as e:
            print(f"Error adding game progress: {e}")

    def get_game_progress(self, game_id: int) -> List[sqlite3.Row]:
        """Retrieve the progress for a specific game."""
        self.cursor.execute("SELECT * FROM game_progress WHERE game_id = ?", (game_id,))
        return self.cursor.fetchall()

    def add_category(self, category_id: int, name: str, emoji: str) -> None:
        """Add a new category."""
        try:
            self.cursor.execute(
                "INSERT INTO categories (id, name, emoji) VALUES (?, ?, ?)",
                (category_id, name, emoji)
            )
            self.connection.commit()
        except sqlite3.IntegrityError as e:
            print(f"Error adding category: {e}")
        except sqlite3.Error as e:
            print(f"Error adding category: {e}")

    def get_all_categories(self) -> List[sqlite3.Row]:
        """Retrieve all categories."""
        self.cursor.execute("SELECT * FROM categories")
        return self.cursor.fetchall()

    def add_question(self, question: str, correct_answer: str) -> int:
        """Add a new question to the database."""
        try:
            self.cursor.execute(
                "INSERT INTO questions (question, correct_answer) VALUES (?, ?)",
                (question, correct_answer)
            )
            self.connection.commit()
            return self.cursor.lastrowid
        except sqlite3.Error as e:
            print(f"Error adding question: {e}")
            return -1

    def get_question_by_id(self, question_id: int) -> Optional[sqlite3.Row]:
        """Retrieve a question by its ID."""
        self.cursor.execute("SELECT * FROM questions WHERE id = ?", (question_id,))
        return self.cursor.fetchone()

    def close(self):
        """Close the database connection."""
        if self.connection:
            print("Closing database connection.")
            self.connection.close()
