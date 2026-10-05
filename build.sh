#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Use the separately installed Command Line Tools when available.
# This needs no Xcode project or third-party dependencies.
if [[ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  compiler=/Library/Developer/CommandLineTools/usr/bin/swiftc
  sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
  lipo_tool=/Library/Developer/CommandLineTools/usr/bin/lipo
else
  compiler=$(xcrun --find swiftc)
  sdk=$(xcrun --show-sdk-path)
  lipo_tool=$(xcrun --find lipo)
fi
build_dir=${TOM_BUILD_DIR:-build}
mkdir -p "$build_dir/cache" "$build_dir/objects"
app="$build_dir/Tom the Mouse.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

for arch in arm64 x86_64; do
  "$compiler" -swift-version 5 -O -sdk "$sdk" -target "$arch-apple-macosx13.0" \
    -module-cache-path "$build_dir/cache" -framework AppKit -framework ApplicationServices \
    Sources/*.swift -o "$build_dir/objects/TomTheMouse-$arch"
done
"$lipo_tool" -create "$build_dir/objects/TomTheMouse-arm64" "$build_dir/objects/TomTheMouse-x86_64" \
  -output "$app/Contents/MacOS/TomTheMouse"
cp Resources/Info.plist "$app/Contents/Info.plist"
"$compiler" -swift-version 5 -sdk "$sdk" -module-cache-path "$build_dir/cache" \
  -framework AppKit Resources/MakeIcon.swift -o "$build_dir/objects/make-icon"
"$build_dir/objects/make-icon" "$app/Contents/Resources/AppIcon.icns"
/usr/bin/codesign --force --sign - --identifier com.muathfathihussinsouki.squeakswitch "$app"
/usr/bin/codesign --verify --strict "$app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$build_dir/Tom-the-Mouse-macOS.zip"
echo "Built: $app (Apple Silicon + Intel)"
