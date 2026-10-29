import Cocoa

final class Input {
    var onTouch: ((CGPoint) -> Void)?
    var onKey: ((UInt16) -> Void)?

    func handle(event: NSEvent, in view: NSView) {
        let point = view.convert(event.locationInWindow, from: nil)
        switch event.type {
        case .leftMouseDown, .leftMouseDragged:
            onTouch?(point)
        case .keyDown:
            onKey?(event.keyCode)
        default:
            break
        }
    }
}
