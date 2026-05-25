import SwiftUI

struct EventRowView: View {
    let event: CalendarEventItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                colorIndicator

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(timeLabel)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 78, alignment: .leading)

                        Text(event.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .padding(.leading, 84)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var timeLabel: String {
        if event.isAllDay {
            return "All Day"
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
