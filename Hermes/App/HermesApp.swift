import SwiftUI

@main
struct HermesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Open Hermes") {
                AppDelegate.shared.showOverlay()
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "clipboard")
        }

        Settings {
            SettingsView(slotStore: appDelegate.slotStore)
        }
    }
}
