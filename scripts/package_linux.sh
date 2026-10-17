#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:?Version is required}"
arch="${2:?Use x64 or arm64}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 1; }
case "$arch" in x64) deb_arch=amd64;; arm64) deb_arch=arm64;; *) exit 1;; esac
bundle="$root/apps/texweft/build/linux/$arch/release/bundle"
[[ -x "$bundle/texweft" && -f "$bundle/lib/libapp.so" && -d "$bundle/data/flutter_assets" ]]
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/DEBIAN" "$stage/usr/lib/texweft" "$stage/usr/bin" \
  "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/256x256/apps" \
  "$stage/usr/share/doc/texweft" "$root/artifacts/release"
cp -a "$bundle/." "$stage/usr/lib/texweft/"
cp "$root/logo.png" "$stage/usr/share/icons/hicolor/256x256/apps/texweft.png"
cp "$root/LICENSE" "$stage/usr/share/doc/texweft/copyright"
printf '#!/bin/sh\nexec /usr/lib/texweft/texweft "$@"\n' > "$stage/usr/bin/texweft"
chmod 755 "$stage/usr/bin/texweft"
cat > "$stage/usr/share/applications/com.codewf.texweft.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Vex
Name[zh_CN]=维刻 Vex
Name[zh_TW]=維刻 Vex
Comment=Write ideas. See connections.
Comment[zh_CN]=写下想法，看见脉络
Comment[zh_TW]=寫下想法，看見脈絡
Exec=texweft
Icon=texweft
Terminal=false
Categories=Office;TextEditor;
StartupWMClass=com.codewf.texweft
EOF
desktop-file-validate "$stage/usr/share/applications/com.codewf.texweft.desktop"
# Derive dependencies from every bundled ELF, including Flutter / plugin libraries.
# dpkg-shlibdeps ignores the private libraries supplied by this package via -l.
mkdir -p "$stage/debian"
printf 'Source: texweft\nSection: text\nPriority: optional\nMaintainer: CodeWF <1012434131@qq.com>\n\nPackage: texweft\nArchitecture: any\nDescription: Markdown writing workspace\n' > "$stage/debian/control"
elf_args=()
while IFS= read -r -d '' file; do
  if file -b "$file" | grep -q '^ELF '; then elf_args+=("-e$file"); fi
done < <(find "$stage/usr/lib/texweft" -type f -print0)
dependencies="$(cd "$stage" && dpkg-shlibdeps --ignore-missing-info -O -l"$stage/usr/lib/texweft/lib" "${elf_args[@]}" | sed -n 's/^shlibs:Depends=//p')"
[[ -n "$dependencies" ]]
cat > "$stage/DEBIAN/control" <<EOF
Package: texweft
Version: $version
Section: text
Priority: optional
Architecture: $deb_arch
Installed-Size: $(du -sk "$stage/usr" | cut -f1)
Maintainer: CodeWF <1012434131@qq.com>
Depends: $dependencies
Homepage: https://github.com/dotnet9/Vex-Flutter
Description: Vex Markdown writing workspace
 Native Flutter editor, reader and mind maps with local files.
EOF
rm -rf "$stage/debian"
chmod 755 "$stage/DEBIAN"
chmod 644 "$stage/DEBIAN/control"
package="$root/artifacts/release/Vex-v$version-linux-$arch.deb"
dpkg-deb --build --root-owner-group "$stage" "$package"
[[ "$(dpkg-deb -f "$package" Version)" == "$version" ]]
[[ "$(dpkg-deb -f "$package" Architecture)" == "$deb_arch" ]]
dpkg-deb --info "$package"
echo "$package"
