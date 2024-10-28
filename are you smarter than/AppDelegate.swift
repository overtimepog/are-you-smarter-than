import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication, 
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        // Initialize the Loading Screen as the starting view controller
        let loadingVC = LoadingViewController()
        window?.rootViewController = loadingVC
        window?.makeKeyAndVisible()

        // Simulate loading process and transition to Main Menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let mainMenuVC = MainMenuViewController()
            let navigationController = UINavigationController(rootViewController: mainMenuVC)
            self.window?.rootViewController = navigationController
            self.window?.makeKeyAndVisible()
        }

        return true
    }
}
