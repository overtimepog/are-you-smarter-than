import UIKit

class WinViewController: UIViewController {

    // UI Elements
    let podiumView = UIView()
    let replayButton = UIButton(type: .system)
    let leaveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // Setup UI
    func setupUI() {
        view.backgroundColor = .systemBackground

        // Podium View
        podiumView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(podiumView)

        // Replay Button
        replayButton.setTitle("Replay", for: .normal)
        replayButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        replayButton.addTarget(self, action: #selector(replayGame), for: .touchUpInside)
        replayButton.translatesAutoresizingMaskIntoConstraints = false

        // Leave Button
        leaveButton.setTitle("Leave", for: .normal)
        leaveButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        leaveButton.addTarget(self, action: #selector(leaveGame), for: .touchUpInside)
        leaveButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(replayButton)
        view.addSubview(leaveButton)

        NSLayoutConstraint.activate([
            podiumView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            podiumView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            podiumView.widthAnchor.constraint(equalToConstant: 300),
            podiumView.heightAnchor.constraint(equalToConstant: 200),

            replayButton.topAnchor.constraint(equalTo: podiumView.bottomAnchor, constant: 20),
            replayButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            leaveButton.topAnchor.constraint(equalTo: replayButton.bottomAnchor, constant: 20),
            leaveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc func replayGame() {
        // Logic to replay the game
        let lobbyVC = LobbyViewController()
        lobbyVC.modalPresentationStyle = .fullScreen
        self.present(lobbyVC, animated: true)
    }

    @objc func leaveGame() {
        // Logic to leave the game
        self.dismiss(animated: true, completion: nil)
        dismiss(animated: true, completion: nil)
    }
}
