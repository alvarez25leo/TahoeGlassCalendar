import SwiftUI

struct EventListView: View {
    let events: [CalendarEventItem]
    let onOpenCalendar: () -> Void
    let onOpenEvent: (CalendarEventItem) -> Void
    let onCreateEvent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if events.isEmpty {
                EmptyEventsView(onCreateEvent: onCreateEvent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(events) { event in
                            EventRowView(event: event) {
                                onOpenEvent(event)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            HStack(spacing: 6) {
                if !events.isEmpty {
                    Button {
                        onCreateEvent()
                    } label: {
                        Label("Crear", systemImage: "plus")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Crear evento (⌘N)")
                }

                Spacer()

                Button {
                    onOpenCalendar()
                } label: {
                    Label("Abrir Calendar", systemImage: "calendar")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Abrir Calendar en esta fecha (⌘O)")
            }
        }
    }
}
