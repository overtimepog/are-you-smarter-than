import UIKit
import SwiftyJSON

class CreateRoomViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

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

    // Category selection
    let categoryButton = UIButton(type: .system)
    let categoryDropdown = UITableView()
    var isDropdownVisible = false
    var categories: [(id: Int, name: String, selected: Bool)] = [
        (9, "General Knowledge", false),
        (10, "Entertainment: Books", false),
        (11, "Entertainment: Film", false),
        (12, "Entertainment: Music", false),
        (13, "Entertainment: Musicals & Theatres", false),
        (14, "Entertainment: Television", false),
        (15, "Entertainment: Video Games", false),
        (16, "Entertainment: Board Games", false),
        (17, "Science & Nature", false),
        (18, "Science: Computers", false),
        (19, "Science: Mathematics", false),
        (20, "Mythology", false),
        (21, "Sports", false),
        (22, "Geography", false),
        (23, "History", false),
        (24, "Politics", false),
        (25, "Art", false),
        (26, "Celebrities", false),
        (27, "Animals", false),
        (28, "Vehicles", false),
        (29, "Entertainment: Comics", false),
        (30, "Science: Gadgets", false),
        (31, "Entertainment: Japanese Anime & Manga", false),
        (32, "Entertainment: Cartoon & Animations", false)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] CreateRoomViewController loaded")
        setupUI()
        setupGestureRecognizer()
    }

    func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.barStyle = .default
        doneToolbar.translatesAutoresizingMaskIntoConstraints = true
        doneToolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        ]
        doneToolbar.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 44)

        playerNameTextField.inputAccessoryView = doneToolbar
        questionGoalTextField.inputAccessoryView = doneToolbar
        maxPlayersTextField.inputAccessoryView = doneToolbar
    }

    func setupUI() {
        view.backgroundColor = .systemBackground

        // Ensure UI elements are configured correctly
        playerNameTextField.delegate = self
        questionGoalTextField.delegate = self
        maxPlayersTextField.delegate = self

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

        addDoneButtonOnKeyboard()
        playerNameTextField.keyboardType = .asciiCapable
        questionGoalTextField.keyboardType = .numberPad
        maxPlayersTextField.keyboardType = .numberPad

        playerNameTextField.placeholder = "Enter Your Name"
        questionGoalTextField.placeholder = "Max Question (e.g., 10)"
        maxPlayersTextField.placeholder = "Enter Max Players (e.g., 8)"

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

        categoryButton.setTitle("Select Categories (0 selected)", for: .normal)
        categoryButton.backgroundColor = .systemBackground
        categoryButton.layer.borderWidth = 1
        categoryButton.layer.borderColor = UIColor.systemGray4.cgColor
        categoryButton.layer.cornerRadius = 8
        categoryButton.contentHorizontalAlignment = .left
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)
        categoryButton.configuration = config
        categoryButton.addTarget(self, action: #selector(toggleCategoryDropdown), for: .touchUpInside)
        categoryButton.translatesAutoresizingMaskIntoConstraints = false

        categoryDropdown.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        categoryDropdown.delegate = self
        categoryDropdown.dataSource = self
        categoryDropdown.isHidden = true
        view.insertSubview(createButton, belowSubview: categoryDropdown)
        categoryDropdown.layer.borderWidth = 1
        categoryDropdown.layer.borderColor = UIColor.systemGray4.cgColor
        categoryDropdown.layer.cornerRadius = 8
        categoryDropdown.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(backButton)
        view.addSubview(playerNameTextField)
        view.addSubview(questionGoalTextField)
        view.addSubview(maxPlayersTextField)
        view.addSubview(difficultyPicker)
        view.addSubview(createButton)
        view.addSubview(statusLabel)
        view.addSubview(categoryButton)
        view.addSubview(categoryDropdown)

        NSLayoutConstraint.activate([
            playerNameTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerNameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            playerNameTextField.widthAnchor.constraint(equalToConstant: 300),

            questionGoalTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            questionGoalTextField.topAnchor.constraint(equalTo: playerNameTextField.bottomAnchor, constant: 30),
            questionGoalTextField.widthAnchor.constraint(equalTo: playerNameTextField.widthAnchor),

            maxPlayersTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            maxPlayersTextField.topAnchor.constraint(equalTo: questionGoalTextField.bottomAnchor, constant: 30),
            maxPlayersTextField.widthAnchor.constraint(equalTo: questionGoalTextField.widthAnchor),

            difficultyPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            difficultyPicker.topAnchor.constraint(equalTo: maxPlayersTextField.bottomAnchor, constant: 30),

            categoryButton.topAnchor.constraint(equalTo: difficultyPicker.bottomAnchor, constant: 30),
            categoryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            categoryButton.heightAnchor.constraint(equalToConstant: 44),

            categoryDropdown.topAnchor.constraint(equalTo: categoryButton.bottomAnchor, constant: 10),
            categoryDropdown.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoryDropdown.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            categoryDropdown.heightAnchor.constraint(equalToConstant: 300),

            createButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            createButton.widthAnchor.constraint(equalToConstant: 200),
            createButton.heightAnchor.constraint(equalToConstant: 50),

            statusLabel.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    func setupGestureRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        swipeDownGesture.direction = .down
        view.addGestureRecognizer(swipeDownGesture)

        // Ensure text fields resign first responder on return
        playerNameTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
        questionGoalTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
        maxPlayersTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)

        playerNameTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
        questionGoalTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
        maxPlayersTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func createRoom() {
        print("[DEBUG] [createRoom] Creating room with playerName: \(playerNameTextField.text ?? ""), questionGoal: \(questionGoalTextField.text ?? ""), maxPlayers: \(maxPlayersTextField.text ?? ""), difficulty: \(selectedDifficulty)")
        print("[DEBUG] createRoom called")
        guard let playerName = playerNameTextField.text, !playerName.isEmpty,
              let questionGoalText = questionGoalTextField.text, let questionGoal = Int(questionGoalText),
              let maxPlayersText = maxPlayersTextField.text, let maxPlayers = Int(maxPlayersText) else {
            print("[DEBUG] Input validation failed")
            statusLabel.text = "Please enter valid numbers."
            return
        }

        let selectedCategories = categories.filter { $0.selected }.map { $0.id }
        print("[DEBUG] Selected categories: \(selectedCategories)")
        if selectedCategories.count < 5 {
            statusLabel.text = "Please select at least 5 categories for the wheel."
            return
        }

        let parameters: [String: Any] = [
            "player_name": playerName,
            "question_goal": questionGoal,
            "max_players": maxPlayers,
            "difficulty": selectedDifficulty.lowercased(),
            "categories": selectedCategories
        ]
        print("[DEBUG] [createRoom] Parameters: \(parameters)")

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/create_room") else {
            print("[DEBUG] Invalid API URL")
            statusLabel.text = "Invalid API URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        print("[DEBUG] Sending request to create room with parameters: \(parameters)")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("[DEBUG] Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Network error: \(error.localizedDescription)"
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DEBUG] No HTTP response received")
                DispatchQueue.main.async {
                    self.statusLabel.text = "No HTTP response received."
                }
                return
            }

            print("[DEBUG] HTTP status code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("[DEBUG] Server error with response: \(response.debugDescription)")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Server error. Please try again later."
                }
                return
            }

            guard let data = data else {
                print("[DEBUG] No data received from server")
                DispatchQueue.main.async {
                    self.statusLabel.text = "No data received."
                }
                return
            }

            do {
                print("[DEBUG] Received response data: \(String(data: data, encoding: .utf8) ?? "")")
                let json = try JSON(data: data)
                if json["success"].boolValue, let roomCode = json["room_code"].string {
                    print("[DEBUG] Room created successfully with code: \(roomCode)")
                    DispatchQueue.main.async {
                        self.statusLabel.text = "Room created with code: \(roomCode)"
                        let lobbyVC = LobbyViewController()
                        lobbyVC.isHost = true
                        lobbyVC.playerName = playerName
                        lobbyVC.roomCode = roomCode
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            print("[DEBUG] Fetching room data for room code: \(roomCode)")
                            lobbyVC.fetchRoomData() // Ensure room is created before fetching data
                        }
                        lobbyVC.modalPresentationStyle = .fullScreen
                        lobbyVC.modalTransitionStyle = .crossDissolve
                        self.present(lobbyVC, animated: true) {
                            self.clearFields()
                        }
                    }
                } else {
                    let message = json["message"].stringValue
                    print("[DEBUG] Room creation failed with message: \(message)")
                    DispatchQueue.main.async {
                        self.statusLabel.text = message.isEmpty ? "Failed to create room." : message
                    }
                }
            } catch {
                print("[DEBUG] Failed to parse server response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Failed to parse server response."
                }
            }
        }.resume()
    }

    @objc func goBack() {
        dismiss(animated: true, completion: nil)
    }

    func clearFields() {
        playerNameTextField.text = ""
        questionGoalTextField.text = ""
        maxPlayersTextField.text = ""
        statusLabel.text = ""
    }

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

    @objc func toggleCategoryDropdown() {
        isDropdownVisible.toggle()

        if isDropdownVisible {
            view.bringSubviewToFront(categoryDropdown)
            categoryDropdown.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.categoryDropdown.alpha = 1.0
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.categoryDropdown.alpha = 0.0
            } completion: { _ in
                self.categoryDropdown.isHidden = true
            }
        }

        // Removed bringSubviewToFront for createButton to ensure it stays behind the dropdown

        let selectedCount = categories.filter { $0.selected }.count
        categoryButton.setTitle("Select Categories (\(selectedCount)) selected", for: .normal)
    }
}

extension CreateRoomViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        let category = categories[indexPath.row]
        cell.textLabel?.text = category.name.replacingOccurrences(of: "Entertainment: ", with: "").replacingOccurrences(of: "Science: ", with: "")
        cell.accessoryType = category.selected ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        categories[indexPath.row].selected.toggle()
        tableView.reloadRows(at: [indexPath], with: .automatic)

        let selectedCount = categories.filter { $0.selected }.count
        categoryButton.setTitle("Select Categories (\(selectedCount)) selected", for: .normal)
    }
}
