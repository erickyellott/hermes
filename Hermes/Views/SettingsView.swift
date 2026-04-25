import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var slotStore: SlotStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return slotStore.configURL.path.replacingOccurrences(of: home, with: "~")
    }

    var body: some View {
        VStack(spacing: 0) {
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
                    Toggle("Hide Menubar Icon", isOn: $hideMenuBarIcon)
                }

                Section("Config File") {
                    LabeledContent("Location") {
                        HStack(spacing: 8) {
                            Text(displayPath)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Change") {
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
                        }
                    }
                    HStack {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [slotStore.configURL])
                        }
                        Button("Export Config") {
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
            }
            .formStyle(.grouped)
            .fixedSize(horizontal: false, vertical: true)

            Button("Quit Hermes") {
                NSApp.terminate(nil)
            }
            .foregroundStyle(.red)
            .padding(.bottom, 20)
        }
        .frame(width: 480)
    }
}
