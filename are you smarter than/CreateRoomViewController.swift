//
//  CreateRoomViewController.swift
//  are you smarter than
//
//  Created by Overtime on 10/17/24.
//

import UIKit

class CreateRoomViewController: UIViewController {

    // UI Elements
    let playerNameTextField = UITextField()
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

        view.addSubview(playerNameTextField)
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
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc func createRoom() {
        guard let playerName = playerNameTextField.text, !playerName.isEmpty,
              let questionGoal = Int(questionGoalTextField.text ?? ""),
              let maxPlayers = Int(maxPlayersTextField.text ?? "") else {
            statusLabel.text = "Please enter valid numbers."
            return
        }

        FlaskWrapper.createRoom(playerName: playerName, questionGoal: questionGoal, maxPlayers: maxPlayers) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let roomCode):
                    let lobbyVC = LobbyViewController()
                    lobbyVC.isHost = true
                    lobbyVC.playerName = playerName
                    lobbyVC.roomCode = roomCode
                    lobbyVC.modalPresentationStyle = .fullScreen
                    self?.present(lobbyVC, animated: true)
                case .failure(let error):
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
