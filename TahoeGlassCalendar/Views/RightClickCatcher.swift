import SwiftUI
import AppKit

/// NSView que captura SOLO right-click. Para el left-click devuelve nil en
/// hitTest para no interferir con los Button de SwiftUI debajo.
struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }
}

final class RightClickNSView: NSView {
    var onRightClick: (() -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    /// Solo "atrapa" el hit cuando el evento actual es right-click; el resto se
    /// deja pasar al SwiftUI Button por debajo.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        switch event.type {
        case .rightMouseDown, .rightMouseUp:
            return self
        default:
            return nil
        }
    }
}
