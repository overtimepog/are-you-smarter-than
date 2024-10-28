import UIKit
import SwiftyJSON
import SocketIO


class LobbyViewController: UIViewController {

    var roomCode: String = ""  // Set this when transitioning to the lobby
    var playerName: String = "" // Set this when transitioning to the lobby
    var isHost: Bool = false   // Indicates if the user is the host
    var players: [String] = []  // List to hold player names
    var playerWins: [String: Int] = [:] // Dictionary to track player wins
    var questionGoal: Int = 0
    var maxPlayers: Int = 0
    var gameStarted: Bool = false
    var categories: [String] = []  // NEW: List to hold categories

    // UI Elements
    let roomCodeLabel = UILabel()
    let categoriesLabel = UILabel()  // NEW: Label to display categories
    let playersTableView = UITableView()
    let refreshButton = UIButton(type: .system)
    let startGameButton = UIButton(type: .system)
    let leaveLobbyButton = UIButton(type: .system)

    var refreshTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] LobbyViewController loaded with roomCode: \(roomCode), playerName: \(playerName), isHost: \(isHost)")
        setupUI()
        if SocketIOManager.shared.socket.status != .connected {
            SocketIOManager.shared.establishConnection()
        }
        playersTableView.dataSource = self
        startGameButton.isHidden = gameStarted || !isHost
        refreshTimer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(refreshRoomData), userInfo: nil, repeats: true)
        SocketIOManager.shared.socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            print("[DEBUG] Socket connected, setting up event listeners")
            self.setupSocketListeners()
        }
    }
    func setupSocketListeners() {
        SocketIOManager.shared.socket.on("player_joined") { [weak self] (data: [Any], ack: SocketAckEmitter) in
            guard let self = self else { return }
            if let playerName = data.first as? String {
                print("[DEBUG] Player joined: \(playerName)")
                self.players.append(playerName)
                DispatchQueue.main.async {
                    self.playersTableView.reloadData()
                }
            }
        }

        SocketIOManager.shared.socket.on("player_left") { [weak self] (data: [Any], ack: SocketAckEmitter) in
            guard let self = self else { return }
            if let playerName = data.first as? String {
                print("[DEBUG] Player left: \(playerName)")
                self.players.removeAll { $0 == playerName }
                DispatchQueue.main.async {
                    self.playersTableView.reloadData()
                }
            }
        }

        SocketIOManager.shared.socket.on("player_count_changed") { [weak self] (data: [Any], ack: SocketAckEmitter) in
            guard let self = self else { return }
            print("[DEBUG] Player count changed, fetching updated room data.")
            self.fetchRoomData()
        }

        SocketIOManager.shared.socket.on("update_view") { [weak self] (data: [Any], ack: SocketAckEmitter) in
            guard let self = self else { return }
            if let newView = data[0] as? [String: Any], let viewName = newView["new_view"] as? String {
                self.handleViewChange(viewName: viewName)
            }
        }
    }


    func handleViewChange(viewName: String) {
        print("[DEBUG] [handleViewChange] Changing view to: \(viewName)")
        // Implement logic to transition to the specified view
        // For example, if viewName is "TriviaView", present the TriviaViewController
        if viewName == "TriviaView" {
            let triviaVC = TriviaViewController()
            triviaVC.modalPresentationStyle = .fullScreen
            triviaVC.roomCode = self.roomCode
            triviaVC.playerName = self.playerName
            triviaVC.questionGoal = self.questionGoal
            triviaVC.categories = self.categories
            self.present(triviaVC, animated: true)
        }
    }

    // Setup UI with Auto Layout
    func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Optimize table view performance
        playersTableView.estimatedRowHeight = 44
        playersTableView.rowHeight = UITableView.automaticDimension

        // Room Code Label
        roomCodeLabel.font = UIFont.systemFont(ofSize: 24)
        roomCodeLabel.textAlignment = .center
        roomCodeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Categories Label
        categoriesLabel.font = UIFont.systemFont(ofSize: 16)
        categoriesLabel.textAlignment = .center
        categoriesLabel.numberOfLines = 0  // Allow label to wrap text
        categoriesLabel.translatesAutoresizingMaskIntoConstraints = false

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

        // Add subviews
        view.addSubview(roomCodeLabel)
        view.addSubview(categoriesLabel)  // NEW: Add categories label to view
        view.addSubview(playersTableView)
        view.addSubview(refreshButton)
        view.addSubview(startGameButton)
        view.addSubview(leaveLobbyButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            roomCodeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            roomCodeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            categoriesLabel.topAnchor.constraint(equalTo: roomCodeLabel.bottomAnchor, constant: 10),  // NEW: Position below room code
            categoriesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoriesLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            playersTableView.topAnchor.constraint(equalTo: categoriesLabel.bottomAnchor, constant: 20),
            playersTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playersTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playersTableView.bottomAnchor.constraint(equalTo: refreshButton.topAnchor, constant: -20),

            startGameButton.bottomAnchor.constraint(equalTo: refreshButton.topAnchor, constant: -20),
            startGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            refreshButton.bottomAnchor.constraint(equalTo: leaveLobbyButton.topAnchor, constant: -20),
            refreshButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            leaveLobbyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            leaveLobbyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Fetch room data from the API
    @objc func fetchRoomData() {
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

            do {
                let json = try JSON(data: data)
                let playerWins = json["player_wins"].dictionaryValue.mapValues { $0.intValue }
                let roomInfo = RoomInfo(
                    room_code: json["room_code"].stringValue,
                    players: json["players"].arrayValue.map { $0.stringValue },
                    playerWins: playerWins,  // Use the updated playerWins
                    question_goal: json["question_goal"].intValue,
                    max_players: json["max_players"].intValue,
                    game_started: json["game_started"].intValue,
                    winners: json["winners"].arrayValue.map { $0.stringValue },
                    categories: json["categories"].arrayValue.map { $0.stringValue }  // NEW: Parse categories
                )
                print("[DEBUG] [fetchRoomData] Room data decoded successfully: \(roomInfo)")
                DispatchQueue.main.async {
                    self.updateUI(with: roomInfo)
                }
            } catch {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[DEBUG] [fetchRoomData] Failed to decode room data. Response: \(jsonString)")
                } else {
                    print("Failed to decode room data. Unable to convert data to string.")
                }
            }
        }.resume()
    }

    // Update the UI with fetched room data
    @objc func updateUI(with roomInfo: RoomInfo) {
        self.players = roomInfo.players
        self.playerWins = roomInfo.playerWins
        self.questionGoal = roomInfo.question_goal
        self.maxPlayers = roomInfo.max_players
        self.gameStarted = (roomInfo.game_started == 1) // Update based on Int value
        self.categories = roomInfo.categories  // NEW: Update categories

        roomCodeLabel.text = "Room Code: \(roomInfo.room_code)"
        categoriesLabel.text = "Categories: \(categories.joined(separator: ", "))"  // NEW: Display categories
        playersTableView.reloadData()
    }

    @objc func refreshRoomData() {
        DispatchQueue.main.async {
            SocketIOManager.shared.socket.disconnect()
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
                triviaVC.roomCode = self.roomCode
                triviaVC.playerName = self.playerName
                triviaVC.questionGoal = self.questionGoal
                triviaVC.categories = self.categories  // NEW: Pass categories to the trivia view
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
        let playerName = players[indexPath.row]
        cell.textLabel?.text = "\(playerName) - Wins: \(playerWins[playerName] ?? 0)"
        return cell
    }
}

// Define RoomInfo struct
struct RoomInfo {
    let room_code: String
    let players: [String]
    let playerWins: [String: Int]
    let question_goal: Int
    let max_players: Int
    let game_started: Int
    let winners: [String]
    let categories: [String]
}
