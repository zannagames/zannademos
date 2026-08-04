# zannademos

Showcase demos, games, and applications for the [Zanna](https://github.com/zannagames/zanna)
compiler toolchain. Everything here is written in Zia or BASIC and compiles with the
`zanna` binary alone — no CMake, no external toolchain.

The content in this repository was externalized from the Zanna repo's `examples/`
tree. A small curated set of teaching examples remains there; the larger demos live
here so the compiler repo stays lean.

## Layout

```
demos.list        manifest of buildable demos (name|category|directory)
demo_tests.tsv    manifest of demo tests consumed by the runner
scripts/          runner + build entry points (POSIX and Windows)
games/            game demos
apps/             application demos
sqldb-basic/      SQL engine written in BASIC
bin/              build output (gitignored)
```

## Requirements

A `zanna` binary. The documented layout is this repository cloned **inside** a
Zanna checkout (`<zanna>/zannademos/`); the tooling then finds
`../build/src/tools/zanna/zanna` automatically. Alternatively set `ZANNA_BIN`
or put `zanna` on `PATH`. The scripts here never build the compiler.

## Running the demo tests

```sh
scripts/run_demo_tests.sh              # fast + full lanes
scripts/run_demo_tests.sh --fast       # fast lane only
scripts/run_demo_tests.sh --perf       # additionally run perf rows (see below)
scripts/run_demo_tests.sh --demo games/ashfall
scripts/run_demo_tests.sh --list       # show what would run
```

Windows: `scripts\run_demo_tests.ps1` (or the `run_demo_tests.cmd` shim) with the
same flags (`-Fast`, `-Perf`, `-List`, `-Demo games/ashfall`, `-Zanna <path>`).

Tests are declared in `demo_tests.tsv` (format documented in the file header).
Notes:

- **Perf rows are opt-in** (`--perf`) and battery-sensitive — run them on AC
  power; efficiency-core scheduling on battery causes false budget failures.
- Set `ZANNA_DEMOS_HEADLESS=1` to skip rows that need a display server.
- Rows marked `native-arm64-macos` (native codegen smokes) only run on Apple
  Silicon macOS hosts.

When this clone sits inside a Zanna checkout, the Zanna test suite bridges to
this runner automatically: `ctest -L demos` runs the fast lane, and
`ZANNA_RUN_DEMOS_FULL=1 ctest -L demos` runs the full lane.

## Building the demos

```sh
scripts/build_demos.sh          # POSIX; native executables land in bin/
scripts\build_demos.ps1         # Windows (per-demo folders under bin\)
```

These delegate to the Zanna repo's platform demo builders with this repository
as the demo root, so they require the nested layout described above.

Individual demos also run directly from source:

```sh
zanna run games/3dbowling/      # any project directory with zanna.project
zanna build apps/zannasql/ -o zannasql
```

## Provenance

Imported from the Zanna repository's `examples/` tree as a fresh copy (no
history rewrite); the Zanna repo's git history remains the archaeology record
for everything that moved. Import commits cite the source SHA.

The Zanna Studio scene-preview probes and the zannagames.com screenshot
pipeline reference `games/ashfall-scenes` and `games/xenoscape-scenes` from
this clone; keep those directories intact.

## License

GNU GPL v3 — see [LICENSE](LICENSE).
