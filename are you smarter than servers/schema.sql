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
