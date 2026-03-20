import AppKit
import Carbon
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppDelegate!

    private var statusItem: NSStatusItem!
    private var overlayWindow: OverlayWindow?
    private var settingsWindow: SettingsWindow?
    private let slotStore = SlotStore()
    let hotkeyManager = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupStatusItem()
        installCarbonEventHandler()
        hotkeyManager.slotStore = slotStore
        hotkeyManager.registerAll()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "Hermes"
            )
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let event = NSApp.currentEvent
        let isRightClick =
            event?.type == .rightMouseDown
            || (event?.type == .leftMouseDown
                && event?.modifierFlags.contains(.control) == true)

        if isRightClick {
            menu.addItem(
                NSMenuItem(
                    title: "Settings…",
                    action: #selector(openSettings),
                    keyEquivalent: ","
                )
            )
            menu.addItem(.separator())
            menu.addItem(
                NSMenuItem(
                    title: "Quit",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q"
                )
            )
        } else {
            menu.cancelTracking()
            DispatchQueue.main.async { [weak self] in
                self?.toggleOverlay()
            }
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.show()
        NSApp.activate(ignoringOtherApps: true)
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

    @objc func toggleOverlay() {
        if let window = overlayWindow, window.isVisible {
            dismissOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
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
