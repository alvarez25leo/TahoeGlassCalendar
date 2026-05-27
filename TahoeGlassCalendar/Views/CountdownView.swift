import SwiftUI

/// Countdown al próximo evento con animación de dígitos tipo number-flow.
/// Tap → oculta (persistido). Cuando está oculto, se reemplaza por un icono
/// minimal que permite restaurarlo.
struct CountdownView: View {
    let event: CalendarEventItem?
    let isHidden: Bool
    let onToggleVisibility: () -> Void

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
                statusDot(state: snapshot.state)

                if let primary = snapshot.primaryText {
                    rollingNumber(primary)
                }

                if let suffix = snapshot.suffix {
                    Text(suffix)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .contentShape(Rectangle())
            .background(pillBackground(state: snapshot.state))
            .help(snapshot.tooltip(eventTitle: event.title))
        }
        .buttonStyle(.pressable(scale: 0.94))
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
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
    private func statusDot(state: CountdownState) -> some View {
        Circle()
            .fill(state.color)
            .frame(width: 5, height: 5)
            .overlay(
                Circle()
                    .stroke(state.color.opacity(0.4), lineWidth: 2)
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

    func tooltip(eventTitle: String) -> String {
        switch state {
        case .inProgress:
            return "En curso: \(eventTitle) — Click para ocultar"
        case .justStarted:
            return "\(eventTitle) finalizó — Click para ocultar"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let timeStr = formatter.string(from: eventStart)
            return "Próximo: \(eventTitle) a las \(timeStr) — Click para ocultar"
        }
    }
}
