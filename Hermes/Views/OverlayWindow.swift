import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted each time the overlay is brought on screen. The window is created
    /// once and reused, so `onAppear` fires only for the first show.
    static let overlayWillShow = Notification.Name("HermesOverlayWillShow")

    /// Posted each time the overlay is hidden. Every dismissal path funnels
    /// through `OverlayWindow.dismiss()`, so this catches all of them.
    static let overlayDidDismiss = Notification.Name("HermesOverlayDidDismiss")
}

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
        self.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]

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
        NotificationCenter.default.post(name: .overlayWillShow, object: self)
    }

    func dismiss() {
        orderOut(nil)
        NotificationCenter.default.post(name: .overlayDidDismiss, object: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onDismiss()
    }
}
