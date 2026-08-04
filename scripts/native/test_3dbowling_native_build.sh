#!/bin/bash
#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: scripts/native/test_3dbowling_native_build.sh
# Purpose: Prove 3dbowling builds and links natively (arm64) with the Zanna
#          toolchain alone.
# Key invariants:
#   - Uses only the zanna binary; never configures or invokes CMake/CTest.
#   - Fails (nonzero exit) on any build, codegen, or link error.
# Ownership/Lifetime: All build artifacts live in a temp dir removed on exit.
# Links: ../run_demo_tests.sh (native-arm64-macos lane), games/3dbowling/
#
#===----------------------------------------------------------------------===#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZANNA_BIN="${1:-${ZANNA_BIN:-zanna}}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/3dbowling_native_build.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

IL_FILE="$TMP_DIR/3dbowling.il"
BIN_FILE="$TMP_DIR/3dbowling"

"$ZANNA_BIN" build "$DEMOS_ROOT/games/3dbowling" -o "$IL_FILE"
"$ZANNA_BIN" codegen arm64 "$IL_FILE" --native-asm --native-link -O1 -o "$BIN_FILE"

test -f "$BIN_FILE"
test -x "$BIN_FILE"
echo "PASS"
