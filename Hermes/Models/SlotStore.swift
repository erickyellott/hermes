import AppKit
import Combine
import Foundation

@MainActor
final class SlotStore: ObservableObject {
    // Nonisolated: the grid shape is also needed off the main actor, by
    // config serialization and migration.
    nonisolated static let columns = 7
    nonisolated static let hotkeyRows = 4
    nonisolated static let totalHotkeySlots = columns * hotkeyRows  // 28

    @Published var slots: [AppSlot] = []
    @Published private(set) var configURL: URL

    private let configFile: ConfigFile

    init(configFile: ConfigFile) {
        self.configFile = configFile
        self.configURL = configFile.url
        slots = configFile.loadSlots()
    }

    /// Apps named in the config that aren't installed on this machine. Their
    /// slots are held rather than cleared, so a shared config isn't eroded by
    /// whichever Mac happens to be missing an app.
    var unresolvedSlots: [AppSlot] { slots.filter(\.isUnresolved) }

    func assignApp(url: URL, toIndex index: Int) {
        guard index >= 0, index < slots.count else { return }
        guard url.pathExtension == "app" else { return }
        slots[index].appURL = url
        save()
    }

    func clearSlot(at index: Int) {
        guard index >= 0, index < slots.count else { return }
        slots[index].appURL = nil
        slots[index].unresolved = nil
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

        // Swap contents but not identity: `id` and `gridIndex` belong to the
        // grid position, not to the app sitting in it.
        let source = slots[sourceIndex]
        let dest = slots[destIndex]

        slots[sourceIndex].appURL = dest.appURL
        slots[sourceIndex].unresolved = dest.unresolved
        slots[sourceIndex].hotkey = dest.hotkey
        slots[destIndex].appURL = source.appURL
        slots[destIndex].unresolved = source.unresolved
        slots[destIndex].hotkey = source.hotkey
        save()
    }

    // MARK: - Config management

    /// Re-reads from the config file. Called after a profile switch.
    func reload() {
        configURL = configFile.url
        slots = configFile.loadSlots()
    }

    func export(to url: URL) throws {
        try configFile.exportCopy(to: url)
    }

    // MARK: - Persistence

    private func save() {
        configFile.update(slots: slots)
    }
}
