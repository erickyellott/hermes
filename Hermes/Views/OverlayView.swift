import SwiftUI

private enum OverlayPage: Int, CaseIterable {
    case apps = 0
    case windowResize = 1
}

struct OverlayView: View {
    @ObservedObject var slotStore: SlotStore
    @ObservedObject var windowLayoutStore: WindowLayoutStore
    let hotkeyManager: HotkeyManager
    @StateObject private var searcher = AppSearcher()
    @State private var recordingIndex: Int?
    @State private var shakeIndex: Int?
    @State private var liveModifiers: String = ""
    @State private var usingEventTap = false
    @State private var currentPage: OverlayPage = .apps
    @State private var dragOffset: CGFloat = 0
    @State private var isResizePageRecording = false
    @State private var scrollAccumX: CGFloat = 0
    @State private var scrollIsHorizontal = false
    let onDismiss: () -> Void

    private let recordingTap = RecordingEventTap()
    private let columns = SlotStore.columns
    private let pageWidth: CGFloat = 700

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Pages slide horizontally
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        appsPage
                            .frame(width: geo.size.width)
                        resizePage
                            .frame(width: geo.size.width)
                    }
                    .offset(x: pageOffset(in: geo.size.width) + dragOffset)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
                }

                // Page dots + close button
                VStack(spacing: 16) {
                    pageDots

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("q", modifiers: .command)
                }
                .padding(.bottom, 40)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard recordingIndex == nil, !isResizePageRecording else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    // Only track predominantly horizontal drags
                    guard abs(dx) > abs(dy) else { return }
                    // Resist at edges
                    if (currentPage == .apps && dx > 0) ||
                        (currentPage == .windowResize && dx < 0) {
                        dragOffset = dx * 0.2
                    } else {
                        dragOffset = dx
                    }
                }
                .onEnded { value in
                    guard recordingIndex == nil, !isResizePageRecording else {
                        dragOffset = 0
                        return
                    }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        let threshold: CGFloat = 80
                        if dx < -threshold, currentPage == .apps {
                            currentPage = .windowResize
                        } else if dx > threshold, currentPage == .windowResize {
                            currentPage = .apps
                        }
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture {
            if recordingIndex != nil { stopRecording() }
        }
        .onKeyDown(
            isActive: recordingIndex != nil && !usingEventTap,
            { event in handleKeyEvent(event) },
            onFlagsChanged: { event in handleFlagsChanged(event) }
        )
        .onScrollWheel { event in handleScroll(event) }
    }

    // MARK: - Trackpad scroll paging

    private func handleScroll(_ event: NSEvent) {
        guard recordingIndex == nil, !isResizePageRecording else { return }
        // Trackpads only — ignores mouse wheels
        guard event.hasPreciseScrollingDeltas else { return }
        // Ignore momentum events; we commit on the user's actual lift
        guard event.momentumPhase == [] else { return }

        switch event.phase {
        case .began:
            scrollAccumX = 0
            scrollIsHorizontal = false

        case .changed:
            if !scrollIsHorizontal {
                if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
                    scrollIsHorizontal = true
                } else {
                    return
                }
            }
            scrollAccumX += event.scrollingDeltaX
            // Negative accumulator = swipe left = reveal next page.
            // Mirror the drag gesture's edge resistance.
            if (currentPage == .apps && scrollAccumX > 0) ||
                (currentPage == .windowResize && scrollAccumX < 0) {
                dragOffset = scrollAccumX * 0.2
            } else {
                dragOffset = scrollAccumX
            }

        case .ended, .cancelled:
            defer {
                scrollAccumX = 0
                scrollIsHorizontal = false
            }
            guard scrollIsHorizontal else { return }
            let threshold: CGFloat = 50
            if scrollAccumX < -threshold, currentPage == .apps {
                currentPage = .windowResize
            } else if scrollAccumX > threshold, currentPage == .windowResize {
                currentPage = .apps
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                dragOffset = 0
            }

        default:
            break
        }
    }

    // MARK: - Pages

    private var appsPage: some View {
        VStack(spacing: 24) {
            SearchField(
                text: $searcher.query,
                shouldFocus: recordingIndex == nil && currentPage == .apps,
                onEscape: { onDismiss() }
            )
            .frame(width: 400, height: 36)
            .padding(.top, 60)

            HStack(spacing: 20) {
                ForEach(0..<columns, id: \.self) { i in
                    if i < searcher.results.count {
                        SearchResultSlot(result: searcher.results[i])
                    } else {
                        Color.clear.frame(width: 90, height: 110)
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
                ForEach(0..<SlotStore.totalHotkeySlots, id: \.self) { index in
                    SlotView(
                        slot: slotStore.slots[index],
                        isRecording: recordingIndex == index,
                        isDimmed: recordingIndex != nil && recordingIndex != index,
                        isShaking: shakeIndex == index,
                        onTap: { handleSlotTap(index) },
                        onDrop: { url in handleDrop(url, at: index) },
                        onSlotDrop: { sourceIndex in
                            slotStore.moveSlot(from: sourceIndex, to: index)
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
        }
    }

    private var resizePage: some View {
        VStack(spacing: 24) {
            Text("Window Resizing")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 60)

            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 60)

            WindowResizePage(
                store: windowLayoutStore,
                hotkeyManager: hotkeyManager,
                isAnyRecording: $isResizePageRecording
            )
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(OverlayPage.allCases, id: \.rawValue) { page in
                Circle()
                    .fill(currentPage == page
                          ? Color.white
                          : Color.white.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .onTapGesture {
                        guard recordingIndex == nil, !isResizePageRecording else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentPage = page
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Helpers

    private func pageOffset(in width: CGFloat) -> CGFloat {
        -CGFloat(currentPage.rawValue) * width
    }

    // MARK: - App slot recording

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
        usingEventTap = recordingTap.start()
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
        if slotStore.slots[index].isEmpty { return }
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
        hotkeyManager.registerAll()
    }
}
