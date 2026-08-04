#!/bin/sh
#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: games/xenoscape/package_dry_run.sh
# Purpose: Validate the Xenoscape tarball packaging manifest without writing
#          an archive (mirrors the old xenoscape_package_dry_run CTest).
# Key invariants: Uses only the zanna binary; never writes package output.
# Ownership/Lifetime: No artifacts are produced (dry run).
# Links: zanna.project, ../../scripts/run_demo_tests.sh
#
#===----------------------------------------------------------------------===#
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ZANNA_BIN=${ZANNA_BIN:-zanna}

cd "$SCRIPT_DIR" || exit 1
exec "$ZANNA_BIN" package "." --target tarball --dry-run
