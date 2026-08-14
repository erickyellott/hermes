import AppKit
import Carbon
import Foundation

struct HotkeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon modifier flags

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    var isValid: Bool {
        let hasPrimaryModifier =
            (modifiers & UInt32(cmdKey) != 0)
            || (modifiers & UInt32(controlKey) != 0)
            || (modifiers & UInt32(optionKey) != 0)
        return hasPrimaryModifier
    }

    static func modifiersDisplayString(flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    static func fromNSEvent(keyCode: UInt16, flags: NSEvent.ModifierFlags)
        -> HotkeyCombo
    {
        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        return HotkeyCombo(
            keyCode: UInt32(keyCode), modifiers: carbonMods)
    }
}

// MARK: - Config file representation

extension HotkeyCombo {
    /// Canonical form for the config file, e.g. `ctrl+alt+shift+cmd+1`.
    ///
    /// Modifier order is fixed rather than following how the combo was typed,
    /// so re-saving an unchanged config produces an identical file.
    var configString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("ctrl") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("alt") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("shift") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("cmd") }
        parts.append(keyCodeToConfigName(keyCode) ?? "key\(keyCode)")
        return parts.joined(separator: "+")
    }

    /// Parses `cmd+shift+1`. Modifier order, casing, and aliases are all
    /// tolerated; the key itself is always the final component.
    init?(configString: String) {
        var tokens = configString
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .split(separator: "+", omittingEmptySubsequences: false)
            .map(String.init)

        guard let keyToken = tokens.popLast(), !keyToken.isEmpty,
            let code = configNameToKeyCode(keyToken)
        else { return nil }

        var mods: UInt32 = 0
        for token in tokens {
            switch token {
            case "cmd", "command", "⌘": mods |= UInt32(cmdKey)
            case "alt", "opt", "option", "⌥": mods |= UInt32(optionKey)
            case "ctrl", "control", "⌃": mods |= UInt32(controlKey)
            case "shift", "⇧": mods |= UInt32(shiftKey)
            default: return nil
            }
        }
        self.init(keyCode: code, modifiers: mods)
    }
}

// MARK: - Key names

/// Glyphs shown in the UI.
private let keyGlyphs: [UInt32: String] = [
    0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
    0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
    0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
    0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
    0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
    0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0",
    0x1E: "]", 0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I",
    0x23: "P", 0x24: "↩", 0x25: "L", 0x26: "J", 0x27: "'",
    0x28: "K", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/",
    0x2D: "N", 0x2E: "M", 0x2F: ".",
    0x30: "⇥", 0x31: "␣", 0x33: "⌫", 0x35: "⎋",
    0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
    0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
    0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
    0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
]

/// Config-file names for keys whose UI glyph isn't typable. Everything else
/// (letters, digits, punctuation, F-keys) uses its lowercased glyph.
private let keyConfigNames: [UInt32: String] = [
    0x24: "return", 0x30: "tab", 0x31: "space", 0x33: "delete", 0x35: "escape",
    0x7B: "left", 0x7C: "right", 0x7D: "down", 0x7E: "up",
]

private let keyCodesByConfigName: [String: UInt32] = {
    var table: [String: UInt32] = [:]
    for (code, glyph) in keyGlyphs { table[glyph.lowercased()] = code }
    for (code, name) in keyConfigNames { table[name] = code }
    table["enter"] = 0x24
    table["esc"] = 0x35
    table["del"] = 0x33
    table["backspace"] = 0x33
    return table
}()

private func keyCodeToString(_ keyCode: UInt32) -> String {
    keyGlyphs[keyCode] ?? "?"
}

private func keyCodeToConfigName(_ keyCode: UInt32) -> String? {
    keyConfigNames[keyCode] ?? keyGlyphs[keyCode]?.lowercased()
}

private func configNameToKeyCode(_ name: String) -> UInt32? {
    if let code = keyCodesByConfigName[name] { return code }
    // `key42` escape hatch keeps unnameable keycodes round-trippable rather
    // than silently dropping the hotkey on save.
    if name.hasPrefix("key"), let code = UInt32(name.dropFirst(3)) { return code }
    return nil
}
