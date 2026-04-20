Build, sign, and publish a new Hermes release to GitHub.

Steps:

1. Read the current version from `VERSION`
2. Build with xcodebuild (Release config, no signing)
3. Ad-hoc sign the .app with codesign
4. Zip to `~/Desktop/Hermes-{version}.zip`
5. Tag the commit as `v{version}` and push to origin
6. Create a GitHub release on erickyellott/hermes and upload the zip

Commands:

```bash
VERSION=$(cat VERSION)

xcodebuild -project Hermes.xcodeproj \
  -scheme Hermes \
  -configuration Release \
  -derivedDataPath build/ \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

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
  --notes "## Install

1. Download and unzip \`Hermes-$VERSION.zip\`
2. Move \`Hermes.app\` to \`/Applications\`
3. Run in Terminal:

\`\`\`bash
xattr -cr /Applications/Hermes.app
\`\`\`

Then open normally. You only need to do this once."
```
