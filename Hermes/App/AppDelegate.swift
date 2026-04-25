import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private var overlayWindow: OverlayWindow?
    let slotStore = SlotStore()
    let hotkeyManager = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        installCarbonEventHandler()
        hotkeyManager.slotStore = slotStore
        hotkeyManager.registerAll()
        showOverlay()
    }

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let id = hotKeyID.id
                Task { @MainActor in
                    AppDelegate.shared!.hotkeyManager.handleHotKey(id: id)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showOverlay()
        return false
    }

    // MARK: - Overlay

    func showOverlay() {
        if overlayWindow == nil {
            overlayWindow = OverlayWindow(
                slotStore: slotStore,
                hotkeyManager: hotkeyManager,
                onDismiss: { [weak self] in self?.dismissOverlay() }
            )
        }
        overlayWindow?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissOverlay() {
        overlayWindow?.dismiss()
    }
}
