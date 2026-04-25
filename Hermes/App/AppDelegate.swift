import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private var overlayWindow: OverlayWindow?
    let slotStore: SlotStore
    let windowLayoutStore: WindowLayoutStore
    let hotkeyManager = HotkeyManager()

    override init() {
        let store = SlotStore()
        slotStore = store
        windowLayoutStore = WindowLayoutStore(
            configDir: store.configURL.deletingLastPathComponent())
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        if !RecordingEventTap.isAccessibilityGranted {
            RecordingEventTap.promptAccessibilityOnce()
        }
        installCarbonEventHandler()
        hotkeyManager.slotStore = slotStore
        hotkeyManager.windowLayoutStore = windowLayoutStore
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

                let sig = hotKeyID.signature
                let id = hotKeyID.id
                print("[Hermes] Carbon hotkey fired: sig=0x\(String(sig, radix: 16)) id=\(id)")
                Task { @MainActor in
                    let mgr = AppDelegate.shared!.hotkeyManager
                    if sig == 0x484D5253 { // "HMRS" — app slots
                        mgr.handleAppHotKey(id: id)
                    } else if sig == 0x484D574C { // "HMWL" — window layouts
                        mgr.handleLayoutHotKey(id: id)
                    } else {
                        print("[Hermes] Carbon hotkey: unrecognized signature 0x\(String(sig, radix: 16))")
                    }
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
                windowLayoutStore: windowLayoutStore,
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
