import Foundation
import SocketIO

class SocketIOManager {
    static let shared = SocketIOManager()
    var socket: SocketIOClient

    private init() {
        let manager = SocketManager(socketURL: URL(string: "https://api.areyousmarterthan.xyz")!, config: [.log(true), .compress])
        socket = manager.defaultSocket
    }

    func establishConnection() {
        socket.connect()
    }

    func closeConnection() {
        socket.disconnect()
    }
}
