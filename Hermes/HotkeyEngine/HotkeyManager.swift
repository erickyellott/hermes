import AppKit
import Carbon
import Foundation

@MainActor
final class HotkeyManager {
    weak var slotStore: SlotStore?
    private var registeredKeys: [UInt32: EventHotKeyRef] = [:]

    func registerAll() {
        unregisterAll()
        guard let store = slotStore else {
            print("[Hermes] registerAll: slotStore is nil!")
            return
        }
        var count = 0
        for slot in store.slots {
            guard let combo = slot.hotkey else { continue }
            register(combo: combo, slotIndex: UInt32(slot.gridIndex))
            count += 1
        }
        print("[Hermes] Registered \(count) hotkeys")
    }

    func unregisterAll() {
        for (_, ref) in registeredKeys {
            UnregisterEventHotKey(ref)
        }
        registeredKeys.removeAll()
    }

    private func register(combo: HotkeyCombo, slotIndex: UInt32) {
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x484D5253), // "HMRS"
            id: slotIndex
        )
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref = ref {
            registeredKeys[slotIndex] = ref
            print("[Hermes] Registered hotkey \(combo.displayString) for slot \(slotIndex)")
        } else {
            print("[Hermes] Failed to register hotkey for slot \(slotIndex): status \(status)")
        }
    }

    func handleHotKey(id: UInt32) {
        print("[Hermes] handleHotKey called with id: \(id)")
        guard let store = slotStore else {
            print("[Hermes] handleHotKey: slotStore is nil!")
            return
        }
        let index = Int(id)
        guard index >= 0, index < store.slots.count else {
            print("[Hermes] handleHotKey: index \(index) out of range")
            return
        }
        guard let appURL = store.slots[index].appURL else {
            print("[Hermes] handleHotKey: no app at index \(index)")
            return
        }
        print("[Hermes] Launching/toggling: \(appURL.lastPathComponent)")

        // Check if app is already frontmost — toggle visibility
        let bundleID =
            Bundle(url: appURL)?.bundleIdentifier ?? ""
        let running = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleID
        }

        if let app = running, app.isActive {
            app.hide()
        } else {
            NSWorkspace.shared.openApplication(
                at: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error = error {
                    print(
                        "Failed to launch \(appURL.lastPathComponent): \(error)"
                    )
                }
            }
        }
    }
}
