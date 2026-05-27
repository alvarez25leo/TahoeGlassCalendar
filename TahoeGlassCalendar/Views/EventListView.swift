import SwiftUI

struct EventListView: View {
    let events: [CalendarEventItem]
    let pendingDeleteEventID: String?
    let upcomingEvent: CalendarEventItem?
    let countdownHidden: Bool
    let onToggleCountdown: () -> Void
    let onOpenCalendar: () -> Void
    let onOpenEvent: (CalendarEventItem) -> Void
    let onCreateEvent: () -> Void
    let onEditEvent: (CalendarEventItem) -> Void
    let onRequestDelete: (CalendarEventItem) -> Void
    let onConfirmDelete: (CalendarEventItem) -> Void
    let onCancelDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if events.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(events) { event in
                            EventRowView(
                                event: event,
                                isConfirmingDelete: event.id == pendingDeleteEventID,
                                onTap: { onOpenEvent(event) },
                                onEdit: { onEditEvent(event) },
                                onRequestDelete: { onRequestDelete(event) },
                                onConfirmDelete: { onConfirmDelete(event) },
                                onCancelDelete: onCancelDelete
                            )
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            footerBar
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, options: .repeat(.continuous).speed(0.4))
            Text("Sin eventos para este día")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 40)
        .padding(.horizontal, 4)
    }

    private var footerBar: some View {
        HStack(spacing: 6) {
            CountdownView(
                event: upcomingEvent,
                isHidden: countdownHidden,
                onToggleVisibility: onToggleCountdown
            )

            Spacer()

            if #available(macOS 26.0, *) {
                glassFooterButtons
            } else {
                fallbackFooterButtons
            }
        }
        .frame(height: 24)
    }

    @available(macOS 26.0, *)
    private var glassFooterButtons: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                Button(action: onCreateEvent) {
                    Label("Crear", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.92))
                .glassEffect(.regular.interactive(), in: Capsule())
                .help("Crear evento (⌘N)")

                Button(action: onOpenCalendar) {
                    Label("Abrir", systemImage: "calendar")
                        .font(.system(size: 11, weight: .medium))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.92))
                .glassEffect(.regular.interactive(), in: Capsule())
                .help("Abrir Calendar en esta fecha (⌘O)")
            }
        }
    }

    private var fallbackFooterButtons: some View {
        HStack(spacing: 4) {
            Button(action: onCreateEvent) {
                Label("Crear", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Capsule().fill(.regularMaterial))
            }
            .buttonStyle(.plain)
            .help("Crear evento (⌘N)")

            Button(action: onOpenCalendar) {
                Label("Abrir", systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Capsule().fill(.regularMaterial))
            }
            .buttonStyle(.plain)
            .help("Abrir Calendar en esta fecha (⌘O)")
        }
    }
}
