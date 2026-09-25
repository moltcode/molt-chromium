#!/usr/bin/env bash
# Builds one platform's npm-layout plugin tarball from the official JetBrains
# Runtime (jcef) archive: package/chromium/ holds JBR's Chromium, unmodified,
# and package.json declares it as `resources` for the Molt Code desktop app.
#
# usage: package.sh <npm-platform> <jbr> <jbr-build> <cache-dir> <build-dir> <out.tgz>
set -euo pipefail

platform="$1" jbr="$2" build="$3" cache="$4" work="$5" out="$6"

case "$platform" in
  darwin-arm64) jbr_platform=osx-aarch64 ;;
  darwin-x64) jbr_platform=osx-x64 ;;
  linux-x64) jbr_platform=linux-x64 ;;
  linux-arm64) jbr_platform=linux-aarch64 ;;
  *) echo "unsupported platform: $platform" >&2; exit 1 ;;
esac

# Chromium runtime files in JBR's Linux lib/ (everything cef_server needs).
linux_files=(
  cef_server chrome-sandbox jcef_helper libcef.so libEGL.so libGLESv2.so
  libvk_swiftshader.so vk_swiftshader_icd.json icudtl.dat resources.pak
  chrome_100_percent.pak chrome_200_percent.pak v8_context_snapshot.bin locales
)

source_name="jbr_jcef-$jbr-$jbr_platform-$build"
source="$cache/$source_name.tar.gz"
if [ ! -f "$source" ]; then
  echo "downloading $source_name.tar.gz"
  curl -fsSL --retry 3 -o "$source.part" "https://cache-redirector.jetbrains.com/intellij-jbr/$source_name.tar.gz"
  mv "$source.part" "$source"
fi

unpack="$work/unpack-$platform"
package="$work/$platform/package"
rm -rf "$unpack" "$work/$platform" && mkdir -p "$unpack" "$package/chromium"
tar -xzf "$source" -C "$unpack"
home="$(find "$unpack" -maxdepth 4 -type d -name legal -print -quit)"
[ -n "$home" ] || { echo "no JBR home (legal/) in $source_name" >&2; exit 1; }
home="$(dirname "$home")"

case "$platform" in
  darwin-*)
    # cp -R keeps the frameworks' symlinks, executable bits and signatures.
    cp -R "$home/../Frameworks" "$package/chromium/Frameworks"
    resources='{
      "cef_server": {
        "path": "chromium/Frameworks/cef_server.app/Contents/MacOS/cef_server",
        "description": "JCEF out-of-process server; finds its helpers and the CEF framework beside it"
      }
    }'
    ;;
  linux-*)
    for f in "${linux_files[@]}"; do
      [ -e "$home/lib/$f" ] || { echo "$source_name has no lib/$f" >&2; exit 1; }
      cp -R "$home/lib/$f" "$package/chromium/"
    done
    resources='{
      "cef_server": {
        "path": "chromium/cef_server",
        "description": "JCEF out-of-process server"
      },
      "jcef_helper": {
        "path": "chromium/jcef_helper",
        "description": "Chromium subprocess helper (renderer, GPU, utility)"
      }
    }'
    ;;
esac

cp "$home/legal/java.base/LICENSE" "$home/legal/java.base/ASSEMBLY_EXCEPTION" NOTICE.md README.md "$package/"
jq --arg platform "$platform" --argjson resources "$resources" \
  '.molt.platforms = [$platform] | .molt.contributes.resources = $resources' \
  package.json > "$package/package.json"

# No AppleDouble `._*` entries: Molt extracts with :erl_tar, which would write
# them as real files inside the signed bundles and break their seals.
if tar --version 2>/dev/null | grep -q bsdtar; then
  COPYFILE_DISABLE=1 tar --no-mac-metadata -czf "$out" -C "$work/$platform" package
else
  tar -czf "$out" -C "$work/$platform" package
fi
rm -rf "$unpack" "$work/$platform"
echo "built $out ($(du -h "$out" | cut -f1))"
