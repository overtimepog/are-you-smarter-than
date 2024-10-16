# main.py

from flask import Flask, jsonify, request, abort, g
from db_manager import DBManager
from functools import wraps
import uuid

# Initialize the Flask app and the database manager
app = Flask(__name__)
db = DBManager("trivia_game.db")

def device_token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        device_token = None
        if 'Device-Token' in request.headers:
            device_token = request.headers['Device-Token']

        if not device_token:
            return jsonify({'message': 'Device token is missing!'}), 401

        player = db.get_player_by_device_token(device_token)
        if not player:
            return jsonify({'message': 'Invalid device token!'}), 401

        g.current_user = player
        return f(*args, **kwargs)
    return decorated

# User registration (no password required)
@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    username = data.get("username")
    if not username:
        abort(400, "Username is required")
    if db.get_player(username):
        abort(400, "Username already exists")
    device_token = str(uuid.uuid4())
    success = db.add_player(username, device_token)
    if not success:
        abort(400, "Username or device token already exists")
    # Send the device token to the client
    return jsonify({"message": f"Player '{username}' registered successfully.", "device_token": device_token}), 201

# Player routes
@app.route("/players/me", methods=["GET"])
@device_token_required
def get_current_player():
    player = g.current_user
    # Exclude device_token from the response for security
    player_data = dict(player)
    player_data.pop('device_token', None)
    return jsonify(player_data)

# Game routes
@app.route("/games/", methods=["POST"])
@device_token_required
def create_game():
    data = request.get_json()
    player2_id = data.get("player2_id")
    player1_id = g.current_user['id']
    if not player2_id:
        abort(400, "player2_id is required")
    # Ensure player2 exists
    player2 = db.get_player_by_id(player2_id)
    if not player2:
        abort(400, "Player 2 not found")
    game_id = db.create_game(player1_id, player2_id)
    return jsonify({"game_id": game_id}), 201

@app.route("/games/<int:game_id>", methods=["GET"])
@device_token_required
def get_game(game_id):
    game = db.get_game(game_id)
    if not game:
        abort(404, "Game not found")
    # Ensure that the current user is a participant in the game
    if g.current_user['id'] not in [game['player1_id'], game['player2_id']]:
        abort(403, "You are not authorized to access this game")
    return jsonify(dict(game))

# Game progress routes
@app.route("/games/progress/", methods=["POST"])
@device_token_required
def add_game_progress():
    data = request.get_json()
    game_id = data.get("game_id")
    question_id = data.get("question_id")
    selected_answer = data.get("selected_answer")
    player_id = g.current_user['id']
    if not all([game_id, question_id, selected_answer]):
        abort(400, "All fields are required")
    # Ensure that the user is a participant in the game
    game = db.get_game(game_id)
    if not game:
        abort(404, "Game not found")
    if player_id not in [game['player1_id'], game['player2_id']]:
        abort(403, "You are not authorized to update this game")

    # Get the correct answer
    question = db.get_question_by_id(question_id)
    if not question:
        abort(404, "Question not found")
    correct_answer = question['correct_answer']
    is_correct = (selected_answer == correct_answer)

    # Add game progress
    db.add_game_progress(game_id, player_id, question_id, selected_answer, is_correct)
    return jsonify({"message": "Game progress added successfully.", "is_correct": is_correct}), 201

@app.route("/games/<int:game_id>/progress", methods=["GET"])
@device_token_required
def get_game_progress(game_id):
    # Ensure that the current user is a participant in the game
    game = db.get_game(game_id)
    if not game:
        abort(404, "Game not found")
    if g.current_user['id'] not in [game['player1_id'], game['player2_id']]:
        abort(403, "You are not authorized to access this game progress")
    progress = db.get_game_progress(game_id)
    return jsonify([dict(row) for row in progress])

# Category routes
@app.route("/categories/", methods=["POST"])
@device_token_required
def add_category():
    # Optional: Implement admin check if needed
    data = request.get_json()
    category_id = data.get("id")
    name = data.get("name")
    emoji = data.get("emoji")
    if not all([category_id, name, emoji]):
        abort(400, "All fields are required")
    db.add_category(category_id, name, emoji)
    return jsonify({"message": f"Category '{name}' added successfully."}), 201

@app.route("/categories/", methods=["GET"])
def get_all_categories():
    categories = db.get_all_categories()
    return jsonify([dict(row) for row in categories])

# Questions routes
@app.route("/questions/", methods=["POST"])
@device_token_required
def add_question():
    # Optional: Implement admin check if needed
    data = request.get_json()
    question_text = data.get("question")
    correct_answer = data.get("correct_answer")
    if not all([question_text, correct_answer]):
        abort(400, "Both question and correct_answer are required")
    question_id = db.add_question(question_text, correct_answer)
    if question_id == -1:
        abort(500, "Failed to add question")
    return jsonify({"message": f"Question added successfully.", "question_id": question_id}), 201

@app.route("/questions/<int:question_id>", methods=["GET"])
@device_token_required
def get_question(question_id):
    question = db.get_question_by_id(question_id)
    if not question:
        abort(404, "Question not found")
    # Do not send the correct_answer to the client
    question_data = {
        "id": question["id"],
        "question": question["question"]
    }
    return jsonify(question_data)

# Cleanup on shutdown
@app.teardown_appcontext
def shutdown(exception=None):
    print("Shutting down the server...")
    db.close()

# Run the Flask app
if __name__ == "__main__":
    print("Starting Flask server...")
    app.run(host="0.0.0.0", port=3000, debug=True)