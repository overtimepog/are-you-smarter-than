import UIKit

class FlaskWrapper {
    static func transitionToLobby(from viewController: UIViewController, roomCode: String, playerName: String) {
        DispatchQueue.main.async {
            print("Room created successfully with room code: \(roomCode)")
            let lobbyVC = LobbyViewController()
            lobbyVC.roomCode = roomCode
            lobbyVC.playerName = playerName
            lobbyVC.modalPresentationStyle = .fullScreen
            viewController.present(lobbyVC, animated: true)
        }
    }
    
    static func createRoom(playerName: String, questionGoal: Int, maxPlayers: Int, completion: @escaping (Result<String, Error>) -> Void) {
        print("Starting to create room with playerName: \(playerName), questionGoal: \(questionGoal), maxPlayers: \(maxPlayers)")
        let parameters: [String: Any] = ["player_name": playerName, "question_goal": questionGoal, "max_players": maxPlayers]
        print("Creating room with parameters: \(parameters)")

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

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let roomCode = json["room_code"] as? String else {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Failed to decode room data. Response: \(jsonString)")
                } else {
                    print("Failed to decode room data. Unable to convert data to string.")
                }
                completion(.failure(NSError(domain: "Failed to create room", code: 0, userInfo: nil)))
                return
            }

            DispatchQueue.main.async {
                completion(.success(roomCode))
            }
        }.resume()
    }

    static func joinRoom(roomCode: String, playerName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("Starting to join room with roomCode: \(roomCode), playerName: \(playerName)")
        print("Starting to leave room with roomCode: \(roomCode), playerName: \(playerName)")
        let parameters: [String: Any] = ["room_code": roomCode, "player_name": playerName]
        print("Leaving room with parameters: \(parameters)")
        print("Joining room with parameters: \(parameters)")

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
