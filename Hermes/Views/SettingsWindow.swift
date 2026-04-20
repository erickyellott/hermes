import AppKit
import SwiftUI
import ServiceManagement

final class SettingsWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "Hermes Settings"
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: SettingsView())
    }

    func show() {
        center()
        makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("[Hermes] Launch at login error: \(error)")
                    }
                }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 360)
    }
}
