import AppKit
import Foundation

/// An app named by the config that couldn't be resolved to a bundle on this
/// machine. Kept verbatim rather than discarded: when one config is shared
/// between Macs, the machine missing an app must not erase it for the other.
struct UnresolvedApp: Equatable {
    var name: String
    var bundleId: String?
    var path: String?
}

struct AppSlot: Identifiable, Equatable {
    var id: UUID
    var appURL: URL?
    var unresolved: UnresolvedApp? = nil
    var hotkey: HotkeyCombo?
    var gridIndex: Int

    var appName: String? {
        if let url = appURL {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return unresolved?.name
    }

    var appIcon: NSImage? {
        guard let url = appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var isEmpty: Bool { appURL == nil && unresolved == nil }
    var isUnresolved: Bool { appURL == nil && unresolved != nil }
}
