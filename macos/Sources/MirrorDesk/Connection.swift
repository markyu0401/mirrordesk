import Foundation
import Network

final class Connection {
    private let queue = DispatchQueue(label: "MirrorDesk.Connection")
    private var connection: NWConnection?

    func connect(host: String, port: UInt16) {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        connection.stateUpdateHandler = { state in
            // handle ready/failed
        }
        connection.start(queue: queue)
        self.connection = connection
    }

    func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }
}
