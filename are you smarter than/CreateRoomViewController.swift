//
//  CreateRoomViewController.swift
//  are you smarter than
//
//  Created by Overtime on 10/17/24.
//

import UIKit
import SwiftyJSON

class CreateRoomViewController: UIViewController {

    // UI Elements
    let playerNameTextField = UITextField()
    let questionGoalTextField = UITextField()
    let maxPlayersTextField = UITextField()
    let createButton = UIButton(type: .system)
    let statusLabel = UILabel()
    let backButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] CreateRoomViewController loaded")
        setupUI()
    }

    // Setup UI
    func setupUI() {
        view.backgroundColor = .systemBackground

        playerNameTextField.placeholder = "Enter Your Name"
        playerNameTextField.borderStyle = .roundedRect
        playerNameTextField.translatesAutoresizingMaskIntoConstraints = false
        questionGoalTextField.placeholder = "Max Question (e.g., 10)"
        questionGoalTextField.borderStyle = .roundedRect
        questionGoalTextField.keyboardType = .numberPad
        questionGoalTextField.translatesAutoresizingMaskIntoConstraints = false

        maxPlayersTextField.placeholder = "Enter Max Players (e.g., 8)"
        maxPlayersTextField.borderStyle = .roundedRect
        maxPlayersTextField.keyboardType = .numberPad
        maxPlayersTextField.translatesAutoresizingMaskIntoConstraints = false

        createButton.setTitle("Create Room", for: .normal)
        createButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        createButton.addTarget(self, action: #selector(createRoom), for: .touchUpInside)
        createButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .red
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        backButton.setTitle("Back", for: .normal)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(backButton)
        view.addSubview(questionGoalTextField)
        view.addSubview(maxPlayersTextField)
        view.addSubview(createButton)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            playerNameTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerNameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            playerNameTextField.widthAnchor.constraint(equalToConstant: 300),
            questionGoalTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            questionGoalTextField.topAnchor.constraint(equalTo: playerNameTextField.bottomAnchor, constant: 20),
            questionGoalTextField.widthAnchor.constraint(equalTo: playerNameTextField.widthAnchor),

            maxPlayersTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            maxPlayersTextField.topAnchor.constraint(equalTo: questionGoalTextField.bottomAnchor, constant: 20),
            maxPlayersTextField.widthAnchor.constraint(equalTo: questionGoalTextField.widthAnchor),

            createButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createButton.topAnchor.constraint(equalTo: maxPlayersTextField.bottomAnchor, constant: 20),

            statusLabel.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    @objc func createRoom() {
        print("[DEBUG] Create Room button tapped")
        guard let playerName = playerNameTextField.text, !playerName.isEmpty,
              let questionGoal = Int(questionGoalTextField.text ?? ""),
              let maxPlayers = Int(maxPlayersTextField.text ?? "") else {
            statusLabel.text = "Please enter valid numbers."
            return
        }

        print("[DEBUG] Creating room with playerName: \(playerName), questionGoal: \(questionGoal), maxPlayers: \(maxPlayers)")
        let parameters: [String: Any] = [
            "player_name": playerName,
            "question_goal": questionGoal,
            "max_players": maxPlayers
        ]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/create_room") else {
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
                print("[DEBUG] Error creating room: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { self.statusLabel.text = "No data received." }
                print("[DEBUG] No data received.")
                return
            }

            let json = JSON(data)
            if json["success"].boolValue, let roomCode = json["room_code"].string {
                DispatchQueue.main.async {
                    print("[DEBUG] Room created with code: \(roomCode)")
                    self.statusLabel.text = "Room created with code: \(roomCode)"
                    
                    let lobbyVC = LobbyViewController()
                    lobbyVC.isHost = true
                    lobbyVC.playerName = playerName
                    lobbyVC.roomCode = roomCode
                    lobbyVC.modalPresentationStyle = .fullScreen
                    self.present(lobbyVC, animated: true)
                }
            } else {
                let message = json["message"].stringValue
                DispatchQueue.main.async { self.statusLabel.text = message.isEmpty ? "Failed to create room." : message }
            }
        }.resume()
    }
    @objc func goBack() {
        dismiss(animated: true, completion: nil)
    }
}
