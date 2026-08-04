#!/bin/bash
#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: scripts/native/test_xenoscape_native_gameplay.sh
# Purpose: Compile and run the Xenoscape mechanics and campaign probes as
#          native ARM64 binaries (historical aggregate-return miscompiles
#          only surfaced in optimized native builds).
# Key invariants: Uses only the zanna binary; each probe must print RESULT: ok.
# Ownership/Lifetime: Owns one temporary directory removed by the EXIT trap.
# Links: games/xenoscape/mechanics_probe.zia, games/xenoscape/campaign_probe.zia
#
#===----------------------------------------------------------------------===#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMOS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZANNA_BIN="${1:-${ZANNA_BIN:-zanna}}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xeno_native_gameplay.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

for probe in mechanics campaign; do
    IL_FILE="$TMP_DIR/${probe}_probe.il"
    BIN_FILE="$TMP_DIR/${probe}_probe"
    "$ZANNA_BIN" build "$DEMOS_ROOT/games/xenoscape/${probe}_probe.zia" -o "$IL_FILE"
    "$ZANNA_BIN" codegen arm64 "$IL_FILE" --native-asm --native-link -O1 -o "$BIN_FILE"
    OUTPUT="$(cd "$DEMOS_ROOT/games/xenoscape" && "$BIN_FILE")"
    printf '%s\n' "$OUTPUT"
    grep -q 'RESULT: ok' <<<"$OUTPUT"
done

echo "PASS"
