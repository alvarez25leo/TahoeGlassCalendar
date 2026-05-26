import SwiftUI

struct EmptyEventsView: View {
    let onCreateEvent: (() -> Void)?

    init(onCreateEvent: (() -> Void)? = nil) {
        self.onCreateEvent = onCreateEvent
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, options: .repeat(.continuous).speed(0.4))

            Text("Sin eventos para este día")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            if let onCreateEvent = onCreateEvent {
                Button(action: onCreateEvent) {
                    Label("Crear evento", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
