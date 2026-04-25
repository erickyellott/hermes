import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    private let slotStore: SlotStore
    private let windowLayoutStore: WindowLayoutStore
    private let hotkeyManager: HotkeyManager
    private let onDismiss: () -> Void

    init(
        slotStore: SlotStore,
        windowLayoutStore: WindowLayoutStore,
        hotkeyManager: HotkeyManager,
        onDismiss: @escaping () -> Void
    ) {
        self.slotStore = slotStore
        self.windowLayoutStore = windowLayoutStore
        self.hotkeyManager = hotkeyManager
        self.onDismiss = onDismiss

        guard let screen = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            return
        }

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .normal
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.fullScreenAuxiliary]

        let overlayView = OverlayView(
            slotStore: slotStore,
            windowLayoutStore: windowLayoutStore,
            hotkeyManager: hotkeyManager,
            onDismiss: onDismiss
        )
        self.contentView = NSHostingView(rootView: overlayView)
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: true)
        makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onDismiss()
    }
}
