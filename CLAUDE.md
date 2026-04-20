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
