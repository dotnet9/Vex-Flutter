#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:?Version is required}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
app="$root/apps/texweft/build/macos/Build/Products/Release/texweft.app"
[[ -d "$app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
# This release is one universal DMG for Intel and Apple silicon.
for binary in "$app/Contents/MacOS/texweft" "$app/Contents/Frameworks/App.framework/App" "$app/Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS"; do
  lipo "$binary" -verify_arch x86_64 arm64
done
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Vex.app"
cp "$root/LICENSE" "$stage/LICENSE.txt"
ln -s /Applications "$stage/Applications"
mkdir -p "$root/artifacts/release"
dmg="$root/artifacts/release/Vex-v$version-macos-universal.dmg"
hdiutil create -volname 'Vex' -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
# Mount the finished image and verify the actual shipped bundle, not just staging.
mount="$stage/mount"
mkdir "$mount"
hdiutil attach "$dmg" -mountpoint "$mount" -nobrowse -readonly
trap 'hdiutil detach "$mount" >/dev/null 2>&1 || true; rm -rf "$stage"' EXIT
codesign --verify --deep --strict "$mount/Vex.app"
test -L "$mount/Applications"
hdiutil detach "$mount"
echo "$dmg"
