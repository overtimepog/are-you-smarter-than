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
        setupUI()
    }

    // Setup the main menu UI
    func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "Are You Smarter Than"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Create Room button
        let createRoomButton = UIButton(type: .system)
        createRoomButton.setTitle("Create Room", for: .normal)
        createRoomButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        createRoomButton.translatesAutoresizingMaskIntoConstraints = false
        createRoomButton.addTarget(self, action: #selector(createRoom), for: .touchUpInside)
        view.addSubview(createRoomButton)

        // Join Room button
        let joinRoomButton = UIButton(type: .system)
        joinRoomButton.setTitle("Join Room", for: .normal)
        joinRoomButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        joinRoomButton.translatesAutoresizingMaskIntoConstraints = false
        joinRoomButton.addTarget(self, action: #selector(joinRoom), for: .touchUpInside)
        view.addSubview(joinRoomButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),

            createRoomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createRoomButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),

            joinRoomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            joinRoomButton.topAnchor.constraint(equalTo: createRoomButton.bottomAnchor, constant: 20)
        ])
    }

    // Transition to Create Room view
    @objc func createRoom() {
        let createRoomVC = CreateRoomViewController()
        createRoomVC.modalPresentationStyle = .fullScreen
        present(createRoomVC, animated: true, completion: nil)
    }

    // Transition to Join Room view
    @objc func joinRoom() {
        let joinRoomVC = JoinRoomViewController()
        joinRoomVC.modalPresentationStyle = .fullScreen
        present(joinRoomVC, animated: true, completion: nil)
    }
}
