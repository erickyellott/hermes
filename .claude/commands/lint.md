# Lint / Fix Build Warnings

Run `xcodebuild` to surface all warnings in the Hermes Xcode project, then fix
every one.

## Steps

1. Run a clean build and collect warnings:

```bash
xcodebuild -project Hermes.xcodeproj -scheme Hermes -configuration Debug clean build 2>&1 | grep -E ":[0-9]+:[0-9]+: warning:" | sort -u
```

2. For each warning, open the relevant file, understand the issue, and apply the
   minimal fix. Common patterns in this Swift/SwiftUI codebase:
   - `var` that's never mutated → change to `let`
   - Redundant `?? default` on non-optional → remove the `??` clause
   - Main-actor-isolated property read from nonisolated context → use
     `nonisolated(unsafe) let` locals or restructure isolation
   - Non-Sendable capture in `@Sendable` closure → use `nonisolated(unsafe) let`
     locals (safe when the closure dispatches back to main before using the
     value)

3. Re-run the build to confirm zero warnings:

```bash
xcodebuild -project Hermes.xcodeproj -scheme Hermes -configuration Debug build 2>&1 | grep -E ":[0-9]+:[0-9]+: warning:"
```

4. Report what was fixed and confirm the build is clean.
