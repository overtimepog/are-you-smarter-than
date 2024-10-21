import UIKit

class FlaskWrapper {
    static func transitionToLobby(from viewController: UIViewController, roomCode: String, playerName: String) {
        DispatchQueue.main.async {
            let lobbyVC = LobbyViewController()
            lobbyVC.roomCode = roomCode
            lobbyVC.playerName = playerName
            lobbyVC.modalPresentationStyle = .fullScreen
            viewController.present(lobbyVC, animated: true)
        }
    }
}
