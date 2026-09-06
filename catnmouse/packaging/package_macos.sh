#!/bin/sh
#===----------------------------------------------------------------------===//
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#===----------------------------------------------------------------------===//
# File: zannademos/catnmouse/packaging/package_macos.sh
# Purpose: Build, ad-hoc sign, verify and zip a drag-to-install macOS DMG.
# Key invariants:
#   - The published stem is derived from zanna.project; art.VERSION and INSTALL.txt
#     must agree with it or the run stops before anything is built.
#   - Existing published artifacts are never replaced.
#   - No Gatekeeper settings or quarantine attributes are changed.
#   - Only this invocation's private temporary directory is cleaned up.
# Ownership/Lifetime:
#   - The script owns its build scratch directory and temporary image mount.
# Links: INSTALL.txt, generate.zia, ../zanna.project
#===----------------------------------------------------------------------===//
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
game_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
workspace_root=$(CDPATH= cd -- "$game_root/../.." && pwd)
zanna_bin=${ZANNA_BIN:-"$workspace_root/build/src/tools/zanna/zanna"}
output_dir=${1:-"$workspace_root/zannagames"}

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
    printf 'error: this package recipe requires an Apple silicon Mac.\n' >&2
    exit 1
fi
if [ ! -x "$zanna_bin" ]; then
    printf 'error: build Zanna first using scripts/build_zanna_mac.sh.\n' >&2
    exit 1
fi
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
# The published stem follows zanna.project, so an artifact can never carry a stale
# version. art.VERSION (the in-game string) and INSTALL.txt ship inside the package,
# so a disagreement between any of them is a packaging bug, not a naming detail.
version=$(sed -n 's/^version[[:space:]][[:space:]]*//p' "$game_root/zanna.project" | head -n 1)
case "$version" in
    '' | *[!0-9.]*)
        printf 'error: no usable version line in %s/zanna.project\n' "$game_root" >&2
        exit 1
        ;;
esac
art_version=$(sed -n 's/^final VERSION = "\(.*\)";$/\1/p' "$game_root/art.zia" | head -n 1)
if [ "$art_version" != "$version" ]; then
    printf 'error: art.VERSION is %s but zanna.project says %s.\n' "$art_version" "$version" >&2
    exit 1
fi
install_version=$(sed -n "s/^CAT 'N' MOUSE //p" "$script_dir/INSTALL.txt" | head -n 1)
if [ "$install_version" != "$version" ]; then
    printf 'error: INSTALL.txt names %s but zanna.project says %s.\n' "$install_version" "$version" >&2
    exit 1
fi
stem=Cat-n-Mouse-$version-macos-arm64
if ! grep -q "$stem.dmg.sha256" "$script_dir/INSTALL.txt"; then
    printf 'error: INSTALL.txt does not name %s.dmg.sha256.\n' "$stem" >&2
    exit 1
fi
for suffix in .dmg .dmg.sha256 .dmg.manifest.json .dmg.zip .dmg.zip.sha256; do
    if [ -e "$output_dir/$stem$suffix" ]; then
        printf 'error: refusing to replace %s\n' "$output_dir/$stem$suffix" >&2
        exit 1
    fi
done

work=$(mktemp -d /private/tmp/catnmouse-package.XXXXXX)
mounted=no
cleanup() {
    if [ "$mounted" = yes ]; then
        if ! hdiutil detach "$work/mount"; then
            printf 'Image still mounted; retained scratch directory: %s\n' "$work" >&2
            return
        fi
    fi
    case "$work" in /private/tmp/catnmouse-package.*) rm -rf -- "$work" ;; esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$work/delivery" "$work/mount"

CATNMOUSE_PACKAGING_OUT="$script_dir" "$zanna_bin" run "$script_dir/generate.zia" -Wall -Werror
"$zanna_bin" build "$game_root" -o "$work/catnmouse" -Wall -Werror
"$work/catnmouse" --seed 173 --smoke
# Ad-hoc signing with the hardened runtime and a sealed bundle is the strictest
# configuration available without an Apple Developer ID; notarization needs one.
"$zanna_bin" package "$game_root" --target dmg --arch arm64 \
    --executable "$work/catnmouse" --macos-sign-mode adhoc --macos-hardened-runtime \
    -o "$work/delivery/$stem.dmg"

hdiutil verify "$work/delivery/$stem.dmg"
hdiutil attach "$work/delivery/$stem.dmg" -readonly -nobrowse -mountpoint "$work/mount"
mounted=yes
app="$work/mount/Cat 'n' Mouse.app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -d --verbose=2 "$app" 2>&1 | grep -q 'flags=.*runtime' || {
    printf 'error: hardened runtime flag missing from the bundle signature.\n' >&2; exit 1; }
plutil -lint "$app/Contents/Info.plist"
# Report (never enforce) the Gatekeeper verdict: ad-hoc builds are expected to be rejected.
spctl --assess --type execute --verbose=2 "$app" 2>&1 | sed 's/^/spctl: /' || true
test "$(readlink "$work/mount/Applications")" = /Applications
test -f "$app/Contents/Resources/assets/README.md"
(cd "$work" && "$app/Contents/MacOS/catnmouse" --seed 173 --zanna-package-smoke)
if [ "${CATNMOUSE_PACKAGE_WINDOW_TEST:-0}" = 1 ]; then
    (cd "$work" && "$app/Contents/MacOS/catnmouse" --seed 173 --window-smoke)
fi
hdiutil detach "$work/mount"
mounted=no

cp "$script_dir/INSTALL.txt" "$work/delivery/INSTALL.txt"
cp "$script_dir/LICENSE" "$work/delivery/LICENSE"
# Recompute in this directory so the checksum uses a portable, relative filename.
(cd "$work/delivery" && shasum -a 256 "$stem.dmg" > "$stem.dmg.sha256")
ditto -c -k --norsrc "$work/delivery" "$work/$stem.dmg.zip"
unzip -t "$work/$stem.dmg.zip"
for suffix in .dmg .dmg.sha256 .dmg.manifest.json; do
    cp -n "$work/delivery/$stem$suffix" "$output_dir/$stem$suffix"
done
cp -n "$work/$stem.dmg.zip" "$output_dir/$stem.dmg.zip"
(cd "$output_dir" && shasum -a 256 "$stem.dmg.zip" > "$stem.dmg.zip.sha256")
printf '\nCreated: %s/%s.dmg.zip\n' "$output_dir" "$stem"
printf 'Ad-hoc signed, NOT notarized. First-launch approval instructions are inside the ZIP.\n'
