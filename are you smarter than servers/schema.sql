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
);

CREATE TABLE IF NOT EXISTS player_scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_code TEXT,
    player_name TEXT,
    score INTEGER,
    timestamp REAL,
    FOREIGN KEY(room_code) REFERENCES rooms(room_code)
);
