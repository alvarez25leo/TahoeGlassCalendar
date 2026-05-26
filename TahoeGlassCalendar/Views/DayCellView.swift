import SwiftUI

struct DayCellView: View {
    let day: CalendarDayItem
    let onSelect: () -> Void
    let onRightClick: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                ZStack {
                    if day.isToday {
                        Circle().fill(Color.accentColor)
                    } else if isHovering && !day.isSelected {
                        Circle().fill(Color.primary.opacity(0.08))
                    }

                    if day.isSelected && !day.isToday {
                        Circle().stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                    }

                    Text("\(day.dayNumber)")
                        .font(.system(size: 15, weight: day.isToday ? .semibold : .regular))
                        .foregroundStyle(numberColor)
                }
                .frame(width: CalendarTheme.dayCircleSize, height: CalendarTheme.dayCircleSize)

                dotsRow
            }
            .frame(width: CalendarTheme.dayCellSize, height: CalendarTheme.dayCellSize)
            .opacity(day.isCurrentMonth ? 1 : CalendarTheme.mutedOpacity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            RightClickCatcher(onRightClick: {
                onSelect()
                onRightClick()
            })
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }

    private var numberColor: Color {
        if day.isToday { return .white }
        if !day.isCurrentMonth { return .primary }
        if day.isWeekend { return .secondary }
        return .primary
    }

    @ViewBuilder
    private var dotsRow: some View {
        if day.eventColors.isEmpty {
            Color.clear.frame(height: 4)
        } else {
            HStack(spacing: 2) {
                ForEach(0..<day.eventColors.count, id: \.self) { index in
                    Circle()
                        .fill(Color(cgColor: day.eventColors[index]))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}
