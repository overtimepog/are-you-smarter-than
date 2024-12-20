import UIKit
import SocketIO

// Make categoryEmojis accessible from other classes
let categoryEmojis: [Int: String] = [
    9: "🤔", 10: "📚", 11: "🎭", 12: "🎵", 13: "🎭", 14: "📺",
    15: "🎮", 16: "🎲", 17: "🍿", 18: "💻", 19: "➕", 20: "🧪",
    21: "⚽", 22: "🌍", 23: "📝", 24: "🗳", 25: "🌟", 26: "🌟",
    27: "🐾", 28: "🚗", 29: "📚", 30: "📱", 31: "🔵", 32: "🐭"
]

// TriviaViewController.swift
class TriviaViewController: UIViewController, CAAnimationDelegate {

    var difficulty: String = "easy" // Default difficulty

    // Trivia question data
    var currentQuestion: TriviaQuestion?
    var currentQuestionIndex = 0
    var score = 0

    // Category data
    var allCategories: [TriviaCategory] = []
    var selectedCategories: [TriviaCategory] = []
    var roomCategories: [Int] = [] // Store categories from room creation

    // Added 'categories' property to store category names
    var categories: [String] = []  // <-- Added this line

    // Multiplayer game data
    var numberOfPlayers: Int = 1 // Default to 1
    var roomCode: String = "" // Set this when transitioning to the trivia view
    var questionGoal: Int = 0 // Set this when transitioning to the trivia view
    var playerName: String = ""
    var playerId: String = ""
    var isCorrect: Bool = false

    // UI Elements
    let questionLabel = UILabel()
    var optionButtons: [UIButton] = []
    let scoreAndQuestionLabel = UILabel()
    var wheelView: WheelView!
    var nextButton: UIButton?
    var spinButton: UIButton?
    var arrowView: UIImageView?
    let categoryNameLabel = UILabel()
    var displayLink: CADisplayLink?
    var rankings: [[String: Any]] = [] // Add this property to hold rankings

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        fetchRoomCategories() // Fetch room categories first
        questionLabel.isHidden = true
        scoreAndQuestionLabel.isHidden = false
        // Establish socket connection
        SocketIOManager.shared.establishConnection()
    }

    deinit {
        // Close socket connection when the view controller is deinitialized
        SocketIOManager.shared.closeConnection()
    }

    // Fetch categories from the room data
    func fetchRoomCategories() {
        guard let url = URL(string: "https://api.areyousmarterthan.xyz/game_room/\(roomCode)") else {
            print("Invalid URL for room info")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching room info: \(error)")
                return
            }

            if let data = data {
                do {
                    // Parse the JSON data
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let categories = json?["categories"] as? [Int] {
                        self.roomCategories = categories
                    } else {
                        print("No categories found in room data")
                        self.roomCategories = [] // Empty array as fallback
                    }

                    // Map category IDs to names and store in 'categories' property
                    self.mapCategoryIDsToNames()
                } catch {
                    print("Error parsing room categories: \(error)")
                }
            }

            DispatchQueue.main.async {
                self.fetchCategories()
            }
        }.resume()
    }

    // Map category IDs to names using the allCategories list
    func mapCategoryIDsToNames() {
        // Ensure allCategories is populated
        if allCategories.isEmpty {
            // Fetch categories first
            fetchCategories()
        } else {
            // Map IDs to names
            self.categories = self.roomCategories.compactMap { id in
                allCategories.first(where: { $0.id == id })?.name
            }
        }
    }

    // Fetch all categories from Open Trivia DB
    func fetchCategories() {
        let urlString = "https://opentdb.com/api_category.php"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for categories")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                print("Failed to fetch categories: \(error)")
                return
            }

            guard let data = data else {
                print("No data returned for categories")
                return
            }

            do {
                let decoder = JSONDecoder()
                let categoryResponse = try decoder.decode(CategoryListResponse.self, from: data)

                // Map the categories to emojis
                self.allCategories = categoryResponse.triviaCategories.compactMap { apiCategory in
                    if let emoji = categoryEmojis[apiCategory.id] {
                        return TriviaCategory(id: apiCategory.id, name: apiCategory.name, emoji: emoji)
                    } else {
                        return nil // Exclude categories without an emoji
                    }
                }

                // Filter categories based on room selection
                self.selectedCategories = self.allCategories.filter { category in
                    self.roomCategories.contains(category.id)
                }

                // If no categories were found, fallback to a default set
                if self.selectedCategories.isEmpty {
                    self.selectedCategories = self.allCategories.shuffled().prefix(5).map { $0 }
                }

                // Map category IDs to names after fetching all categories
                self.mapCategoryIDsToNames()

                DispatchQueue.main.async {
                    self.setupWheel()
                }
            } catch {
                print("Failed to decode categories: \(error)")
            }
        }.resume()
    }

    // Setup UI elements
    func setupUI() {
        // Set up question label
        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        questionLabel.textAlignment = .center
        questionLabel.numberOfLines = 0
        questionLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        questionLabel.isHidden = true
        view.addSubview(questionLabel)
        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Set up score and question label
        scoreAndQuestionLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreAndQuestionLabel.textAlignment = .center
        scoreAndQuestionLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        scoreAndQuestionLabel.isHidden = false
        view.addSubview(scoreAndQuestionLabel)
        NSLayoutConstraint.activate([
            scoreAndQuestionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            scoreAndQuestionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // Add next button
        nextButton = UIButton(type: .system)
        nextButton?.setTitle("Next", for: .normal)
        nextButton?.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nextButton?.translatesAutoresizingMaskIntoConstraints = false
        nextButton?.addTarget(self, action: #selector(nextQuestion), for: .touchUpInside)
        if let nextButton = nextButton {
            view.addSubview(nextButton)
            NSLayoutConstraint.activate([
                nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
            nextButton.isHidden = true // Initially hide the next button
        }
    }

    // Handle next question
    @objc func nextQuestion() {
        // Reset button states
        self.optionButtons.forEach { button in
            button.backgroundColor = UIColor.systemGray6
            button.isEnabled = true
            button.removeFromSuperview()
        }
        self.optionButtons.removeAll()
        self.questionLabel.isHidden = true
        self.currentQuestion = nil

        // Show the wheel again
        self.wheelView.isHidden = false
        self.spinButton?.isHidden = false
        self.arrowView?.isHidden = false
        self.categoryNameLabel.isHidden = false
        self.spinButton?.isEnabled = true
        self.nextButton?.isHidden = true
    }

    // Setup the wheel with categories
    func setupWheel() {
        // Remove existing wheel if any
        wheelView?.removeFromSuperview()
        spinButton?.removeFromSuperview()
        arrowView?.removeFromSuperview()
        categoryNameLabel.removeFromSuperview()

        // Create the wheel view
        wheelView = WheelView(categories: selectedCategories)
        wheelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wheelView)
        NSLayoutConstraint.activate([
            wheelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            wheelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            wheelView.widthAnchor.constraint(equalToConstant: 300),
            wheelView.heightAnchor.constraint(equalTo: wheelView.widthAnchor)
        ])

        // Add arrow indicator
        arrowView = UIImageView(image: UIImage(systemName: "arrowtriangle.down.fill"))
        arrowView?.tintColor = .red
        arrowView?.translatesAutoresizingMaskIntoConstraints = false
        if let arrowView = arrowView {
            view.addSubview(arrowView)
            NSLayoutConstraint.activate([
                arrowView.bottomAnchor.constraint(equalTo: wheelView.topAnchor, constant: 10),
                arrowView.centerXAnchor.constraint(equalTo: wheelView.centerXAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: 30),
                arrowView.heightAnchor.constraint(equalToConstant: 30)
            ])
        }

        // Add category name label
        categoryNameLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryNameLabel.textAlignment = .center
        categoryNameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        categoryNameLabel.textColor = .label
        categoryNameLabel.numberOfLines = 0
        categoryNameLabel.lineBreakMode = .byWordWrapping
        view.addSubview(categoryNameLabel)
        NSLayoutConstraint.activate([
            categoryNameLabel.bottomAnchor.constraint(equalTo: arrowView?.topAnchor ?? view.topAnchor, constant: -10),
            categoryNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoryNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Add spin button
        spinButton = UIButton(type: .system)
        spinButton?.setTitle("Spin", for: .normal)
        spinButton?.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        spinButton?.translatesAutoresizingMaskIntoConstraints = false
        spinButton?.addTarget(self, action: #selector(spinWheel), for: .touchUpInside)
        if let spinButton = spinButton {
            view.addSubview(spinButton)
            NSLayoutConstraint.activate([
                spinButton.topAnchor.constraint(equalTo: wheelView.bottomAnchor, constant: 20),
                spinButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        }
    }

    // Spin the wheel
    @objc func spinWheel() {
        // Disable the spin button during animation
        spinButton?.isEnabled = false

        let randomRotation = CGFloat(Double.random(in: 2 * Double.pi * 3...2 * Double.pi * 5)) // Rotate 3 to 5 times
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = randomRotation
        rotationAnimation.duration = 3.0
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        rotationAnimation.fillMode = .forwards
        rotationAnimation.isRemovedOnCompletion = false
        rotationAnimation.delegate = self
        wheelView.layer.add(rotationAnimation, forKey: "rotationAnimation")

        // Start display link to update category name
        displayLink = CADisplayLink(target: self, selector: #selector(updateCategoryName))
        displayLink?.add(to: .main, forMode: .default)
    }

    // Update the category name label during spinning
    @objc func updateCategoryName() {
        let currentRotation = (wheelView.layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0
        let normalizedRotation = currentRotation.truncatingRemainder(dividingBy: 2 * CGFloat.pi)

        let anglePerSegment = (2 * CGFloat.pi) / CGFloat(selectedCategories.count)
        let adjustedRotation = (normalizedRotation + (CGFloat.pi / 2)).truncatingRemainder(dividingBy: 2 * CGFloat.pi)
        var index = Int(adjustedRotation / anglePerSegment)
        if adjustedRotation < 0 {
            index = selectedCategories.count + index
        }
        let selectedIndex = (selectedCategories.count - index) % selectedCategories.count

        let currentCategory = selectedCategories[selectedIndex]
        categoryNameLabel.text = currentCategory.name
    }

    // Animation delegate method
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        // Stop updating the category name
        displayLink?.invalidate()
        displayLink = nil

        // Get the angle where the wheel stopped
        let presentationLayer = wheelView.layer.presentation()
        let currentRotation = presentationLayer?.value(forKeyPath: "transform.rotation.z") as? CGFloat ?? 0
        let normalizedRotation = currentRotation.truncatingRemainder(dividingBy: 2 * CGFloat.pi)

        // Determine the selected category based on rotation
        let anglePerSegment = (2 * CGFloat.pi) / CGFloat(selectedCategories.count)
        let adjustedRotation = (normalizedRotation + (CGFloat.pi / 2)).truncatingRemainder(dividingBy: 2 * CGFloat.pi)
        var index = Int(adjustedRotation / anglePerSegment)
        if adjustedRotation < 0 {
            index = selectedCategories.count + index
        }
        let selectedIndex = (selectedCategories.count - index) % selectedCategories.count

        let selectedCategory = selectedCategories[selectedIndex]
        categoryNameLabel.text = selectedCategory.name
        // Fetch question from the selected category
        self.loadQuestionFromCategory(category: selectedCategory)
    }

    // Load question from the selected category
    func loadQuestionFromCategory(category: TriviaCategory) {
        let urlString = "https://opentdb.com/api.php?amount=1&category=\(category.id)&type=multiple&difficulty=\(difficulty)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for question")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                print("Failed to fetch question: \(error)")
                return
            }

            guard let data = data else {
                print("No data returned for question")
                return
            }

            do {
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(OpenTriviaResponse.self, from: data)
                guard let result = apiResponse.results.first else {
                    print("No questions found")
                    return
                }
                // Prepare options and find the correct answer index
                var allAnswers = result.incorrectAnswers + [result.correctAnswer]
                allAnswers = allAnswers.map { $0.htmlDecoded() }
                let shuffledOptions = allAnswers.shuffled()
                let correctAnswerIndex = shuffledOptions.firstIndex(of: result.correctAnswer.htmlDecoded()) ?? 0

                let question = TriviaQuestion(
                    question: result.question.htmlDecoded(),
                    options: shuffledOptions,
                    correctAnswer: correctAnswerIndex
                )
                DispatchQueue.main.async {
                    self.showQuestion(question: question)
                }
            } catch {
                print("Failed to decode question: \(error)")
            }
        }.resume()
    }

    // Show the question UI
    func showQuestion(question: TriviaQuestion) {
        // Hide the wheel and spin button
        wheelView.isHidden = true
        spinButton?.isHidden = true
        arrowView?.isHidden = true
        categoryNameLabel.isHidden = true

        // Set up question UI
        currentQuestion = question
        currentQuestionIndex += 1
        questionLabel.text = question.question
        questionLabel.isHidden = false

        // Remove existing buttons
        optionButtons.forEach { $0.removeFromSuperview() }
        optionButtons.removeAll()

        for (index, option) in question.options.enumerated() {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = index // Assign index to button
            button.setTitle(option, for: .normal)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.5
            button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            button.backgroundColor = UIColor.systemGray6
            button.layer.cornerRadius = 10
            button.addTarget(self, action: #selector(optionSelected(_:)), for: .touchUpInside)
            view.addSubview(button)
            optionButtons.append(button)

            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: CGFloat(40 + index * 60)),
                button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                button.heightAnchor.constraint(equalToConstant: 50)
            ])
        }

        // Update score label
        scoreAndQuestionLabel.text = "Score: \(score)/\(questionGoal)"
        scoreAndQuestionLabel.isHidden = false
    }

    // Handle option selection
    @objc func optionSelected(_ sender: UIButton) {
        guard let currentQuestion = currentQuestion else { return }

        let selectedIndex = sender.tag
        isCorrect = selectedIndex == currentQuestion.correctAnswer

        if isCorrect {
            score += 1
            sendResultToServer(correct: true)
        } else {
            sendResultToServer(correct: false)
        }

        // Animate the selected button
        UIView.animate(withDuration: 0.3) {
            sender.backgroundColor = self.isCorrect ? UIColor.systemGreen : UIColor.systemRed
        }

        // If incorrect, highlight the correct answer
        if !isCorrect {
            let correctButton = optionButtons[currentQuestion.correctAnswer]
            UIView.animate(withDuration: 0.3) {
                correctButton.backgroundColor = UIColor.systemGreen
            }
        }

        // Disable all buttons to prevent multiple taps
        optionButtons.forEach { $0.isEnabled = false }

        // Show next button
        nextButton?.isHidden = false
    }

    // Send the result to the server
    func sendResultToServer(correct: Bool) {
        // Emit event to notify other players about the game end
        SocketIOManager.shared.socket.emit("host_view_change", ["room_code": roomCode, "new_view": "WinView"])

        let parameters: [String: Any] = [
            "room_code": roomCode,
            "player_name": playerName,
            "is_correct": correct
        ]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/submit_answer") else {
            print("Invalid URL for submitting answer")
            return
        }

        print("Sending answer to server with parameters: \(parameters)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("Error submitting answer: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received from server")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response from server: \(json)")
                    if let success = json["success"] as? Bool, success {
                        if let scores = json["scores"] as? [[String: Any]] {
                            // Find current player's score
                            if let playerScore = scores.first(where: { ($0["player_name"] as? String) == self.playerName }) {
                                if let newScore = playerScore["score"] as? Int {
                                    DispatchQueue.main.async {
                                        self.score = newScore
                                        self.scoreAndQuestionLabel.text = "Score: \(self.score)/\(self.questionGoal)"
                                    }
                                }
                            }
                        }

                        if let gameEnded = json["game_ended"] as? Bool, gameEnded, let rankings = json["rankings"] as? [[String: Any]] {
                            DispatchQueue.main.async {
                                // Update player's win count on the server
                                self.endGame()
                                self.showWinViewController(with: rankings, roomCode: self.roomCode, playerName: self.playerName)
                                if rankings.contains(where: { $0["player_name"] as? String == self.playerName }) {
                                    if let playerIndex = self.rankings.firstIndex(where: { $0["player_name"] as? String == self.playerName }),
                                       let wins = self.rankings[playerIndex]["wins"] as? Int {
                                        print("Congratulations \(self.playerName)! You have \(wins) wins.")
                                    }
                                }
                            }
                        }
                    } else {
                        print("Failed to submit answer: \(json["message"] as? String ?? "Unknown error")")
                    }
                }
            } catch {
                print("Failed to parse server response: \(error)")
            }
        }.resume()
    }

    // Show the win view controller
    func showWinViewController(with rankings: [[String: Any]], roomCode: String, playerName: String) {
        let winVC = WinViewController()
        winVC.modalPresentationStyle = .fullScreen
        winVC.rankings = rankings
        winVC.roomCode = roomCode
        winVC.playerName = playerName
        print("[DEBUG] Showing WinViewController with roomCode: \(roomCode), playerName: \(playerName), rankings: \(rankings)")
        winVC.modalTransitionStyle = .crossDissolve
        self.present(winVC, animated: true, completion: nil)
    }
    // Function to update player's win count on the server
    func endGame() {
        let parameters: [String: Any] = [
            "room_code": roomCode,
            "winners": [playerName]  // Send winners as a list
        ]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/end_game") else {
            print("Invalid URL for ending game")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error incrementing win: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received from server")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response from server: \(json)")
                }
            } catch {
                print("Failed to parse server response: \(error)")
            }
        }.resume()
    }
}

// WheelView class to draw the wheel
class WheelView: UIView {
    var categories: [TriviaCategory]

    init(categories: [TriviaCategory]) {
        self.categories = categories
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func draw(_ rect: CGRect) {
        // Draw the wheel with validation
        guard let context = UIGraphicsGetCurrentContext(),
              rect.width > 0,
              rect.height > 0 else { return }

        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let anglePerSegment = (2 * CGFloat.pi) / CGFloat(categories.count)

        for (index, category) in categories.enumerated() {
            context.move(to: centerPoint)
            let startAngle = CGFloat(index) * anglePerSegment - CGFloat.pi / 2
            let endAngle = startAngle + anglePerSegment

            context.addArc(center: centerPoint, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

            context.setFillColor(UIColor(hue: CGFloat(index) / CGFloat(categories.count), saturation: 0.5, brightness: 1.0, alpha: 1.0).cgColor)
            context.fillPath()

            // Draw the emoji
            let emojiString = NSAttributedString(string: category.emoji, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 40)])
            let textAngle = startAngle + anglePerSegment / 2
            let textRadius = radius * 0.7
            let textX = centerPoint.x + textRadius * cos(textAngle) - 20
            let textY = centerPoint.y + textRadius * sin(textAngle) - 20
            let textRect = CGRect(x: textX, y: textY, width: 40, height: 40)
            emojiString.draw(in: textRect)
        }
    }
}

// String extension to decode HTML entities
extension String {
    func htmlDecoded() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let decoded = (try? NSAttributedString(data: data, options: options, documentAttributes: nil))?.string ?? ""

        return decoded
    }
}

// TriviaQuestion model
struct TriviaQuestion: Codable {
    let question: String
    let options: [String]
    let correctAnswer: Int
}

// OpenTriviaResponse model
struct OpenTriviaResponse: Codable {
    let results: [OpenTriviaQuestion]
}

struct OpenTriviaQuestion: Codable {
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]

    enum CodingKeys: String, CodingKey {
        case question
        case correctAnswer = "correct_answer"
        case incorrectAnswers = "incorrect_answers"
    }
}

// TriviaCategory model
struct TriviaCategory: Codable {
    let id: Int
    let name: String
    let emoji: String
}

// CategoryListResponse model
struct CategoryListResponse: Codable {
    let triviaCategories: [TriviaCategoryAPI]

    enum CodingKeys: String, CodingKey {
        case triviaCategories = "trivia_categories"
    }
}

struct TriviaCategoryAPI: Codable {
    let id: Int
    let name: String
}
