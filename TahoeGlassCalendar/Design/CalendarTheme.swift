import SwiftUI
import CoreGraphics

/// Tokens de diseño centralizados. Cualquier valor que se use en más de una vista
/// (radius, padding, opacidad, color por defecto, animación, etc.) vive acá para
/// mantener consistencia visual sin pelearnos con valores mágicos por componente.
enum CalendarTheme {
    // MARK: Panel principal
    static let panelCornerRadius: CGFloat = 16
    static let panelPadding: CGFloat = 18
    static let panelWidth: CGFloat = 420
    static let panelVStackSpacing: CGFloat = 14

    // MARK: Modal (composer / overlays)
    static let modalCornerRadius: CGFloat = 18
    static let modalWidth: CGFloat = 360
    static let modalHeight: CGFloat = 440
    static let modalPaddingH: CGFloat = 14
    static let modalPaddingV: CGFloat = 10

    // MARK: Campos de formulario
    static let fieldCornerRadius: CGFloat = 9
    static let fieldPaddingH: CGFloat = 12
    static let fieldPaddingV: CGFloat = 9
    static let fieldFillOpacity: Double = 0.05

    // MARK: Filas (event list)
    static let rowCornerRadius: CGFloat = 8
    static let rowPaddingH: CGFloat = 8
    static let rowPaddingV: CGFloat = 6
    static let rowHoverOpacity: Double = 0.06

    // MARK: Cápsulas / botones
    static let capsuleHeight: CGFloat = 26
    static let capsuleHeightSmall: CGFloat = 24
    static let capsulePaddingH: CGFloat = 12

    // MARK: Grid de días
    static let dayCellSize: CGFloat = 42
    static let dayCircleSize: CGFloat = 30
    static let dayDotSize: CGFloat = 4
    static let dayDotSpacing: CGFloat = 2
    static let dayGridSpacing: CGFloat = 4

    // MARK: Trazos
    static let focusStrokeWidth: CGFloat = 1.2
    static let selectionStrokeWidth: CGFloat = 1.5
    static let borderStrokeWidth: CGFloat = 0.5

    // MARK: Símbolos del header (Lun-Dom)
    static let weekdaySymbols: [String] = ["L", "M", "M", "J", "V", "S", "D"]

    // MARK: Opacidades
    static let mutedOpacity: Double = 0.45
    static let subtleHoverOpacity: Double = 0.08
    static let dividerOpacity: Double = 0.5
    static let subtleDividerOpacity: Double = 0.3
    static let backdropOpacity: Double = 0.22
    static let popoverBorderOpacity: Double = 0.08
    static let weekendSymbolOpacity: Double = 0.85

    // MARK: Espaciado vertical genérico
    static let stackSpacing: CGFloat = 8
    static let tightSpacing: CGFloat = 4
    static let listInnerSpacing: CGFloat = 2

    // MARK: Animaciones unificadas
    static let microAnimation: Animation = .easeInOut(duration: 0.18)
    static let pressableSpring: Animation = .spring(response: 0.22, dampingFraction: 0.75)
    static let smoothSpring: Animation = .spring(response: 0.28, dampingFraction: 0.86)
    static let bouncySpring: Animation = .spring(response: 0.32, dampingFraction: 0.82)
    static let hoverSpring: Animation = .spring(response: 0.25, dampingFraction: 0.7)

    // MARK: Color por defecto cuando un calendario no tiene CGColor.
    static let defaultEventCGColor: CGColor = CGColor(red: 0, green: 0.48, blue: 1, alpha: 1)
    static var defaultEventColor: Color { Color(cgColor: defaultEventCGColor) }
}
