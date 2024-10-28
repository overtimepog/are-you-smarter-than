import Foundation
import SocketIO

class SocketIOManager {
    static let shared = SocketIOManager()
    var socket: SocketIOClient

    private init() {
        let manager = SocketManager(socketURL: URL(string: "https://api.areyousmarterthan.xyz")!, config: [.log(true), .compress])
        socket = manager.defaultSocket
        socket.on(clientEvent: .connect) { data, ack in
            print("[DEBUG] Socket connected")
        }

        socket.on(clientEvent: .disconnect) { data, ack in
            print("[DEBUG] Socket disconnected")
        }

        socket.on(clientEvent: .reconnect) { data, ack in
            print("[DEBUG] Socket attempting to reconnect")
        }
    }

    func reconnect() {
        if socket.status != .connected {
            print("[DEBUG] Attempting to reconnect socket")
            socket.connect()
        }

    func establishConnection() {
        socket.connect()
    }

    func closeConnection() {
        socket.disconnect()
    }
}
