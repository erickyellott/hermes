import AppKit
import Foundation

struct AppSlot: Codable, Identifiable, Equatable {
    var id: UUID
    var appURL: URL?
    var hotkey: HotkeyCombo?
    var gridIndex: Int

    var appName: String? {
        guard let url = appURL else { return nil }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    var appIcon: NSImage? {
        guard let url = appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var isEmpty: Bool { appURL == nil }
}
