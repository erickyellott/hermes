import AppKit
import Combine
import Foundation

@MainActor
final class SlotStore: ObservableObject {
    static let columns = 7
    static let hotkeyRows = 4
    static let totalHotkeySlots = columns * hotkeyRows  // 28

    @Published var slots: [AppSlot] = []

    private let defaultsKey = "hermes.slots"

    init() {
        load()
        if slots.isEmpty {
            slots = (0..<Self.totalHotkeySlots).map { i in
                AppSlot(id: UUID(), appURL: nil, hotkey: nil, gridIndex: i)
            }
        }
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
        // Clear any other slot that has this same hotkey
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

        // Swap the app and hotkey data, keep gridIndex stable
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

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(
                [AppSlot].self, from: data)
        else { return }
        slots = decoded
    }
}
