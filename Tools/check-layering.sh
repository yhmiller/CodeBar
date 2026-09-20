#!/bin/zsh
set -eu

ROOT="${0:a:h}/.."
cd "$ROOT"

violations=0

FORBIDDEN=(
  "CodeBarUI:CodeStore"
  "CodeCore:CodeStore"
  "CodeCore:CodeBarUI"
  "CodeCore:AppKit"
  "CodeCore:SwiftUI"
  "CodeStore:CodeBarUI"
  "CodeStore:AppKit"
  "CodeStore:SwiftUI"
  "CodeCore:CodePlatform"
  "CodePlatform:CodeStore"
  "CodePlatform:CodeBarUI"
  "CodeCore:CodeLibrary"
  "CodeCore:SQLiteKit"
  "CodeBarUI:CodeLibrary"
  "CodeBarUI:CodeStore"
  "CodeLibrary:CodeStore"
  "CodeLibrary:CodeBarUI"
  "CodeLibrary:AppKit"
  "CodeLibrary:SwiftUI"
  "SQLiteKit:CodeCore"
  "SQLiteKit:AppKit"
)

for rule in $FORBIDDEN; do
  package="${rule%%:*}"
  forbidden="${rule##*:}"
  sources="Packages/$package/Sources"
  [[ -d "$sources" ]] || continue

  if grep -rqn "^import $forbidden\$" "$sources"; then
    echo "LAYERING VIOLATION: $package imports $forbidden"
    grep -rn "^import $forbidden\$" "$sources"
    violations=1
  fi
done

if (( violations == 0 )); then
  echo "layering rules hold"
fi
exit $violations
