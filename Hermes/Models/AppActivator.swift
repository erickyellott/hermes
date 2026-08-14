import AppKit

/// Finds and activates running instances of an app bundle.
///
/// Matching on `bundleIdentifier` alone is not enough: an app started by running its
/// executable directly (e.g. `/opt/homebrew/bin/neovide`, a symlink into
/// `Neovide.app/Contents/MacOS`) is never registered as a bundle launch by
/// LaunchServices, so its `NSRunningApplication.bundleIdentifier` is nil. Such an app
/// looks "not running" to a bundle-ID match, and `openApplication` on it may raise an
/// existing instance or spawn a new one nondeterministically.
@MainActor
enum AppActivator {
    static func runningInstances(of appURL: URL) -> [NSRunningApplication] {
        let bundleID = Bundle(url: appURL)?.bundleIdentifier
        let canonical = appURL.resolvingSymlinksInPath().standardizedFileURL.path

        return NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular else { return false }
            if let bundleID, app.bundleIdentifier == bundleID { return true }
            if app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path == canonical {
                return true
            }
            if let exe = app.executableURL?.resolvingSymlinksInPath().standardizedFileURL.path {
                return exe.hasPrefix(canonical + "/")
            }
            return false
        }
    }

    /// Raise the app, launching it if no instance is running.
    static func activate(_ appURL: URL) {
        guard let target = frontmost(of: runningInstances(of: appURL)) else {
            launch(appURL)
            return
        }
        raise(target)
    }

    /// Raise the app, or hide it if it is already frontmost.
    static func toggle(_ appURL: URL) {
        let instances = runningInstances(of: appURL)
        if instances.contains(where: { $0.isActive }) {
            instances.forEach { $0.hide() }
        } else if let target = frontmost(of: instances) {
            raise(target)
        } else {
            launch(appURL)
        }
    }

    private static func raise(_ app: NSRunningApplication) {
        app.unhide()
        app.activate(options: [.activateAllWindows])
    }

    /// `runningApplications` has no recency ordering, so when an app has several
    /// instances pick whichever owns the front-most on-screen window. CGWindowList is
    /// ordered front-to-back.
    private static func frontmost(of instances: [NSRunningApplication]) -> NSRunningApplication? {
        guard instances.count > 1 else { return instances.first }

        let byPID = Dictionary(
            instances.map { (Int($0.processIdentifier), $0) },
            uniquingKeysWith: { first, _ in first })
        let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []

        for info in windows {
            if let pid = info[kCGWindowOwnerPID as String] as? Int, let app = byPID[pid] {
                return app
            }
        }
        return instances.first(where: { !$0.isHidden }) ?? instances.first
    }

    private static func launch(_ appURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                print("[Hermes] Failed to launch \(appURL.lastPathComponent): \(error)")
            }
        }
    }
}
