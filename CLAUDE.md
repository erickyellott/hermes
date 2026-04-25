# Hermes

A macOS menu bar app that lets you assign global hotkeys to apps for instant
switching.

## Stack

- Swift / SwiftUI + AppKit
- No dependencies, no sandbox
- Xcode project (`Hermes.xcodeproj`), target: macOS

## Key files

- `Hermes/App/AppDelegate.swift` — menu bar setup, overlay lifecycle
- `Hermes/Models/SlotStore.swift` — persists hotkey→app assignments
- `Hermes/Models/AppSearcher.swift` — searches installed apps
- `Hermes/HotkeyEngine/` — Carbon event tap for global hotkeys
- `Hermes/Views/` — overlay window, settings window, slot UI
- `VERSION` — single source of truth for the release version

## Release

Bump `VERSION`, then run `/release`.

## Accessibility permissions when developing

Window resizing requires Accessibility permission (TCC). macOS keys this
permission on the binary path, not the bundle ID — so debug builds from Xcode
(DerivedData), release builds in `/Applications`, and ad-hoc builds elsewhere
are all treated as separate apps. Granting one does not grant the others.

If `AXIsProcessTrusted()` logs `false` even though "Hermes" appears enabled in
System Settings → Privacy & Security → Accessibility, the listed entry is a
different binary than the running one. Reset and re-grant:

```
tccutil reset Accessibility com.hermes.app
```

Then quit the running Hermes, relaunch, and grant when prompted. The prompt is
fired at launch from `AppDelegate.applicationDidFinishLaunching` via
`RecordingEventTap.promptAccessibilityOnce()`.
