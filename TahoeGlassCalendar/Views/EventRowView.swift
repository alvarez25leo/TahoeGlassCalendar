import SwiftUI

struct EventRowView: View {
    let event: CalendarEventItem
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                colorIndicator

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(timeLabel)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 78, alignment: .leading)
                            .monospacedDigit()

                        Text(event.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.leading, 84)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }

    private var timeLabel: String {
        if event.isAllDay {
            return "Todo el día"
        }
        let start = DateFormatters.eventTime.string(from: event.startDate)
        let end = DateFormatters.eventTime.string(from: event.endDate)
        return "\(start)-\(end)"
    }

    @ViewBuilder
    private var colorIndicator: some View {
        let color: Color = {
            if let cg = event.calendarColor {
                return Color(cgColor: cg)
            }
            return Color.accentColor
        }()

        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 3, height: 28)
    }
}
