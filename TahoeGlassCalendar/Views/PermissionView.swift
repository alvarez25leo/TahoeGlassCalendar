import SwiftUI
import AppKit

struct PermissionView: View {
    let onAllow: () -> Void

    @State private var iconBounce: Int = 0

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear {
                    iconBounce = 1
                }

            Text("Acceso al calendario")
                .font(.system(size: 16, weight: .semibold))

            Text("Permite el acceso para mostrar tus eventos desde la barra de menú.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Permitir acceso", action: onAllow)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 4)
                .scaleEffect(iconBounce > 0 ? 1.0 : 0.95)
                .opacity(iconBounce > 0 ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: iconBounce)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.orange.opacity(0.85))

            Text("Acceso bloqueado")
                .font(.system(size: 14, weight: .semibold))

            Text("Habilítalo en Ajustes del Sistema → Privacidad y seguridad → Calendarios.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button("Abrir Ajustes del Sistema") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
