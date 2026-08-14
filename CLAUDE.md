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

Window resizing requires Accessibility permission (TCC). Hermes is ad-hoc signed
(`codesign --sign -`), which gives it a designated requirement that is nothing
but the cdhash of the binary:

```
codesign -d -r- /Applications/Hermes.app
# designated => cdhash H"9b294e9b751f8b0e63c0073f783313df61442466"
```

TCC records that requirement when you grant permission. The cdhash changes on
every build, so **every new build invalidates the grant** — debug builds from
Xcode, release builds in `/Applications`, and ad-hoc builds elsewhere are all
treated as different apps.

The failure is silent: the stale entry keeps showing as enabled in System
Settings → Privacy & Security → Accessibility while `AXIsProcessTrusted()` logs
`false`. To reset and re-grant:

```
scripts/reset-accessibility.sh [/path/to/Hermes.app]
```

It quits Hermes, resets the TCC entry, clears quarantine, and relaunches. The
prompt is fired at launch from `AppDelegate.applicationDidFinishLaunching` via
`RecordingEventTap.promptAccessibilityOnce()` — so that launch-time prompt is
load-bearing for this flow, don't remove it while ad-hoc signing is in use.

The real fix is signing with a stable identity (self-signed code-signing cert or
a Developer ID) instead of ad-hoc. That makes the requirement identity-based
rather than cdhash-based, so the grant survives rebuilds and you only grant
once.
