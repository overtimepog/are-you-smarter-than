import UIKit

// Make soloCategoryEmojis accessible from other classes
let soloCategoryEmojis: [Int: String] = [
    9: "🤔", 10: "📚", 11: "🎭", 12: "🎵", 13: "🎭", 14: "📺",
    15: "🎮", 16: "🎲", 17: "🍿", 18: "💻", 19: "➕", 20: "🧚",
    21: "⚽", 22: "🌍", 23: "📝", 24: "🗳️", 25: "🌟", 26: "🌟",
    27: "🐾", 28: "🚗", 29: "📚", 30: "📱", 31: "🔵", 32: "🐭"
]

// SoloViewController.swift
class SoloViewController: UIViewController, CAAnimationDelegate {

    var difficulty: String = "easy" // Default difficulty

    // Handle next button press
    @objc func nextQuestion() {
        // Reset button colors
        self.optionButtons.forEach { button in
            button.backgroundColor = UIColor.systemGray6
            button.isEnabled = true // Re-enable buttons for next question
            button.removeFromSuperview()
        }
        self.optionButtons.removeAll()
        self.questionLabel.isHidden = true
        self.currentQuestion = nil

        self.scoreAndQuestionLabel.text = "Streak: \(self.streak)"

        // Update difficulty based on question index
        if currentQuestionIndex >= 10 && currentQuestionIndex < 20 {
            difficulty = "medium"
        } else if currentQuestionIndex >= 20 {
            difficulty = "hard"
        }

        // Show the wheel again
        self.wheelView.isHidden = false
        self.spinButton?.isHidden = false
        self.arrowView?.isHidden = false
        self.categoryNameLabel.isHidden = false
        self.spinButton?.isEnabled = true
        self.nextButton?.isHidden = true // Hide the next button
        
        // Add back button
        let backButton = UIButton(type: .system)
        backButton.setTitle("Back", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(returnToMainMenu), for: .touchUpInside)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ])
    }

    // Trivia question data
    var currentQuestion: SoloTriviaQuestion?
    var currentQuestionIndex = 0
    var score = 0
    var streak = 0 // For solo mode

    // Category data
    var allCategories: [SoloTriviaCategory] = []
    var selectedCategories: [SoloTriviaCategory] = []

    var isCorrect: Bool = false
    var isWheelSpinning: Bool = false // To prevent multiple spins

    // UI Elements
    let questionLabel = UILabel()
    var optionButtons: [UIButton] = []
    let scoreAndQuestionLabel = UILabel()
    var wheelView: SoloWheelView!
    var nextButton: UIButton?
    var spinButton: UIButton?
    var arrowView: UIImageView?
    let categoryNameLabel = UILabel()
    var displayLink: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchCategories()
        questionLabel.isHidden = true
        scoreAndQuestionLabel.isHidden = false
    }

    // Setup the UI
    func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Question label
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

        // Score and Question label
        scoreAndQuestionLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreAndQuestionLabel.textAlignment = .center
        scoreAndQuestionLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        scoreAndQuestionLabel.isHidden = false
        view.addSubview(scoreAndQuestionLabel)
        NSLayoutConstraint.activate([
            scoreAndQuestionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            scoreAndQuestionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // Initialize next button but don't set constraints here
        nextButton = UIButton(type: .system)
        nextButton?.setTitle("Next", for: .normal)
        nextButton?.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nextButton?.translatesAutoresizingMaskIntoConstraints = false
        nextButton?.addTarget(self, action: #selector(nextQuestion), for: .touchUpInside)
        nextButton?.isHidden = true // Initially hide the next button
    }

    // Fetch categories
    func fetchCategories() {
        scoreAndQuestionLabel.text = "Streak: \(streak)"
        // Fetch categories from the API
        let urlString = "https://opentdb.com/api_category.php"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for categories")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
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
                let categoryResponse = try decoder.decode(SoloCategoryListResponse.self, from: data)

                // Map the categories to emojis
                self.allCategories = categoryResponse.triviaCategories.compactMap { apiCategory in
                    if let emoji = soloCategoryEmojis[apiCategory.id] {
                        return SoloTriviaCategory(id: apiCategory.id, name: apiCategory.name, emoji: emoji)
                    } else {
                        return nil // Exclude categories without an emoji
                    }
                }

                // Randomly select 5 categories
                self.selectedCategories = self.allCategories.shuffled().prefix(5).map { $0 }

                DispatchQueue.main.async {
                    self.setupWheel()
                }
            } catch {
                print("Failed to decode categories: \(error)")
            }
        }.resume()
    }

    // Setup the wheel UI
    func setupWheel() {
        // Remove existing wheel if any
        wheelView?.removeFromSuperview()
        spinButton?.removeFromSuperview()
        arrowView?.removeFromSuperview()
        categoryNameLabel.removeFromSuperview()

        // Create a wheel view
        wheelView = SoloWheelView(frame: .zero, categories: selectedCategories)
        wheelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wheelView)

        NSLayoutConstraint.activate([
            wheelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            wheelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            wheelView.widthAnchor.constraint(equalToConstant: 300),
            wheelView.heightAnchor.constraint(equalTo: wheelView.widthAnchor)
        ])

        // Add tap gesture recognizer to the wheel
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(spinWheel))
        wheelView.addGestureRecognizer(tapGesture)

        // Add arrow indicator
        arrowView = UIImageView(image: UIImage(systemName: "arrowtriangle.down.fill"))
        arrowView?.tintColor = .red
        arrowView?.translatesAutoresizingMaskIntoConstraints = false
        if let arrowView = arrowView {
            view.addSubview(arrowView)
        }

        if let arrowView = arrowView {
            NSLayoutConstraint.activate([
                arrowView.bottomAnchor.constraint(equalTo: wheelView.topAnchor, constant: 10),
                arrowView.centerXAnchor.constraint(equalTo: wheelView.centerXAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: 30),
                arrowView.heightAnchor.constraint(equalToConstant: 30)
            ])
        }

        // Add category name label with wrapping
        categoryNameLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryNameLabel.textAlignment = .center
        categoryNameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        categoryNameLabel.textColor = .label
        categoryNameLabel.numberOfLines = 0 // Allow multiple lines for wrapping
        categoryNameLabel.lineBreakMode = .byWordWrapping
        view.addSubview(categoryNameLabel)
        NSLayoutConstraint.activate([
            categoryNameLabel.bottomAnchor.constraint(equalTo: arrowView?.topAnchor ?? view.topAnchor, constant: -10),
            categoryNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), // Allow wrapping
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
        }

        if let spinButton = spinButton {
            NSLayoutConstraint.activate([
                spinButton.topAnchor.constraint(equalTo: wheelView.bottomAnchor, constant: 20),
                spinButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        }
    }

    // Spin the wheel
    @objc func spinWheel() {
        // Prevent multiple spins
        if isWheelSpinning {
            return
        }
        isWheelSpinning = true

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

        // Set wheel spinning to false
        isWheelSpinning = false

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
    func loadQuestionFromCategory(category: SoloTriviaCategory) {
        let urlString = "https://opentdb.com/api.php?amount=1&category=\(category.id)&type=multiple&difficulty=\(difficulty)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for question")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
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
                let apiResponse = try decoder.decode(SoloOpenTriviaResponse.self, from: data)
                guard let result = apiResponse.results.first else {
                    print("No questions found")
                    return
                }
                // Prepare options and find the correct answer index
                var allAnswers = result.incorrectAnswers + [result.correctAnswer]
                allAnswers = allAnswers.map { $0.htmlDecoded() } // Use existing htmlDecoded()
                let shuffledOptions = allAnswers.shuffled()
                let correctAnswerIndex = shuffledOptions.firstIndex(of: result.correctAnswer.htmlDecoded()) ?? 0

                let question = SoloTriviaQuestion(
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
    func showQuestion(question: SoloTriviaQuestion) {
        // Hide the wheel and spin button
        wheelView.isHidden = true
        spinButton?.isHidden = true
        arrowView?.isHidden = true
        categoryNameLabel.isHidden = true

        // Set up question UI
        currentQuestion = question
        currentQuestionIndex += 1 // Keep track of the number of times
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
                button.topAnchor.constraint(equalTo: index == 0 ? questionLabel.bottomAnchor : optionButtons[index - 1].bottomAnchor, constant: 20),
                button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                button.heightAnchor.constraint(equalToConstant: 50)
            ])
        }

        // Add next button below the last option button
        if let nextButton = self.nextButton {
            nextButton.removeFromSuperview()
            nextButton.isHidden = true // Hide it initially
            view.addSubview(nextButton)
            NSLayoutConstraint.activate([
                nextButton.topAnchor.constraint(equalTo: optionButtons.last!.bottomAnchor, constant: 20),
                nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                nextButton.heightAnchor.constraint(equalToConstant: 50)
            ])
        }

        // Update streak
        scoreAndQuestionLabel.text = "Streak: \(streak)"
        scoreAndQuestionLabel.isHidden = false
    }

    // Handle option selection with animation
    @objc func optionSelected(_ sender: UIButton) {
        guard let currentQuestion = currentQuestion else { return }

        let selectedIndex = sender.tag
        isCorrect = selectedIndex == currentQuestion.correctAnswer

        if isCorrect {
            score += 1 // Correct answer, increment score
            streak += 1
        } else {
            streak = 0
        }

        // Update streak label
        scoreAndQuestionLabel.text = "Streak: \(streak)"

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

        // After a delay, show the next button
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.nextButton?.isHidden = false
            self?.nextButton?.removeTarget(nil, action: nil, for: .allEvents)
            self?.nextButton?.addTarget(self, action: #selector(self?.nextQuestion), for: .touchUpInside)
        }
    }

    // Return to main menu (if needed elsewhere)
    @objc func returnToMainMenu() {
        self.navigationController?.popToRootViewController(animated: true)
    }

    // Reset the game
    @objc func resetGame() {
        score = 0
        streak = 0
        currentQuestionIndex = 0
        questionLabel.isHidden = true
        optionButtons.forEach { $0.removeFromSuperview() }
        optionButtons.removeAll()

        // Show the wheel again
        self.wheelView.isHidden = false
        self.spinButton?.isHidden = false
        self.arrowView?.isHidden = false
        self.categoryNameLabel.isHidden = false
        self.spinButton?.isEnabled = true
    }
}

// SoloWheelView class to draw the wheel
class SoloWheelView: UIView {
    var categories: [SoloTriviaCategory]

    init(frame: CGRect, categories: [SoloTriviaCategory]) {
        self.categories = categories
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        self.categories = []
        super.init(coder: aDecoder)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        // Draw the wheel
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

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

// SoloTriviaQuestion model
struct SoloTriviaQuestion: Codable {
    let question: String
    let options: [String]
    let correctAnswer: Int
}

// SoloOpenTriviaResponse model
struct SoloOpenTriviaResponse: Codable {
    let results: [SoloOpenTriviaQuestion]
}

struct SoloOpenTriviaQuestion: Codable {
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]

    enum CodingKeys: String, CodingKey {
        case question
        case correctAnswer = "correct_answer"
        case incorrectAnswers = "incorrect_answers"
    }
}

// SoloTriviaCategory model
struct SoloTriviaCategory: Codable {
    let id: Int
    let name: String
    let emoji: String
}

// SoloCategoryListResponse model
struct SoloCategoryListResponse: Codable {
    let triviaCategories: [SoloTriviaCategoryAPI]

    enum CodingKeys: String, CodingKey {
        case triviaCategories = "trivia_categories"
    }
}

struct SoloTriviaCategoryAPI: Codable {
    let id: Int
    let name: String
}
