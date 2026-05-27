import SwiftUI

struct EmptyEventsView: View {
    let onCreateEvent: (() -> Void)?

    init(onCreateEvent: (() -> Void)? = nil) {
        self.onCreateEvent = onCreateEvent
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, options: .repeat(.continuous).speed(0.4))
                .accessibilityHidden(true)

            Text("Sin eventos para este día")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            if let onCreateEvent {
                Button(action: onCreateEvent) {
                    Label("Crear", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .labelStyle(.iconOnly)
                        .frame(width: CalendarTheme.capsuleHeightSmall, height: CalendarTheme.capsuleHeightSmall)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .background(createButtonBackground)
                .help("Crear evento (⌘N)")
                .accessibilityLabel("Crear evento")
            }
        }
        .frame(height: 40)
        .padding(.horizontal, CalendarTheme.tightSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sin eventos para este día")
    }

    @ViewBuilder
    private var createButtonBackground: some View {
        if #available(macOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            Circle()
                .fill(Color.primary.opacity(CalendarTheme.subtleHoverOpacity))
        }
    }
}
