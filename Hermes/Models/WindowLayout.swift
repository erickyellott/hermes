import Foundation

struct WindowLayout: Codable, Identifiable {
    var id: UUID
    var kind: LayoutKind
    var hotkey: HotkeyCombo?
}
