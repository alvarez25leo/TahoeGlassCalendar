import SwiftUI

struct EventListView: View {
    let events: [CalendarEventItem]
    let onOpenCalendar: () -> Void
    let onOpenEvent: (CalendarEventItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if events.isEmpty {
                EmptyEventsView()
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

            HStack {
                Spacer()
                Button("Open Calendar", action: onOpenCalendar)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
