import AppKit
import Foundation

@MainActor
final class WindowResizer {
    // Tracks the last resize applied per app (by PID)
    private struct LastResize: Equatable {
        var kind: LayoutKind
        var screenID: CGDirectDisplayID
    }
    private var lastResize: [pid_t: LastResize] = [:]

    func resize(to kind: LayoutKind) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            print("[Hermes] WindowResizer: no frontmost application")
            return
        }
        let pid = app.processIdentifier
        print("[Hermes] WindowResizer: frontmost app=\(app.localizedName ?? "?") pid=\(pid), AXIsProcessTrusted=\(AXIsProcessTrusted())")

        let axApp = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        let axResult = AXUIElementCopyAttributeValue(
            axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard axResult == .success, let window = windowRef else {
            print("[Hermes] WindowResizer: failed to get focused window, AXError=\(axResult.rawValue) — check Accessibility permissions")
            return
        }

        let axWindow = window as! AXUIElement
        let currentScreen = screen(for: axWindow) ?? NSScreen.main ?? NSScreen.screens[0]
        print("[Hermes] WindowResizer: screen=\(currentScreen.localizedName) visibleFrame=\(currentScreen.visibleFrame)")

        let screens = NSScreen.screens
        let last = lastResize[pid]

        if let last, last.kind == kind, last.screenID == displayID(of: currentScreen) {
            if screens.count > 1, let idx = screens.firstIndex(of: currentScreen) {
                let nextScreen = screens[(idx + 1) % screens.count]
                print("[Hermes] WindowResizer: cycling to next screen \(nextScreen.localizedName)")
                apply(kind: kind, window: axWindow, screen: nextScreen)
                lastResize[pid] = LastResize(kind: kind, screenID: displayID(of: nextScreen))
            } else {
                print("[Hermes] WindowResizer: already on this layout+screen, single display — re-applying")
                apply(kind: kind, window: axWindow, screen: currentScreen)
            }
        } else {
            apply(kind: kind, window: axWindow, screen: currentScreen)
            lastResize[pid] = LastResize(kind: kind, screenID: displayID(of: currentScreen))
        }
    }

    private func apply(kind: LayoutKind, window: AXUIElement, screen: NSScreen) {
        let target = kind.frame(in: screen.visibleFrame)

        // AXUIElement uses flipped coordinates (top-left origin).
        // NSScreen.visibleFrame uses bottom-left origin.
        // Convert y: flip relative to the primary screen height.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let flippedY = primaryHeight - target.maxY

        var position = CGPoint(x: target.minX, y: flippedY)
        var size = CGSize(width: target.width, height: target.height)

        print("[Hermes] WindowResizer: applying \(kind.displayName) → position=\(position) size=\(size)")

        if let posValue = AXValueCreate(.cgPoint, &position) {
            let r = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
            if r != .success { print("[Hermes] WindowResizer: set position failed AXError=\(r.rawValue)") }
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let r = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            if r != .success { print("[Hermes] WindowResizer: set size failed AXError=\(r.rawValue)") }
        }
    }

    private func screen(for window: AXUIElement) -> NSScreen? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window, kAXPositionAttribute as CFString, &posRef) == .success,
            AXUIElementCopyAttributeValue(
                window, kAXSizeAttribute as CFString, &sizeRef) == .success,
            let posRef, let sizeRef
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        // AX coords are flipped; convert to NSScreen coordinate space
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let windowCenter = CGPoint(
            x: point.x + size.width / 2,
            y: primaryHeight - point.y - size.height / 2
        )

        return NSScreen.screens.min(by: {
            distanceSq(from: windowCenter, to: $0.frame) <
                distanceSq(from: windowCenter, to: $1.frame)
        })
    }

    private func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    private func distanceSq(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let cx = max(rect.minX, min(point.x, rect.maxX))
        let cy = max(rect.minY, min(point.y, rect.maxY))
        let dx = point.x - cx
        let dy = point.y - cy
        return dx * dx + dy * dy
    }
}
