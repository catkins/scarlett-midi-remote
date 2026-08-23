#!/usr/bin/env bash
# Lint and/or test the Swift package.
#   ./scripts/ci.sh          # lint then test (local default)
#   ./scripts/ci.sh lint
#   ./scripts/ci.sh test
#
# On Buildkite, bktec invokes `./scripts/ci.sh test` and sets
# BUILDKITE_TEST_ENGINE_RESULT_PATH to a JUnit XML path.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  echo "usage: $0 [lint|test|all]" >&2
  exit 2
}

setup_sourcekit() {
  # SwiftLint needs sourcekitd. Command Line Tools keep it off the default dyld path.
  if [[ ! -d /Applications/Xcode.app && -d /Library/Developer/CommandLineTools/usr/lib/sourcekitdInProc.framework ]]; then
    export DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/usr/lib${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
  fi
}

run_lint() {
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

  result_path="${BUILDKITE_TEST_ENGINE_RESULT_PATH:-}"
  if [[ -n "$result_path" ]]; then
    mkdir -p "$(dirname "$result_path")"
    swift_test+=(--xunit-output "$result_path")
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
}

cmd="${1:-all}"
if [[ $# -gt 0 ]]; then
  shift
fi
case "$cmd" in
  lint) run_lint ;;
  test) run_test "$@" ;;
  all)
    run_lint
    run_test
    ;;
  *) usage ;;
esac
