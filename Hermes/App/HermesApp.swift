import SwiftUI

private struct MenuBarMenuView: View {
    @Environment(\.openSettings) private var openSettings
    let appDelegate: AppDelegate
    @ObservedObject private var profileStore: ProfileStore

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        self.profileStore = appDelegate.profileStore
    }

    var body: some View {
        Button("Open Hermes") {
            AppDelegate.shared.showOverlay()
        }
        Divider()
        Menu("Profile") {
            ForEach(profileStore.names, id: \.self) { name in
                Button {
                    appDelegate.switchProfile(to: name)
                } label: {
                    // Menu items can't show a checkmark directly, so the
                    // active profile is marked inline.
                    Text(name == profileStore.active ? "✓ \(name)" : name)
                }
            }
        }
        Divider()
        Button("Settings") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

@main
struct HermesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!hideMenuBarIcon)) {
            MenuBarMenuView(appDelegate: appDelegate)
        } label: {
            Image(systemName: "clipboard")
        }

        Settings {
            SettingsView(
                slotStore: appDelegate.slotStore,
                profileStore: appDelegate.profileStore)
        }
    }
}
