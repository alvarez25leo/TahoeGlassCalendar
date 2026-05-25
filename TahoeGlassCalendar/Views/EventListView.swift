import SwiftUI

struct EventListView: View {
    let events: [CalendarEventItem]
    let onOpenCalendar: () -> Void
    let onOpenEvent: (CalendarEventItem) -> Void
    let onCreateEvent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if events.isEmpty {
                emptyState
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
                .buttonStyle(.plain)
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
                .buttonStyle(.plain)
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
