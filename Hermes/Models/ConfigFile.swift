import AppKit
import Foundation

// MARK: - On-disk shape

/// One occupied grid slot, as written to the config file.
///
/// Deliberately decoupled from `AppSlot`: this is a stable, human-readable
/// contract, while `AppSlot` is free to carry runtime-only state.
struct ConfigAppEntry: Codable {
    var app: String
    var bundleId: String?
    var column: Int
    var hotkey: String?
    var path: String?
    var row: Int
}

struct HermesConfig: Codable {
    var apps: [ConfigAppEntry]
    var version: Int
    var windows: [String: String]

    init(apps: [ConfigAppEntry] = [], windows: [String: String] = [:]) {
        self.apps = apps
        self.version = ConfigFile.currentVersion
        self.windows = windows
    }

    /// Every section is optional on read so a partial or hand-trimmed file
    /// still loads instead of failing wholesale.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps = try c.decodeIfPresent([ConfigAppEntry].self, forKey: .apps) ?? []
        version =
            try c.decodeIfPresent(Int.self, forKey: .version)
            ?? ConfigFile.currentVersion
        windows =
            try c.decodeIfPresent([String: String].self, forKey: .windows) ?? [:]
    }
}

// MARK: - File

/// Sole owner of reads and writes to the config file.
///
/// `SlotStore` and `WindowLayoutStore` both persist into the same document, so
/// neither may touch the file directly — a store writing only its own section
/// would drop the other's.
@MainActor
final class ConfigFile {
    nonisolated static let currentVersion = 2

    private(set) var url: URL
    private var config: HermesConfig

    /// False when nothing parseable was found at `url` — the signal migration
    /// uses to decide whether there's anything worth converting.
    private(set) var hasLoadedConfig: Bool

    init(url: URL) {
        let loaded = ConfigFile.read(from: url)
        self.url = url
        self.config = loaded ?? HermesConfig()
        self.hasLoadedConfig = loaded != nil
    }

    /// Writes a fresh empty document. Used when creating a new profile.
    static func createEmpty(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try encode(HermesConfig()).write(to: url, options: .atomic)
    }

    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    // MARK: Reading

    /// Resolves every entry against installed apps. Costly enough to be a
    /// method rather than a property — call once per load, not per access.
    func loadSlots() -> [AppSlot] {
        ConfigFile.slots(from: config.apps)
    }

    func loadLayouts() -> [WindowLayout] {
        LayoutKind.allCases.map { kind in
            WindowLayout(
                id: UUID(),
                kind: kind,
                hotkey: config.windows[kind.configName]
                    .flatMap(HotkeyCombo.init(configString:)))
        }
    }

    func switchFile(to newURL: URL) {
        url = newURL
        let loaded = ConfigFile.read(from: newURL)
        config = loaded ?? HermesConfig()
        hasLoadedConfig = loaded != nil
    }

    /// Writes a copy elsewhere without changing the active path.
    func exportCopy(to destination: URL) throws {
        try encoded().write(to: destination, options: .atomic)
    }

    private static func read(from url: URL) -> HermesConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HermesConfig.self, from: data)
    }

    // MARK: Writing

    func update(slots: [AppSlot]) {
        config.apps = slots.compactMap(ConfigFile.entry(for:))
        write()
    }

    /// Rewrites only the layouts Hermes knows about. Unrecognized keys under
    /// `windows` are left in place, so a config written by a newer build
    /// survives a round-trip through an older one.
    func update(layouts: [WindowLayout]) {
        var windows = config.windows
        for kind in LayoutKind.allCases {
            windows.removeValue(forKey: kind.configName)
        }
        for layout in layouts {
            guard let hotkey = layout.hotkey else { continue }
            windows[layout.kind.configName] = hotkey.configString
        }
        config.windows = windows
        write()
    }

    /// Replaces the whole document at once. Used by migration.
    func replace(with newConfig: HermesConfig) {
        config = newConfig
        hasLoadedConfig = true
        write()
    }

    /// `.sortedKeys` is not cosmetic: without it `JSONEncoder` emits keys in
    /// hash order seeded per process, so an unchanged config would serialize
    /// differently on every launch and churn the whole file on each write.
    private static func encode(_ config: HermesConfig) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        return try encoder.encode(config)
    }

    private func encoded() throws -> Data {
        try ConfigFile.encode(config)
    }

    private func write() {
        config.version = Self.currentVersion
        guard let data = try? encoded() else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Entry ↔ slot

extension ConfigFile {
    /// Expands the file's sparse entries into the full fixed-size grid.
    static func slots(from entries: [ConfigAppEntry]) -> [AppSlot] {
        var slots = (0..<SlotStore.totalHotkeySlots).map {
            AppSlot(id: UUID(), appURL: nil, hotkey: nil, gridIndex: $0)
        }
        let installed = InstalledAppIndex()

        for entry in entries {
            guard let index = gridIndex(row: entry.row, column: entry.column),
                slots[index].isEmpty
            else { continue }

            if let url = installed.resolve(entry) {
                slots[index].appURL = url
            } else {
                slots[index].unresolved = UnresolvedApp(
                    name: entry.app, bundleId: entry.bundleId, path: entry.path)
            }
            slots[index].hotkey = entry.hotkey.flatMap(
                HotkeyCombo.init(configString:))
        }
        return slots
    }

    static func entry(for slot: AppSlot) -> ConfigAppEntry? {
        guard !slot.isEmpty else { return nil }
        let row = slot.gridIndex / SlotStore.columns
        let column = slot.gridIndex % SlotStore.columns
        let hotkey = slot.hotkey?.configString

        if let unresolved = slot.unresolved {
            return ConfigAppEntry(
                app: unresolved.name, bundleId: unresolved.bundleId,
                column: column, hotkey: hotkey, path: unresolved.path, row: row)
        }

        guard let url = slot.appURL else { return nil }
        let bundleId = Bundle(url: url)?.bundleIdentifier
        return ConfigAppEntry(
            app: slot.appName ?? url.deletingPathExtension().lastPathComponent,
            bundleId: bundleId,
            column: column,
            hotkey: hotkey,
            // Only needed when there's no bundle ID to resolve by; an absolute
            // path is the one field that doesn't survive syncing between Macs.
            path: bundleId == nil ? url.path : nil,
            row: row)
    }

    private static func gridIndex(row: Int, column: Int) -> Int? {
        guard row >= 0, row < SlotStore.hotkeyRows,
            column >= 0, column < SlotStore.columns
        else { return nil }
        return row * SlotStore.columns + column
    }
}

/// Resolves config entries to app bundles: bundle ID, then explicit path, then
/// display name. The installed-app scan happens once and only if some entry
/// actually falls through to a name lookup.
private final class InstalledAppIndex {
    private var byName: [String: URL]?

    func resolve(_ entry: ConfigAppEntry) -> URL? {
        if let bundleId = entry.bundleId,
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleId)
        {
            return url
        }
        if let path = entry.path,
            FileManager.default.fileExists(atPath: path)
        {
            return URL(fileURLWithPath: path)
        }
        return index()[entry.app.lowercased()]
    }

    private func index() -> [String: URL] {
        if let byName { return byName }
        var map: [String: URL] = [:]
        for url in InstalledApps.urls() {
            map[url.deletingPathExtension().lastPathComponent.lowercased()] =
                url
        }
        byName = map
        return map
    }
}

// MARK: - Migration

/// One-time conversion from the pre-2 layout: a bare `[AppSlot]` array in
/// `~/Library/Application Support/Hermes/config.json`, with layout hotkeys in
/// a sibling `window-layouts.json`.
@MainActor
enum ConfigMigration {
    private struct LegacyHotkey: Decodable {
        var keyCode: UInt32
        var modifiers: UInt32
    }

    private struct LegacySlot: Decodable {
        var appURL: URL?
        var hotkey: LegacyHotkey?
        var gridIndex: Int
    }

    private struct LegacyLayout: Decodable {
        var kind: String
        var hotkey: LegacyHotkey?
    }

    static var oldDefaultURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Hermes/config.json")
    }

    /// Retired setting: before profiles, the config file could live anywhere.
    /// Read once so that data can still be found, then cleared.
    private static let legacyPathKey = "hermes.configPath"

    static func runIfNeeded(into configFile: ConfigFile) {
        defer { UserDefaults.standard.removeObject(forKey: legacyPathKey) }
        guard !configFile.hasLoadedConfig else { return }

        var candidates: [URL] = []
        if let custom = UserDefaults.standard.string(forKey: legacyPathKey) {
            candidates.append(URL(fileURLWithPath: custom))
        }
        candidates.append(oldDefaultURL)

        guard
            let source = candidates.first(where: { legacySlots(at: $0) != nil }),
            let slots = legacySlots(at: source)
        else { return }

        // Always lands in the active profile, wherever the old data was found.
        configFile.replace(
            with: HermesConfig(
                apps: slots.compactMap(entry(from:)),
                windows: legacyWindows(besideConfigAt: source)))
    }

    private static func legacySlots(at url: URL) -> [LegacySlot]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([LegacySlot].self, from: data)
    }

    private static func legacyWindows(besideConfigAt url: URL) -> [String: String] {
        let layoutsURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("window-layouts.json")
        guard let data = try? Data(contentsOf: layoutsURL),
            let layouts = try? JSONDecoder().decode([LegacyLayout].self, from: data)
        else { return [:] }

        var windows: [String: String] = [:]
        for layout in layouts {
            guard let kind = LayoutKind(rawValue: layout.kind),
                let hotkey = layout.hotkey
            else { continue }
            windows[kind.configName] = HotkeyCombo(
                keyCode: hotkey.keyCode, modifiers: hotkey.modifiers
            ).configString
        }
        return windows
    }

    private static func entry(from slot: LegacySlot) -> ConfigAppEntry? {
        guard let url = slot.appURL,
            slot.gridIndex >= 0, slot.gridIndex < SlotStore.totalHotkeySlots
        else { return nil }

        let bundleId = Bundle(url: url)?.bundleIdentifier
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        let hotkey = slot.hotkey.map {
            HotkeyCombo(keyCode: $0.keyCode, modifiers: $0.modifiers).configString
        }

        return ConfigAppEntry(
            app: name,
            bundleId: bundleId,
            column: slot.gridIndex % SlotStore.columns,
            hotkey: hotkey,
            path: bundleId == nil ? url.path : nil,
            row: slot.gridIndex / SlotStore.columns)
    }
}
