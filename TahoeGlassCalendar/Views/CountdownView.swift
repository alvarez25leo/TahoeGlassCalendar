import SwiftUI

/// Countdown al próximo evento con animación de dígitos tipo number-flow.
/// Tap → oculta (persistido). Cuando está oculto, se reemplaza por un icono
/// minimal que permite restaurarlo.
struct CountdownView: View {
    let event: CalendarEventItem?
    let isHidden: Bool
    let onToggleVisibility: () -> Void

    @State private var isHovering: Bool = false
    @State private var showDetailPopover: Bool = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isHidden {
                hiddenAffordance
            } else if let event {
                activeCountdown(for: event)
            } else {
                EmptyView()
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isHidden)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: event?.id)
    }

    // MARK: - Affordance cuando está oculto

    private var hiddenAffordance: some View {
        Button(action: onToggleVisibility) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.88))
        .help("Mostrar contador del próximo evento")
        .transition(.opacity.combined(with: .scale(scale: 0.7)))
    }

    // MARK: - Countdown activo

    @ViewBuilder
    private func activeCountdown(for event: CalendarEventItem) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let snapshot = CountdownSnapshot(event: event, now: context.date)
            countdownPill(snapshot: snapshot, event: event)
        }
    }

    @ViewBuilder
    private func countdownPill(snapshot: CountdownSnapshot, event: CalendarEventItem) -> some View {
        Button(action: onToggleVisibility) {
            HStack(spacing: 6) {
                statusDot(state: snapshot.state, color: eventColor(for: event))
                    .accessibilityHidden(true)

                if let primary = snapshot.primaryText {
                    rollingNumber(primary)
                        .accessibilityHidden(true)
                }

                if let suffix = snapshot.suffix {
                    Text(suffix)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: CalendarTheme.capsuleHeightSmall)
            .contentShape(Rectangle())
            .background(pillBackground(state: snapshot.state))
        }
        .buttonStyle(.pressable(scale: 0.94))
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: event, snapshot: snapshot))
        .accessibilityHint("Doble click para ocultar el contador")
        .accessibilityAddTraits(.isButton)
        .onHover { hovering in
            isHovering = hovering
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    if !Task.isCancelled {
                        await MainActor.run { showDetailPopover = true }
                    }
                }
            } else {
                showDetailPopover = false
            }
        }
        .popover(isPresented: $showDetailPopover, arrowEdge: .top) {
            CountdownDetailCard(event: event, snapshot: snapshot)
        }
    }

    // MARK: - Rolling number

    /// Renderiza una cadena tipo "12:34" o "1h 23m" donde cada DIGITO se anima
    /// rolling vertical. Los separadores (":", "h", "m", " ") son estáticos.
    @ViewBuilder
    private func rollingNumber(_ text: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                if let digit = char.wholeNumberValue, (0...9).contains(digit) {
                    RollingDigit(digit: digit)
                } else {
                    Text(String(char))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Status dot

    @ViewBuilder
    private func statusDot(state: CountdownState, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 2)
                    .scaleEffect(state == .imminent ? 2.0 : 1.0)
                    .opacity(state == .imminent ? 0 : 0)
                    .animation(
                        state == .imminent
                            ? .easeOut(duration: 1.4).repeatForever(autoreverses: false)
                            : .default,
                        value: state
                    )
            )
    }

    private func eventColor(for event: CalendarEventItem) -> Color {
        if let cg = event.calendarColor {
            return Color(cgColor: cg)
        }
        return .accentColor
    }

    private func accessibilityLabel(for event: CalendarEventItem, snapshot: CountdownSnapshot) -> String {
        var parts: [String] = [snapshot.stateLabel, event.title]
        if let primary = snapshot.primaryText {
            parts.append(primary)
        }
        if let suffix = snapshot.suffix {
            parts.append(suffix)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Background

    @ViewBuilder
    private func pillBackground(state: CountdownState) -> some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(
                    state.useTint
                        ? .regular.tint(state.color.opacity(0.55)).interactive()
                        : .regular.interactive(),
                    in: Capsule()
                )
        } else {
            Capsule()
                .fill(state.useTint
                      ? AnyShapeStyle(state.color.opacity(0.18))
                      : AnyShapeStyle(.regularMaterial))
        }
    }
}

// MARK: - RollingDigit

/// Dígito 0-9 que anima verticalmente cuando cambia. Estilo number-flow.
private struct RollingDigit: View {
    let digit: Int

    private let digitHeight: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { n in
                Text("\(n)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .frame(height: digitHeight)
            }
        }
        .frame(height: digitHeight, alignment: .top)
        .offset(y: -CGFloat(digit) * digitHeight)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: digit)
        .clipped()
        .frame(width: 7)
    }
}

// MARK: - State / snapshot

enum CountdownState: Equatable {
    case future       // > 1h
    case soon         // 5-60 min — tint accent
    case imminent     // < 5 min — tint warning + pulse
    case inProgress   // evento corriendo
    case justStarted  // 0-60s post-start

    var color: Color {
        switch self {
        case .future:       return .secondary
        case .soon:         return .accentColor
        case .imminent:     return .orange
        case .inProgress:   return .green
        case .justStarted:  return .green
        }
    }

    var useTint: Bool {
        switch self {
        case .future:       return false
        case .soon, .imminent, .inProgress, .justStarted: return true
        }
    }
}

struct CountdownSnapshot {
    let state: CountdownState
    let primaryText: String?
    let suffix: String?
    private let totalSeconds: Int
    private let eventStart: Date

    init(event: CalendarEventItem, now: Date) {
        self.eventStart = event.startDate
        let delta = Int(event.startDate.timeIntervalSince(now))
        self.totalSeconds = delta

        // Evento en curso
        if delta <= 0 {
            let endDelta = Int(event.endDate.timeIntervalSince(now))
            if endDelta > 0 {
                self.state = .inProgress
                let mins = max(1, endDelta / 60)
                self.primaryText = "\(mins)"
                self.suffix = mins == 1 ? "min restantes" : "min restantes"
                return
            }
            self.state = .justStarted
            self.primaryText = nil
            self.suffix = "Finalizado"
            return
        }

        // Determinar estado
        if delta < 5 * 60 {
            self.state = .imminent
        } else if delta < 60 * 60 {
            self.state = .soon
        } else {
            self.state = .future
        }

        // Formato según rango. Minutos siempre visibles; segundos rollean cuando
        // queda menos de 24h. Más allá de un día, mostramos días + HH:MM.
        if delta < 60 * 60 {
            // MM:SS
            let m = delta / 60
            let s = delta % 60
            self.primaryText = String(format: "%02d:%02d", m, s)
            self.suffix = nil
        } else if delta < 24 * 60 * 60 {
            // H:MM:SS
            let h = delta / 3600
            let m = (delta % 3600) / 60
            let s = delta % 60
            self.primaryText = String(format: "%d:%02d:%02d", h, m, s)
            self.suffix = nil
        } else {
            // Xd HH:MM:SS
            let d = delta / 86_400
            let h = (delta % 86_400) / 3600
            let m = (delta % 3600) / 60
            let s = delta % 60
            self.primaryText = String(format: "%dd %02d:%02d:%02d", d, h, m, s)
            self.suffix = nil
        }
    }

    var stateLabel: String {
        switch state {
        case .future:       return "Próximo evento"
        case .soon:         return "Empieza pronto"
        case .imminent:     return "¡Ya casi!"
        case .inProgress:   return "En curso ahora"
        case .justStarted:  return "Finalizado"
        }
    }
}

// MARK: - Detail card (hover popover)

/// Card detallada que se muestra al hacer hover sobre el countdown.
/// Pensada para que el usuario entienda de un vistazo a qué evento corresponde
/// el contador antes de decidir si lo oculta.
struct CountdownDetailCard: View {
    let event: CalendarEventItem
    let snapshot: CountdownSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider().opacity(CalendarTheme.dividerOpacity * 0.85)
            scheduleRow
            if let location = event.location, !location.isEmpty {
                locationRow(location)
            }
            calendarRow
            if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                Divider().opacity(CalendarTheme.subtleDividerOpacity)
                notesRow(notes)
            }
            Divider().opacity(CalendarTheme.subtleDividerOpacity)
            footerHint
        }
        .padding(.horizontal, CalendarTheme.modalPaddingH)
        .padding(.vertical, 12)
        .frame(width: 280, alignment: .leading)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(eventColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.stateLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.state.color)
                    .tracking(0.6)

                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var scheduleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            iconBadge(systemName: "clock.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(scheduleText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(relativeText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func locationRow(_ location: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            iconBadge(systemName: "mappin.and.ellipse")
            Text(location)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var calendarRow: some View {
        HStack(alignment: .center, spacing: 8) {
            iconBadge(systemName: "calendar")
            HStack(spacing: 6) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 7, height: 7)
                Text(event.calendarTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
    }

    private func notesRow(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            iconBadge(systemName: "text.alignleft")
            Text(notes)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("Click en el contador para ocultarlo")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func iconBadge(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)
    }

    private var eventColor: Color {
        if let cg = event.calendarColor {
            return Color(cgColor: cg)
        }
        return .accentColor
    }

    private var scheduleText: String {
        if event.isAllDay {
            return "Todo el día · \(DateFormatters.selectedDateLong.string(from: event.startDate))"
        }
        let startTime = DateFormatters.eventTime.string(from: event.startDate)
        let endTime = DateFormatters.eventTime.string(from: event.endDate)
        let day = DateFormatters.selectedDateLong.string(from: event.startDate)
        return "\(day) · \(startTime)–\(endTime)"
    }

    private var relativeText: String {
        let now = Date()
        let delta = Int(event.startDate.timeIntervalSince(now))
        let duration = Int(event.endDate.timeIntervalSince(event.startDate))

        if delta <= 0 {
            let remaining = Int(event.endDate.timeIntervalSince(now))
            if remaining > 0 {
                return "Termina en \(formatDuration(remaining))"
            }
            return "Ya terminó"
        }

        let durationStr = formatDuration(duration)
        let relStr: String
        if delta < 60 {
            relStr = "Empieza en \(delta)s"
        } else if delta < 3600 {
            let m = delta / 60
            relStr = "Empieza en \(m) min"
        } else if delta < 86_400 {
            let h = delta / 3600
            let m = (delta % 3600) / 60
            relStr = m > 0 ? "Empieza en \(h)h \(m)m" : "Empieza en \(h)h"
        } else {
            let d = delta / 86_400
            let h = (delta % 86_400) / 3600
            relStr = h > 0 ? "Empieza en \(d)d \(h)h" : "Empieza en \(d)d"
        }
        return "\(relStr) · dura \(durationStr)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60) min" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}
