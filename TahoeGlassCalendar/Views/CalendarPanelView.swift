import SwiftUI
import Combine

final class PopoverPresentationState: ObservableObject {
    @Published private(set) var generation = 0

    func markPresented() {
        generation += 1
    }
}

struct CalendarPanelView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var presentationState: PopoverPresentationState

    init(
        viewModel: CalendarViewModel,
        presentationState: PopoverPresentationState = PopoverPresentationState()
    ) {
        self.viewModel = viewModel
        self.presentationState = presentationState
    }

    var body: some View {
        ZStack {
            GlassPanel(refreshToken: presentationState.generation) {
                Group {
                    switch viewModel.permissionState {
                    case .fullAccess:
                        calendarContent
                    case .notDetermined:
                        PermissionView {
                            Task {
                                await viewModel.requestCalendarAccess()
                            }
                        }
                    case .denied, .restricted, .writeOnly, .unknown:
                        PermissionDeniedView()
                    }
                }
            }
            .frame(width: CalendarTheme.panelWidth)
            .background(
                keyboardShortcuts
                    .frame(width: 0, height: 0)
                    .opacity(0)
            )

            if viewModel.quickAddDate != nil {
                quickAddOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                    .zIndex(10)
            }
        }
        .animation(CalendarTheme.smoothSpring, value: viewModel.quickAddDate != nil)
    }

    private var calendarContent: some View {
        VStack(spacing: CalendarTheme.panelVStackSpacing) {
            CalendarHeaderView(viewModel: viewModel)
            WeekdayHeaderView()
            MonthGridView(viewModel: viewModel)

            Divider()
                .opacity(CalendarTheme.dividerOpacity)

            EventListView(
                events: viewModel.selectedDateEvents,
                pendingDeleteEventID: viewModel.pendingDeleteEvent?.id,
                upcomingEvent: viewModel.upcomingEvent,
                countdownHidden: viewModel.countdownHidden,
                isSearchActive: viewModel.isSearchActive,
                searchQuery: viewModel.searchQuery,
                searchResults: viewModel.searchResults,
                isSearchLoading: viewModel.isSearchLoading,
                searchScopeLabel: viewModel.searchScopeLabel,
                onToggleCountdown: { viewModel.toggleCountdownHidden() },
                onOpenCalendar: { viewModel.openCalendar() },
                onOpenEvent: { event in viewModel.openEvent(event) },
                onCreateEvent: { viewModel.createNewEvent() },
                onEditEvent: { event in viewModel.presentEdit(for: event) },
                onRequestDelete: { event in viewModel.requestDelete(event) },
                onConfirmDelete: { event in
                    Task { await viewModel.confirmDelete(event) }
                },
                onCancelDelete: { viewModel.cancelDelete() }
            )
        }
        .task {
            await viewModel.refreshAll()
        }
    }

    private var quickAddOverlay: some View {
        ZStack {
            // Backdrop dim + tap-to-dismiss.
            Color.black.opacity(CalendarTheme.backdropOpacity)
                .onTapGesture { viewModel.dismissQuickAdd() }
                .accessibilityHidden(true)

            QuickEventComposerView(
                initialDate: viewModel.quickAddDate ?? Date(),
                editingEvent: viewModel.editingEvent,
                calendars: viewModel.availableCalendars,
                defaultCalendarID: viewModel.defaultCalendarID(),
                errorMessage: viewModel.quickAddError,
                onCancel: { viewModel.dismissQuickAdd() },
                onSave: { draft in
                    await viewModel.saveDraft(draft)
                }
            )
            .padding(10)
        }
    }

    @ViewBuilder
    private var keyboardShortcuts: some View {
        VStack {
            Button("") { Task { await viewModel.goToPreviousMonth() } }
                .keyboardShortcut(.leftArrow, modifiers: .command)

            Button("") { Task { await viewModel.goToNextMonth() } }
                .keyboardShortcut(.rightArrow, modifiers: .command)

            Button("") { Task { await viewModel.goToToday() } }
                .keyboardShortcut("t", modifiers: [])

            Button("") { Task { await viewModel.moveSelection(by: -1) } }
                .keyboardShortcut(.leftArrow, modifiers: [])

            Button("") { Task { await viewModel.moveSelection(by: 1) } }
                .keyboardShortcut(.rightArrow, modifiers: [])

            Button("") { Task { await viewModel.moveSelection(by: -7) } }
                .keyboardShortcut(.upArrow, modifiers: [])

            Button("") { Task { await viewModel.moveSelection(by: 7) } }
                .keyboardShortcut(.downArrow, modifiers: [])

            Button("") { viewModel.openCalendar() }
                .keyboardShortcut("o", modifiers: .command)

            Button("") { viewModel.createNewEvent() }
                .keyboardShortcut("n", modifiers: .command)

            Button("") { viewModel.toggleSearch() }
                .keyboardShortcut("f", modifiers: .command)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}
