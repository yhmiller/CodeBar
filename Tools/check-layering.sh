#!/bin/zsh
# Enforces the module dependency rules from docs/ARCHITECTURE.md §3.
#
# The layering is the whole point of the package split: if the UI can reach the
# concrete store, the CodeRepository seam stops meaning anything and the view
# models stop being testable without SQLite.
set -eu

ROOT="${0:a:h}/.."
cd "$ROOT"

violations=0

# Each rule is "<package> must not import <module>".
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
