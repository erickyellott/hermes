import AppKit
import Carbon
import Foundation

@MainActor
final class HotkeyManager {
    weak var slotStore: SlotStore?
    weak var windowLayoutStore: WindowLayoutStore?

    // Separate ref dictionaries keyed by slot/layout index
    private var appHotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var layoutHotKeyRefs: [UInt32: EventHotKeyRef] = [:]

    private let resizer = WindowResizer()

    // Carbon OSType signatures
    private let appSig: OSType = 0x484D5253   // "HMRS"
    private let layoutSig: OSType = 0x484D574C // "HMWL"

    func registerAll() {
        unregisterAll()

        if let store = slotStore {
            for slot in store.slots {
                guard let combo = slot.hotkey else { continue }
                let id = EventHotKeyID(signature: appSig, id: UInt32(slot.gridIndex))
                register(combo: combo, hotKeyID: id, into: &appHotKeyRefs)
            }
            print("[Hermes] Registered \(appHotKeyRefs.count) app hotkeys")
        }

        if let store = windowLayoutStore {
            for layout in store.layouts {
                guard let combo = layout.hotkey else { continue }
                let id = EventHotKeyID(signature: layoutSig, id: layout.kind.hotkeyIndex)
                register(combo: combo, hotKeyID: id, into: &layoutHotKeyRefs)
            }
            print("[Hermes] Registered \(layoutHotKeyRefs.count) layout hotkeys")
        }
    }

    func unregisterAll() {
        for (_, ref) in appHotKeyRefs { UnregisterEventHotKey(ref) }
        for (_, ref) in layoutHotKeyRefs { UnregisterEventHotKey(ref) }
        appHotKeyRefs.removeAll()
        layoutHotKeyRefs.removeAll()
    }

    private func register(
        combo: HotkeyCombo,
        hotKeyID: EventHotKeyID,
        into refs: inout [UInt32: EventHotKeyRef]
    ) {
        var id = hotKeyID
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode, combo.modifiers, id,
            GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[hotKeyID.id] = ref
            print("[Hermes] Registered hotkey \(combo.displayString) sig=0x\(String(hotKeyID.signature, radix: 16)) id=\(hotKeyID.id)")
        } else {
            print("[Hermes] Failed to register hotkey \(combo.displayString) sig=0x\(String(hotKeyID.signature, radix: 16)) id=\(hotKeyID.id): status \(status)")
        }
    }

    func handleAppHotKey(id: UInt32) {
        guard let store = slotStore else { return }
        let index = Int(id)
        guard index >= 0, index < store.slots.count else { return }
        guard let appURL = store.slots[index].appURL else { return }

        let bundleID = Bundle(url: appURL)?.bundleIdentifier ?? ""
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
                    print("Failed to launch \(appURL.lastPathComponent): \(error)")
                }
            }
        }
    }

    func handleLayoutHotKey(id: UInt32) {
        print("[Hermes] handleLayoutHotKey: id=\(id)")
        guard let kind = LayoutKind.allCases.first(where: { $0.hotkeyIndex == id }) else {
            print("[Hermes] handleLayoutHotKey: no LayoutKind for id=\(id)")
            return
        }
        print("[Hermes] handleLayoutHotKey: resizing to \(kind.displayName)")
        resizer.resize(to: kind)
    }
}
