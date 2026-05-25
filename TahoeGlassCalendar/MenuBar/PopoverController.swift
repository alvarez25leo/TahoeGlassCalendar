import AppKit
import SwiftUI
import os

@MainActor
final class PopoverController {
    private let popover: NSPopover
    private let viewModel: CalendarViewModel
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(viewModel: CalendarViewModel) {
        self.viewModel = viewModel
        let rootView = CalendarPanelView(viewModel: viewModel)

        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.animates = true
        self.popover.contentSize = NSSize(width: 420, height: 540)
        self.popover.contentViewController = NSHostingController(rootView: rootView)
    }

    var isShown: Bool { popover.isShown }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )

        // Activamos brevemente la app para que el popover capture eventos de teclado.
        NSApp.activate(ignoringOtherApps: true)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self else { return event }

            if let popoverWindow = self.popover.contentViewController?.view.window,
               event.window === popoverWindow {
                return event
            }

            Task { @MainActor in
                self.close()
            }
            return event
        }

        AppLogger.popover.debug("Popover shown")
    }

    func close() {
        if popover.isShown {
            popover.performClose(nil)
            AppLogger.popover.debug("Popover closed")
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
