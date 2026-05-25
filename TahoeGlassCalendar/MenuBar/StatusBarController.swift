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
    private var eventStoreObserver: NSObjectProtocol?
    private var dayChangeObserver: NSObjectProtocol?

    private var lastIconHasDot: Bool?

    func start() {
        configureStatusItem()
        bindViewModel()
        startRefreshTimer()
        observeEventStoreChanges()
        observeDayChange()

        Task {
            await viewModel.bootstrap()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        if let observer = eventStoreObserver {
            NotificationCenter.default.removeObserver(observer)
            eventStoreObserver = nil
        }

        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            dayChangeObserver = nil
        }

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    private func configureStatusItem() {
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

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.viewModel.refreshTodayIndicator()
            }
        }
        if let timer = refreshTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func observeEventStoreChanges() {
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AppLogger.menubar.info("EKEventStoreChanged received")
            Task { @MainActor in
                await self?.viewModel.refreshAll()
            }
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

        // Refresh en background después de mostrar -> SwiftUI re-renderiza solo.
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
        // NSMenuDelegate.menuDidClose vuelve a poner statusItem.menu = nil
        // para que el próximo click reciba la acción normal.
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

    @objc private func menuAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
