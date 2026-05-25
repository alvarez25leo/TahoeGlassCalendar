import SwiftUI

struct WeekdayHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(CalendarTheme.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }
}
