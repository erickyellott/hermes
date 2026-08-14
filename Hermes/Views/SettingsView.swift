import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// What a name prompt will do once confirmed.
private enum ProfilePrompt: Identifiable {
    case new
    case duplicate

    var id: String { title }

    var title: String {
        switch self {
        case .new: return "New Profile"
        case .duplicate: return "Duplicate Profile"
        }
    }

    var message: String {
        switch self {
        case .new: return "Create an empty profile."
        case .duplicate: return "Copy the active profile under a new name."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var slotStore: SlotStore
    @ObservedObject var profileStore: ProfileStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false

    @State private var prompt: ProfilePrompt?
    @State private var newProfileName = ""

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return slotStore.configURL.path.replacingOccurrences(of: home, with: "~")
    }

    /// Names apps the config carries that aren't installed here, so it's clear
    /// they're being held rather than quietly lost.
    private var unresolvedMessage: String {
        let names = slotStore.unresolvedSlots.compactMap(\.appName)
        let count = names.count
        let noun = count == 1 ? "app isn't" : "apps aren't"
        return "\(count) \(noun) installed on this Mac "
            + "(\(names.joined(separator: ", "))). "
            + "Their slots are kept in the config."
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

                Section("Profiles") {
                    Picker("Active", selection: activeProfile) {
                        ForEach(profileStore.names, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    HStack {
                        Button("New") {
                            newProfileName = ""
                            prompt = .new
                        }
                        Button("Duplicate") {
                            newProfileName = "\(profileStore.active) copy"
                            prompt = .duplicate
                        }
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [slotStore.configURL])
                        }
                        Button("Export") {
                            let panel = NSSavePanel()
                            panel.nameFieldStringValue =
                                "\(profileStore.active).json"
                            panel.allowedContentTypes = [.json]
                            panel.title = "Export Hermes Profile"
                            if panel.runModal() == .OK, let url = panel.url {
                                try? slotStore.export(to: url)
                            }
                        }
                    }

                    LabeledContent("File") {
                        Text(displayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if !slotStore.unresolvedSlots.isEmpty {
                        Label(
                            unresolvedMessage,
                            systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
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
        .alert(
            prompt?.title ?? "",
            isPresented: Binding(
                get: { prompt != nil },
                set: { if !$0 { prompt = nil } })
        ) {
            TextField("Profile name", text: $newProfileName)
            Button("Create") { if let prompt { commit(prompt) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(prompt?.message ?? "")
        }
    }

    /// Switching profiles has to move the shared `ConfigFile` and rebind
    /// hotkeys, so it routes through `AppDelegate` rather than a store.
    private var activeProfile: Binding<String> {
        Binding(
            get: { profileStore.active },
            set: { AppDelegate.shared?.switchProfile(to: $0) })
    }

    private func commit(_ prompt: ProfilePrompt) {
        let created =
            switch prompt {
            case .new: profileStore.createEmpty(named: newProfileName)
            case .duplicate: profileStore.duplicateActive(as: newProfileName)
            }
        if let created { AppDelegate.shared?.switchProfile(to: created) }
    }
}
