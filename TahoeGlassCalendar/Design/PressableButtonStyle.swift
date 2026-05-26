import SwiftUI

/// Button style con press feedback (scale around center -> no layout shift).
/// Reemplaza `.buttonStyle(.plain)` cuando quieras feedback táctil.
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.94
    var response: Double = 0.22
    var damping: Double = 0.6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.spring(response: response, dampingFraction: damping), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle {
        PressableButtonStyle(pressedScale: scale)
    }
}
