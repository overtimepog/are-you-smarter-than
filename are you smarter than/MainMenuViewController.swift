//
//  MainMenuViewController.swift
//  are you smarter than
//
//  Created by Overtime on 10/17/24.
//

import UIKit

class MainMenuViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.async {
            self.setupUI()
        }
    }

    // Setup the main menu UI
    func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Title label
        let titleLabel = createLabel(text: "Are You Smarter Than", fontSize: 32)
        view.addSubview(titleLabel)

        // Create Room button
        let createRoomButton = createButton(title: "Create Room", action: #selector(createRoom))
        view.addSubview(createRoomButton)

        // Join Room button
        let joinRoomButton = createButton(title: "Join Room", action: #selector(joinRoom))
        view.addSubview(joinRoomButton)

        let highestStreak = UserDefaults.standard.integer(forKey: "HighestStreak")
        let solobutton = createButton(title: "Solo (Highest Streak: \(highestStreak))", action: #selector(startSolo))
        view.addSubview(solobutton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),

            // Create room button constraints
            createRoomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createRoomButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),

            // Join room button constraints
            joinRoomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            joinRoomButton.topAnchor.constraint(equalTo: createRoomButton.bottomAnchor, constant: 20),

            // Solo button constraints
            solobutton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            solobutton.topAnchor.constraint(equalTo: joinRoomButton.bottomAnchor, constant: 20)
        ])
    }

    private func createLabel(text: String, fontSize: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // Transition to Create Room view
    @objc func createRoom() {
        let createRoomVC = CreateRoomViewController()
        createRoomVC.modalPresentationStyle = .fullScreen
        createRoomVC.modalTransitionStyle = .crossDissolve
        present(createRoomVC, animated: true)
    }

    // Transition to Join Room view
    @objc func joinRoom() {
        let joinRoomVC = JoinRoomViewController()
        joinRoomVC.modalPresentationStyle = .fullScreen
        joinRoomVC.modalTransitionStyle = .crossDissolve
        present(joinRoomVC, animated: true)
    }
    
    @objc func startSolo() {
        // Code to handle the "Solo" button tap
        print("Solo game started")
        
        // Present modally instead of pushing
        let soloGameViewController = SoloViewController()
        soloGameViewController.modalPresentationStyle = .fullScreen
        soloGameViewController.modalTransitionStyle = .crossDissolve
        present(soloGameViewController, animated: true)
    }

}
