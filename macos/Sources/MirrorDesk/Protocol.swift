import Foundation

enum MessageType: UInt8 {
    case hello = 1
    case welcome = 2
    case start = 3
    case ready = 4
    case videoConfig = 5
    case videoFrame = 6
    case touch = 7
    case key = 8
    case text = 9
    case scroll = 10
    case global = 11
    case ping = 12
    case pong = 13
    case orientation = 14
    case error = 15
}

struct Message {
    let type: MessageType
    let payload: Data

    func encoded() -> Data {
        var data = Data()
        var length = UInt32(payload.count + 1).bigEndian
        data.append(Data(bytes: &length, count: 4))
        data.append(type.rawValue)
        data.append(payload)
        return data
    }
}
