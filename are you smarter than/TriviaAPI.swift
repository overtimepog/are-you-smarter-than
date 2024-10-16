import Foundation

struct Player: Codable {
    let id: Int
    let username: String
}

struct GameProgress: Codable {
    let message: String
    let is_correct: Bool
}

class TriviaAPI {
    private let baseURL = "http://localhost:3000"
    
    // Shared URLSession instance
    private let session = URLSession.shared

    // Retrieve or generate a device token and store it in UserDefaults
    private var deviceToken: String {
        if let token = UserDefaults.standard.string(forKey: "device_token") {
            return token
        } else {
            let newToken = UUID().uuidString
            UserDefaults.standard.set(newToken, forKey: "device_token")
            return newToken
        }
    }

    func register(username: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/register") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["username": username]
        request.httpBody = try? JSONEncoder().encode(body)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            if let response = try? JSONDecoder().decode([String: String].self, from: data),
               let token = response["device_token"] {
                UserDefaults.standard.set(token, forKey: "device_token")
                completion(.success(token))
            } else {
                completion(.failure(NSError(domain: "RegisterError", code: 400, userInfo: nil)))
            }
        }.resume()
    }

    func getCurrentPlayer(completion: @escaping (Result<Player, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/players/me") else { return }
        
        var request = URLRequest(url: url)
        request.addValue(deviceToken, forHTTPHeaderField: "Device-Token")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            do {
                let player = try JSONDecoder().decode(Player.self, from: data)
                completion(.success(player))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func createGame(player2ID: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/games/") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(deviceToken, forHTTPHeaderField: "Device-Token")
        
        let body = ["player2_id": player2ID]
        request.httpBody = try? JSONEncoder().encode(body)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            if let response = try? JSONDecoder().decode([String: Int].self, from: data),
               let gameID = response["game_id"] {
                completion(.success(gameID))
            } else {
                completion(.failure(NSError(domain: "CreateGameError", code: 400, userInfo: nil)))
            }
        }.resume()
    }

    func addGameProgress(gameID: Int, questionID: Int, answer: String, completion: @escaping (Result<GameProgress, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/games/progress/") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(deviceToken, forHTTPHeaderField: "Device-Token")
        
        let body: [String: Any] = [
            "game_id": gameID,
            "question_id": questionID,
            "selected_answer": answer
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            do {
                let progress = try JSONDecoder().decode(GameProgress.self, from: data)
                completion(.success(progress))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
