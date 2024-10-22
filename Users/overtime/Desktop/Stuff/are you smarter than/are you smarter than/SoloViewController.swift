import UIKit

class SoloViewController: UIViewController {

    var nextButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Add next button
        nextButton = UIButton(type: .system)
        nextButton.setTitle("Next", for: .normal)
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextQuestion), for: .touchUpInside)
        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        nextButton.isHidden = true // Initially hide the next button
    }

    @objc func nextQuestion() {
        // Logic to proceed to the next question
        // This is where you would implement the transition to the next question
        print("Next question")
        nextButton.isHidden = true // Hide the button after pressing
    }
}
