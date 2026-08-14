# 06 — Human-Readable JSON Config

## Problem

`04-config-file.md` moved persistence out of `UserDefaults` and into a file you
can point anywhere. That solved _location_. It did not solve _shape_ — the file
is a direct `Codable` dump of internal types:

```json
{
  "appURL": "file:///Applications/Ghostty.app/",
  "gridIndex": 7,
  "hotkey": { "keyCode": 18, "modifiers": 256 },
  "id": "3F2A9C41-…"
}
```

`keyCode: 18` is Carbon for `1`. `modifiers: 256` is the cmd bit. There are 28
of these, of which maybe six are non-empty. Layout hotkeys live in a second
file. Absolute `.app` paths are machine-specific, so the file does not survive
being synced to another machine where an app lives in `~/Applications`.

Staying with JSON — the file is not meant to be hand-authored. The goal is a
file that syncs predictably and can be read at a glance.

## Non-goals

- Hand-editing as the primary workflow. The GUI stays the source of truth and
  rewrites the file on every change.
- Comments. Not available in JSON; not worth a custom format for this use.

---

## Schema

Single file, version-tagged, empty slots omitted:

```json
{
  "apps": [
    {
      "app": "Ghostty",
      "bundleId": "com.mitchellh.ghostty",
      "column": 0,
      "hotkey": "cmd+1",
      "row": 0
    },
    {
      "app": "Safari",
      "bundleId": "com.apple.Safari",
      "column": 1,
      "row": 0
    }
  ],
  "version": 2,
  "windows": {
    "left-half": "ctrl+alt+left",
    "maximize": "ctrl+alt+m"
  }
}
```

- `apps` — one entry per occupied slot. Omitted entirely when a slot is empty,
  so the file is as long as your setup, not always 28 entries.
- `app` — display name. Redundant with `bundleId`, deliberately: plenty of
  bundle IDs are opaque (`com.todesktop.230313mzl4w4u92` is Cursor), so a file
  carrying only IDs stops being readable. Also the fallback for resolution and
  the label for apps not installed on this machine. Sorts first, so it's the
  line your eye lands on per entry.
- `row` / `column` — grid position, **0-based**, matching the code. Rows `0…3`,
  columns `0…6`.
- `hotkey` — omitted when a slot holds an app but no hotkey (a valid state
  today).
- `windows` — window-resize hotkeys, keyed by layout name. Layouts with no
  hotkey are omitted.
- `version` — lets a future schema change migrate instead of guess.

### Key ordering is not optional

`.sortedKeys` has to stay on. Verified against Swift's `JSONEncoder`: without
it, key order comes out of a per-process-seeded hash, so the same struct
serializes in a **different order on every launch**:

```
{"name":"Ghostty","bundleId":"com.x.y","column":0,"hotkey":"cmd+1","row":0}
{"bundleId":"com.x.y","row":0,"name":"Ghostty","column":0,"hotkey":"cmd+1"}
{"column":0,"hotkey":"cmd+1","row":0,"bundleId":"com.x.y","name":"Ghostty"}
```

Property declaration order is _not_ preserved — that was worth checking, since
it would have given us free control over layout. Every write would rewrite every
line. For a file whose purpose is predictable syncing, that's fatal.

Alphabetical order is then simply accepted. Entries are five keys; the only
residue is `column` and `row` sitting apart, which is not worth contorting field
names to fix.

An underscore prefix does work as an escape hatch if that ever matters — `_`
sorts before lowercase, so `_row` / `_column` group at the top of the entry. Not
used here: a leading underscore reads as "internal field" on what is actually
the most user-facing value in the file.

### Why row/column instead of a flat index

The grid is 7 wide, so a flat index needs mental division to locate:
`"index": 15` is row 2, column 1. `"row": 2, "column": 1` just says it. Since
readability is the point of this change, the extra field earns its place.

Internally it stays a flat index — `HotkeyManager` uses it as the Carbon hotkey
ID — derived at load with `row * 7 + column`.

### Window layout names

`LayoutKind.rawValue` is camelCase (`leftTwoThirds`), which reads poorly in a
file. Add a `configName` to `LayoutKind` alongside the existing `displayName`:

| `LayoutKind`    | file name         |
| --------------- | ----------------- |
| `maximize`      | `maximize`        |
| `leftTwoThirds` | `left-two-thirds` |
| `rightOneThird` | `right-one-third` |
| `leftHalf`      | `left-half`       |
| `rightHalf`     | `right-half`      |

Unknown names in the file are preserved on write rather than dropped, so a
config written by a newer Hermes survives a round-trip through an older one.

### Why not store the app path

`appURL` is the one field that reliably breaks sync: `/Applications/Foo.app` on
one machine, `~/Applications/Foo.app` on another. Storing `bundleId` + `app`
keeps the file portable and readable, and resolves back to a URL at load.

`path` is written **only** as a fallback, for a bundle with no identifier:

```json
{
  "app": "Some Tool",
  "column": 3,
  "path": "/Applications/Some Tool.app",
  "row": 0
}
```

### Resolution order at load

`AppActivator` needs a `URL`, so each entry resolves to one:

1. `bundleId` via `NSWorkspace.urlForApplication(withBundleIdentifier:)`
2. `path`, if present and the bundle exists on disk
3. `app` matched against `AppSearcher`'s installed-app list (case-insensitive)

If all three fail the slot loads as **unresolved** — it keeps its position,
`hotkey`, and `app`, renders greyed out in the overlay with the stored name, and is
written back unchanged. An app that is merely not installed on this machine must
not be silently dropped, or syncing between two machines would erase whatever
the other one has.

---

## Hotkey strings

Replaces `keyCode` / `modifiers`. New `HotkeyCombo` conversions, alongside the
existing `displayString` (which stays as-is for the UI — that shows `⌘⇧1`, the
file shows `cmd+shift+1`).

**Writing** — canonical, fixed order so diffs don't churn:

```
ctrl+alt+shift+cmd+<key>
```

**Reading** — tolerant. Any modifier order, case-insensitive, and these aliases:

| Canonical | Also accepted        |
| --------- | -------------------- |
| `cmd`     | `command`, `⌘`       |
| `alt`     | `opt`, `option`, `⌥` |
| `ctrl`    | `control`, `⌃`       |
| `shift`   | `⇧`                  |

Key names are ASCII words rather than the glyphs used in the UI: `return`,
`space`, `delete`, `escape`, `tab`, `left`, `right`, `up`, `down`, `f1`–`f12`,
plus letters, digits, and punctuation.

`keyCodeToString` in `HotkeyCombo.swift` already holds one direction of this
table. It becomes a single bidirectional table serving both the UI glyphs and
the file names.

---

## One file, one writer

`window-layouts.json` folds into the same file so there is a single thing to
sync or symlink.

That creates a hazard: `SlotStore` and `WindowLayoutStore` would both write the
same file, and whichever saved last would clobber the other's section. So
neither store touches the disk directly anymore.

New `Hermes/Models/ConfigFile.swift`:

- `HermesConfig` — `Codable` struct matching the schema above (`apps`,
  `windows`, `version`). The on-disk shape, decoupled from `AppSlot` /
  `WindowLayout`.
- `ConfigFile` — `@MainActor` class owning the file URL and the last-loaded
  `HermesConfig`. Exposes `load()`, `update(apps:)`, `update(layouts:)`. Each
  `update` mutates its own section and writes the **whole** document, so no
  section can be lost.

`SlotStore` and `WindowLayoutStore` keep their current public API and hold a
shared `ConfigFile`. `AppDelegate` constructs the `ConfigFile` and passes it to
both.

Encoder options:

```swift
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
```

`.withoutEscapingSlashes` matters for the `path` fallback — without it
Foundation writes `\/Applications\/Foo.app`.

### Write safety

A failed or partial write currently truncates the config. Write to a temp file
in the same directory and atomically replace, via
`Data.write(to:options: .atomic)`. Cheap, and the file is now the only copy of
the mappings.

---

## Location

Moves to:

```
$XDG_CONFIG_HOME/hermes/<profile>.json   # if XDG_CONFIG_HOME is set
~/.config/hermes/<profile>.json          # otherwise
```

`~/.config` over `~/.hermes.json` because dotfile managers — stow, chezmoi, yadm
— are all organized around `~/.config`, which is exactly the syncing this change
is for. A bare `~/.hermes.json` has to be special-cased in every one of them. It
also leaves room for a second file later without adding home-directory clutter.

The bare-home dotfile is the older Unix convention (`.zshrc`, `.gitconfig`) and
is still perfectly respectable, but new developer-facing tools have largely
moved. Ghostty — in the example config above — reads `~/.config/ghostty/config`
on macOS, as do neovim, gh, starship, and wezterm.

The Settings "Change…" picker keeps working for pointing somewhere else
entirely.

### Resolving the path

`UserDefaults` `hermes.configPath` still wins if set. Otherwise the default is
computed from `XDG_CONFIG_HOME`, falling back to `~/.config`. Directories are
created on first write.

---

## Migration

Two migrations land at once — the location moves and the schema changes. On
launch, if no file exists at the new path:

1. Look for the old `~/Library/Application Support/Hermes/config.json` (or
   whatever `hermes.configPath` points at). Decode it as the old `[AppSlot]`
   array, plus `window-layouts.json` beside it.
2. For each non-empty slot, read `bundleIdentifier` off the stored `appURL`. Nil
   identifier → write `path` instead.
3. Convert `gridIndex` to `row` / `column`, keycodes to key strings, and
   `LayoutKind` to its `configName`.
4. Write the new file to the active profile, `~/.config/hermes/default.json`.
5. Clear the stale `hermes.configPath` default if it pointed at the old
   Application Support location, so the new path takes effect.
6. Leave the old files on disk untouched. They are the fallback if a migrated
   app mis-resolves.

Migration runs once — the presence of `version` in the file means it's already
in the new format.

---

## Settings UI

Small follow-ons in `SettingsView.swift`:

- Show a warning row when any slot is unresolved: _"2 apps in your config aren't
  installed on this Mac"_ — makes it clear they're preserved, not lost.
- Export defaults to `<profile>.json`.

---

## Todo

### Phase 1 — Schema and codec

- [x] Bidirectional key table + `HotkeyCombo(configString:)` / `configString` in
      `HotkeyCombo.swift`
- [x] `configName` on `LayoutKind`, with round-trip parsing
- [x] `ConfigFile.swift` — `HermesConfig` + `ConfigFile` load/update/atomic
      write, and the `~/.config` path resolution
- [x] App resolution (bundleId → path → name) and the unresolved-slot state on
      `AppSlot`

### Phase 2 — Wire up the stores

- [x] `SlotStore` reads/writes through `ConfigFile`, drops its own JSON encoding
      and the stored `id` / `gridIndex`
- [x] `WindowLayoutStore` reads/writes through `ConfigFile`, drops
      `window-layouts.json`
- [x] `AppDelegate` constructs `ConfigFile` and injects it into both

### Phase 3 — Migration and UI

- [x] One-time migration: old location + old schema → `~/.config/hermes`
- [x] Unresolved-app warning in `SettingsView`, greyed rendering in the overlay
- [x] Config path display in `SettingsView` (shows the new default), export
      filename

---

## Addendum — Profiles

Separate app sets for work and personal, switchable at runtime.

A profile **is** a config file. The schema, resolution, and single-writer rules
above are unchanged — profiles only add "which file is active, and how do you
switch." Any number of them; the name is the filename stem:

```
~/.config/hermes/
  default.json
  work.json
```

### Active profile lives outside the config

In `UserDefaults` under `hermes.activeProfile`, never in a profile file. If it
were in the file, switching profiles on one Mac would drag every synced Mac
onto the same one. It's per-machine state.

### Everything is per-profile

Including window-resize hotkeys. Keeps "a profile is a complete config file"
true, which is what makes the model easy to reason about and each file
portable on its own. The cost — window hotkeys duplicated across profiles,
edited independently — is accepted.

### No more arbitrary config path

The Settings "Change…" picker and the `hermes.configPath` default are removed.
Hermes only looks in its config directory. A profile that needs to live
elsewhere (a synced folder, a work-managed directory) is a symlink.

`hermes.configPath` is still read once by migration, to find data belonging to
someone who had set a custom path, and then cleared.

### Operations

- **Switch** — menu bar submenu and a Settings picker. Reloads both stores and
  re-registers hotkeys.
- **New** — empty profile.
- **Duplicate** — copy the active profile under a new name, to start from an
  existing setup.
- **Reveal in Finder** — also how a profile gets deleted, rather than adding a
  destructive in-app action.

Bootstrapping: if `hermes.activeProfile` is unset or names a file that's gone,
the first profile found alphabetically is adopted, else `default` is created.
That also picks up a `config.json` left by a pre-profile build without needing
a rename.

### Todo

- [x] `ProfileStore.swift` — discovery, active profile, create, duplicate
- [x] `ConfigFile` drops `hermes.configPath`, `defaultURL()`, and
      `resetToDefaultPath()`; takes an explicit URL
- [x] `SlotStore` / `WindowLayoutStore` gain `reload()`
- [x] `AppDelegate.switchProfile(to:)` coordinates reload + hotkey re-register
- [x] Settings: replace the Config File section with profile management
- [x] Menu bar profile submenu
- [x] Migration targets `default.json` and clears the legacy path default
