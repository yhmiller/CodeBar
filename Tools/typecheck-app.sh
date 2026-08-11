#!/bin/zsh
# Typechecks the app target's sources against the locally built CodeCore and
# CodeStore modules.
#
# The app target itself can only be built through Xcode, which needs XcodeGen
# and a generated project. This gives the same Swift 6 concurrency and type
# checking from `make check`, so app-layer regressions surface without that
# round trip. It is not a substitute for an actual build — it does not link,
# compile resources, or sign.
set -eu

ROOT="${0:a:h}/.."
BIN=$(cd "$ROOT/Packages/CodeStore" && swift build --show-bin-path)
SDK=$(xcrun --show-sdk-path --sdk macosx)

cd "$ROOT"

# zsh's ** already matches zero directories, so this covers CodeBar/*.swift too.
APP_SOURCES=(CodeBar/**/*.swift(N))

swiftc -typecheck \
  -swift-version 6 \
  -target arm64-apple-macos14.0 \
  -sdk "$SDK" \
  -I "$BIN/Modules" \
  "${APP_SOURCES[@]}"

echo "app sources typecheck clean"
