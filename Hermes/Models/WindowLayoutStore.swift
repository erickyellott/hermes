import Combine
import Foundation

@MainActor
final class WindowLayoutStore: ObservableObject {
    @Published var layouts: [WindowLayout] = []

    private let configURL: URL

    init(configDir: URL) {
        configURL = configDir.appendingPathComponent("window-layouts.json")
        load()
    }

    private func makeDefaults() -> [WindowLayout] {
        LayoutKind.allCases.map {
            WindowLayout(id: UUID(), kind: $0, hotkey: nil)
        }
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layouts) else { return }
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: configURL)
    }

    private func load() {
        if let data = try? Data(contentsOf: configURL),
            let decoded = try? JSONDecoder().decode(
                [WindowLayout].self, from: data)
        {
            // Ensure all kinds present (handles adding new kinds later)
            var result = decoded
            for kind in LayoutKind.allCases {
                if !result.contains(where: { $0.kind == kind }) {
                    result.append(WindowLayout(id: UUID(), kind: kind, hotkey: nil))
                }
            }
            layouts = result
        } else {
            layouts = makeDefaults()
        }
    }
}
