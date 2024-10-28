import UIKit

class MainMenuViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("MainMenuViewController: viewDidLoad")
        setupUI()
    }

    // Setup the main menu UI
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Title Label
        let titleLabel = createLabel(text: "Are You Smarter Than", fontSize: 32)

        // Stack View for Buttons
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.alignment = .fill
        buttonStackView.distribution = .equalSpacing
        buttonStackView.spacing = 20
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false

        // Create Room Button
        let createRoomButton = createButton(title: "Create Room", action: #selector(createRoom))

        // Join Room Button
        let joinRoomButton = createButton(title: "Join Room", action: #selector(joinRoom))

        // Solo Button with Highest Streak
        let highestStreak = UserDefaults.standard.integer(forKey: "HighestStreak")
        let soloButton = createButton(
            title: "Solo (Highest Streak: \(highestStreak))",
            action: #selector(startSolo)
        )

        // Add Buttons to Stack View
        buttonStackView.addArrangedSubview(createRoomButton)
        buttonStackView.addArrangedSubview(joinRoomButton)
        buttonStackView.addArrangedSubview(soloButton)

        // Add Views to Main View
        view.addSubview(titleLabel)
        view.addSubview(buttonStackView)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Title Label Constraints
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),

            // Button Stack View Constraints
            buttonStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            buttonStackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }

    // Create a UILabel
    private func createLabel(text: String, fontSize: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // Create a UIButton
    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // Handle Create Room
    @objc func createRoom() {
        let createRoomVC = CreateRoomViewController()
        createRoomVC.modalPresentationStyle = .fullScreen
        createRoomVC.modalTransitionStyle = .crossDissolve
        present(createRoomVC, animated: true)
    }

    // Handle Join Room
    @objc func joinRoom() {
        let joinRoomVC = JoinRoomViewController()
        joinRoomVC.modalPresentationStyle = .fullScreen
        joinRoomVC.modalTransitionStyle = .crossDissolve
        present(joinRoomVC, animated: true)
    }

    // Handle Solo Game Start
    @objc func startSolo() {
        let soloGameVC = SoloViewController()
        soloGameVC.modalPresentationStyle = .fullScreen
        soloGameVC.modalTransitionStyle = .crossDissolve
        present(soloGameVC, animated: true)
    }
}
