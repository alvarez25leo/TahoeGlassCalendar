import SwiftUI

struct EventListView: View {
    let events: [CalendarEventItem]
    let pendingDeleteEventID: String?
    let upcomingEvent: CalendarEventItem?
    let countdownHidden: Bool

    // Estado de búsqueda (provisto por el panel).
    let isSearchActive: Bool
    let searchQuery: String
    let searchResults: [CalendarViewModel.SearchResultGroup]
    let isSearchLoading: Bool
    let searchScopeLabel: String

    let onToggleCountdown: () -> Void
    let onOpenCalendar: () -> Void
    let onOpenEvent: (CalendarEventItem) -> Void
    let onCreateEvent: () -> Void
    let onEditEvent: (CalendarEventItem) -> Void
    let onRequestDelete: (CalendarEventItem) -> Void
    let onConfirmDelete: (CalendarEventItem) -> Void
    let onCancelDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CalendarTheme.stackSpacing) {
            if isSearchActive && !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                searchSection
            } else if events.isEmpty {
                EmptyEventsView(onCreateEvent: onCreateEvent)
            } else {
                eventsScroll
            }

            footerBar
        }
    }

    // MARK: - Lista de eventos del día seleccionado

    private var eventsScroll: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: CalendarTheme.listInnerSpacing) {
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lista de eventos del día seleccionado")
    }

    // MARK: - Resultados de búsqueda agrupados

    private var searchSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: CalendarTheme.stackSpacing) {
                if searchResults.isEmpty && isSearchLoading {
                    searchLoadingState
                } else if searchResults.isEmpty {
                    searchEmptyState
                } else {
                    ForEach(searchResults) { group in
                        VStack(alignment: .leading, spacing: CalendarTheme.listInnerSpacing) {
                            Text(DateFormatters.searchGroupDate.string(from: group.date).capitalized)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .tracking(0.4)
                                .padding(.horizontal, CalendarTheme.rowPaddingH)
                                .padding(.top, 4)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(group.events) { event in
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
                }
            }
        }
        .frame(maxHeight: 220)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Resultados de búsqueda")
    }

    private var searchEmptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sin resultados para \"\(searchQuery)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Buscado en \(searchScopeLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(height: 40)
        .padding(.horizontal, CalendarTheme.rowPaddingH)
    }

    private var searchLoadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.65)
            Text("Buscando en \(searchScopeLabel)…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 40)
        .padding(.horizontal, CalendarTheme.rowPaddingH)
    }

    // MARK: - Footer

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
        .frame(height: CalendarTheme.capsuleHeightSmall)
    }

    @available(macOS 26.0, *)
    private var glassFooterButtons: some View {
        GlassEffectContainer(spacing: CalendarTheme.tightSpacing) {
            HStack(spacing: CalendarTheme.tightSpacing) {
                Button(action: onCreateEvent) {
                    Label("Crear", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10)
                        .frame(height: CalendarTheme.capsuleHeightSmall)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.92))
                .glassEffect(.regular.interactive(), in: Capsule())
                .help("Crear evento (⌘N)")
                .accessibilityLabel("Crear evento")

                Button(action: onOpenCalendar) {
                    Label("Abrir", systemImage: "calendar")
                        .font(.system(size: 11, weight: .medium))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10)
                        .frame(height: CalendarTheme.capsuleHeightSmall)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.92))
                .glassEffect(.regular.interactive(), in: Capsule())
                .help("Abrir Calendar en esta fecha (⌘O)")
                .accessibilityLabel("Abrir Calendar")
            }
        }
    }

    private var fallbackFooterButtons: some View {
        HStack(spacing: CalendarTheme.tightSpacing) {
            Button(action: onCreateEvent) {
                Label("Crear", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: CalendarTheme.capsuleHeightSmall)
                    .background(Capsule().fill(.regularMaterial))
            }
            .buttonStyle(.plain)
            .help("Crear evento (⌘N)")

            Button(action: onOpenCalendar) {
                Label("Abrir", systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: CalendarTheme.capsuleHeightSmall)
                    .background(Capsule().fill(.regularMaterial))
            }
            .buttonStyle(.plain)
            .help("Abrir Calendar en esta fecha (⌘O)")
        }
    }
}
