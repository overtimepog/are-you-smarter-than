import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication, 
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        // Initialize the Main Menu as the starting view controller
        DispatchQueue.main.async {
            let mainMenuVC = MainMenuViewController()
            let navigationController = UINavigationController(rootViewController: mainMenuVC)

            self.window?.rootViewController = navigationController
            self.window?.makeKeyAndVisible()
        }

        return true
    }
}
