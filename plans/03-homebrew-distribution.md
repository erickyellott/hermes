# 03 — Build & GitHub Release (personal use)

## Overview

Build Hermes locally, zip it up, and attach it to a GitHub Release. To run it,
right-click → Open the first time to bypass Gatekeeper. Signing, notarization,
and Homebrew can come later.

---

## Phase 1 — Build release app

1. In Xcode: **Product → Archive**
2. In the Organizer window: **Distribute App → Copy App**
3. This exports `Hermes.app` to a folder of your choice

Alternatively, via command line:

```bash
xcodebuild -project Hermes.xcodeproj \
  -scheme Hermes \
  -configuration Release \
  -derivedDataPath build/ \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
# App lands at build/Build/Products/Release/Hermes.app
```

---

## Phase 2 — Zip & GitHub Release

```bash
cd build/Build/Products/Release
zip -r Hermes-1.0.0.zip Hermes.app
```

Then:

1. Tag the commit: `git tag v1.0.0 && git push origin v1.0.0`
2. Create a GitHub Release on the tag
3. Upload `Hermes-1.0.0.zip` as the release asset

---

## Phase 3 — Install & run

1. Download and unzip
2. Move `Hermes.app` to `/Applications`
3. First launch: right-click → Open → Open (to bypass Gatekeeper)
4. After that it launches normally

---

## Todo

### Phase 1 — Build

- [ ] Verify `xcodebuild` command works (or use Xcode GUI)
- [ ] Confirm `Hermes.app` runs correctly from the exported build

### Phase 2 — GitHub Release

- [ ] Create GitHub repo if not already pushed
- [ ] Tag v1.0.0 and push
- [ ] Create release and upload zip

### Phase 3 — Install

- [ ] Install to /Applications and smoke test
