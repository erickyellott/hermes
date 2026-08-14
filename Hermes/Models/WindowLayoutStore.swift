import Combine
import Foundation

@MainActor
final class WindowLayoutStore: ObservableObject {
    @Published var layouts: [WindowLayout] = []

    private let configFile: ConfigFile

    init(configFile: ConfigFile) {
        self.configFile = configFile
        layouts = configFile.loadLayouts()
    }

    /// Re-reads from the config file. Called after a profile switch.
    func reload() {
        layouts = configFile.loadLayouts()
    }

    func layout(for kind: LayoutKind) -> WindowLayout? {
        layouts.first { $0.kind == kind }
    }

    func index(of kind: LayoutKind) -> Int? {
        layouts.firstIndex { $0.kind == kind }
    }

    func setHotkey(_ combo: HotkeyCombo, forKind kind: LayoutKind) {
        // Clear duplicate across all layouts
        for i in layouts.indices where layouts[i].hotkey == combo {
            layouts[i].hotkey = nil
        }
        guard let i = index(of: kind) else { return }
        layouts[i].hotkey = combo
        save()
    }

    func clearHotkey(forKind kind: LayoutKind) {
        guard let i = index(of: kind) else { return }
        layouts[i].hotkey = nil
        save()
    }

    // MARK: - Persistence

    private func save() {
        configFile.update(layouts: layouts)
    }
}
