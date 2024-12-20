//
//  JoinRoomViewController.swift
//  are you smarter than
//
//  Created by Overtime on 10/17/24.
//

import UIKit
import SwiftyJSON

class JoinRoomViewController: UIViewController {

    let roomCodeTextField = UITextField()
    let playerNameTextField = UITextField()
    let joinButton = UIButton(type: .system)
    let statusLabel = UILabel()
    let backButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        SocketIOManager.shared.socket.connect()
        setupUI()
    }

    @objc func goBack() {
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.barStyle = .default
        doneToolbar.translatesAutoresizingMaskIntoConstraints = false
        doneToolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        ]
        doneToolbar.sizeToFit()

        roomCodeTextField.inputAccessoryView = doneToolbar
        playerNameTextField.inputAccessoryView = doneToolbar
    }

    func setupUI() {
        view.backgroundColor = .systemBackground

        // Optimize text field configuration
        let textFields = [roomCodeTextField, playerNameTextField]
        textFields.forEach { field in
            field.borderStyle = .roundedRect
            field.translatesAutoresizingMaskIntoConstraints = false
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.smartDashesType = .no
            field.smartQuotesType = .no
            field.autocapitalizationType = .none
        }
        
        // Configure specific text field behaviors
        addDoneButtonOnKeyboard()
        roomCodeTextField.keyboardType = .asciiCapable
        playerNameTextField.keyboardType = .asciiCapable
        
        roomCodeTextField.placeholder = "Enter Room Code"
        roomCodeTextField.autocapitalizationType = .allCharacters
        
        playerNameTextField.placeholder = "Enter Your Name"

        joinButton.setTitle("Join Room", for: .normal)
        joinButton.addTarget(self, action: #selector(joinRoom), for: .touchUpInside)
        joinButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .red
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        backButton.setTitle("Back", for: .normal)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(backButton)
        view.addSubview(roomCodeTextField)
        view.addSubview(playerNameTextField)
        view.addSubview(joinButton)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            roomCodeTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            roomCodeTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            roomCodeTextField.widthAnchor.constraint(equalToConstant: 300),

            playerNameTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerNameTextField.topAnchor.constraint(equalTo: roomCodeTextField.bottomAnchor, constant: 20),

            joinButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            joinButton.topAnchor.constraint(equalTo: playerNameTextField.bottomAnchor, constant: 20),

            statusLabel.topAnchor.constraint(equalTo: joinButton.bottomAnchor, constant: 20),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    @objc func joinRoom() {
        guard let roomCode = roomCodeTextField.text, !roomCode.isEmpty,
              let playerName = playerNameTextField.text, !playerName.isEmpty else {
            statusLabel.text = "Please enter both room code and name."
            return
        }

        SocketIOManager.shared.socket.disconnect()
        let parameters: [String: Any] = ["room_code": roomCode, "player_name": playerName]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/join_room") else {
            statusLabel.text = "Invalid API URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { self.statusLabel.text = "Error: \(error.localizedDescription)" }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { self.statusLabel.text = "No data received." }
                return
            }

            do {
                let json = try JSON(data: data)
                if json["success"].boolValue {
                    DispatchQueue.main.async {
                        self.fetchRoomDataAndPresentLobby(roomCode: roomCode, playerName: playerName)
                    }
                } else if let message = json["message"].string {
                    DispatchQueue.main.async { self.statusLabel.text = message }
                    let message = json["message"].stringValue
                    DispatchQueue.main.async { self.statusLabel.text = message.isEmpty ? "Failed to join room." : message }
                }
            } catch {
                DispatchQueue.main.async { self.statusLabel.text = "Failed to parse server response." }
            }
        }.resume()
    }
    func fetchRoomDataAndPresentLobby(roomCode: String, playerName: String) {
        guard let url = URL(string: "https://api.areyousmarterthan.xyz/game_room/\(roomCode)") else {
            DispatchQueue.main.async { self.statusLabel.text = "Invalid URL" }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { self.statusLabel.text = "Error: \(error.localizedDescription)" }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { self.statusLabel.text = "No data received." }
                return
            }

            do {
                let json = try JSON(data: data)
                let lobbyVC = LobbyViewController()
                lobbyVC.isHost = false
                lobbyVC.playerName = playerName
                lobbyVC.roomCode = roomCode
                lobbyVC.modalPresentationStyle = .fullScreen
                lobbyVC.modalTransitionStyle = .crossDissolve
                lobbyVC.players = json["players"].arrayValue.map { $0.stringValue }
                lobbyVC.playerWins = json["player_wins"].dictionaryValue.mapValues { $0.intValue }
                lobbyVC.questionGoal = json["question_goal"].intValue
                lobbyVC.maxPlayers = json["max_players"].intValue
                lobbyVC.gameStarted = json["game_started"].boolValue
                lobbyVC.categories = json["categories"].arrayValue.map { $0.stringValue }

                DispatchQueue.main.async {
                    if let presentingVC = self.presentingViewController {
                        presentingVC.dismiss(animated: true) {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController?.present(lobbyVC, animated: true, completion: nil)
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { self.statusLabel.text = "Failed to parse server response." }
            }
        }.resume()
    }
}
