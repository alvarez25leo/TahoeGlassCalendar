import SwiftUI

struct CalendarHeaderView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(DateFormatters.capitalizedMonthTitle(for: viewModel.visibleMonth))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                if viewModel.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                            .frame(width: 10, height: 10)
                        Text("Actualizando…")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .transition(.opacity)
                }
            }

            Spacer()

            if #available(macOS 26.0, *) {
                liquidGlassNavGroup
            } else {
                fallbackNavGroup
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    @available(macOS 26.0, *)
    private var liquidGlassNavGroup: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    Task { await viewModel.goToPreviousMonth() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Mes anterior")
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button {
                    Task { await viewModel.goToToday() }
                } label: {
                    Text("Hoy")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .foregroundStyle(viewModel.isViewingCurrentMonth ? .secondary : .primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect(
                    viewModel.isViewingCurrentMonth
                        ? .regular.interactive()
                        : .regular.tint(.accentColor.opacity(0.35)).interactive(),
                    in: Capsule()
                )
                .accessibilityLabel("Ir a hoy")

                Button {
                    Task { await viewModel.goToNextMonth() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
