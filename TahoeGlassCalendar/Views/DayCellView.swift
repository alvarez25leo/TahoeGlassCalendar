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
                        Circle().fill(Color.primary.opacity(CalendarTheme.subtleHoverOpacity))
                    }

                    if day.isSelected && !day.isToday {
                        Circle()
                            .stroke(
                                Color.accentColor.opacity(0.7),
                                lineWidth: CalendarTheme.selectionStrokeWidth
                            )
                    }

                    Text("\(day.dayNumber)")
                        .font(.system(size: 15, weight: day.isToday ? .semibold : .regular))
                        .foregroundStyle(numberColor)
                        .accessibilityHidden(true)
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
        .animation(CalendarTheme.hoverSpring, value: isHovering)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(day.isSelected ? [.isSelected, .isButton] : .isButton)
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
            Color.clear.frame(height: CalendarTheme.dayDotSize)
        } else {
            HStack(spacing: CalendarTheme.dayDotSpacing) {
                ForEach(0..<day.eventColors.count, id: \.self) { index in
                    Circle()
                        .fill(Color(cgColor: day.eventColors[index]))
                        .frame(width: CalendarTheme.dayDotSize, height: CalendarTheme.dayDotSize)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: CalendarTheme.dayDotSize)
        }
    }

    private var accessibilityLabelText: String {
        var parts: [String] = [DateFormatters.accessibleDate.string(from: day.date)]
        if day.isToday { parts.append("hoy") }
        if day.isSelected { parts.append("seleccionado") }
        if day.hasEvents {
            let n = day.eventColors.count
            parts.append(n == 1 ? "1 evento" : "\(n) eventos")
        } else {
            parts.append("sin eventos")
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHintText: String {
        "Click para seleccionar. Click derecho para crear evento."
    }
}
