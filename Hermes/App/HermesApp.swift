import SwiftUI

private struct MenuBarMenuView: View {
    @Environment(\.openSettings) private var openSettings
    let appDelegate: AppDelegate

    var body: some View {
        Button("Open Hermes") {
            AppDelegate.shared.showOverlay()
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
            SettingsView(slotStore: appDelegate.slotStore)
        }
    }
}
