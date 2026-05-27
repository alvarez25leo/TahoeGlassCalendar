import AppKit
import SwiftUI
import Combine
import EventKit
import os

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let viewModel = CalendarViewModel()
    private let iconRenderer = StatusIconRenderer()
    private let launchAtLogin = LaunchAtLoginManager.shared
    private lazy var popoverController = PopoverController(viewModel: viewModel)

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var dayChangeObserver: NSObjectProtocol?

    private var lastIconHasDot: Bool?
    private var lastUpcomingLabel: String?

    /// Ventana de tiempo desde "ahora" para mostrar el evento en el menubar.
    private let upcomingDisplayWindow: TimeInterval = 90 * 60

    func start() {
        configureStatusItem()
        bindViewModel()
        startRefreshTimer()
        observeDayChange()

        Task {
            await viewModel.bootstrap()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            dayChangeObserver = nil
        }

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    private func configureStatusItem() {
        statusItem.autosaveName = "TahoeGlassCalendarStatusItem"
        statusItem.behavior = .removalAllowed

        guard let button = statusItem.button else { return }

        button.image = iconRenderer.render(hasDot: false)
        lastIconHasDot = false
        button.imagePosition = .imageOnly
        button.toolTip = "Calendar"
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func bindViewModel() {
        viewModel.$hasTodayEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasEvents in
                self?.updateStatusIcon(hasEvents: hasEvents)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            viewModel.$todayEventCount,
            viewModel.$nextTodayEvent
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] count, next in
            self?.updateTooltip(count: count, next: next)
        }
        .store(in: &cancellables)

        // Texto del próximo evento al lado del icono (configurable).
        viewModel.$upcomingEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.updateUpcomingLabel(event: event)
            }
            .store(in: &cancellables)
    }

    private func updateStatusIcon(hasEvents: Bool) {
        if lastIconHasDot == hasEvents { return }
        statusItem.button?.image = iconRenderer.render(hasDot: hasEvents)
        lastIconHasDot = hasEvents
    }

    private func updateTooltip(count: Int, next: CalendarEventItem?) {
        guard let button = statusItem.button else { return }

        if count == 0 {
            button.toolTip = "Sin eventos hoy"
            return
        }

        if let next = next, !next.isAllDay {
            let time = DateFormatters.eventTime.string(from: next.startDate)
            button.toolTip = "Próximo: \(next.title) \(time) · \(count) hoy"
        } else {
            button.toolTip = "\(count) eventos hoy"
        }
    }

    /// Muestra "Título · HH:MM" junto al icono cuando hay un evento timed dentro
    /// de los próximos 90 minutos y la preferencia está activa. Se hace render
    /// con NSAttributedString para mantener el ancho compacto y respetar el
    /// look del menubar (sistema, color adaptable, ligadura monoespaciada en la
    /// hora).
    private func updateUpcomingLabel(event: CalendarEventItem?) {
        guard let button = statusItem.button else { return }

        let label = composeUpcomingLabel(event: event)

        // Evitamos reasignar attributedTitle si no cambió (no hay parpadeo).
        if label == lastUpcomingLabel { return }
        lastUpcomingLabel = label

        if let label {
            let attr = NSAttributedString(
                string: " " + label,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]
            )
            button.attributedTitle = attr
            button.imagePosition = .imageLeading
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private func composeUpcomingLabel(event: CalendarEventItem?) -> String? {
        guard AppPreferences.showUpcomingInMenuBar,
              let event,
              !event.isAllDay else { return nil }

        let now = Date()
        let delta = event.startDate.timeIntervalSince(now)
        guard delta > -300, delta < upcomingDisplayWindow else { return nil }

        let title = event.title.count > 22
            ? String(event.title.prefix(22)) + "…"
            : event.title

        if delta <= 0 {
            return "\(title) · ahora"
        }
        let mins = Int(delta / 60)
        if mins < 60 {
            return "\(title) · en \(mins)m"
        }
        let time = DateFormatters.eventTime.string(from: event.startDate)
        return "\(title) · \(time)"
    }

    private func startRefreshTimer() {
        // Cada 30s actualiza el indicador y la etiqueta "en Nm" del menubar.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.viewModel.refreshTodayIndicator()
                // Forzar recomputo del label aunque el evento no cambió.
                self?.lastUpcomingLabel = nil
                self?.updateUpcomingLabel(event: self?.viewModel.upcomingEvent)
            }
        }
        if let timer = refreshTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func observeDayChange() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AppLogger.menubar.info("NSCalendarDayChanged received")
            Task { @MainActor in
                await self?.viewModel.handleDayChange()
            }
        }
    }

    // MARK: - Click handling

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        popoverController.toggle(relativeTo: button)

        if popoverController.isShown {
            Task { @MainActor in
                await viewModel.refreshAll()
            }
        }
    }

    // MARK: - Context menu (right-click)

    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let refreshItem = NSMenuItem(
            title: "Refrescar ahora",
            action: #selector(menuRefresh),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        let openItem = NSMenuItem(
            title: "Abrir Calendar.app",
            action: #selector(menuOpenCalendar),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let upcomingItem = NSMenuItem(
            title: "Mostrar próximo evento en la barra",
            action: #selector(menuToggleUpcomingInMenuBar),
            keyEquivalent: ""
        )
        upcomingItem.target = self
        upcomingItem.state = AppPreferences.showUpcomingInMenuBar ? .on : .off
        menu.addItem(upcomingItem)

        launchAtLogin.refresh()
        let loginItem = NSMenuItem(
            title: "Iniciar al iniciar sesión",
            action: #selector(menuToggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = launchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "Acerca de Tahoe Glass Calendar",
            action: #selector(menuAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "Salir",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor in
            self.statusItem.menu = nil
        }
    }

    @objc private func menuRefresh() {
        Task { @MainActor in
            await viewModel.refreshAll()
        }
    }

    @objc private func menuOpenCalendar() {
        viewModel.openCalendarBasic()
    }

    @objc private func menuToggleLaunchAtLogin() {
        launchAtLogin.toggle()
    }

    @objc private func menuToggleUpcomingInMenuBar() {
        AppPreferences.showUpcomingInMenuBar.toggle()
        lastUpcomingLabel = nil
        updateUpcomingLabel(event: viewModel.upcomingEvent)
    }

    @objc private func menuAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
