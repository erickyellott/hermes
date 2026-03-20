import AppKit
import Carbon

final class RecordingEventTap: @unchecked Sendable {
    var onKeyDown: (@Sendable (UInt16, NSEvent.ModifierFlags) -> Void)?
    var onFlagsChanged: (@Sendable (NSEvent.ModifierFlags) -> Void)?

    fileprivate var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    nonisolated(unsafe) private static var promptedThisSession = false

    static func promptAccessibilityOnce() {
        guard !promptedThisSession else { return }
        promptedThisSession = true

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start() -> Bool {
        guard Self.isAccessibilityGranted else { return false }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: recordingTapCallback,
            userInfo: userInfo
        ) else {
            print("[Hermes] Failed to create CGEventTap")
            return false
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault, tap, 0
        )
        CFRunLoopAddSource(
            CFRunLoopGetMain(), runLoopSource, .commonModes
        )
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[Hermes] Recording event tap started")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(), runLoopSource, .commonModes
            )
        }
        tap = nil
        runLoopSource = nil
        print("[Hermes] Recording event tap stopped")
    }

    deinit {
        stop()
    }
}

private func recordingTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<RecordingEventTap>
        .fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let machPort = tap.tap {
            CGEvent.tapEnable(tap: machPort, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = NSEvent.ModifierFlags(
        rawValue: UInt(event.flags.rawValue)
    )

    if type == .flagsChanged {
        DispatchQueue.main.async {
            tap.onFlagsChanged?(flags)
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        // Let ⌘Q through so the app can always be quit
        let isCommandQ = keyCode == 0x0C && flags.contains(.command)
        DispatchQueue.main.async {
            tap.onKeyDown?(keyCode, flags)
        }
        return isCommandQ ? Unmanaged.passUnretained(event) : nil
    }

    return Unmanaged.passUnretained(event)
}
