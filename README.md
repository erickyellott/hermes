# Hermes

A macOS menu bar app for assigning global hotkeys to apps for instant switching.

## Install

1. Download `Hermes-{version}.zip` from the
   [latest release](https://github.com/erickyellott/hermes/releases/latest)
2. Unzip and move `Hermes.app` to `/Applications`
3. First launch: right-click → Open (to bypass Gatekeeper), or run:

```bash
xattr -cr /Applications/Hermes.app
```

> **"Not Opened" / "damaged" error?** macOS blocks unsigned apps downloaded from
> the browser. Run the command above in Terminal, then open normally. You only
> need to do this once.
