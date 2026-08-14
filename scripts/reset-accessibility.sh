#!/usr/bin/env bash
#
# Re-grant Accessibility after installing a new Hermes build.
#
# Ad-hoc signing (codesign --sign -) gives Hermes a designated requirement that
# is nothing but the cdhash:
#
#   # designated => cdhash H"9b294e9b751f8b0e63c0073f783313df61442466"
#
# The cdhash changes on every build, so the TCC grant silently stops matching.
# The old entry keeps showing as enabled in System Settings while
# AXIsProcessTrusted() returns false. Resetting clears the stale entry so the
# prompt fires again on next launch.
#
# This is a stopgap. The real fix is signing with a stable identity, which makes
# the requirement identity-based and survives rebuilds — see CLAUDE.md.
#
# Usage: scripts/reset-accessibility.sh [/path/to/Hermes.app]

set -euo pipefail

BUNDLE_ID=com.hermes.app
APP=${1:-/Applications/Hermes.app}

if [ ! -d "$APP" ]; then
    echo "error: no app bundle at $APP" >&2
    echo "usage: $0 [/path/to/Hermes.app]" >&2
    exit 1
fi

echo "==> Quitting Hermes"
pkill -f "$APP/Contents/MacOS/Hermes" 2>/dev/null || true
sleep 1

echo "==> Resetting Accessibility for $BUNDLE_ID"
tccutil reset Accessibility "$BUNDLE_ID"

echo "==> Clearing quarantine on $APP"
xattr -cr "$APP"

echo "==> Relaunching"
open -a "$APP"

cat <<'EOF'

Grant Accessibility when the prompt appears. Hermes asks at launch, so it should
come up on its own within a second or two.

If nothing appears, there is probably still a stale "Hermes" row in
System Settings > Privacy & Security > Accessibility. Select it, click the minus
button to remove it, then run this script again.

To confirm which binary is actually running:

    pgrep -lf Hermes.app

EOF
