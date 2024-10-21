import UIKit

class WinViewController: UIViewController {

    var roomCode: String = ""  // Set this when transitioning to the win view
    var playerName: String = "" // Set this when transitioning to the win view
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
        // Logic to replay the game by returning to the lobby
        FlaskWrapper.transitionToLobby(from: self, roomCode: roomCode, playerName: playerName)
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
                self.dismiss(animated: true, completion: nil)
            }
        }.resume()
    }
}
