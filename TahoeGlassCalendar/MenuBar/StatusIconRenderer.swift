import AppKit

final class StatusIconRenderer {
    private let canvasSize = NSSize(width: 20, height: 22)
    private let symbolPointSize: CGFloat = 16

    func render(hasDot: Bool) -> NSImage {
        let image = NSImage(size: canvasSize, flipped: false) { [self] _ in
            let symbolConfig = NSImage.SymbolConfiguration(
                pointSize: symbolPointSize,
                weight: .regular
            )

            guard let calendarImage = NSImage(
                systemSymbolName: "calendar",
                accessibilityDescription: "Calendar"
            )?.withSymbolConfiguration(symbolConfig) else {
                return true
            }

            calendarImage.isTemplate = true

            let symbolSize: CGFloat = 17
            let symbolOrigin = NSPoint(
                x: (canvasSize.width - symbolSize) / 2,
                y: (canvasSize.height - symbolSize) / 2
            )

            calendarImage.draw(
                in: NSRect(origin: symbolOrigin, size: NSSize(width: symbolSize, height: symbolSize))
            )

            if hasDot {
                let dotSize: CGFloat = 6
                let dotRect = NSRect(
                    x: canvasSize.width - dotSize - 0.5,
                    y: canvasSize.height - dotSize - 0.5,
                    width: dotSize,
                    height: dotSize
                )

                NSColor.black.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }

            return true
        }

        image.isTemplate = true
        return image
    }
}
