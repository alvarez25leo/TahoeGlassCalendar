import SwiftUI

struct WeekdayHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(CalendarTheme.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        isWeekendColumn(index)
                            ? Color.secondary.opacity(CalendarTheme.weekendSymbolOpacity)
                            : .secondary
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Encabezado de días de la semana, lunes a domingo")
    }

    private func isWeekendColumn(_ index: Int) -> Bool {
        // With Monday-first week: 0..4 = L..V, 5 = S, 6 = D
        index == 5 || index == 6
    }
}
