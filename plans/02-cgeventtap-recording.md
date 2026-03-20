# Plan: CGEventTap for Hotkey Recording

## Problem

During hotkey recording, some key combos (e.g. ⌘⌥M, ⌘⌥') are never
delivered to Hermes as `keyDown` events. This happens because another
app (e.g. Alfred) has registered those combos via Carbon's
`RegisterEventHotKey`. Carbon consumes the event and delivers it as a
`kEventHotKeyPressed` to the registrant — Hermes's `KeyCaptureView`
never sees it.

## Solution

Use a `CGEventTap` **only during recording mode**. A CGEventTap at
`.cgSessionEventTap` / `.headInsertEventTap` fires before Carbon's
hotkey dispatch, so it captures every keyDown regardless of what other
apps have registered.

Requires **Accessibility permission** (`AXIsProcessTrusted()`).

## Behavior

- On first recording attempt, if accessibility isn't granted:
  - Show a one-time alert directing the user to System Settings >
    Privacy & Security > Accessibility
  - Fall back to existing `KeyCaptureView` behavior (combos intercepted
    by other apps won't register)
- Once accessibility is granted:
  - `startRecording` installs the CGEventTap
  - `stopRecording` removes it
  - The tap only intercepts keyDown and flagsChanged events
  - It passes the event through (doesn't consume it) so normal typing
    still works elsewhere — but since the overlay is frontmost, that's
    fine; we can suppress the event to prevent Alfred from also
    triggering

## Implementation

### New file: `HotkeyEngine/RecordingEventTap.swift`

```swift
// Wraps CGEventTap lifecycle for use during recording
final class RecordingEventTap {
    var onKeyDown: ((CGEvent) -> Void)?
    var onFlagsChanged: ((CGEvent) -> Void)?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() { ... }  // create tap, add to run loop
    func stop() { ... }   // invalidate tap, remove from run loop
}
```

The tap callback translates the `CGEvent` into an `NSEvent` and
forwards to `onKeyDown` / `onFlagsChanged`.

### Changes to `OverlayView.swift`

- In `startRecording`: call `recordingTap.start()`
- In `stopRecording`: call `recordingTap.stop()`
- Wire `recordingTap.onKeyDown` → `handleKeyEvent`
- Wire `recordingTap.onFlagsChanged` → `handleFlagsChanged`
- Keep existing `KeyCaptureView` (`onKeyDown` modifier) as fallback
  for when accessibility isn't available, or as the primary path when
  the tap isn't installed

### Accessibility permission check

In `OverlayView` or `AppDelegate`, before starting the tap:

```swift
if !AXIsProcessTrusted() {
    // show alert once (UserDefaults flag to avoid repeat)
    showAccessibilityAlert()
    return  // fall through to KeyCaptureView fallback
}
```

### Event suppression

When the tap receives a keyDown during recording, return
`.tapDisabledByTimeout` or set the event to null to suppress it —
this prevents the triggering app (Alfred) from also acting on it.

## Tradeoffs

- Pro: any combo can be captured regardless of other app registrations
- Pro: accessibility is already commonly granted for Alfred users
- Con: requires one extra permission
- Con: CGEventTap is disabled by macOS if it lags > 1s (use async
  dispatch carefully)

---

## Todo

- [x] Create `RecordingEventTap.swift` with tap lifecycle
- [x] Wire into `OverlayView` `startRecording`/`stopRecording`
- [x] Accessibility permission check + one-time alert
- [ ] Test with Alfred combo stealing (⌘⌥M, ⌘⌥')
