Build, sign, and publish a new Hermes release to GitHub.

Steps:

1. Read the current version from `VERSION`
2. Build with xcodebuild (Release config, no signing), passing the version in as
   a build setting
3. Verify the built bundle reports that version
4. Ad-hoc sign the .app with codesign
5. Zip to `~/Desktop/Hermes-{version}.zip`
6. Tag the commit as `v{version}` and push to origin
7. Create a GitHub release on erickyellott/hermes and upload the zip

## Version wiring

`VERSION` is the single source of truth, but the Xcode project does **not** read
it — `MARKETING_VERSION` in `project.pbxproj` is a hardcoded fallback used only
by IDE builds. Releases must pass `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` on the xcodebuild command line, as below.

A pre-build script phase does not work here: `GENERATE_INFOPLIST_FILE = YES`
means Xcode regenerates `Info.plist` _after_ shell script phases, discarding any
PlistBuddy edits. Always run the verification step and stop if it disagrees.

## Release notes

Keep them terse. One line per feature or fix, no prose, no headings beyond the
two below. Describe the user-visible change, not the implementation.

Prefix every bullet with `feat:` or `fix:`. List all `feat:` lines first and all
`fix:` lines last.

```
## Changes

- feat: Profiles let you swap whole hotkey sets from the config file
- fix: Window resize no longer flickers when moving between displays
- fix: Overlay app list refreshes on open instead of going stale

## Install
...
```

Do not add "Full changelog", contributor lists, or per-commit detail.

Commands:

```bash
VERSION=$(cat VERSION)

xcodebuild -project Hermes.xcodeproj \
  -scheme Hermes \
  -configuration Release \
  -derivedDataPath build/ \
  MARKETING_VERSION=$VERSION \
  CURRENT_PROJECT_VERSION=$VERSION \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Fail loudly rather than shipping a mislabelled bundle
BUILT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  build/Build/Products/Release/Hermes.app/Contents/Info.plist)
[ "$BUILT" = "$VERSION" ] || { echo "bundle is $BUILT, expected $VERSION"; exit 1; }

codesign --force --deep --sign - \
  build/Build/Products/Release/Hermes.app

cd build/Build/Products/Release
zip -r ~/Desktop/Hermes-$VERSION.zip Hermes.app
cd -

git tag v$VERSION
git push origin v$VERSION

gh release create v$VERSION ~/Desktop/Hermes-$VERSION.zip \
  --repo erickyellott/hermes \
  --title "Hermes v$VERSION" \
  --notes "## Changes

- feat: <one line, all feat: lines first>
- fix: <one line, all fix: lines last>

## Install

1. Download and unzip \`Hermes-$VERSION.zip\`
2. Move \`Hermes.app\` to \`/Applications\`
3. Run in Terminal:

\`\`\`bash
xattr -cr /Applications/Hermes.app
\`\`\`

Then open normally. You only need to do this once."
```
