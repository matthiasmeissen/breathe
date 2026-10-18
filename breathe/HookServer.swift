import Foundation
import Network

/// Minimal HTTP listener on 127.0.0.1. Claude Code hooks hit
/// /working, /idle or /attention; nothing else is parsed.
final class HookServer {
    enum Event: String {
        case working    // UserPromptSubmit – Claude started a turn
        case idle       // Stop – Claude finished the turn
        case attention  // Notification – Claude needs you (permission prompt etc.)
    }

    var onEvent: ((Event) -> Void)?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "claude-breathe.hooks")

    func start(port: UInt16) throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1",
                                                 port: NWEndpoint.Port(rawValue: port)!)
        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.read(connection)
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("ClaudeBreathe: listener failed: \(error)")
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    private func read(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, _, error in
            guard error == nil, let data, let text = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            // Request line looks like: POST /working HTTP/1.1
            let requestLine = text.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
            let parts = requestLine.split(separator: " ")
            let path = parts.count > 1 ? String(parts[1]) : "/"
            let event = Event(rawValue: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))

            let status = event == nil ? "404 Not Found" : "200 OK"
            let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: response.data(using: .utf8),
                            completion: .contentProcessed { _ in connection.cancel() })

            if let event {
                DispatchQueue.main.async { self.onEvent?(event) }
            }
        }
    }
}
