import SwiftUI

struct DayCellView: View {
    let day: CalendarDayItem
    let onSelect: () -> Void
    let onRightClick: () -> Void

    @State private var isHovering = false
    @State private var pulse: Bool = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                ZStack {
                    if day.isToday {
                        Circle()
                            .fill(Color.accentColor)
                            .scaleEffect(pulse ? 1.0 : 0.92)
                            .opacity(pulse ? 1.0 : 0.85)
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
        .buttonStyle(.pressable(scale: 0.88))
        .overlay(
            RightClickCatcher(onRightClick: {
                onSelect()
                onRightClick()
            })
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        .onAppear {
            if day.isToday {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onChange(of: day.isToday) { _, isToday in
            if isToday {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
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
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 4)
        }
    }
}
