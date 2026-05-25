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
    }

    private var calendarContent: some View {
        VStack(spacing: 16) {
            CalendarHeaderView(viewModel: viewModel)
            WeekdayHeaderView()
            MonthGridView(viewModel: viewModel)

            Divider()

            EventListView(
                events: viewModel.selectedDateEvents,
                onOpenCalendar: {
                    viewModel.openCalendar()
                },
                onOpenEvent: { event in
                    viewModel.openEvent(event)
                }
            )
        }
        .task {
            await viewModel.refresh()
        }
    }
}
