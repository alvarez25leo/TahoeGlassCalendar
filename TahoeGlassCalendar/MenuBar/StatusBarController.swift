import AppKit
import SwiftUI
import Combine
import EventKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let viewModel = CalendarViewModel()
    private let iconRenderer = StatusIconRenderer()
    private lazy var popoverController = PopoverController(viewModel: viewModel)

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var eventStoreObserver: NSObjectProtocol?

    func start() {
        configureStatusItem()
        bindViewModel()
        startRefreshTimer()
        observeEventStoreChanges()

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

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = iconRenderer.render(hasDot: false)
        button.imagePosition = .imageOnly
        button.toolTip = "Calendar"
        button.target = self
        button.action = #selector(togglePopover)
    }

    private func bindViewModel() {
        viewModel.$hasTodayEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasEvents in
                self?.updateStatusIcon(hasEvents: hasEvents)
            }
            .store(in: &cancellables)

        viewModel.$todayEventCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.statusItem.button?.toolTip = count == 0
                    ? "No events today"
                    : "\(count) events today"
            }
            .store(in: &cancellables)
    }

    private func updateStatusIcon(hasEvents: Bool) {
        statusItem.button?.image = iconRenderer.render(hasDot: hasEvents)
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.viewModel.refresh()
            }
        }
    }

    private func observeEventStoreChanges() {
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.viewModel.refresh()
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        Task {
            await viewModel.refresh()
        }

        popoverController.toggle(relativeTo: button)
    }
}
