# Plan: Window Resizing Page

A second page in the overlay for assigning global hotkeys to window layout
presets, with display-cycling when re-triggered on an already- snapped window.

---

## Overview

The main overlay becomes a two-page experience. Page 1 is the existing
app-switcher. Page 2 is the window-resizing grid. A row of dots at the bottom
(like Launchpad) reflects the current page; a horizontal swipe or arrow keys
navigates between them.

---

## Layouts

Two groups of layouts, plus a standalone maximize:

| Group  | Slot | Layout    | Default appearance |
| ------ | ---- | --------- | ------------------ |
| Thirds | 1    | Left 2/3  | Wide left block    |
| Thirds | 2    | Right 1/3 | Narrow right block |
| Halves | 1    | Left 1/2  | Equal left block   |
| Halves | 2    | Right 1/2 | Equal right block  |
| —      | —    | Maximize  | Full screen rect   |

Each slot has:

- A small vector icon showing the proportion (drawn in SwiftUI).
- A `HotkeyBadge` beneath the icon, same as app slots.
- Tap to begin recording a hotkey, tap again or press Escape to cancel.

---

## Layout icons

Each icon is a miniature rectangle (e.g. 40×28 pt) split into regions. The
"active" region is white/bright; inactive regions are dim. Using pure SwiftUI
`Path` or `Rectangle` shapes — no images needed.

```
Left 2/3       Right 1/3      Left 1/2       Right 1/2
┌────┬──┐      ┌──┬────┐      ┌───┬───┐      ┌───┬───┐
│####│  │      │  │####│      │###│   │       │   │###│
└────┴──┘      └──┴────┘      └───┴───┘      └───┴───┘

Maximize
┌────────┐
│########│
└────────┘
```

---

## Data model

### `LayoutKind` (enum)

```swift
enum LayoutKind: String, Codable, CaseIterable {
    case leftTwoThirds, rightOneThird
    case leftHalf, rightHalf
    case maximize
}
```

### `WindowLayout` (struct)

```swift
struct WindowLayout: Codable, Identifiable {
    var id: UUID
    var kind: LayoutKind
    var hotkey: HotkeyCombo?
}
```

### `WindowLayoutStore` (ObservableObject)

- Owns a fixed array of `WindowLayout` (one per kind).
- Saves/loads from the same config directory as `SlotStore` but a separate file
  (`window-layouts.json`).
- Methods: `setHotkey(_:forKind:)`, `clearHotkey(forKind:)`.
- Deduplicates hotkeys across layouts (same logic as `SlotStore`).

---

## Hotkey engine changes

### ID space

Carbon `EventHotKeyID` has two fields: `signature` (4-byte OSType) and `id`
(UInt32). App-slot hotkeys already use `"HMRS"`. Window layout hotkeys will use
signature `"HMWL"` with `id` = `LayoutKind.rawIndex` (0–4).

### `HotkeyManager` additions

```swift
weak var windowLayoutStore: WindowLayoutStore?

func registerAll() {
    // existing app slots …
    // + window layout hotkeys
    for layout in windowLayoutStore?.layouts ?? [] {
        guard let combo = layout.hotkey else { continue }
        registerWindowLayout(combo: combo, kind: layout.kind)
    }
}

func handleWindowLayoutHotKey(id: UInt32) {
    // resize frontmost window
}
```

### `AppDelegate` Carbon handler

Check `hotKeyID.signature`:

- `"HMRS"` → existing app-slot path.
- `"HMWL"` → new window-layout path.

---

## Window resizing logic

Uses the macOS Accessibility API (`AXUIElement`) — same permission already
requested for the event tap.

```
1. Get the frontmost NSRunningApplication.
2. Get its focused window via AXUIElement.
3. Get the window's current screen using NSScreen.screens +
   window position.
4. Compute target frame = layoutKind.frame(in: screen.visibleFrame).
5. Compare with last-applied state:
   - Same layout + same screen → move to next screen (cycle),
     apply same layout there.
   - Otherwise → apply on current screen.
6. Set position (AXPosition) and size (AXSize) via AXUIElement.
```

A small `WindowResizeTracker` (or just a `[pid_t: LastResize]` dictionary on
`HotkeyManager`) records the last `(kind, screenID)` per frontmost-app PID to
enable the cycle-display behavior.

### Frame calculation

```swift
func frame(for kind: LayoutKind, in visibleFrame: CGRect) -> CGRect {
    switch kind {
    case .leftTwoThirds:
        return CGRect(x: visibleFrame.minX, y: visibleFrame.minY,
                      width: visibleFrame.width * 2/3,
                      height: visibleFrame.height)
    case .rightOneThird:
        return CGRect(x: visibleFrame.minX + visibleFrame.width * 2/3,
                      y: visibleFrame.minY,
                      width: visibleFrame.width / 3,
                      height: visibleFrame.height)
    case .leftHalf:
        return CGRect(x: visibleFrame.minX, y: visibleFrame.minY,
                      width: visibleFrame.width / 2,
                      height: visibleFrame.height)
    case .rightHalf:
        return CGRect(x: visibleFrame.minX + visibleFrame.width / 2,
                      y: visibleFrame.minY,
                      width: visibleFrame.width / 2,
                      height: visibleFrame.height)
    case .maximize:
        return visibleFrame
    }
}
```

> Note: AXUIElement uses flipped coordinates (top-left origin) while NSScreen
> uses bottom-left. Conversion needed.

---

## Overlay UI changes

### Page state

```swift
@State private var currentPage: OverlayPage = .apps
enum OverlayPage { case apps, windowResize }
```

### Navigation

Horizontal drag gesture on the overlay switches page with a slide animation.
Tapping a page dot also navigates. No arrow-key shortcuts.

### Page dots

At the bottom, above the close button: two dots. Active dot is white, inactive
is `white.opacity(0.3)`. Tapping a dot navigates to that page. Same visual style
as Launchpad.

### Slide animation

Manual `offset`-based animation for full visual control.
`.animation(.spring(response: 0.35, dampingFraction: 0.8))`.

---

## New files

| File                               | Purpose                            |
| ---------------------------------- | ---------------------------------- |
| `Models/LayoutKind.swift`          | `LayoutKind` enum + frame math     |
| `Models/WindowLayout.swift`        | `WindowLayout` struct              |
| `Models/WindowLayoutStore.swift`   | Persistence + published state      |
| `Views/WindowResizePage.swift`     | Page 2 content (groups + slots)    |
| `Views/LayoutIcon.swift`           | SVG-style proportion icons         |
| `Views/WindowLayoutSlotView.swift` | Slot UI for a window layout        |
| `HotkeyEngine/WindowResizer.swift` | AXUIElement resize + display cycle |

---

## Modified files

- `HotkeyEngine/HotkeyManager.swift` — register/handle window hotkeys
- `App/AppDelegate.swift` — wire `WindowLayoutStore`; update Carbon handler to
  dispatch by signature
- `Views/OverlayView.swift` — add page state, swipe, dots, slide

---

## Decisions

- **Default hotkeys**: None. User assigns their own.
- **Maximize**: Uses `visibleFrame` (respects menu bar + dock). No full-screen
  animation.
- **Page navigation**: Horizontal drag gesture + dot taps only. No arrow key
  shortcuts.
- **More layouts**: `LayoutKind` is extensible — top/bottom halves etc. can be
  added later without changing persistence format.

---

## Todo

### Phase 1 — Data model

- [ ] `Models/LayoutKind.swift`
- [ ] `Models/WindowLayout.swift`
- [ ] `Models/WindowLayoutStore.swift`

### Phase 2 — Hotkey engine

- [ ] `HotkeyEngine/WindowResizer.swift` (AXUIElement + display cycle)
- [ ] Update `HotkeyManager` to register/handle window layout hotkeys
- [ ] Update `AppDelegate` Carbon handler (signature dispatch)

### Phase 3 — Overlay paging

- [ ] Add page state + slide animation to `OverlayView`
- [ ] Add page dots
- [ ] Wire swipe gesture and arrow-key navigation

### Phase 4 — Window resize page UI

- [ ] `Views/LayoutIcon.swift`
- [ ] `Views/WindowLayoutSlotView.swift`
- [ ] `Views/WindowResizePage.swift`

### Phase 5 — Xcode project

- [ ] Add all new files to `Hermes.xcodeproj`
