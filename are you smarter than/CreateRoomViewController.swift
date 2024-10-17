//
//  CreateRoomViewController.swift
//  are you smarter than
//
//  Created by Overtime on 10/17/24.
//

import UIKit

class CreateRoomViewController: UIViewController {

    // UI Elements
    let questionGoalTextField = UITextField()
    let maxPlayersTextField = UITextField()
    let createButton = UIButton(type: .system)
    let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // Setup UI
    func setupUI() {
        view.backgroundColor = .systemBackground

        questionGoalTextField.placeholder = "Enter Question Goal (e.g., 10)"
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

        view.addSubview(questionGoalTextField)
        view.addSubview(maxPlayersTextField)
        view.addSubview(createButton)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            questionGoalTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            questionGoalTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            questionGoalTextField.widthAnchor.constraint(equalToConstant: 300),

            maxPlayersTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            maxPlayersTextField.topAnchor.constraint(equalTo: questionGoalTextField.bottomAnchor, constant: 20),
            maxPlayersTextField.widthAnchor.constraint(equalTo: questionGoalTextField.widthAnchor),

            createButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createButton.topAnchor.constraint(equalTo: maxPlayersTextField.bottomAnchor, constant: 20),

            statusLabel.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc func createRoom() {
        guard let questionGoal = Int(questionGoalTextField.text ?? ""),
              let maxPlayers = Int(maxPlayersTextField.text ?? "") else {
            statusLabel.text = "Please enter valid numbers."
            return
        }

        let parameters: [String: Any] = ["question_goal": questionGoal, "max_players": maxPlayers]

        guard let url = URL(string: "http://<your-server-ip>:3000/create_room") else {
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

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let roomCode = json["room_code"] as? String else {
                DispatchQueue.main.async { self.statusLabel.text = "Failed to create room." }
                return
            }

            DispatchQueue.main.async {
                let lobbyVC = LobbyViewController()
                lobbyVC.isHost = true
                lobbyVC.playerName = "Host"
                lobbyVC.roomCode = roomCode
                lobbyVC.modalPresentationStyle = .fullScreen
                self.present(lobbyVC, animated: true)
            }
        }.resume()
    }
}
