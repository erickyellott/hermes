import SwiftUI

struct WindowLayoutSlotView: View {
    let layout: WindowLayout
    let isRecording: Bool
    let isDimmed: Bool
    let isShaking: Bool
    let onTap: () -> Void
    let onClearHotkey: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isRecording {
                    recordingContent
                } else {
                    LayoutIcon(kind: layout.kind)
                }

                if let combo = layout.hotkey, !isRecording {
                    VStack {
                        Spacer()
                        HotkeyBadge(combo: combo)
                            .padding(.bottom, 3)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .background(slotBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .onHover { isHovered = $0 }
            .offset(x: isShaking ? -4 : 0)
            .animation(
                isShaking
                    ? .default.repeatCount(3, autoreverses: true).speed(6)
                    : .default,
                value: isShaking
            )
            .onTapGesture { onTap() }
            .contextMenu {
                if layout.hotkey != nil {
                    Button("Clear Hotkey") { onClearHotkey() }
                }
            }

            Text(layout.kind.displayName)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(width: 90, height: 110)
        .opacity(isDimmed ? 0.4 : 1.0)
    }

    private var recordingContent: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "keyboard")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var slotBackground: some ShapeStyle {
        .white.opacity(0.05)
    }

    private var borderColor: Color {
        if isRecording { return .accentColor }
        if layout.hotkey != nil { return .clear }
        return .white.opacity(0.15)
    }

    private var borderWidth: CGFloat {
        isRecording ? 2 : (layout.hotkey == nil ? 1 : 0)
    }
}
