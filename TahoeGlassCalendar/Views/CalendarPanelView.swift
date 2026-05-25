import SwiftUI

struct CalendarPanelView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        GlassPanel {
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
    }

    private var calendarContent: some View {
        VStack(spacing: 14) {
            CalendarHeaderView(viewModel: viewModel)
            WeekdayHeaderView()

            MonthGridView(viewModel: viewModel)

            Divider()
                .opacity(0.5)

            EventListView(
                events: viewModel.selectedDateEvents,
                onOpenCalendar: {
                    viewModel.openCalendar()
                },
                onOpenEvent: { event in
                    viewModel.openEvent(event)
                },
                onCreateEvent: {
                    viewModel.createNewEvent()
                }
            )
        }
        .task {
            await viewModel.refreshAll()
        }
    }

    @ViewBuilder
    private var keyboardShortcuts: some View {
        // Botones invisibles que registran atajos de teclado dentro del popover.
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
        }
        .buttonStyle(.plain)
    }
}
