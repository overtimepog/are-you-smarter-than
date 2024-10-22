CREATE TABLE IF NOT EXISTS rooms (
    room_code TEXT PRIMARY KEY,
    host TEXT,
    players TEXT,
    game_started BOOLEAN,
    question_goal INTEGER,
    max_players INTEGER,
    winners TEXT,
    difficulty TEXT CHECK(difficulty IN ('easy', 'medium', 'hard')),
    last_active REAL,
    creation_time REAL
);

CREATE TABLE IF NOT EXISTS player_scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_code TEXT NOT NULL,
    player_name TEXT NOT NULL,
    score INTEGER NOT NULL,
    timestamp REAL NOT NULL,
    FOREIGN KEY(room_code) REFERENCES rooms(room_code)
);