import SwiftUI

struct CalendarHeaderView: View {
    @ObservedObject var viewModel: CalendarViewModel

    @State private var prevBounce: Int = 0
    @State private var nextBounce: Int = 0
    @State private var todayBounce: Int = 0
    @State private var searchBounce: Int = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CalendarTheme.stackSpacing) {
            HStack(spacing: CalendarTheme.stackSpacing) {
                Text(DateFormatters.capitalizedMonthTitle(for: viewModel.visibleMonth))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                if viewModel.isOffline {
                    offlineBadge
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }

                Spacer()

                if #available(macOS 26.0, *) {
                    liquidGlassNavGroup
                } else {
                    fallbackNavGroup
                }
            }

            if viewModel.isSearchActive {
                searchField
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(CalendarTheme.smoothSpring, value: viewModel.isSearchActive)
        .animation(CalendarTheme.smoothSpring, value: viewModel.isOffline)
    }

    // MARK: - Offline badge

    /// Aviso de "sin conexión": iCloud/CalDAV no sincroniza, así que los eventos
    /// podrían estar desactualizados. Tooltip explica el motivo al pasar el mouse.
    private var offlineBadge: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.orange)
            .symbolRenderingMode(.hierarchical)
            .help("Sin conexión a internet — los eventos podrían no estar sincronizados.")
            .accessibilityLabel("Sin conexión a internet")
            .accessibilityHint("Los eventos podrían no estar sincronizados.")
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField(viewModel.searchPlaceholder, text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit {
                    // Mantenemos el foco; submit no cierra.
                }
                .accessibilityLabel("Campo de búsqueda de eventos")

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpiar búsqueda")
            }

            Button {
                viewModel.clearSearch()
            } label: {
                Text("Cerrar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Cerrar búsqueda")
        }
        .padding(.horizontal, CalendarTheme.fieldPaddingH)
        .padding(.vertical, CalendarTheme.fieldPaddingV)
        .background(searchFieldBackground)
        .onAppear { searchFocused = true }
    }

    @ViewBuilder
    private var searchFieldBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: CalendarTheme.fieldCornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: CalendarTheme.fieldCornerRadius, style: .continuous)
                )
        } else {
            RoundedRectangle(cornerRadius: CalendarTheme.fieldCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(CalendarTheme.fieldFillOpacity))
        }
    }

    // MARK: - Liquid glass nav

    @available(macOS 26.0, *)
    private var liquidGlassNavGroup: some View {
        GlassEffectContainer(spacing: CalendarTheme.tightSpacing) {
            HStack(spacing: CalendarTheme.tightSpacing) {
                Button {
                    prevBounce += 1
                    Task { await viewModel.goToPreviousMonth() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolEffect(.bounce, value: prevBounce)
                        .frame(width: CalendarTheme.capsuleHeight, height: CalendarTheme.capsuleHeight)
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
                        .padding(.horizontal, CalendarTheme.capsulePaddingH)
                        .frame(height: CalendarTheme.capsuleHeight)
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
                        .frame(width: CalendarTheme.capsuleHeight, height: CalendarTheme.capsuleHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Mes siguiente")
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button {
                    searchBounce += 1
                    viewModel.toggleSearch()
                } label: {
                    Image(systemName: viewModel.isSearchActive ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolEffect(.bounce, value: searchBounce)
                        .frame(width: CalendarTheme.capsuleHeight, height: CalendarTheme.capsuleHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .glassEffect(
                    viewModel.isSearchActive
                        ? .regular.tint(.accentColor.opacity(0.35)).interactive()
                        : .regular.interactive(),
                    in: Circle()
                )
                .accessibilityLabel(viewModel.isSearchActive ? "Cerrar búsqueda" : "Buscar eventos")
                .help("Buscar eventos (⌘F)")
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }

    private var fallbackNavGroup: some View {
        HStack(spacing: CalendarTheme.tightSpacing) {
            fallbackButton(systemName: "chevron.left", accessibility: "Mes anterior") {
                Task { await viewModel.goToPreviousMonth() }
            }

            Button {
                Task { await viewModel.goToToday() }
            } label: {
                Text("Hoy")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, CalendarTheme.capsulePaddingH)
                    .frame(height: CalendarTheme.capsuleHeight)
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

            fallbackButton(
                systemName: viewModel.isSearchActive ? "magnifyingglass.circle.fill" : "magnifyingglass",
                accessibility: viewModel.isSearchActive ? "Cerrar búsqueda" : "Buscar eventos"
            ) {
                viewModel.toggleSearch()
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
                .frame(width: CalendarTheme.capsuleHeight, height: CalendarTheme.capsuleHeight)
                .background(Circle().fill(.regularMaterial))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}
