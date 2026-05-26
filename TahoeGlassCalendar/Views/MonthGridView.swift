import SwiftUI

struct MonthGridView: View {
    @ObservedObject var viewModel: CalendarViewModel

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 0, alignment: .center),
        count: 7
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(viewModel.days) { day in
                DayCellView(
                    day: day,
                    onSelect: { viewModel.selectDate(day.date) },
                    onRightClick: {
                        let suggested = viewModel.defaultQuickAddDate(for: day.date)
                        viewModel.presentQuickAdd(on: suggested)
                    }
                )
            }
        }
    }
}
