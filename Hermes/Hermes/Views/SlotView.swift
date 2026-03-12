import SwiftUI
import UniformTypeIdentifiers

struct SlotView: View {
    let slot: AppSlot
    let isRecording: Bool
    let isShaking: Bool
    let onTap: () -> Void
    let onDrop: (URL) -> Void
    let onSlotDrop: (Int) -> Void
    let onRemove: () -> Void
    let onClearHotkey: () -> Void
    let onOpenApp: () -> Void

    @State private var isTargeted = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                if isRecording {
                    recordingContent
                } else if let icon = slot.appIcon {
                    filledContent(icon: icon)
                } else {
                    emptyContent
                }
            }
            .frame(width: 72, height: 72)
            .background(slotBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .overlay(alignment: .topTrailing) {
                if isHovered && !slot.isEmpty && !isRecording {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .offset(x: isShaking ? -4 : 0)
            .animation(
                isShaking
                    ? .default.repeatCount(3, autoreverses: true).speed(6)
                    : .default,
                value: isShaking
            )
            .onTapGesture { onTap() }
            .onDrop(
                of: [UTType.fileURL, UTType.plainText],
                isTargeted: $isTargeted
            ) { providers in
                handleDrop(providers)
            }
            .conditionalDraggable(
                enabled: !slot.isEmpty && !isRecording,
                data: "hermes-slot:\(slot.gridIndex)"
            )
            .contextMenu {
                if !slot.isEmpty {
                    Button("Open App") { onOpenApp() }
                    Divider()
                    if slot.hotkey != nil {
                        Button("Clear Hotkey") { onClearHotkey() }
                    }
                    Button("Remove App") { onRemove() }
                }
            }

            if let name = slot.appName {
                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            } else {
                Text("")
                    .font(.system(size: 11))
            }
        }
        .frame(width: 90, height: 110)
    }

    private var recordingContent: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "keyboard")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func filledContent(icon: NSImage) -> some View {
        ZStack(alignment: .bottom) {
            // macOS icons have ~18% built-in padding; scale up to fill
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 90, height: 90)
                .frame(width: 72, height: 72)
                .clipped()

            if let combo = slot.hotkey {
                HotkeyBadge(combo: combo)
                    .padding(.bottom, 3)
            }
        }
    }

    private var emptyContent: some View {
        ZStack {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var slotBackground: some ShapeStyle {
        .white.opacity(isTargeted ? 0.15 : 0.05)
    }

    private var borderColor: Color {
        if isRecording {
            return .accentColor
        } else if isTargeted {
            return .white.opacity(0.4)
        } else if slot.isEmpty {
            return .white.opacity(0.15)
        } else {
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        if isRecording || isTargeted { return 2 }
        if slot.isEmpty { return 1 }
        return 0
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Check for internal slot reorder
        if provider.canLoadObject(ofClass: String.self) {
            provider.loadObject(ofClass: String.self) { string, _ in
                guard let string = string,
                    string.hasPrefix("hermes-slot:"),
                    let sourceIndex = Int(
                        string.replacingOccurrences(
                            of: "hermes-slot:", with: ""))
                else {
                    // Not an internal drag — try as file URL
                    self.loadFileURL(from: provider)
                    return
                }
                DispatchQueue.main.async {
                    onSlotDrop(sourceIndex)
                }
            }
            return true
        }

        loadFileURL(from: provider)
        return true
    }

    private func loadFileURL(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) {
            item, _ in
            guard let data = item as? Data,
                let url = URL(
                    dataRepresentation: data, relativeTo: nil)
            else { return }
            if url.pathExtension == "app" {
                DispatchQueue.main.async {
                    onDrop(url)
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func conditionalDraggable(enabled: Bool, data: String) -> some View {
        if enabled {
            self.draggable(data)
        } else {
            self
        }
    }
}
