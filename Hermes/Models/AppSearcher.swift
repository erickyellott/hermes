import AppKit
import Foundation

struct SearchResult: Identifiable, Equatable {
    let id: URL
    let url: URL
    let name: String
    let icon: NSImage

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.url == rhs.url
    }
}

/// Scans the standard application directories. Shared by the overlay's search
/// and by config-entry resolution, which needs the same name → bundle lookup.
enum InstalledApps {
    static func urls() -> [URL] {
        var dirs = FileManager.default.urls(
            for: .applicationDirectory, in: .allDomainsMask)
        dirs.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications"))

        var found: [URL] = []
        for dir in dirs {
            guard
                let contents = try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else { continue }
            found.append(contentsOf: contents.filter { $0.pathExtension == "app" })
        }
        return found.sorted {
            $0.deletingPathExtension().lastPathComponent.lowercased()
                < $1.deletingPathExtension().lastPathComponent.lowercased()
        }
    }
}

@MainActor
final class AppSearcher: ObservableObject {
    @Published var query: String = "" {
        didSet { search() }
    }
    @Published var results: [SearchResult] = []

    private var allApps: [URL] = []

    init() {
        refresh()
    }

    /// Re-scans installed apps and recomputes results. The overlay window is
    /// created once and reused, so without this both the installed-app list and
    /// the running-app defaults stay frozen at first-show for the app's lifetime.
    func refresh() {
        allApps = InstalledApps.urls()
        search()
    }

    private func defaultResults() -> [SearchResult] {
        var seen = Set<URL>()
        var combined: [SearchResult] = []

        for app in NSWorkspace.shared.runningApplications {
            guard let url = app.bundleURL,
                url.pathExtension == "app",
                !app.isHidden,
                app.activationPolicy == .regular,
                !seen.contains(url)
            else { continue }
            seen.insert(url)
            let name =
                FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            combined.append(
                SearchResult(id: url, url: url, name: name, icon: icon))
        }

        return Array(combined.prefix(SlotStore.columns))
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else {
            results = defaultResults()
            return
        }
        let matched = allApps.filter {
            $0.deletingPathExtension().lastPathComponent.lowercased()
                .contains(q)
        }
        results = Array(matched.prefix(SlotStore.columns)).map { url in
            let name =
                FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return SearchResult(id: url, url: url, name: name, icon: icon)
        }
    }
}
