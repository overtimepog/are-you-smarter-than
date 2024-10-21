import UIKit

// SoloViewController.swift
class SoloViewController: UIViewController {

    // Trivia question data
    var currentQuestion: SoloTriviaQuestion?
    var currentQuestionIndex = 0
    var score = 0

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

        // After a delay, load the next question
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.optionButtons.forEach { button in
                button.backgroundColor = UIColor.systemGray6
                button.isEnabled = true // Re-enable buttons for next question
                button.removeFromSuperview()
            }
            self.optionButtons.removeAll()
            self.questionLabel.isHidden = true
            self.scoreLabel.isHidden = true
            self.currentQuestion = nil

            if self.currentQuestionIndex < 3 {
                self.loadQuestionFromCategory(category: self.selectedCategories.first!)
            } else {
                self.showRetryButton()
            }
        }
    }

    // Show retry button after 3 questions
    func showRetryButton() {
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(resetGame), for: .touchUpInside)
        view.addSubview(retryButton)

        NSLayoutConstraint.activate([
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // Reset the game
    @objc func resetGame() {
        view.subviews.filter { $0 is UIButton && ($0 as! UIButton).title(for: .normal) == "Retry" }.forEach { $0.removeFromSuperview() }

        score = 0
        currentQuestionIndex = 0
        scoreLabel.text = "Score: \(score)"
        scoreLabel.isHidden = true
        questionLabel.isHidden = true
        optionButtons.forEach { $0.removeFromSuperview() }
        optionButtons.removeAll()

        self.loadQuestionFromCategory(category: self.selectedCategories.first!)
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
