import UIKit
import SwiftyJSON

class WinViewController: UIViewController {

    var roomCode: String = ""  // Set this when transitioning to the win view
    var playerName: String = "" // Set this when transitioning to the win view
    var rankings: [[String: Any]] = [] // Add this property to hold rankings
    let rankingsTableView = UITableView()
    let titleLabel = UILabel()
    let replayButton = UIButton(type: .system)
    let leaveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] WinViewController loaded with roomCode: \(roomCode), playerName: \(playerName), rankings: \(rankings)")
        setupUI()
        rankingsTableView.reloadData() // Ensure rankings are displayed
    }
    
    // Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Title Label
        titleLabel.text = "Final Scores"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Rankings Table View
        rankingsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "RankingCell")
        rankingsTableView.dataSource = self
        rankingsTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rankingsTableView)

        // Replay Button
        replayButton.setTitle("Replay", for: .normal)
        replayButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        replayButton.addTarget(self, action: #selector(replayGame), for: .touchUpInside)
        replayButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(replayButton)

        // Leave Button
        leaveButton.setTitle("Leave", for: .normal)
        leaveButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        leaveButton.addTarget(self, action: #selector(leaveGame), for: .touchUpInside)
        leaveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(leaveButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            rankingsTableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            rankingsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            rankingsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            rankingsTableView.bottomAnchor.constraint(equalTo: replayButton.topAnchor, constant: -20),

            replayButton.bottomAnchor.constraint(equalTo: leaveButton.topAnchor, constant: -20),
            replayButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            leaveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            leaveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}

// MARK: - UITableViewDataSource
extension WinViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rankings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RankingCell", for: indexPath)
        
        let playerData = rankings[indexPath.row]
        if let playerName = playerData["player_name"] as? String,
           let score = playerData["score"] as? Int {
            cell.textLabel?.text = "\(indexPath.row + 1). \(playerName) - Score: \(score)"
            cell.textLabel?.font = UIFont.systemFont(ofSize: 18)
        }
        
        return cell
    }


    @objc func replayGame() {
        // Logic to replay the game by returning to the lobby
        print("[DEBUG] Attempting to replay game with roomCode: \(roomCode), playerName: \(playerName)")
        
        guard !roomCode.isEmpty, !playerName.isEmpty else {
            print("[ERROR] Cannot replay - missing roomCode or playerName")
            return
        }
        
        // First, get room info to check if we're the host
        guard let url = URL(string: "https://api.areyousmarterthan.xyz/game_room/\(roomCode)") else {
            print("[ERROR] Invalid API URL.")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error getting room info: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let json = try JSON(data: data)
                let host = json["host"].stringValue
                let isHost = (host == self.playerName)
                
                // Now join the room
                let joinParameters: [String: Any] = ["room_code": self.roomCode, "player_name": self.playerName]
                guard let joinUrl = URL(string: "https://api.areyousmarterthan.xyz/join_room") else {
                    print("Invalid join URL.")
                    return
                }
                
                var joinRequest = URLRequest(url: joinUrl)
                joinRequest.httpMethod = "POST"
                joinRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                joinRequest.httpBody = try? JSONSerialization.data(withJSONObject: joinParameters)
                
                URLSession.shared.dataTask(with: joinRequest) { [weak self] joinData, _, joinError in
                    guard let self = self else { return }
                    
                    if let joinError = joinError {
                        print("Error joining lobby: \(joinError.localizedDescription)")
                        return
                    }
                    
                    guard let joinData = joinData else {
                        print("No data received from join request")
                        return
                    }
                    
                    let joinJson = JSON(joinData)
                    if joinJson["success"].boolValue {
                        DispatchQueue.main.async {
                            let lobbyVC = LobbyViewController()
                            lobbyVC.isHost = isHost
                            lobbyVC.playerName = self.playerName
                            lobbyVC.roomCode = self.roomCode
                            lobbyVC.modalPresentationStyle = .fullScreen
                            self.present(lobbyVC, animated: true)
                        }
                    } else {
                        print("Failed to join room: \(joinJson["message"].stringValue)")
                        DispatchQueue.main.async {
                            let alert = UIAlertController(
                                title: "Error",
                                message: joinJson["message"].stringValue,
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(alert, animated: true)
                        }
                    }
                }.resume()
                
            } catch {
                print("Error parsing room info: \(error)")
            }
        }.resume()
    }

    @objc func leaveGame() {
        // Logic to leave the game
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
                print("Error leaving game: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                // Present the main menu
                let mainMenuVC = MainMenuViewController()
                mainMenuVC.modalPresentationStyle = .fullScreen
                self.present(mainMenuVC, animated: true)
            }
        }.resume()
    }
}
