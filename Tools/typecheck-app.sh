#!/bin/zsh
set -eu

ROOT="${0:a:h}/.."
SDK=$(xcrun --show-sdk-path --sdk macosx)

MODULE_ARGS=()
for package in CodeStore CodeBarUI CodePlatform CodeLibrary; do
  bin=$(cd "$ROOT/Packages/$package" && swift build --show-bin-path)
  MODULE_ARGS+=(-I "$bin" -I "$bin/Modules")
done

cd "$ROOT"

APP_SOURCES=(CodeBar/**/*.swift(N))

swiftc -typecheck \
  -swift-version 6 \
  -target arm64-apple-macos14.0 \
  -sdk "$SDK" \
  "${MODULE_ARGS[@]}" \
  "${APP_SOURCES[@]}"

echo "app sources typecheck clean"
