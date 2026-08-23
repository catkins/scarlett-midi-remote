#!/usr/bin/env bash
# Local/CI helper: lint when SwiftLint is available, then run package tests.
set -euo pipefail
cd "$(dirname "$0")/.."

# SwiftLint needs sourcekitd. Command Line Tools keep it off the default dyld path.
if [[ ! -d /Applications/Xcode.app && -d /Library/Developer/CommandLineTools/usr/lib/sourcekitdInProc.framework ]]; then
  export DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/usr/lib${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
fi

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --config .swiftlint.yml
else
  echo "swiftlint not installed; skipping lint (install with: brew install swiftlint)"
fi

# Hosted Xcode agents already expose Testing. Command Line Tools need extra
# search/rpath flags or `import Testing` fails at compile or dyld time.
swift_test=(swift test)
clt_frameworks="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
clt_lib="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
if [[ ! -d /Applications/Xcode.app && -d "${clt_frameworks}/Testing.framework" ]]; then
  swift_test+=(
    -Xswiftc -F -Xswiftc "${clt_frameworks}"
    -Xlinker -F -Xlinker "${clt_frameworks}"
    -Xlinker -rpath -Xlinker "${clt_frameworks}"
    -Xlinker -rpath -Xlinker "${clt_lib}"
  )
fi

"${swift_test[@]}"
