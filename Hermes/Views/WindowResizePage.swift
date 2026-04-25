import SwiftUI

struct WindowResizePage: View {
    @ObservedObject var store: WindowLayoutStore
    let hotkeyManager: HotkeyManager
    @Binding var isAnyRecording: Bool

    @State private var recordingKind: LayoutKind?
    @State private var shakeKind: LayoutKind?
    @State private var liveModifiers: String = ""
    @State private var usingEventTap = false

    private let recordingTap = RecordingEventTap()

    var body: some View {
        VStack(spacing: 32) {
            ForEach(layoutGroups, id: \.self) { group in
                HStack(spacing: 20) {
                    ForEach(group) { kind in
                        if let layout = store.layout(for: kind) {
                            WindowLayoutSlotView(
                                layout: layout,
                                isRecording: recordingKind == kind,
                                isDimmed: recordingKind != nil && recordingKind != kind,
                                isShaking: shakeKind == kind,
                                onTap: { handleTap(kind) },
                                onClearHotkey: {
                                    store.clearHotkey(forKind: kind)
                                    hotkeyManager.registerAll()
                                }
                            )
                        }
                    }
                }
            }

            if recordingKind != nil {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 12))
                    if liveModifiers.isEmpty {
                        Text("Press a key combo\u{2026}")
                    } else {
                        Text(liveModifiers)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .onKeyDown(
            isActive: recordingKind != nil && !usingEventTap,
            { event in handleKeyEvent(event) },
            onFlagsChanged: { event in handleFlagsChanged(event) }
        )
        .onTapGesture {
            if recordingKind != nil { stopRecording() }
        }
    }

    private func handleTap(_ kind: LayoutKind) {
        if recordingKind == kind {
            stopRecording()
        } else {
            startRecording(kind)
        }
    }

    private func startRecording(_ kind: LayoutKind) {
        hotkeyManager.unregisterAll()
        recordingKind = kind
        isAnyRecording = true
        liveModifiers = ""

        recordingTap.onKeyDown = { keyCode, flags in
            MainActor.assumeIsolated {
                handleRecordedKey(keyCode: keyCode, flags: flags)
            }
        }
        recordingTap.onFlagsChanged = { flags in
            MainActor.assumeIsolated {
                guard recordingKind != nil else { return }
                liveModifiers = HotkeyCombo.modifiersDisplayString(flags: flags)
            }
        }
        usingEventTap = recordingTap.start()
        if !usingEventTap && !RecordingEventTap.isAccessibilityGranted {
            RecordingEventTap.promptAccessibilityOnce()
        }
    }

    private func stopRecording() {
        if usingEventTap {
            recordingTap.stop()
            usingEventTap = false
        }
        recordingKind = nil
        isAnyRecording = false
        liveModifiers = ""
        hotkeyManager.registerAll()
    }

    private func handleRecordedKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        if keyCode == 0x35 { // Escape
            stopRecording()
            return
        }
        guard let kind = recordingKind else { return }

        if keyCode == 0x33 || keyCode == 0x75 { // Backspace / Delete
            store.clearHotkey(forKind: kind)
            stopRecording()
            return
        }

        let combo = HotkeyCombo.fromNSEvent(keyCode: keyCode, flags: flags)
        if combo.isValid {
            store.setHotkey(combo, forKind: kind)
            stopRecording()
        } else {
            shakeKind = kind
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeKind = nil
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        handleRecordedKey(keyCode: event.keyCode, flags: event.modifierFlags)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard recordingKind != nil else { return }
        liveModifiers = HotkeyCombo.modifiersDisplayString(flags: event.modifierFlags)
    }
}
