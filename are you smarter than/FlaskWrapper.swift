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
    
    static func createRoom(playerName: String, questionGoal: Int, maxPlayers: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let parameters: [String: Any] = ["player_name": playerName, "question_goal": questionGoal, "max_players": maxPlayers]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/create_room") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let roomCode = json["room_code"] as? String else {
                completion(.failure(NSError(domain: "Failed to create room", code: 0, userInfo: nil)))
                return
            }

            completion(.success(roomCode))
        }.resume()
    }

    static func joinRoom(roomCode: String, playerName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters: [String: Any] = ["room_code": roomCode, "player_name": playerName]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/join_room") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success else {
                completion(.failure(NSError(domain: "Failed to join room", code: 0, userInfo: nil)))
                return
            }

            completion(.success(()))
        }.resume()
    }

    static func leaveRoom(roomCode: String, playerName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters: [String: Any] = ["room_code": roomCode, "player_name": playerName]

        guard let url = URL(string: "https://api.areyousmarterthan.xyz/leave_room") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }.resume()
    }
}