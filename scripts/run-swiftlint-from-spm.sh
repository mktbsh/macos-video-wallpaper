#!/bin/zsh
set -euo pipefail

swiftlint_bin=".build/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint"

if [[ ! -x "$swiftlint_bin" ]]; then
  echo "SwiftLint artifact is not bootstrapped." >&2
  echo "Run: swift package plugin --list >/dev/null" >&2
  exit 1
fi

"$swiftlint_bin" lint --strict --quiet
