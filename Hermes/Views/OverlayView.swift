import SwiftUI

struct OverlayView: View {
    @ObservedObject var slotStore: SlotStore
    let hotkeyManager: HotkeyManager
    @StateObject private var searcher = AppSearcher()
    @State private var recordingIndex: Int?
    @State private var shakeIndex: Int?
    @State private var liveModifiers: String = ""
    @State private var usingEventTap = false
    let onDismiss: () -> Void

    private let recordingTap = RecordingEventTap()

    private let columns = SlotStore.columns

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                SearchField(
                    text: $searcher.query,
                    shouldFocus: recordingIndex == nil,
                    onEscape: { onDismiss() }
                )
                .frame(width: 400, height: 36)
                .padding(.top, 60)

                HStack(spacing: 20) {
                    ForEach(0..<columns, id: \.self) { i in
                        if i < searcher.results.count {
                            SearchResultSlot(result: searcher.results[i])
                        } else {
                            Color.clear
                                .frame(width: 90, height: 110)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .opacity(recordingIndex != nil ? 0.4 : 1.0)

                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 60)

                if recordingIndex != nil {
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
                    .frame(height: 20)
                } else {
                    Color.clear.frame(height: 20)
                }

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(90), spacing: 20),
                        count: columns),
                    spacing: 16
                ) {
                    ForEach(0..<SlotStore.totalHotkeySlots, id: \.self) {
                        index in
                        SlotView(
                            slot: slotStore.slots[index],
                            isRecording: recordingIndex == index,
                            isDimmed: recordingIndex != nil && recordingIndex != index,
                            isShaking: shakeIndex == index,
                            onTap: { handleSlotTap(index) },
                            onDrop: { url in handleDrop(url, at: index) },
                            onSlotDrop: { sourceIndex in
                                slotStore.moveSlot(
                                    from: sourceIndex, to: index)
                                reregisterHotkeys()
                            },
                            onRemove: { slotStore.clearSlot(at: index) },
                            onClearHotkey: {
                                slotStore.clearHotkey(at: index)
                                reregisterHotkeys()
                            },
                            onOpenApp: { openApp(at: index) }
                        )
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .onTapGesture {
            if recordingIndex != nil {
                stopRecording()
            }
        }
        .onKeyDown(
            isActive: recordingIndex != nil && !usingEventTap,
            { event in handleKeyEvent(event) },
            onFlagsChanged: { event in handleFlagsChanged(event) }
        )
    }

    private func startRecording(_ index: Int) {
        hotkeyManager.unregisterAll()
        recordingIndex = index
        liveModifiers = ""

        recordingTap.onKeyDown = { keyCode, flags in
            MainActor.assumeIsolated {
                handleRecordedKey(keyCode: keyCode, flags: flags)
            }
        }
        recordingTap.onFlagsChanged = { flags in
            MainActor.assumeIsolated {
                guard recordingIndex != nil else { return }
                liveModifiers = HotkeyCombo.modifiersDisplayString(flags: flags)
            }
        }
        let accessGranted = RecordingEventTap.isAccessibilityGranted
        print("[Hermes] Accessibility granted: \(accessGranted)")
        usingEventTap = recordingTap.start()
        print("[Hermes] Event tap started: \(usingEventTap)")
        if !usingEventTap && !accessGranted {
            RecordingEventTap.promptAccessibilityOnce()
        }
    }

    private func stopRecording() {
        if usingEventTap {
            recordingTap.stop()
            usingEventTap = false
        }
        recordingIndex = nil
        liveModifiers = ""
        hotkeyManager.registerAll()
    }

    private func handleSlotTap(_ index: Int) {
        if slotStore.slots[index].isEmpty {
            return
        }
        if recordingIndex == index {
            stopRecording()
        } else {
            startRecording(index)
        }
    }

    private func handleRecordedKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        if keyCode == 0x35 {
            stopRecording()
            return
        }

        guard let index = recordingIndex else { return }

        if keyCode == 0x33 || keyCode == 0x75 {
            slotStore.clearHotkey(at: index)
            stopRecording()
            return
        }

        let combo = HotkeyCombo.fromNSEvent(keyCode: keyCode, flags: flags)
        if combo.isValid {
            slotStore.setHotkey(combo, forIndex: index)
            stopRecording()
        } else {
            shakeIndex = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeIndex = nil
            }
        }
    }

    // Fallback when CGEventTap isn't available
    private func handleKeyEvent(_ event: NSEvent) {
        handleRecordedKey(keyCode: event.keyCode, flags: event.modifierFlags)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard recordingIndex != nil else { return }
        liveModifiers = HotkeyCombo.modifiersDisplayString(flags: event.modifierFlags)
    }

    private func handleDrop(_ url: URL, at index: Int) {
        slotStore.assignApp(url: url, toIndex: index)
    }

    private func openApp(at index: Int) {
        guard let url = slotStore.slots[index].appURL else { return }
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in }
        onDismiss()
    }

    private func reregisterHotkeys() {
        print("[Hermes] Re-registering hotkeys...")
        hotkeyManager.registerAll()
    }
}
