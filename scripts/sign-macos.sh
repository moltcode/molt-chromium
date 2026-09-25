#!/usr/bin/env bash
# Re-signs JetBrains' Chromium bundles with Molt's Developer ID, keeping each
# binary's entitlements, hardened runtime and a secure timestamp.
#
# Why: macOS App Management lets an app modify only bundles from its own
# developer. Chromium writes into its bundle at startup; signed by JetBrains
# (2ZEFAR8TH3) under Molt Code (ZW445NH299) that write is denied and macOS
# shows "Molt Code was prevented from modifying apps". Same team, no denial —
# as with IntelliJ, which ships JBR's Chromium under JetBrains' own team.
#
# usage: sign-macos.sh <chromium-dir>
set -euo pipefail

dir="$1"
identity="${MOLT_SIGN_IDENTITY:-Developer ID Application: Utpun Tech Labs Private Limited (ZW445NH299)}"
entitlements="$(mktemp -d)"
trap 'rm -rf "$entitlements"' EXIT

sign() {
  local target="$1"
  local plist
  plist="$entitlements/$(printf '%s' "$target" | shasum | cut -c1-16).plist"
  # Read before re-signing: the original signature carries JetBrains' entitlements.
  codesign -d --entitlements - --xml "$target" > "$plist" 2>/dev/null || true
  if grep -q "<key>" "$plist" 2>/dev/null; then
    codesign --force --options runtime --timestamp --sign "$identity" --entitlements "$plist" "$target"
  else
    codesign --force --options runtime --timestamp --sign "$identity" "$target"
  fi
}

# Loose libraries first, then bundles deepest-first so each outer seal covers
# already re-signed contents.
find "$dir" -type f \( -name "*.dylib" -o -name "*.so" \) -print0 |
  while IFS= read -r -d '' f; do sign "$f"; done

find "$dir" -type d \( -name "*.app" -o -name "*.framework" \) -print0 |
  while IFS= read -r -d '' b; do printf '%s\t%s\n' "$(tr -cd '/' <<< "$b" | wc -c)" "$b"; done |
  sort -rn | cut -f2- |
  while IFS= read -r b; do sign "$b"; done

find "$dir" -maxdepth 2 -type d \( -name "*.app" -o -name "*.framework" \) -print0 |
  while IFS= read -r -d '' b; do codesign --verify --deep --strict "$b"; done
echo "signed $(find "$dir" -type d \( -name '*.app' -o -name '*.framework' \) | wc -l | tr -d ' ') bundles as: $identity"
