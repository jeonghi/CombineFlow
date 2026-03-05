import CombineFlow
import UIKit

@MainActor
final class CounterViewController: UIViewController {
    private let stepper: CounterStepper
    private var count = 0

    private let countLabel = UILabel()
    private let incrementButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    init(stepper: CounterStepper) {
        self.stepper = stepper
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Counter"
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        countLabel.text = "0"
        countLabel.font = .systemFont(ofSize: 48, weight: .bold)
        countLabel.textAlignment = .center

        incrementButton.setTitle("+ Increment", for: .normal)
        incrementButton.addTarget(self, action: #selector(increment), for: .touchUpInside)

        doneButton.setTitle("Done →", for: .normal)
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [countLabel, incrementButton, doneButton])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func increment() {
        count += 1
        countLabel.text = "\(count)"
    }

    @objc private func done() {
        stepper.counterDone(count: count)
    }
}
