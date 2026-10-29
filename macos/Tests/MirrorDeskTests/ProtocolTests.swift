import XCTest
@testable import MirrorDesk

final class ProtocolTests: XCTestCase {
    func testMessageEncoding() {
        let message = Message(type: .hello, payload: Data([1, 2, 3]))
        let encoded = message.encoded()
        XCTAssertEqual(encoded.count, 8)
        XCTAssertEqual(encoded[4], MessageType.hello.rawValue)
    }
}
