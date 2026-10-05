#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  compiler=/Library/Developer/CommandLineTools/usr/bin/swiftc
  sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
else
  compiler=$(xcrun --find swiftc)
  sdk=$(xcrun --show-sdk-path)
fi
build_dir=${TOM_BUILD_DIR:-build}
mkdir -p "$build_dir/cache"
"$compiler" -swift-version 5 -sdk "$sdk" -module-cache-path "$build_dir/cache" \
  Sources/GestureLogic.swift Sources/ScrollReversal.swift Tests/main.swift -o "$build_dir/gesture-tests"
"$build_dir/gesture-tests"
