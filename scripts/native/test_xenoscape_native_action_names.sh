#!/bin/bash
#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: scripts/native/test_xenoscape_native_action_names.sh
# Purpose: Prove Xenoscape's input action-name constants survive native ARM64
#          codegen (historical string-constant miscompile family).
# Key invariants: Uses only the zanna binary; fails on any mismatch.
# Ownership/Lifetime: Owns one temporary directory removed by the EXIT trap.
# Links: games/xenoscape/action_name_probe.zia
#
#===----------------------------------------------------------------------===#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZANNA_BIN="${1:-${ZANNA_BIN:-zanna}}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xeno_native_action_names.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

IL_FILE="$TMP_DIR/action_name_probe.il"
BIN_FILE="$TMP_DIR/action_name_probe"

"$ZANNA_BIN" build "$DEMOS_ROOT/games/xenoscape/action_name_probe.zia" -o "$IL_FILE"
"$ZANNA_BIN" codegen arm64 "$IL_FILE" --native-asm --native-link -O1 -o "$BIN_FILE"

OUTPUT="$("$BIN_FILE")"
printf '%s\n' "$OUTPUT"

grep -q '^ACT_LEFT=move_left$' <<<"$OUTPUT"
grep -q '^ACT_RIGHT=move_right$' <<<"$OUTPUT"
grep -q '^ACT_LEFT_LEN=9$' <<<"$OUTPUT"
grep -q '^ACT_RIGHT_LEN=10$' <<<"$OUTPUT"
grep -q '^exists_ACT_LEFT=1$' <<<"$OUTPUT"
grep -q '^exists_literal_left=1$' <<<"$OUTPUT"
grep -q '^exists_ACT_RIGHT=1$' <<<"$OUTPUT"
grep -q '^exists_literal_right=1$' <<<"$OUTPUT"
grep -q '^bindings_ACT_LEFT=Pad Left, Left, A$' <<<"$OUTPUT"
grep -q '^bindings_literal_left=Pad Left, Left, A$' <<<"$OUTPUT"
grep -q '^bindings_ACT_RIGHT=Pad Right, Right, D$' <<<"$OUTPUT"
grep -q '^bindings_literal_right=Pad Right, Right, D$' <<<"$OUTPUT"
grep -q '^ACT_LEFT_eq_literal=1$' <<<"$OUTPUT"
grep -q '^ACT_RIGHT_eq_literal=1$' <<<"$OUTPUT"

echo "PASS"
