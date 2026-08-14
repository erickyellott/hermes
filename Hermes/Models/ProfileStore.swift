import Combine
import Foundation

/// Profiles are just config files in the Hermes config directory — the profile
/// name is the filename stem.
///
/// Which one is active is deliberately *not* stored in any profile: it's
/// per-machine state. Putting it in the file would mean switching profiles on
/// one Mac dragged every synced Mac along with it.
@MainActor
final class ProfileStore: ObservableObject {
    static let defaultName = "default"
    private static let activeKey = "hermes.activeProfile"

    @Published private(set) var names: [String] = []
    @Published private(set) var active: String

    init() {
        let found = ProfileStore.discover()
        names = found
        active = ProfileStore.resolveActive(names: found)
    }

    var activeURL: URL { ProfileStore.url(for: active) }

    // MARK: - Locations

    static func directory() -> URL {
        let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        let base =
            if let xdg, !xdg.isEmpty {
                URL(fileURLWithPath: xdg, isDirectory: true)
            } else {
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".config", isDirectory: true)
            }
        return base.appendingPathComponent("hermes", isDirectory: true)
    }

    static func url(for name: String) -> URL {
        directory().appendingPathComponent("\(name).json")
    }

    private static func discover() -> [String] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directory(),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])) ?? []
        return
            contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Falls back to whatever is actually on disk when the stored name is
    /// missing — which is also how a `config.json` left by a pre-profile build
    /// gets adopted without needing a rename.
    private static func resolveActive(names: [String]) -> String {
        if let saved = UserDefaults.standard.string(forKey: activeKey),
            names.contains(saved)
        {
            return saved
        }
        return names.first ?? defaultName
    }

    // MARK: - Mutation

    func refresh() {
        names = ProfileStore.discover()
    }

    func setActive(_ name: String) {
        active = name
        UserDefaults.standard.set(name, forKey: ProfileStore.activeKey)
        refresh()
    }

    /// Copies the active profile under a new name, as a starting point.
    @discardableResult
    func duplicateActive(as name: String) -> String? {
        guard let target = prepare(name) else { return nil }
        guard
            (try? FileManager.default.copyItem(at: activeURL, to: target.url))
                != nil
        else { return nil }
        refresh()
        return target.name
    }

    @discardableResult
    func createEmpty(named name: String) -> String? {
        guard let target = prepare(name) else { return nil }
        guard (try? ConfigFile.createEmpty(at: target.url)) != nil else {
            return nil
        }
        refresh()
        return target.name
    }

    /// Rejects names that aren't safe as a filename, and names already taken.
    private func prepare(_ name: String) -> (name: String, url: URL)? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("."),
            !trimmed.contains("/"), !trimmed.contains(":"),
            !names.contains(trimmed)
        else { return nil }

        try? FileManager.default.createDirectory(
            at: ProfileStore.directory(), withIntermediateDirectories: true)
        return (trimmed, ProfileStore.url(for: trimmed))
    }
}
