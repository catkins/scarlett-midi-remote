#!/usr/bin/env bash
# Lint and/or test the Swift package.
#   ./scripts/ci.sh          # lint then test (local default)
#   ./scripts/ci.sh lint
#   ./scripts/ci.sh test
#   ./scripts/ci.sh build    # release .app zip for Buildkite artifacts
#
# On Buildkite, bktec invokes `./scripts/ci.sh test` and sets
# BUILDKITE_TEST_ENGINE_RESULT_PATH to a JUnit XML path.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  echo "usage: $0 [lint|test|build|all]" >&2
  exit 2
}

setup_sourcekit() {
  # SwiftLint needs sourcekitd. Command Line Tools keep it off the default dyld path.
  if [[ ! -d /Applications/Xcode.app && -d /Library/Developer/CommandLineTools/usr/lib/sourcekitdInProc.framework ]]; then
    export DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/usr/lib${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
  fi
}

# Hosted agents sometimes start with a bare toolchain; SwiftShims lives in the Xcode SDK.
setup_xcode() {
  if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  fi
  if command -v xcrun >/dev/null 2>&1; then
    export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
  fi
  echo "DEVELOPER_DIR=${DEVELOPER_DIR:-}"
  echo "SDKROOT=${SDKROOT:-}"
  xcode-select -p || true
  swift --version || true
}

run_lint() {
  setup_xcode
  setup_sourcekit
  if ! command -v swiftlint >/dev/null 2>&1; then
    if [[ -n "${BUILDKITE:-}" ]]; then
      brew install swiftlint
    else
      echo "swiftlint not installed; skipping lint (install with: brew install swiftlint)"
      return 0
    fi
  fi
  swiftlint lint --config .swiftlint.yml
}

run_test() {
  setup_xcode
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

  # Hosted Xcode writes Swift Testing XML to <name>-swift-testing.xml unless
  # --xunit-output=path uses an equals sign. Keep results off the .build cache volume.
  result_path="${BUILDKITE_TEST_ENGINE_RESULT_PATH:-}"
  if [[ -z "$result_path" && -n "${BUILDKITE:-}" ]]; then
    result_path="tmp/swift-test-results.xml"
  fi
  if [[ -n "$result_path" ]]; then
    mkdir -p "$(dirname "$result_path")"
    swift_test+=(--xunit-output="$result_path")
  fi

  # Optional file list from bktec {{testExamples}}: map FooTests.swift -> --filter FooTests.
  for arg in "$@"; do
    case "$arg" in
      *.swift)
        swift_test+=(--filter "$(basename "$arg" .swift)")
        ;;
    esac
  done

  "${swift_test[@]}"

  if [[ -n "$result_path" ]]; then
    sibling="${result_path%.xml}-swift-testing.xml"
    if [[ ! -f "$result_path" && -f "$sibling" ]]; then
      mv "$sibling" "$result_path"
    fi
    if [[ ! -f "$result_path" ]]; then
      echo "error: expected JUnit XML at $result_path" >&2
      ls -la "$(dirname "$result_path")" >&2 || true
      exit 1
    fi
  fi
}

run_build() {
  setup_xcode
  local app zip
  app="$(./scripts/bundle-app.sh release)"
  mkdir -p tmp
  zip="tmp/ScarlettMidiControl.app.zip"
  rm -f "$zip"
  ditto -c -k --keepParent "$app" "$zip"
  echo "Built $zip ($(du -h "$zip" | awk '{print $1}'))"
}

cmd="${1:-all}"
if [[ $# -gt 0 ]]; then
  shift
fi
case "$cmd" in
  lint) run_lint ;;
  test) run_test "$@" ;;
  build) run_build ;;
  all)
    run_lint
    run_test
    ;;
  *) usage ;;
esac
