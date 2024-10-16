//
//  JoinRoomViewController.swift
//  are you smarter than
//
//  Created by Overtime on 10/17/24.
//

import UIKit

class JoinRoomViewController: UIViewController {

    let roomCodeTextField = UITextField()
    let playerNameTextField = UITextField()
    let joinButton = UIButton(type: .system)
    let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func setupUI() {
        view.backgroundColor = .systemBackground

        roomCodeTextField.placeholder = "Enter Room Code"
        roomCodeTextField.borderStyle = .roundedRect
        roomCodeTextField.autocapitalizationType = .allCharacters
        roomCodeTextField.translatesAutoresizingMaskIntoConstraints = false

        playerNameTextField.placeholder = "Enter Your Name"
        playerNameTextField.borderStyle = .roundedRect
        playerNameTextField.translatesAutoresizingMaskIntoConstraints = false

        joinButton.setTitle("Join Room", for: .normal)
        joinButton.addTarget(self, action: #selector(joinRoom), for: .touchUpInside)
        joinButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .red
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

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

            statusLabel.topAnchor.constraint(equalTo: joinButton.bottomAnchor, constant: 20)
        ])
    }

    @objc func joinRoom() {
        guard let roomCode = roomCodeTextField.text, !roomCode.isEmpty,
              let playerName = playerNameTextField.text, !playerName.isEmpty else {
            statusLabel.text = "Please enter both room code and name."
            return
        }

        let parameters: [String: Any] = ["room_code": roomCode, "player_name": playerName]

        guard let url = URL(string: "http://<your-server-ip>:3000/join_room") else {
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

            DispatchQueue.main.async {
                let lobbyVC = LobbyViewController()
                lobbyVC.isHost = false
                lobbyVC.playerName = playerName
                lobbyVC.roomCode = roomCode
                lobbyVC.modalPresentationStyle = .fullScreen
                self.present(lobbyVC, animated: true)
            }
        }.resume()
    }
}
