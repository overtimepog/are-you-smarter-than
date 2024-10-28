import UIKit
import SwiftyJSON

class CreateRoomViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    // UI Elements
    let playerNameTextField = UITextField()
    let questionGoalTextField = UITextField()
    let maxPlayersTextField = UITextField()
    let difficultyPicker = UIPickerView()
    let createButton = UIButton(type: .system)
    let statusLabel = UILabel()
    let backButton = UIButton(type: .system)

    let difficulties = ["Easy", "Medium", "Hard"]
    var selectedDifficulty: String = "Easy"

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] CreateRoomViewController loaded")
        setupUI()
        setupGestureRecognizer()
    }

    // Setup UI
    func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure text fields with better performance settings
        let textFields = [playerNameTextField, questionGoalTextField, maxPlayersTextField]
        textFields.forEach { field in
            field.borderStyle = .roundedRect
            field.translatesAutoresizingMaskIntoConstraints = false
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.smartDashesType = .no
            field.smartQuotesType = .no
            field.autocapitalizationType = .none
        }
        
        // Configure specific text field behaviors
        playerNameTextField.keyboardType = .asciiCapable
        questionGoalTextField.keyboardType = .numberPad
        maxPlayersTextField.keyboardType = .numberPad
        
        playerNameTextField.placeholder = "Enter Your Name"
        questionGoalTextField.placeholder = "Max Question (e.g., 10)"
        questionGoalTextField.borderStyle = .roundedRect
        questionGoalTextField.keyboardType = .numberPad
        questionGoalTextField.translatesAutoresizingMaskIntoConstraints = false

        maxPlayersTextField.placeholder = "Enter Max Players (e.g., 8)"
        maxPlayersTextField.borderStyle = .roundedRect
        maxPlayersTextField.keyboardType = .numberPad
        maxPlayersTextField.translatesAutoresizingMaskIntoConstraints = false

        difficultyPicker.delegate = self
        difficultyPicker.dataSource = self
        difficultyPicker.translatesAutoresizingMaskIntoConstraints = false

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
        view.addSubview(playerNameTextField)
        view.addSubview(questionGoalTextField)
        view.addSubview(maxPlayersTextField)
        view.addSubview(difficultyPicker)
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

            difficultyPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            difficultyPicker.topAnchor.constraint(equalTo: maxPlayersTextField.bottomAnchor, constant: 20),

            createButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createButton.topAnchor.constraint(equalTo: difficultyPicker.bottomAnchor, constant: 20),

            statusLabel.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    // Setup Gesture Recognizer to Dismiss Keyboard
    func setupGestureRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func createRoom() {
        print("[DEBUG] [createRoom] Create Room button tapped")
        guard let playerName = playerNameTextField.text, !playerName.isEmpty,
              let questionGoalText = questionGoalTextField.text, let questionGoal = Int(questionGoalText),
              let maxPlayersText = maxPlayersTextField.text, let maxPlayers = Int(maxPlayersText) else {
            print("[DEBUG] [createRoom] Invalid input: playerName: \(playerNameTextField.text ?? ""), questionGoal: \(questionGoalTextField.text ?? ""), maxPlayers: \(maxPlayersTextField.text ?? "")")
            statusLabel.text = "Please enter valid numbers."
            return
        }

        print("[DEBUG] [createRoom] Creating room with playerName: \(playerName), questionGoal: \(questionGoal), maxPlayers: \(maxPlayers), difficulty: \(selectedDifficulty)")
        let parameters: [String: Any] = [
            "player_name": playerName,
            "question_goal": questionGoal,
            "max_players": maxPlayers,
            "difficulty": selectedDifficulty.lowercased()
        ]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/create_room") else {
            print("[DEBUG] [createRoom] Invalid API URL.")
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
                print("[DEBUG] [createRoom] Error creating room: \(error.localizedDescription)")
                DispatchQueue.main.async { self.statusLabel.text = "Error: \(error.localizedDescription)" }
                return
            }

            guard let data = data else {
                print("[DEBUG] [createRoom] No data received.")
                DispatchQueue.main.async { self.statusLabel.text = "No data received." }
                return
            }

            let json = JSON(data)
            if json["success"].boolValue, let roomCode = json["room_code"].string {
                print("[DEBUG] [createRoom] Room created successfully with code: \(roomCode)")
                DispatchQueue.main.async {
                    print("[DEBUG] Room created with code: \(roomCode)")
                    self.statusLabel.text = "Room created with code: \(roomCode)"
                    
                    let lobbyVC = LobbyViewController()
                    lobbyVC.isHost = true
                    lobbyVC.playerName = playerName
                    lobbyVC.roomCode = roomCode
                    lobbyVC.modalPresentationStyle = .fullScreen
                    lobbyVC.modalTransitionStyle = .crossDissolve
                    self.view.window?.rootViewController?.dismiss(animated: true) {
                        self.present(lobbyVC, animated: true)
                    }
                }
            } else {
                let message = json["message"].stringValue
                print("[DEBUG] [createRoom] Room creation failed with message: \(message)")
                DispatchQueue.main.async { self.statusLabel.text = message.isEmpty ? "Failed to create room." : message }
            }
        }.resume()
    }

    @objc func goBack() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UIPickerView Delegate & DataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return difficulties.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return difficulties[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedDifficulty = difficulties[row]
    }
}
