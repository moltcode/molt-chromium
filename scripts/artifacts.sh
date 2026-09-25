#!/usr/bin/env bash
# Prints the per-platform `artifacts` map for the Molt plugin catalog.
# usage: artifacts.sh <name> <version> <platform>...
set -euo pipefail
name="$1" version="$2"; shift 2
first=true
printf '{\n'
for p in "$@"; do
  file="out/$name-$version-$p.tgz"
  sha=$(shasum -a 256 "$file" | awk '{print $1}')
  size=$(wc -c < "$file" | tr -d ' ')
  $first || printf ',\n'
  first=false
  printf '  "%s": {"url": "https://github.com/moltcode/%s/releases/download/v%s/%s-%s-%s.tgz", "sha256": "%s", "size": %s}' \
    "$p" "$name" "$version" "$name" "$version" "$p" "$sha" "$size"
done
printf '\n}\n'
