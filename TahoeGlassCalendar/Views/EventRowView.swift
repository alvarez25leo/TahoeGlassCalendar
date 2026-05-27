import SwiftUI

struct EventRowView: View {
    let event: CalendarEventItem
    let isConfirmingDelete: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onRequestDelete: () -> Void
    let onConfirmDelete: () -> Void
    let onCancelDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Group {
            if isConfirmingDelete {
                confirmationRow
            } else {
                normalRow
            }
        }
        .animation(CalendarTheme.microAnimation, value: isConfirmingDelete)
    }

    // MARK: - Normal row

    private var normalRow: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                colorIndicator

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(timeLabel)
                            .font(.system(size: 11, weight: event.isAllDay ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(event.isAllDay ? .primary : .secondary)
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
                                .symbolEffect(.pulse, options: .speed(0.6), isActive: isHovering)
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
            .padding(.vertical, CalendarTheme.rowPaddingV)
            .padding(.horizontal, CalendarTheme.rowPaddingH)
            .background(
                RoundedRectangle(cornerRadius: CalendarTheme.rowCornerRadius, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(CalendarTheme.rowHoverOpacity) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.98))
        .onHover { hovering in isHovering = hovering }
        .animation(CalendarTheme.pressableSpring, value: isHovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Doble click para abrir en Calendar. Click derecho para editar o eliminar.")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onRequestDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    // MARK: - Confirmation row (inline, sin modal)

    private var confirmationRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeat(.continuous).speed(1.2))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("¿Eliminar \"\(event.title)\"?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("No se puede deshacer")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Button("Cancelar", action: onCancelDelete)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancelar eliminación")

            Button(action: onConfirmDelete) {
                Text("Eliminar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
            }
            .buttonStyle(.pressable(scale: 0.92))
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityLabel("Confirmar eliminación de \(event.title)")
        }
        .padding(.vertical, CalendarTheme.rowPaddingV)
        .padding(.horizontal, CalendarTheme.rowPaddingH)
        .background(
            RoundedRectangle(cornerRadius: CalendarTheme.rowCornerRadius, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CalendarTheme.rowCornerRadius, style: .continuous)
                .stroke(Color.red.opacity(0.3), lineWidth: CalendarTheme.borderStrokeWidth)
        )
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
            return CalendarTheme.defaultEventColor
        }()

        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 3, height: 28)
            .accessibilityHidden(true)
    }

    private var accessibilityLabelText: String {
        var parts: [String] = [event.title]
        parts.append(timeLabel)
        if let loc = event.location, !loc.isEmpty {
            parts.append("en \(loc)")
        }
        parts.append("calendario \(event.calendarTitle)")
        return parts.joined(separator: ", ")
    }
}
