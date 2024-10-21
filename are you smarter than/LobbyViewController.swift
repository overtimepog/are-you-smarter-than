//
//  LobbyViewController.swift
//  Are You Smarter Than
//

import UIKit

class LobbyViewController: UIViewController {

    var roomCode: String = ""  // Set this when transitioning to the lobby
    var playerName: String = "" // Set this when transitioning to the lobby
    var isHost: Bool = false   // Indicates if the user is the host
    var players: [String] = []  // List to hold player names
    var questionGoal: Int = 0
    var maxPlayers: Int = 0
    var gameStarted: Bool = false

    // UI Elements
    let roomCodeLabel = UILabel()
    let playersTableView = UITableView()
    let refreshButton = UIButton(type: .system)
    let startGameButton = UIButton(type: .system)
    let leaveLobbyButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchRoomData()  // Fetch room data when the view loads
        playersTableView.dataSource = self
        // Hide the start game button if the game has already started
        startGameButton.isHidden = gameStarted || !isHost
    }

    // Setup UI with Auto Layout
    func setupUI() {
        view.backgroundColor = .systemBackground

        // Room Code Label
        roomCodeLabel.font = UIFont.systemFont(ofSize: 24)
        roomCodeLabel.textAlignment = .center
        roomCodeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Players Table View
        playersTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlayerCell")
        playersTableView.translatesAutoresizingMaskIntoConstraints = false

        // Refresh Button
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshRoomData), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        // Start Game Button
        startGameButton.setTitle("Start Game", for: .normal)
        startGameButton.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        startGameButton.translatesAutoresizingMaskIntoConstraints = false
        startGameButton.isHidden = !isHost

        // Leave Lobby Button
        leaveLobbyButton.setTitle("Leave Lobby", for: .normal)
        leaveLobbyButton.addTarget(self, action: #selector(leaveLobby), for: .touchUpInside)
        leaveLobbyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roomCodeLabel)
        view.addSubview(playersTableView)
        view.addSubview(refreshButton)
        view.addSubview(startGameButton)
        view.addSubview(leaveLobbyButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            roomCodeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            roomCodeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            playersTableView.topAnchor.constraint(equalTo: roomCodeLabel.bottomAnchor, constant: 20),
            playersTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playersTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playersTableView.bottomAnchor.constraint(equalTo: refreshButton.topAnchor, constant: -20),

            refreshButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            refreshButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            startGameButton.bottomAnchor.constraint(equalTo: leaveLobbyButton.topAnchor, constant: -20),
            startGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            leaveLobbyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            leaveLobbyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Fetch room data from the API
    func fetchRoomData() {
        guard let url = URL(string: "https://api.areyousmarterthan.xyz/game_room/\(roomCode)") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching room data: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                let roomInfo = try JSONDecoder().decode(RoomInfo.self, from: data)
                DispatchQueue.main.async {
                    self.updateUI(with: roomInfo)
                }
            } catch {
                print("Failed to decode room data: \(error.localizedDescription)")
            }
        }.resume()
    }

    // Update the UI with fetched room data
    func updateUI(with roomInfo: RoomInfo) {
        self.players = [playerName] + roomInfo.players
        self.questionGoal = roomInfo.question_goal
        self.maxPlayers = roomInfo.max_players
        self.gameStarted = roomInfo.game_started

        roomCodeLabel.text = "Room Code: \(roomInfo.room_code)"
        playersTableView.reloadData()
    }

    @objc func refreshRoomData() {
        fetchRoomData()  // Refresh the room data when the button is pressed
    }
    @objc func startGame() {
        guard isHost else { return }

        let parameters: [String: Any] = ["room_code": roomCode, "player_name": playerName]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/start_game") else {
            print("Invalid API URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                print("Error starting game: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.gameStarted = true
                self.startGameButton.isHidden = true
                // Transition to the game view
                let triviaVC = TriviaViewController()
                triviaVC.modalPresentationStyle = .fullScreen
                self.present(triviaVC, animated: true)
            }
        }.resume()
    }

    @objc func leaveLobby() {
        FlaskWrapper.leaveRoom(roomCode: roomCode, playerName: playerName) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.dismiss(animated: true, completion: nil)
                case .failure(let error):
                    print("Error leaving lobby: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension LobbyViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerCell", for: indexPath)
        cell.textLabel?.text = players[indexPath.row]
        return cell
    }
}

// MARK: - RoomInfo Struct
struct RoomInfo: Codable {
    let room_code: String
    let players: [String]
    let question_goal: Int
    let max_players: Int
    let game_started: Bool
    let winners: [String]
}
