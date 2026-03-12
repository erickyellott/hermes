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

@MainActor
final class AppSearcher: ObservableObject {
    @Published var query: String = "" {
        didSet { search() }
    }
    @Published var results: [SearchResult] = []

    private var allApps: [URL] = []
    private var dockApps: [SearchResult] = []

    init() {
        loadApps()
        loadDockApps()
        results = defaultResults()
    }

    private func loadApps() {
        let dirs = FileManager.default.urls(
            for: .applicationDirectory, in: .allDomainsMask
        )
        var found: [URL] = []
        for dir in dirs {
            guard
                let contents = try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else { continue }
            found.append(
                contentsOf: contents.filter {
                    $0.pathExtension == "app"
                })
        }
        let homeApps =
            FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: homeApps,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            found.append(
                contentsOf: contents.filter {
                    $0.pathExtension == "app"
                })
        }
        allApps = found.sorted {
            $0.deletingPathExtension().lastPathComponent.lowercased()
                < $1.deletingPathExtension().lastPathComponent.lowercased()
        }
    }

    private func loadDockApps() {
        let plistPath =
            FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Preferences/com.apple.dock.plist")
        guard let plist = NSDictionary(contentsOf: plistPath),
            let persistentApps = plist["persistent-apps"] as? [[String: Any]]
        else { return }

        var apps: [SearchResult] = []
        for entry in persistentApps {
            guard
                let tileData = entry["tile-data"] as? [String: Any],
                let fileData = tileData["file-data"] as? [String: Any],
                let path = fileData["_CFURLString"] as? String
            else { continue }

            // Clean up the URL string (may be file:// prefixed)
            let url: URL
            if path.hasPrefix("file://") {
                guard let parsed = URL(string: path) else { continue }
                url = parsed
            } else {
                url = URL(fileURLWithPath: path)
            }

            guard FileManager.default.fileExists(atPath: url.path)
            else { continue }

            let name =
                FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            apps.append(
                SearchResult(id: url, url: url, name: name, icon: icon))
        }
        dockApps = Array(apps.prefix(SlotStore.columns))
    }

    private func defaultResults() -> [SearchResult] {
        var seen = Set<URL>()
        var combined: [SearchResult] = []

        // Dock apps first
        for app in dockApps {
            guard !seen.contains(app.url) else { continue }
            seen.insert(app.url)
            combined.append(app)
        }

        // Then running apps not already in Dock
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
