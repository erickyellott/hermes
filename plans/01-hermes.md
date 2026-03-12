# Hermes — macOS Menu Bar App Launcher

## Overview

A macOS menu bar app that lets you assign global hotkeys to applications
via a drag-and-drop grid. Inspired by the WoW Bartender addon.

---

## Tech Stack

| Concern          | Choice                        | Reason                        |
|------------------|-------------------------------|-------------------------------|
| Language         | Swift 6.2.4                   | Native macOS, best API access |
| UI framework     | SwiftUI                       | Grid, drag-drop, overlay      |
| Menu bar         | `NSStatusItem`                | Standard macOS pattern        |
| Global hotkeys   | `Carbon` HotKey API           | System-level, no extra deps   |
| App launch       | `NSWorkspace`                 | Standard app launching        |
| Persistence      | `UserDefaults` + `Codable`    | Simple, no external DB needed |

**No Electron. No SwiftPM dependencies if avoidable.** Pure Swift +
AppKit/SwiftUI.

---

## Phase 1 — App Grid & Hotkey Assignment (MVP)

### Overlay Behavior

- Small icon in the menu bar — mascot is **Hermes Conrad** (Futurama);
  menu bar icon should evoke him (e.g. clipboard, sash/medal, or a
  stylized silhouette)
- Clicking the menu bar icon **or** pressing the global hotkey opens
  the full-screen **Launchpad-style overlay** (blurred background,
  centered grid)
- Pressing the same global hotkey again **toggles the overlay closed**
  (Alfred-style toggle)
- Clicking outside the overlay or pressing `Escape` also dismisses it

### App Grid

- Launchpad-style uniform grid, **7 columns × 5 rows** (35 slots total)
- **Top row (7 slots) is the search row** — reserved for search results,
  not assignable as hotkey slots
- **Bottom 4 rows (28 slots)** are the assignable hotkey grid
- Each slot shows:
  - App icon (~64px, rounded corners like Launchpad)
  - App name (small label beneath icon)
  - Hotkey badge (bottom-right corner, e.g. `⌘1`) — hotkey slots only
  - Empty state: subtle dashed border with a "+" hint — hotkey slots only
- Future setting: keyboard-layout grid mode (slots arranged in QWERTY
  rows so the visual maps directly to physical key positions)

### Type-to-Search

- Typing anywhere in the overlay filters installed apps (searching
  `/Applications` and other standard locations via `NSWorkspace`)
- Results populate the top search row (up to 7 matches, best first)
- Search row slots look distinct — no dashed border, no hotkey badge,
  slightly dimmed to indicate they're transient
- Clearing the search (Backspace to empty, or `Escape`) empties the
  search row
- **Drag from search row → hotkey slot** to assign that app to a
  permanent slot, then record a hotkey as usual

### Drag & Drop — Assigning Apps

- Drag sources:
  - **Search row** → hotkey slot (primary workflow)
  - **Finder** → hotkey slot (direct drop)
  - ~~Dock~~ — macOS intercepts Dock drags as "remove from Dock"
- Accept `NSItemProvider` with `public.file-url` type
- Validate it's an `.app` bundle before accepting
- Show visual feedback (highlight) on drag-over
- Replace existing slot contents if dragged onto an occupied slot
- Dragging from the search row does not remove it from search results

### Hotkey Recording

- Click an occupied slot → enters **recording mode**
  - Slot gets a pulsing outline
  - Text shows "Press a key combo…"
  - Capture next key event with validation:
    - **Valid:** combo includes at least one of ⌘, ⌃, or ⌥
    - **Invalid:** bare key, or ⇧-only modifier (e.g. `⇧A` = just
      uppercase — rejected)
    - Invalid combos show a brief shake/flash and stay in recording mode
  - `Escape` cancels recording
  - Backspace/Delete on a recording slot clears the hotkey
- Hotkey badge updates immediately on assignment
- Registering a hotkey already used by another slot clears the previous one

### Global Hotkey Dispatch

- On startup, register all saved hotkeys with Carbon's
  `RegisterEventHotKey`
- When triggered: launch the app (`NSWorkspace.open`) or bring it to
  front if already running (`NSRunningApplication.activate`)
- Re-register hotkeys whenever the grid is modified

### Right-Click Context Menu (per slot)

- Remove app
- Clear hotkey
- Open app

### Persistence

```swift
struct AppSlot: Codable, Identifiable {
    var id: UUID
    var appURL: URL?
    var hotkey: HotkeyCombo?  // keyCode + modifierFlags
    var gridIndex: Int
}
```

Saved to `UserDefaults` on every change.

---

## Phase 2 — Window Resizing Hotkeys

A second page in the overlay (Launchpad-style page 2) for window layout
hotkeys. Skipped for MVP.

### Preset Layouts

| Name          | Description                          |
|---------------|--------------------------------------|
| Left 50%      | Left half of screen                  |
| Right 50%     | Right half of screen                 |
| Left 60%      | Left 60% of screen                   |
| Right 40%     | Right 40% of screen                  |
| Top 50%       | Top half                             |
| Bottom 50%    | Bottom half                          |
| Maximize      | Full screen (not native fullscreen)  |
| Top-Left      | Top-left quadrant                    |
| Top-Right     | Top-right quadrant                   |
| Bottom-Left   | Bottom-left quadrant                 |
| Bottom-Right  | Bottom-right quadrant                |
| Center        | Centered, ~80% of screen             |

Each layout gets its own hotkey slot (same recording UX as Phase 1).

### Implementation

- Use `AXUIElement` (`Accessibility` framework) to move/resize the
  frontmost window
- Requires **Accessibility permission** — prompt with `AXIsProcessTrusted()`
- Resize formula: `screen.visibleFrame` × layout percentages
- Works on the frontmost app's key window
- Multi-monitor: resize to the screen the frontmost window is currently on

---

## Project Structure

```
Hermes/
├── Hermes.xcodeproj
├── Hermes/
│   ├── App/
│   │   ├── HermesApp.swift         # @main, NSApplicationDelegate
│   │   └── AppDelegate.swift       # NSStatusItem + overlay wiring
│   ├── Models/
│   │   ├── AppSlot.swift
│   │   ├── HotkeyCombo.swift
│   │   └── SlotStore.swift         # ObservableObject, persistence
│   ├── HotkeyEngine/
│   │   ├── HotkeyRecorder.swift    # Key capture logic
│   │   └── HotkeyManager.swift     # Carbon registration/dispatch
│   ├── Views/
│   │   ├── OverlayView.swift       # Full-screen Launchpad-style overlay
│   │   ├── GridView.swift          # 7×5 slot grid
│   │   ├── SlotView.swift          # Individual slot
│   │   └── HotkeyBadge.swift       # Key combo display
│   └── Assets.xcassets
└── plans/
    └── 01-hermes.md
```

---

## Todo

### Phase 1 — MVP

- [x] Create Xcode project (macOS, SwiftUI, menu bar only, Swift 6.2.4)
- [x] `NSStatusItem` + full-screen overlay wiring
- [x] `SlotStore` model + `UserDefaults` persistence
- [x] `GridView` (7×5) + `SlotView` with empty/filled states
- [x] Search row (top row) — distinct visual treatment
- [x] Type-to-search: filters installed apps into search row
- [x] Launchpad-style overlay (blur, animation)
- [x] Global hotkey to open overlay + Alfred-style toggle to close
- [x] Drag & drop `.app` from Finder and Dock onto slots
- [x] Hotkey recording (key capture in-slot)
- [x] `HotkeyManager` — Carbon registration + app launch/focus dispatch
- [x] Right-click context menu per slot
- [ ] Polish: icons, badge styling, empty state hints

### Phase 2 — Window Management

- [ ] Window resize layouts as page 2 of overlay
- [ ] `AXUIElement` window resize implementation
- [ ] Accessibility permission prompt + guidance
- [ ] Multi-monitor handling (resize to window's current screen)

### Future / Backlog

- [ ] Keyboard-layout grid mode (slots arranged in QWERTY rows)
- [ ] Script and URL support in slots
- [ ] Configurable grid dimensions
