# 04 — Config File Persistence + Settings UX

## Goals

1. Move slot/hotkey data from `UserDefaults` to a user-configurable JSON file.
2. Left-clicking the menu bar icon opens Settings instead of the overlay.

---

## Config file

### Default location

`~/Library/Application Support/Hermes/config.json`

macOS-conventional path; accessible via Finder → Go → Library → Application
Support → Hermes.

### User-configurable path

The user can pick a different file in Settings (e.g. a Dropbox folder for
cross-machine sync). The chosen path is stored in `UserDefaults` under
`hermes.configPath`.

### `SlotStore.swift`

- Add a `configURL` computed property that reads `hermes.configPath` from
  `UserDefaults`, falling back to the default path.
- `save()` — JSON-encode slots, write to `configURL` (create directory if
  needed).
- `load()` — read from `configURL`; on first run, if no file exists but the old
  `hermes.slots` key is present, migrate and delete that key.
- Add a `switchConfig(to newURL: URL)` method that saves the new path to
  `UserDefaults` and loads slots from the new file, replacing current state.

### `SettingsView` (in `SettingsWindow.swift`)

- Show the current config file path with a "Change…" button that opens an
  `NSOpenPanel` filtered to `.json`; selecting a file calls `switchConfig(to:)`,
  loading slots from that file and making it the active config path.
- Show a "Reveal in Finder" button next to the path.
- **Export** — "Export Config…" button opens an `NSSavePanel` pre-filled with
  `config.json`; writes a copy of the current slots JSON to the chosen path.
  Does not change the active config path.

---

## Menu bar click behavior

### `AppDelegate.swift`

Currently, left-clicking the menu bar icon calls `toggleOverlay()`. Change it to
call `openSettings()` instead. The overlay is still accessible via its global
hotkeys.

The right-click menu (Settings…, Quit) stays as-is.

---

## What's already done

- Launch at login toggle in `SettingsWindow`.

---

## Todo

### Phase 1 — Config file

- [x] Add `configURL` + `switchConfig(to:)` + `export(to:)` to `SlotStore.swift`
- [x] Rewrite `save()` / `load()` to use the file
- [x] Add config path picker + Reveal in Finder + Export Config… to
      `SettingsView`

### Phase 2 — Menu bar click

- [x] Change left-click in `menuNeedsUpdate` to open Settings
