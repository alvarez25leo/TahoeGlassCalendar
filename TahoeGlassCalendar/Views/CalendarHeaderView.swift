import SwiftUI

struct CalendarHeaderView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text(DateFormatters.capitalizedMonthTitle(for: viewModel.visibleMonth))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if #available(macOS 26.0, *) {
                liquidGlassNavGroup
            } else {
                fallbackNavGroup
            }
        }
    }

    @State private var prevBounce: Int = 0
    @State private var nextBounce: Int = 0
    @State private var todayBounce: Int = 0

    @available(macOS 26.0, *)
    private var liquidGlassNavGroup: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    prevBounce += 1
                    Task { await viewModel.goToPreviousMonth() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolEffect(.bounce, value: prevBounce)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Mes anterior")
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button {
                    todayBounce += 1
                    Task { await viewModel.goToToday() }
                } label: {
                    Text("Hoy")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .foregroundStyle(viewModel.isViewingCurrentMonth ? .secondary : .primary)
                        .contentShape(Rectangle())
                        .scaleEffect(todayBounce % 2 == 0 ? 1.0 : 1.05)
                        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: todayBounce)
                }
                .buttonStyle(.pressable(scale: 0.94))
                .glassEffect(
                    viewModel.isViewingCurrentMonth
                        ? .regular.interactive()
                        : .regular.tint(.accentColor.opacity(0.35)).interactive(),
                    in: Capsule()
                )
                .accessibilityLabel("Ir a hoy")

                Button {
                    nextBounce += 1
                    Task { await viewModel.goToNextMonth() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolEffect(.bounce, value: nextBounce)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Mes siguiente")
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
    }

    private var fallbackNavGroup: some View {
        HStack(spacing: 4) {
            fallbackButton(systemName: "chevron.left", accessibility: "Mes anterior") {
                Task { await viewModel.goToPreviousMonth() }
            }

            Button {
                Task { await viewModel.goToToday() }
            } label: {
                Text("Hoy")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(
                        Capsule().fill(
                            viewModel.isViewingCurrentMonth
                                ? AnyShapeStyle(.regularMaterial)
                                : AnyShapeStyle(Color.accentColor.opacity(0.25))
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ir a hoy")

            fallbackButton(systemName: "chevron.right", accessibility: "Mes siguiente") {
                Task { await viewModel.goToNextMonth() }
            }
        }
    }

    private func fallbackButton(
        systemName: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(.regularMaterial))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}
