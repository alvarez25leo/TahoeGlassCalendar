import SwiftUI

struct DayCellView: View {
    let day: CalendarDayItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text("\(day.dayNumber)")
                    .font(.system(size: 15, weight: day.isToday ? .semibold : .regular))
                    .foregroundStyle(day.isToday ? Color.white : Color.primary)
                    .frame(width: CalendarTheme.dayCircleSize, height: CalendarTheme.dayCircleSize)
                    .background(todayBackground)
                    .overlay(selectedBorder)
                    .clipShape(Circle())

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 4)
                    .opacity(day.hasEvents ? 1 : 0)
            }
            .frame(width: CalendarTheme.dayCellSize, height: CalendarTheme.dayCellSize)
            .opacity(day.isCurrentMonth ? 1 : CalendarTheme.mutedOpacity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var todayBackground: some View {
        if day.isToday {
            Circle().fill(Color.accentColor)
        }
    }

    @ViewBuilder
    private var selectedBorder: some View {
        if day.isSelected && !day.isToday {
            Circle().stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
        }
    }
}
