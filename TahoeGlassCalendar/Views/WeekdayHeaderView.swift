import SwiftUI

struct WeekdayHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(CalendarTheme.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isWeekendColumn(index) ? Color.secondary.opacity(0.6) : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }

    private func isWeekendColumn(_ index: Int) -> Bool {
        // With Monday-first week: 0..4 = L..V, 5 = S, 6 = D
        index == 5 || index == 6
    }
}
