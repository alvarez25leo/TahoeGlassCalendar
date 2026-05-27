import AppKit
import SwiftUI
import os

@MainActor
final class PopoverController {
    private let popover: NSPopover
    private let viewModel: CalendarViewModel
    private let presentationState = PopoverPresentationState()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(viewModel: CalendarViewModel) {
        self.viewModel = viewModel
        let rootView = CalendarPanelView(
            viewModel: viewModel,
            presentationState: presentationState
        )

        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.animates = true

        // Oculta la flecha del NSPopover para que el glassEffect no muestre un
        // corte visible en la base del anchor. Es un KVC privado estable usado
        // por muchas menu bar apps (Bartender, Things, etc.).
        self.popover.setValue(true, forKey: "shouldHideAnchor")

        let hosting = NSHostingController(rootView: rootView)
        // Hace que el popover siempre tome el tamaño intrinseco del SwiftUI view
        // -> sin espacio en blanco al abrir, sin necesidad de setear contentSize fijo.
        hosting.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        configureTransparentView(hosting.view)
        self.popover.contentViewController = hosting
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
        // Liquid Glass necesita una ventana activa/key para resolver el efecto
        // desde el primer frame; si no, AppKit lo recompone al primer click.
        NSApp.activate(ignoringOtherApps: true)

        // Encogemos el rect de anclaje desde abajo: el popover se ancla al borde
        // minY del rect, asi que subir ese borde acerca el panel a la menu bar.
        let anchor = NSRect(
            x: button.bounds.origin.x,
            y: button.bounds.origin.y + 6,
            width: button.bounds.width,
            height: max(button.bounds.height - 6, 1)
        )

        popover.show(
            relativeTo: anchor,
            of: button,
            preferredEdge: .minY
        )

        configurePopoverWindow()
        activatePopoverWindow()
        presentationState.markPresented()

        Task { @MainActor in
            configurePopoverWindow()
            activatePopoverWindow()
            presentationState.markPresented()
        }

        // Subimos la ventana del popover 10px adicionales una vez mostrada,
        // para que quede mas pegada a la menu bar.
        if let popoverWindow = popover.contentViewController?.view.window {
            var frame = popoverWindow.frame
            frame.origin.y += 7
            popoverWindow.setFrameOrigin(frame.origin)
        }

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

    private func configurePopoverWindow() {
        guard let view = popover.contentViewController?.view else { return }

        configureTransparentView(view)
        view.needsLayout = true
        view.needsDisplay = true

        guard let window = view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.invalidateShadow()

        if let contentView = window.contentView {
            configureTransparentView(contentView)
            contentView.layoutSubtreeIfNeeded()
            contentView.displayIfNeeded()
            contentView.needsLayout = true
            contentView.needsDisplay = true
        }
    }

    private func activatePopoverWindow() {
        guard let window = popover.contentViewController?.view.window else { return }

        window.makeKey()
        window.orderFrontRegardless()
        window.acceptsMouseMovedEvents = true
        window.contentView?.layoutSubtreeIfNeeded()
        window.contentView?.displayIfNeeded()
    }

    private func configureTransparentView(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
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
