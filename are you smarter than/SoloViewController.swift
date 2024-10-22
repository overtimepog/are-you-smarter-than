import UIKit

// SoloViewController.swift
class SoloViewController: UIViewController {

    // Trivia question data
    var currentQuestion: SoloTriviaQuestion?
    var currentQuestionIndex = 0
    var score = 0
    var wheelView: WheelView!
    var spinButton: UIButton!
    var arrowView: UIImageView!
    var categoryNameLabel = UILabel()
    var displayLink: CADisplayLink?

    // Category data
    var allCategories: [SoloTriviaCategory] = []
    var selectedCategories: [SoloTriviaCategory] = []

    // UI Elements
    let questionLabel = UILabel()
    var optionButtons: [UIButton] = []
    let scoreLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchCategories()
        setupWheel()
    }

    // Setup the wheel UI
    func setupWheel() {
        // Remove existing wheel if any
        wheelView?.removeFromSuperview()
        spinButton?.removeFromSuperview()
        arrowView?.removeFromSuperview()
        categoryNameLabel.removeFromSuperview()

        // Create a wheel view
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
        arrowView.tintColor = .red
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arrowView)

        NSLayoutConstraint.activate([
            arrowView.bottomAnchor.constraint(equalTo: wheelView.topAnchor, constant: 10),
            arrowView.centerXAnchor.constraint(equalTo: wheelView.centerXAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 30),
            arrowView.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Add category name label with wrapping
        categoryNameLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryNameLabel.textAlignment = .center
        categoryNameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        categoryNameLabel.textColor = .label
        categoryNameLabel.numberOfLines = 0 // Allow multiple lines for wrapping
        categoryNameLabel.lineBreakMode = .byWordWrapping
        view.addSubview(categoryNameLabel)
        NSLayoutConstraint.activate([
            categoryNameLabel.bottomAnchor.constraint(equalTo: arrowView.topAnchor, constant: -10),
            categoryNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), // Allow wrapping
            categoryNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Add spin button
        spinButton = UIButton(type: .system)
        spinButton.setTitle("Spin", for: .normal)
        spinButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        spinButton.translatesAutoresizingMaskIntoConstraints = false
        spinButton.addTarget(self, action: #selector(spinWheel), for: .touchUpInside)
        view.addSubview(spinButton)

        NSLayoutConstraint.activate([
            spinButton.topAnchor.constraint(equalTo: wheelView.bottomAnchor, constant: 20),
            spinButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Spin the wheel
    @objc func spinWheel() {
        // Disable the spin button during animation
        spinButton.isEnabled = false

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

        // Score label
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        scoreLabel.isHidden = true
        view.addSubview(scoreLabel)
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            scoreLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Fetch categories
    func fetchCategories() {
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
                    if let emoji = categoryEmojis[apiCategory.id] {
                        return SoloTriviaCategory(id: apiCategory.id, name: apiCategory.name, emoji: emoji)
                    } else {
                        return nil // Exclude categories without an emoji
                    }
                }

                // Randomly select 5 categories
                self.selectedCategories = self.allCategories.shuffled().prefix(5).map { $0 }

                DispatchQueue.main.async {
                    self.loadQuestionFromCategory(category: self.selectedCategories.first!)
                }
            } catch {
                print("Failed to decode categories: \(error)")
            }
        }.resume()
    }

    // Load question from the selected category
    func loadQuestionFromCategory(category: SoloTriviaCategory) {
        let urlString = "https://opentdb.com/api.php?amount=1&category=\(category.id)&type=multiple"
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
                allAnswers = allAnswers.map { $0.htmlDecoded() }
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

        // Update score
        scoreLabel.text = "Score: \(score)"
        scoreLabel.isHidden = false
    }

    // Handle option selection with animation
    @objc func optionSelected(_ sender: UIButton) {
        guard let currentQuestion = currentQuestion else { return }

        let selectedIndex = sender.tag
        let isCorrect = selectedIndex == currentQuestion.correctAnswer

        if isCorrect {
            score += 1 // Correct answer, increment score
        }

        // Update score label
        scoreLabel.text = "Score: \(score)"

        // Animate the selected button
        UIView.animate(withDuration: 0.3) {
            sender.backgroundColor = isCorrect ? UIColor.systemGreen : UIColor.systemRed
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

        // After a delay, load the next question or end the game
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if isCorrect {
                self.optionButtons.forEach { button in
                    button.backgroundColor = UIColor.systemGray6
                    button.isEnabled = true // Re-enable buttons for next question
                    button.removeFromSuperview()
                }
                self.optionButtons.removeAll()
                self.questionLabel.isHidden = true
                self.scoreLabel.isHidden = true
                self.currentQuestion = nil

                // Show the wheel again
                self.wheelView.isHidden = false
                self.spinButton.isHidden = false
                self.arrowView.isHidden = false
                self.categoryNameLabel.isHidden = false
                self.spinButton.isEnabled = true
            } else {
                // End the game and return to main menu
                self.dismiss(animated: true, completion: nil)
            }
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
