#!/bin/sh
#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: scripts/build_demos.sh
# Purpose: Build every demo in this repository by delegating to the Zanna
#          repo's platform demo builders with this repo as the demo root.
# Key invariants:
#   - No build logic is duplicated here; the parent builders own it.
#   - Requires this repository to be cloned inside a Zanna checkout (the
#     documented nested layout) so ../scripts/build_demos.sh exists.
# Ownership/Lifetime: Build outputs land in bin/ (gitignored).
# Cross-platform touchpoints:
#   - build_demos.ps1 provides the equivalent native Windows entry point.
# Links: demos.list, ../scripts/build_demos.sh
#
#===----------------------------------------------------------------------===#

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PARENT_BUILDER=$ROOT/../scripts/build_demos.sh

if [ ! -f "$PARENT_BUILDER" ]; then
    echo "error: building demos requires the Zanna repo checked out as the parent of this clone" >&2
    echo "expected builder at: $PARENT_BUILDER" >&2
    exit 1
fi

ZANNA_DEMO_MANIFEST=$ROOT/demos.list
ZANNA_DEMO_ROOT=$ROOT
ZANNA_DEMO_BIN_DIR=$ROOT/bin
export ZANNA_DEMO_MANIFEST ZANNA_DEMO_ROOT ZANNA_DEMO_BIN_DIR

exec sh "$PARENT_BUILDER" "$@"
