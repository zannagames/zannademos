# Cat 'n' Mouse

A complete ten-room real-time cheese heist, written in Zia using Zanna's 2D
runtime. You are the mouse. Collect twelve cheese pieces in each room, keep
crates between yourself and the roaming cats, grab the star bonus, and reach the
exit once it appears. From room 2 on, you must also box in every roaming cat
before the exit will appear.

The board is **20 × 11 cells**, including the enclosing walls, with **64 × 64
pixels per cell**. The entire 1280 × 704 board stays visible in a 1344 × 872
window, with status above and controls below.

The presentation is pixel art throughout: crisp sprites, bitmap lettering,
stepped shapes, animated pixel details and nearest-neighbor scaling. Everything
is generated in code, including the original looping chiptune and sound effects.
Optional PNGs can replace individual sprites without changing game code. No
downloads or external libraries are required.

![Cat 'n' Mouse pixel-art menu](preview.png)

The front menu includes Start/Resume, Settings, High Scores, How to Play and Quit.
Menus support keyboard, mouse and controller navigation. The pause menu preserves
the current heist, including when returning to the main menu.

## Play

From the Zanna checkout:

```sh
./build/src/tools/zanna/zanna run zannademos/catnmouse
```

For a native executable (recommended for play):

```sh
./build/src/tools/zanna/zanna build zannademos/catnmouse -o zannademos/bin/catnmouse
./zannademos/bin/catnmouse
```

On Windows, use `build\src\tools\zanna\zanna.exe` and an output path ending
in `.exe`. The game source has no platform-specific branches. Build the compiler
first using the repository's platform build script if it is not available.

The project deliberately lives at `zannademos/catnmouse/`, as requested. The
bulk demo builder currently accepts only `games/`, `apps/`, and `3d/` categories;
build this project directly with the command above. Its checks are registered
in `zannademos/demo_tests.tsv` and run through the usual demo test runner.

## macOS installer

The Apple silicon package (macOS 14+) is written to
`../../zannagames/Cat-n-Mouse-1.1.4-macos-arm64.dmg.zip`, alongside the DMG,
checksums and artifact manifest. Unzip, open the DMG, drag the game to
Applications, then eject the image. No Zanna installation is needed to play.

The app uses **ad-hoc signing with the hardened runtime**, matching Legacy
Baseball; it is not Apple notarized (that needs a Developer ID identity). On first launch, trusted recipients may need to approve this specific
app under System Settings → Privacy & Security → Open Anyway. The ZIP includes
an installation guide with [Apple's instructions](https://support.apple.com/102445).
Do not disable Gatekeeper globally. Managed Macs can prohibit this exception.

Rebuild the package on an Apple silicon Mac with the existing Zanna toolchain:

```sh
sh zannademos/catnmouse/packaging/package_macos.sh
# Optional: also exercise the real window/audio from the mounted app.
CATNMOUSE_PACKAGE_WINDOW_TEST=1 sh zannademos/catnmouse/packaging/package_macos.sh /tmp/catnmouse-release
```

The recipe regenerates the pixel icon and installer backdrop, builds with
warnings as errors, signs through Zanna's packager, remounts the compressed
image read-only, verifies the complete bundle signature, runs its smoke entry
from outside the checkout, tests the ZIP and produces SHA-256 checksums. It
refuses to overwrite an existing release. The current package is arm64, not
Intel/universal. A clean downloaded-install test on another Mac remains useful.

## Controls and rules

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move / navigate | Arrows or WASD | D-pad or left stick |
| Wait one turn | Space | X / Square |
| Confirm / continue | Enter | A / Cross |
| Back / cancel / pause | Escape | B / Circle |
| Pause / resume | P | Start / Options |
| Help | H / F1 | Back / View |
| Toggle lane overlay | L | Y / Triangle |
| Offer surrender (costs one life) | R | Right bumper / R1 |
| Restart the room (costs one life) | Backspace / T | Left bumper / L1 |
| Toggle music | M | Settings menu |
| Toggle sound effects | N | Settings menu |

Controller labels follow Zanna's standard logical layout. Any connected supported
controller can operate the game; hot connection is handled by the runtime. Losing
window focus or disconnecting the last controller while using it pauses play.
The analog stick engages at 0.55 and must return within 0.25 of center to rearm;
diagonals choose the dominant axis. This prevents drift and accidental repeated
turns. Menus show controller hints after controller input.

The cats live in real time: the simulation advances in fixed 100 ms ticks while
the board is live, and pauses in every menu. You move one square per key press.
Hold a direction to run: the first press moves once, then after a 400 ms pause
the mouse keeps moving at ten squares per second until you let go. Invalid
moves do nothing. A "GET READY" banner marks the 1.5 second grace period at the start of
every room, after every respawn and after a restart: no cat moves or hunts, and
no cat can see the entrance when a room begins.

Cats see in all four cardinal directions, however far away you are. A crate or
the outer wall stops a sightline. Cheese, the bonus and other cats do not.
Entering a hunting cat's lane, or having one wander into yours, starts the catch:
your controls lock, the cat walks square by square to you, and only then do you
lose a life. The cat returns to where it spotted you.

Amber sentries never move and cannot be removed. They only hunt while they glow;
between searches they are harmless, on a random timer of 2 to 5 seconds idle and
1.5 to 3 seconds searching. Blue stalkers and violet prowlers wander at random,
avoiding immediate reversals, and cannot push crates. Every 14 to 24 steps a
wanderer drops a fresh pale crate on the square it just left. Drops never land on
cheese, the bonus, the exit or you, and never seal any of those in completely.
A gold corner badge means a cat is standing on cheese.

A wandering cat enclosed on all four sides by crates or walls is removed for good
once all twelve cheese are collected. Box one in earlier, or trap it between other
cats, and it simply respawns somewhere covered, out of your lanes, with its own
short hold before it moves again. You cannot push a crate onto another crate, a
cat, cheese, the bonus, a wall or the exit. There is no pulling, chain pushing,
shooting or undo.

Cheese spawns at random places when a room begins and never moves. One star
bonus per room is worth 300 points; it hops to a new random square on a visible
countdown (10 seconds in rooms 1–3, 8 in 4–7, 6 in 8–10 on Classic) until you
take it. The exit stays hidden until the room's objective is met: twelve cheese
and every roaming cat boxed in (room 1 has sentries only, which never count);
it then appears on a floor square you can walk to.

On Classic, you have five lives for the entire campaign. Deaths preserve moved
crates, surviving cats, collected cheese and the turn counter. Enter drops you
on a random covered square, scatters every roaming cat to a random covered spot
of its own (sentries stay where they are), and grants a fresh grace period. If
no refuge remains, the run ends. Surrender uses the same process. If crates have boxed the cheese in,
Backspace offers a restart: it costs one life and rebuilds the room with new
cheese, bonus and cat positions. New rooms restore their authored layouts, but
your remaining lives carry forward. There are no saved checkpoints. An ending
records your score; Enter opens the high-score board and Escape returns to the
main menu, where you can begin a new campaign.

## Settings and high scores

| Difficulty | Campaign lives | Stalker / prowler seconds per step | Bonus hop: rooms 1–3 / 4–7 / 8–10 |
| --- | --- | --- | --- |
| Cozy | 7 | 1.1 / 0.8 | 14 / 12 / 10 seconds |
| Classic (default) | 5 | 0.9 / 0.5 | 10 / 8 / 6 seconds |
| Fierce | 3 | 0.8 / 0.4 | 8 / 6 / 4 seconds |

Difficulty changes apply to the next heist; the current run keeps its original
rules. Music, sound effects, lane assistance and reduced motion change immediately.
Reduced motion removes screen fades, menu motes and event sparkles. Music ducks
in menus and becomes silent while the window is unfocused. If no audio device is
available, the game continues silently.

Set your three-letter initials in Settings. Each completed or failed campaign
is recorded once, with separate top-ten lists for each difficulty. Tied scores
keep their existing order. The score is 100 per cheese, 1,000 per cleared room,
250 per captured cat, 300 per bonus, minus 2 per turn, with a floor of zero. Victory adds 5,000
plus 500 per remaining life. Abandoning a live run does not submit a score.

Preferences and scores save atomically through `SaveData` under the `catnmouse`
key: macOS `~/Library/Application Support/Zanna/catnmouse/save.json`, Linux
`~/.local/share/zanna/catnmouse/save.json`, or Windows
`%APPDATA%\Zanna\catnmouse\save.json`. This is local persistence, not Steam Cloud.
Missing profiles use defaults; corrupt data or failed writes produce a visible
notice and preserve playable in-memory state. Scores shown by the real game start
empty; the visual probe uses explicitly isolated sample records for screenshots.

## Artwork and customization

See [assets/README.md](assets/README.md) for the twelve PNG names, transparency,
dimensions and search order. Set `CATNMOUSE_ASSETS` to use a separate skin
directory. Missing or unreadable sprites use the generated defaults.

Rules live in `rules.zia`; the ten authored crate layouts, titles, enemy mixes and
bonus intervals are in `rooms.zia`. Rendering is in `view.zia`; artwork is in
`art.zia`. `session.zia` coordinates menus and campaign state; `menus.zia` draws
the front end; `profile.zia` owns preferences and scores; `controls.zia` unifies
keyboard/controller input; `sound.zia` builds audio; `main.zia` owns the native loop.

[DESIGN.md](DESIGN.md) contains the runtime assessment, implementation plan,
explicit decisions for the gaps in the original brief, tick-resolution order,
and acceptance scenarios.

## Reproducibility and checks

```sh
# Fixed initial RNG seed (0 through 2147483646).
./build/src/tools/zanna/zanna run zannademos/catnmouse -- --seed 173

# No window or audio device needed for these commands.
./build/src/tools/zanna/zanna run zannademos/catnmouse -- --smoke
./build/src/tools/zanna/zanna run zannademos/catnmouse -- --seed 173 --screenshot /tmp/catnmouse.png
./build/src/tools/zanna/zanna run zannademos/catnmouse -- --screenshot /tmp/catnmouse-menu.png --screen menu
./build/src/tools/zanna/zanna run zannademos/catnmouse/rules_probe.zia
./build/src/tools/zanna/zanna run zannademos/catnmouse/campaign_probe.zia
./build/src/tools/zanna/zanna run zannademos/catnmouse/visual_probe.zia
./build/src/tools/zanna/zanna run zannademos/catnmouse/session_probe.zia
./build/src/tools/zanna/zanna run zannademos/catnmouse/controls_probe.zia
./zannademos/scripts/run_demo_tests.sh --demo catnmouse --fast
```

Native executables accept the same flags without the extra `--`. A new campaign
after an ending increments the previous campaign's seed. The smoke entry also
accepts `--zanna-package-smoke`.

`--screen board|menu|settings|scores` selects a headless screenshot (requires
`--screenshot`). `--window-smoke` opens a real window, exercises 120 frames of
menu/settings/play transitions and audio setup, then closes. It never loads or
writes the player's profile.

Set `CATNMOUSE_PREVIEW` to an existing output directory when running
`visual_probe.zia` to export all rooms, title, help, dialogs, map and endings.
For `skin_probe.zia`, set `CATNMOUSE_ASSETS` to a new empty scratch directory;
the probe creates one tiny PNG and one deliberately corrupt fixture there,
verifies resize/alpha/fallback, and leaves those fixtures for inspection.

For `profile_probe.zia`, set `CATNMOUSE_PROFILE_TEST_KEY` to a new key starting
with `catnmouse-test-`. The probe refuses an existing save, verifies atomic
preferences/score round trips and corrupt-data recovery, and leaves its isolated
fixture in the platform's application-data directory. It needs write access there.

The checks cover sightline occlusion, legal/illegal pushes, grace and hold
periods, sentry searching, random roaming and crate drops, escape/capture,
the catch walk, persistent room state, respawn failure, static cheese, bonus
hops, hidden/revealed exits, restarts, deterministic randomness, room
boundaries, objectives, progression, pixel alpha, and all
rendered screens, menu transitions, locked difficulty, score ordering, exactly-once
recording, controller bindings, analog hysteresis, and persistent settings.

## Verified and release testing

Verified on macOS: native build with `-Wall -Werror`, native window/audio smoke,
all six registered demo checks, PNG replacement/alpha/fallback, profile persistence
and corruption recovery, and matching VM/native campaign trace `158328625`.
The repository's 2,024-test run completed; its twelve sandbox-related failures
passed when rerun with the required filesystem/network/window access. Runtime
surface audit, platform policy lint and cross-platform smoke scripts also passed.

The macOS DMG passed read-only remount verification, strict bundle-signature
validation, and packaged headless/window/audio smoke tests. ZIP integrity and
both published SHA-256 checksums passed. The package recipe's overwrite guard
was also tested. This checks integrity and operation, not Apple notarization.

Windows/Linux hardware runs, physical-controller playtesting, and full human
campaign balance testing remain release gates. Automated invariants do not prove
every stochastic position remains recoverable. The game has a complete local
front end and campaign; Steamworks, achievements, Cloud and store assets are
not implemented. The macOS packaging recipe verifies ad-hoc signature integrity,
not automatic Gatekeeper trust; Developer ID signing/notarization and Windows/Linux
installers are not included.
