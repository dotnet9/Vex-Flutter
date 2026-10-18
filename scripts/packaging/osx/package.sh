#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
version="${1:?Version is required}"
output="${2:-$root/artifacts/release}"
python="${VEX_PYTHON:-python3}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
app="$root/apps/vex/build/macos/Build/Products/Release/Vex.app"
[[ -d "$app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
# This release is one universal DMG for Intel and Apple silicon.
for binary in "$app/Contents/MacOS/Vex" "$app/Contents/Frameworks/App.framework/App" "$app/Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS"; do
  lipo "$binary" -verify_arch x86_64 arm64
done
stage="$(mktemp -d)"
mount=''
cleanup() {
  if [[ -n "$mount" ]]; then hdiutil detach "$mount" >/dev/null 2>&1 || true; fi
  rm -rf "$stage"
}
trap cleanup EXIT
ditto "$app" "$stage/Vex.app"
cp "$root/LICENSE" "$stage/Vex.app/Contents/Resources/LICENSE.txt"
codesign --force --deep --sign - "$stage/Vex.app"
codesign --verify --deep --strict --verbose=2 "$stage/Vex.app"
mkdir -p "$output"
dmg="$output/Vex-v$version-macos-universal.dmg"
"$python" "$root/scripts/packaging/osx/build_dmg.py" build --app "$stage/Vex.app" --output "$dmg" --version "$version"
hdiutil verify "$dmg"
# Mount the finished image and verify the actual shipped bundle, not just staging.
mount="$stage/mount"
mkdir "$mount"
hdiutil attach "$dmg" -mountpoint "$mount" -nobrowse -readonly
codesign --verify --deep --strict "$mount/Vex.app"
"$python" "$root/scripts/packaging/osx/build_dmg.py" verify --mount "$mount"
hdiutil detach "$mount"
mount=''
echo "$dmg"
