#!/usr/bin/env bash
# Notarizes re-signed Chromium bundles and staples the ticket into each .app,
# so Gatekeeper accepts them offline once installed from the plugin tarball.
#
# usage: notarize-macos.sh <chromium-dir>
# env:   NOTARIZE_ENV (default ../acp/.notarize.env) with APPLE_ID,
#        APPLE_PASSWORD (app-specific), APPLE_TEAM_ID
set -euo pipefail

dir="$1"
env_file="${NOTARIZE_ENV:-$(cd "$(dirname "$0")/../.." && pwd)/acp/.notarize.env}"
# shellcheck disable=SC1090
source "$env_file"

zip="$(mktemp -d)/chromium.zip"
ditto -c -k --keepParent "$dir" "$zip"
result="$(xcrun notarytool submit "$zip" --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" --wait --timeout 60m)"
rm -rf "$(dirname "$zip")"
echo "$result" >&2
grep -q "status: Accepted" <<< "$result" || { echo "notarization was not accepted" >&2; exit 1; }

find "$dir" -type d -name "*.app" -print0 | while IFS= read -r -d '' app; do
  xcrun stapler staple -q "$app"
done
echo "notarized and stapled $dir"
