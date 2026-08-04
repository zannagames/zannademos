#!/bin/sh
#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: scripts/run_demo_tests.sh
# Purpose: Manifest-driven test runner for every demo in this repository,
#          driven by an existing Zanna binary.
# Key invariants:
#   - The runner never configures, builds, or invokes CMake/CTest.
#   - A run-probe row passes only when the process exits cleanly and prints
#     "RESULT: ok"; check and run-script rows pass on a clean exit.
#   - Lane selection is explicit: perf rows never run without --perf.
# Ownership/Lifetime:
#   - Temporary output is removed on normal exit and interruption.
# Cross-platform touchpoints:
#   - run_demo_tests.ps1 provides the equivalent native Windows entry point.
# Links: demo_tests.tsv, run_demo_tests.ps1, README.md
#
#===----------------------------------------------------------------------===#

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TAB=$(printf '\t')

MODE="default"
PERF=0
LIST=0
ZANNA_ARG=""
DEMO_FILTERS=""

usage() {
    cat <<'EOF'
Usage: scripts/run_demo_tests.sh [options]
  --fast          run only rows in the fast lane
  --perf          also run perf rows (battery-sensitive; run on AC power)
  --list          print the rows that would run, then exit
  --demo PATH     restrict to one demo directory (repeatable), e.g. games/ashfall
  --zanna PATH    explicit Zanna binary (overrides ZANNA_BIN and discovery)
  --help          show this help

Environment:
  ZANNA_BIN                  Zanna binary when --zanna is not given
  ZANNA_DEMO_TESTS_MANIFEST  manifest override (default: demo_tests.tsv)
  ZANNA_DEMOS_HEADLESS=1     skip rows in the requires_display lane

The binary is resolved as: --zanna, then ZANNA_BIN, then the nested-clone
default ../build/src/tools/zanna/zanna, then `zanna` on PATH.
Exit status: 0 when every selected row passes or is skipped, 1 otherwise.
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        --fast) MODE="fast" ;;
        --perf) PERF=1 ;;
        --list) LIST=1 ;;
        --demo)
            [ $# -ge 2 ] || { echo "error: --demo requires a path" >&2; exit 1; }
            DEMO_FILTERS="$DEMO_FILTERS $2"
            shift
            ;;
        --zanna)
            [ $# -ge 2 ] || { echo "error: --zanna requires a path" >&2; exit 1; }
            ZANNA_ARG=$2
            shift
            ;;
        --help|-h) usage; exit 0 ;;
        *) echo "error: unknown option '$1'" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

MANIFEST=${ZANNA_DEMO_TESTS_MANIFEST:-$ROOT/demo_tests.tsv}
if [ ! -f "$MANIFEST" ]; then
    echo "error: demo test manifest not found: $MANIFEST" >&2
    exit 1
fi

resolve_zanna() {
    if [ -n "$ZANNA_ARG" ]; then
        ZANNA=$ZANNA_ARG
    elif [ -n "${ZANNA_BIN:-}" ]; then
        ZANNA=$ZANNA_BIN
    elif [ -x "$ROOT/../build/src/tools/zanna/zanna" ]; then
        ZANNA=$ROOT/../build/src/tools/zanna/zanna
    else
        ZANNA=zanna
    fi
    case $ZANNA in
        */*)
            if [ ! -x "$ZANNA" ]; then
                echo "demo tests: Zanna binary not found: $ZANNA" >&2
                echo "Set ZANNA_BIN to an existing zanna executable; this runner never builds it." >&2
                exit 1
            fi
            ZANNA=$(CDPATH= cd -- "$(dirname -- "$ZANNA")" && pwd)/$(basename -- "$ZANNA")
            ;;
        *)
            if ! command -v "$ZANNA" >/dev/null 2>&1; then
                echo "demo tests: Zanna binary not found: $ZANNA" >&2
                echo "Set ZANNA_BIN to an existing zanna executable; this runner never builds it." >&2
                exit 1
            fi
            ;;
    esac
}

TIMEOUT_TOOL=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_TOOL=timeout
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_TOOL=gtimeout
fi
TIMEOUT_WARNED=0

has_lane() {
    case ",$1," in
        *",$2,"*) return 0 ;;
    esac
    return 1
}

# Selection: perf rows require --perf; fast rows run in both modes; full rows
# run only in the default mode. requires_display / native-arm64-macos act as
# platform filters (skips), not selection lanes.
row_selected() {
    lanes=$1
    if has_lane "$lanes" perf; then
        [ "$PERF" -eq 1 ]
        return
    fi
    if has_lane "$lanes" fast; then
        return 0
    fi
    if has_lane "$lanes" full; then
        [ "$MODE" = "default" ]
        return
    fi
    return 1
}

# Sets SKIP_REASON and fails when the row cannot run on this host.
row_platform_ok() {
    lanes=$1
    SKIP_REASON=""
    if has_lane "$lanes" requires_display && [ "${ZANNA_DEMOS_HEADLESS:-0}" = "1" ]; then
        SKIP_REASON="requires a display (ZANNA_DEMOS_HEADLESS=1)"
        return 1
    fi
    if has_lane "$lanes" native-arm64-macos; then
        if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
            SKIP_REASON="requires a macOS arm64 host"
            return 1
        fi
    fi
    return 0
}

demo_filter_ok() {
    [ -z "$DEMO_FILTERS" ] && return 0
    for f in $DEMO_FILTERS; do
        [ "$1" = "$f" ] && return 0
    done
    return 1
}

# run_cmd TIMEOUT ENVS COMMAND... — applies the row env pairs and timeout.
# Env values must not contain spaces or commas (manifest contract).
run_cmd() {
    _t=$1
    _e=$2
    shift 2
    if [ "$_e" != "-" ] && [ -n "$_e" ]; then
        # shellcheck disable=SC2046
        set -- env $(printf '%s' "$_e" | tr ',' ' ') "$@"
    fi
    if [ "$_t" -gt 0 ] 2>/dev/null; then
        if [ -n "$TIMEOUT_TOOL" ]; then
            set -- "$TIMEOUT_TOOL" "$_t" "$@"
        elif [ "$TIMEOUT_WARNED" -eq 0 ]; then
            echo "warning: no timeout/gtimeout tool found; rows run untimed" >&2
            TIMEOUT_WARNED=1
        fi
    fi
    "$@"
}

resolve_zanna

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/zannademos-test.XXXXXX") || exit 1
trap 'rm -f "$OUTPUT"' EXIT HUP INT TERM

passed=0
failed=0
skipped=0

if [ "$LIST" -eq 0 ]; then
    echo "demo tests: using zanna binary: $ZANNA"
fi

while IFS=$TAB read -r demo action target lanes timeout envs; do
    case $demo in
        ''|\#*) continue ;;
    esac
    if [ -z "$action" ] || [ -z "$target" ] || [ -z "$lanes" ] || [ -z "$timeout" ]; then
        echo "MANIFEST ERROR: malformed row for '$demo' (need 6 tab-separated columns)" >&2
        failed=$((failed + 1))
        continue
    fi
    envs=${envs:--}
    row_selected "$lanes" || continue
    demo_filter_ok "$demo" || continue
    if ! row_platform_ok "$lanes"; then
        skipped=$((skipped + 1))
        echo "SKIP ($SKIP_REASON): $demo :: $action $target"
        continue
    fi
    if [ "$LIST" -eq 1 ]; then
        echo "$demo$TAB$action$TAB$target$TAB$lanes$TAB$timeout$TAB$envs"
        continue
    fi

    echo "==> $demo :: $action $target"
    case $action in
        check)
            if [ "$target" = "." ]; then
                check_target=$ROOT/$demo
            else
                check_target=$ROOT/$demo/$target
            fi
            run_cmd "$timeout" "$envs" "$ZANNA" check "$check_target" \
                --diagnostic-format=json >"$OUTPUT" 2>&1
            status=$?
            ;;
        run-probe)
            (
                cd "$ROOT/$demo" || exit 125
                run_cmd "$timeout" "$envs" "$ZANNA" run "$target"
            ) >"$OUTPUT" 2>&1
            status=$?
            ;;
        run-script)
            (
                cd "$ROOT" || exit 125
                ZANNA_BIN=$ZANNA
                export ZANNA_BIN
                run_cmd "$timeout" "$envs" sh "$ROOT/$demo/$target"
            ) >"$OUTPUT" 2>&1
            status=$?
            ;;
        *)
            echo "MANIFEST ERROR: unknown action '$action' for $demo" >&2
            failed=$((failed + 1))
            continue
            ;;
    esac

    cat "$OUTPUT"
    ok=0
    if [ "$status" -eq 0 ]; then
        if [ "$action" = "run-probe" ]; then
            grep -Fq "RESULT: ok" "$OUTPUT" && ok=1
        else
            ok=1
        fi
    fi
    if [ "$ok" -eq 1 ]; then
        passed=$((passed + 1))
    else
        echo "DEMO TEST FAILED: $demo :: $action $target (exit $status)" >&2
        failed=$((failed + 1))
    fi
done <"$MANIFEST"

if [ "$LIST" -eq 1 ]; then
    exit 0
fi

echo "zannademos: $passed passed, $failed failed, $skipped skipped"
if [ "$failed" -ne 0 ]; then
    exit 1
fi
