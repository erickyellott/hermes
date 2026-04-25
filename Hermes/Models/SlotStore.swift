import AppKit
import Combine
import Foundation

@MainActor
final class SlotStore: ObservableObject {
    static let columns = 7
    static let hotkeyRows = 4
    static let totalHotkeySlots = columns * hotkeyRows  // 28

    @Published var slots: [AppSlot] = []
    @Published private(set) var configURL: URL

    private let configPathKey = "hermes.configPath"
    private let legacyDefaultsKey = "hermes.slots"

    init() {
        if let saved = UserDefaults.standard.string(forKey: "hermes.configPath") {
            configURL = URL(fileURLWithPath: saved)
        } else {
            configURL = Self.makeDefaultConfigURL()
        }
        load()
        if slots.isEmpty {
            slots = (0..<Self.totalHotkeySlots).map { i in
                AppSlot(id: UUID(), appURL: nil, hotkey: nil, gridIndex: i)
            }
        }
    }

    private static func makeDefaultConfigURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Hermes/config.json")
    }

    func assignApp(url: URL, toIndex index: Int) {
        guard index >= 0, index < slots.count else { return }
        guard url.pathExtension == "app" else { return }
        slots[index].appURL = url
        save()
    }

    func clearSlot(at index: Int) {
        guard index >= 0, index < slots.count else { return }
        slots[index].appURL = nil
        slots[index].hotkey = nil
        save()
    }

    func setHotkey(_ combo: HotkeyCombo, forIndex index: Int) {
        guard index >= 0, index < slots.count else { return }
        for i in slots.indices where slots[i].hotkey == combo && i != index {
            slots[i].hotkey = nil
        }
        slots[index].hotkey = combo
        save()
    }

    func clearHotkey(at index: Int) {
        guard index >= 0, index < slots.count else { return }
        slots[index].hotkey = nil
        save()
    }

    func moveSlot(from sourceIndex: Int, to destIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < slots.count,
            destIndex >= 0, destIndex < slots.count,
            sourceIndex != destIndex
        else { return }

        let sourceApp = slots[sourceIndex].appURL
        let sourceHotkey = slots[sourceIndex].hotkey
        let destApp = slots[destIndex].appURL
        let destHotkey = slots[destIndex].hotkey

        slots[sourceIndex].appURL = destApp
        slots[sourceIndex].hotkey = destHotkey
        slots[destIndex].appURL = sourceApp
        slots[destIndex].hotkey = sourceHotkey
        save()
    }

    // MARK: - Config management

    func switchConfig(to url: URL) {
        configURL = url
        UserDefaults.standard.set(url.path, forKey: configPathKey)
        load()
        if slots.isEmpty {
            slots = (0..<Self.totalHotkeySlots).map { i in
                AppSlot(id: UUID(), appURL: nil, hotkey: nil, gridIndex: i)
            }
        }
    }

    func export(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(slots)
        try data.write(to: url)
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(slots) else { return }
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        try? data.write(to: configURL)
    }

    private func load() {
        if let data = try? Data(contentsOf: configURL),
            let decoded = try? JSONDecoder().decode([AppSlot].self, from: data)
        {
            slots = decoded
            return
        }
        // Migrate from UserDefaults on first run
        if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
            let decoded = try? JSONDecoder().decode([AppSlot].self, from: data)
        {
            slots = decoded
            save()
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        }
    }
}
