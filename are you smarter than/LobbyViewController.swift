//
//  LobbyViewController.swift
//  Are You Smarter Than
//

import UIKit
import SwiftyJSON

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

    var refreshTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] LobbyViewController loaded with roomCode: \(roomCode), playerName: \(playerName), isHost: \(isHost)")
        setupUI()
        fetchRoomData()  // Fetch room data when the view loads
        playersTableView.dataSource = self
        // Hide the start game button if the game has already started
        startGameButton.isHidden = gameStarted || !isHost
        // Set up a timer to refresh room data every 5 seconds
        refreshTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(refreshRoomData), userInfo: nil, repeats: true)
    }

    // Setup UI with Auto Layout
    func setupUI() {
        view.backgroundColor = .systemBackground

        // Debug: Check for NaN values in UI setup
        if playersTableView.frame.width.isNaN || playersTableView.frame.height.isNaN {
            print("[DEBUG] NaN detected in playersTableView dimensions")
        }

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

            startGameButton.bottomAnchor.constraint(equalTo: refreshButton.topAnchor, constant: -20),
            startGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            refreshButton.bottomAnchor.constraint(equalTo: leaveLobbyButton.topAnchor, constant: -20),
            startGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            leaveLobbyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            leaveLobbyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Fetch room data from the API
    func fetchRoomData() {
        print("[DEBUG] [fetchRoomData] Fetching room data for roomCode: \(roomCode)")
        guard let url = URL(string: "https://api.areyousmarterthan.xyz/game_room/\(roomCode)") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else {
                print("[DEBUG] [fetchRoomData] Self is nil, returning")
                return
            }

            if let error = error {
                print("[DEBUG] [fetchRoomData] Error fetching room data: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("[DEBUG] [fetchRoomData] No data received")
                return
            }

            _ = JSON(data)
            let decoder = JSONDecoder()
            if let roomInfo = try? decoder.decode(RoomInfo.self, from: data) {
                print("[DEBUG] [fetchRoomData] Room data decoded successfully: \(roomInfo)")
                DispatchQueue.main.async {
                    self.updateUI(with: roomInfo)
                }
            } else {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[DEBUG] [fetchRoomData] Failed to decode room data. Response: \(jsonString)")
                } else {
                    print("Failed to decode room data. Unable to convert data to string.")
                }
            }
        }.resume()
    }

    // Update the UI with fetched room data
    func updateUI(with roomInfo: RoomInfo) {
        self.players = roomInfo.players
        self.questionGoal = roomInfo.question_goal
        self.maxPlayers = roomInfo.max_players
        self.gameStarted = (roomInfo.game_started == 1) // Update based on Int value

        roomCodeLabel.text = "Room Code: \(roomInfo.room_code)"
        playersTableView.reloadData()
    }

    @objc func refreshRoomData() {
        DispatchQueue.main.async {
            self.fetchRoomData()  // Refresh the room data when the button is pressed
        }
    }
    @objc func startGame() {
        guard isHost else { return }

        print("[DEBUG] Attempting to start game with roomCode: \(roomCode), playerName: \(playerName)")
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
            guard let self = self else {
                print("Self is nil, returning")
                return
            }

            if let error = error {
                print("Error starting game: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.gameStarted = true
                self.refreshTimer?.invalidate()
                self.refreshTimer = nil
                self.startGameButton.isHidden = true
                // Transition to the game view
                let triviaVC = TriviaViewController()
                triviaVC.modalPresentationStyle = .fullScreen
                triviaVC.gameMode = .multiplayer
                self.present(triviaVC, animated: true)
            }
        }.resume()
    }

    @objc func leaveLobby() {
        let parameters: [String: Any] = ["room_code": roomCode, "player_name": playerName]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/leave_room") else {
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
                print("Error leaving lobby: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.refreshTimer?.invalidate()
                self.refreshTimer = nil
                self.dismiss(animated: true, completion: nil)
            }
        }.resume()
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
    let game_started: Int // Changed to Int to match response
    let winners: [String]
}
