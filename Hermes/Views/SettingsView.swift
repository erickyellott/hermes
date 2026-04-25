import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var slotStore: SlotStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return slotStore.configURL.path.replacingOccurrences(of: home, with: "~")
    }

    var body: some View {
        Form {
            Section("General") {
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

            Section("Config File") {
                LabeledContent("Location") {
                    Text(displayPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200, alignment: .trailing)
                }
                HStack {
                    Button("Change…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.json]
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.title = "Select Config File"
                        panel.message = "Choose a Hermes config file to load."
                        if panel.runModal() == .OK, let url = panel.url {
                            slotStore.switchConfig(to: url)
                        }
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [slotStore.configURL])
                    }
                }
                Button("Export Config…") {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "config.json"
                    panel.allowedContentTypes = [.json]
                    panel.title = "Export Hermes Config"
                    if panel.runModal() == .OK, let url = panel.url {
                        try? slotStore.export(to: url)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
    }
}
