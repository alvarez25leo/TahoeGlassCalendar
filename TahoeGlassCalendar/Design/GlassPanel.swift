import SwiftUI

struct GlassPanel<Content: View>: View {
    let content: Content
    let refreshToken: Int

    init(refreshToken: Int = 0, @ViewBuilder content: () -> Content) {
        self.refreshToken = refreshToken
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            content
                .padding(CalendarTheme.panelPadding)
                .background {
                    RoundedRectangle(
                        cornerRadius: CalendarTheme.panelCornerRadius,
                        style: .continuous
                    )
                    .fill(.clear)
                    .glassEffect(
                        .regular,
                        in: RoundedRectangle(
                            cornerRadius: CalendarTheme.panelCornerRadius,
                            style: .continuous
                        )
                    )
                    .id(refreshToken)
                }
        } else {
            content
                .padding(CalendarTheme.panelPadding)
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: CalendarTheme.panelCornerRadius,
                        style: .continuous
                    )
                )
        }
    }
}
