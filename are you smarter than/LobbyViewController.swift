//
//  LobbyViewController.swift
//  are you smarter than
//
//  Created by Overtime on 10/17/24.
//

import UIKit

class LobbyViewController: UIViewController {

    var isHost: Bool = false
    var playerName: String = ""
    var roomCode: String = ""

    // UI Elements
    let roomCodeLabel = UILabel()
    let avatarLabel = UILabel()
    let playerNameLabel = UILabel()
    let startGameButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // Setup UI with Auto Layout
    func setupUI() {
        view.backgroundColor = .systemBackground

        // Room Code Label
        roomCodeLabel.text = "Room Code: \(roomCode)"
        roomCodeLabel.font = UIFont.systemFont(ofSize: 24)
        roomCodeLabel.textAlignment = .center
        roomCodeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Avatar Label
        avatarLabel.text = isHost ? "⭐️" : ["🐶", "🐱", "🐭", "🦊", "🐸", "🐵", "🐧", "🐯", "🐼"].randomElement() ?? "🐶"
        avatarLabel.font = UIFont.systemFont(ofSize: 100)
        avatarLabel.textAlignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false

        // Player Name Label
        playerNameLabel.text = playerName
        playerNameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        playerNameLabel.textAlignment = .center
        playerNameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Start Game Button (Visible only for the host)
        startGameButton.setTitle("Start Game", for: .normal)
        startGameButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        startGameButton.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        startGameButton.translatesAutoresizingMaskIntoConstraints = false
        startGameButton.isHidden = !isHost

        // Add all subviews
        view.addSubview(roomCodeLabel)
        view.addSubview(avatarLabel)
        view.addSubview(playerNameLabel)
        view.addSubview(startGameButton)

        // Apply Auto Layout constraints
        NSLayoutConstraint.activate([
            // Room Code Label
            roomCodeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            roomCodeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Avatar Label
            avatarLabel.topAnchor.constraint(equalTo: roomCodeLabel.bottomAnchor, constant: 40),
            avatarLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Player Name Label
            playerNameLabel.topAnchor.constraint(equalTo: avatarLabel.bottomAnchor, constant: 20),
            playerNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Start Game Button
            startGameButton.topAnchor.constraint(equalTo: playerNameLabel.bottomAnchor, constant: 40),
            startGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Start Game Action (Host Only)
    @objc func startGame() {
        let triviaVC = TriviaViewController()
        triviaVC.modalPresentationStyle = .fullScreen
        present(triviaVC, animated: true, completion: nil)
    }
}
