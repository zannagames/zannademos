# Cat 'n' Mouse: implementation plan and rules

## Runtime review

The existing engine can implement this game without runtime changes, new ABI,
dependencies, downloaded assets, or an ADR.

| Need | Existing capability and evidence | Use here |
| --- | --- | --- |
| Single-screen 2D game | `docs/zannalib/graphics/canvas.md`, `examples/games/dumbsnake/main.zia` | Canvas, frame lifecycle, focus-aware keyboard input |
| Generated, replaceable artwork | `docs/zannalib/graphics/pixels.md`, `examples/games/chess/ui/pieces.zia`, `examples/games/crackman/ui/sprites.zia` | Cached Pixels sprites, PNG overrides, built-in bitmap text |
| Tactical grid | `docs/zannalib/graphics/game2d.md`, `examples/games/dumbsnake/snake.zia` | Renderer-independent integer simulation; bounded lists are sufficient for 220 cells |
| Sound without assets | `docs/zannalib/audio.md`, `examples/games/crackman/audio/sfx_bank.zia` | Optional Synth/SoundBank feedback |
| Pixel-art front end and saves | `examples/games/chess/settings.zia`, `docs/zannalib/game/persistence.md` | Atomic SaveData preferences and difficulty-separated local high scores |
| Controller support | `docs/zannalib/input.md`, `examples/games/chess/ui/game.zia` | Any-controller action bindings, D-pad and hysteresis-latched left stick |
| Demo distribution | `zannademos/games/centipede/main.zia`, `zannademos/games/ridgebound/zanna.project`, `zannademos/demo_tests.tsv` | Zia project, source/native execution, headless probes |

The lower-level engine is a cross-platform software renderer
(`docs/graphics-library.md`). This game does not need physics, scrolling, a scene
graph, pathfinding services, external fonts, or a GPU. Rendering is cached between
actions. Simulation work is bounded by the board and cat count, with no
unbounded placement/retry loops. The target is responsive discrete input and
a 60 FPS presentation loop; this is a design target, not a measured platform SLA.

## Scope and decisions

The original blocks paragraph was truncated, and movement, regeneration timing,
respawn, and the exact capture rule were unspecified. The 2026-09 rework moved
the game from turn-based to real time and settled the following rules:

- A 20 by 11 board (including its outer walls), 64 by 64 pixel cells, cardinal
  single-cell movement, twelve cheese pieces per room, ten generated rooms, and
  five lives shared across the Classic campaign.
- Generated rooms (2026-09-05): `rooms.generate()` places 14 + n .. 18 + n crates
  (never in a corner, never completing a 2 by 2 solid block), a random start with
  two free neighbours, then each cat of the room's recipe at least five squares
  from the start, three from other cats, out of the start's lanes and with enough
  free neighbours (two for roamers). `rooms.validate()` accepts a room only when
  every floor cell is one walkable region from the start, the start is covered,
  no cat is boxed and `crateCount() <= MAX_CRATES` (40). Up to `GEN_ATTEMPTS` (24)
  tries, then `rooms.repair()` opens boundary crates between regions and rehomes
  cats; both paths are deterministic from the campaign seed.
- Real time: `Board.tick()` advances one 100 ms step, driven by the frame clock
  in `main.zia` and explicitly by probes. Menus, pause, help and dialogs never
  tick. The mouse moves only on `Board.step()`, one square per fresh key press;
  Space "waits" in place without spending a turn.
- Only the outer boundary is fixed. Every interior block is a pushable crate;
  generated crates are brown, cat-dropped crates are pale (tile value 3) and
  behave identically.
- Grace: `GRACE` (15) ticks at room start, after a respawn/resume and after a
  restart, during which no cat moves or hunts. Room authoring guarantees no cat
  has a clear lane to the entrance; a respawned cat also gets a 15-tick hold.
- Sightlines: crates and walls occlude; cheese, the bonus and cats do not.
  Roaming cats always hunt (outside grace/hold). Sentries hunt only while
  `searching`, toggled on random timers (idle 20..50 ticks, searching 15..30).
- Catch walk: entering or being caught in a hunting cat's lane sets `CAUGHT`,
  locks movement, and walks the killer one square every `CHASE` (3) ticks until
  it is adjacent, then `lose()` fires and the killer returns to where it spotted
  the mouse. A cat blocking the lane takes over the walk (the first returns home);
  a crate in the lane ends it.
- Roaming: stalkers step every 9 ticks and prowlers every 5 on Classic (11/8 Cozy,
  8/4 Fierce) to a random legal neighbour, avoiding an immediate reversal when
  another option exists. Every 14..24 steps a roamer drops a crate on the square it
  just vacated unless that square holds cheese, the bonus, the exit or the mouse,
  the board already holds `MAX_CRATES` crates, or a flood fill from the mouse
  would no longer reach every remaining cheese, the bonus and the shown exit (or
  the mouse would lose its last free neighbour).
- Boxed roamers (four solid sides): captured (+250) once twelve cheese are
  collected, otherwise they respawn to a random covered floor cell with at least
  two free neighbours and no clear lane to the mouse; if no such cell exists the
  cat holds for GRACE ticks before trying again (no per-tick spam). A roamer with
  no legal move for three consecutive due moves also respawns. On a step, cheese
  is collected before enclosures are judged, so the twelfth cheese and the final
  push on the same step capture rather than respawn. Sentries are never boxed, captured or required for
  the exit; `liveCats()` counts roamers only, and every room's exit requires
  twelve cheese plus zero surviving roamers (`mustClear` is now HUD-only).
- Cheese scatters once per room over cells reachable from the mouse and never moves;
  bonus hops use the same reachable set. One star bonus per room hops to
  a random eligible cell every `interval` seconds (the old scatter table) until
  collected; it is worth `BONUS_POINTS` (300).
- The exit is hidden (`ex = ey = -1`) until `exitOpen()`; it is then placed on a
  random floor cell reachable from the mouse, preferring cells at least four
  steps away, and pushes may no longer cover it.
- Quick restart (Backspace / T / LB) costs one life and reloads the current room
  with fresh randomness; on the last life it ends the run instead.
- Seeded integer randomness makes a run reproducible. New campaigns get a fresh
  seed; tests and `--seed N` can choose a repeatable seed. VM and native traces
  over interleaved steps and ticks must match.
- After a death, Enter respawns the mouse on a random floor cell outside every
  sentry lane with at least one free neighbour and from which every remaining
  cheese is reachable (any such cell failing, the old rule applies), then `respawn()`s every roaming
  cat (random covered cell with no lane to the mouse, hold = GRACE); sentries
  never move. Crates, collected cheese, the bonus and the turn counter persist.
  Cheese at the refuge is collected on arrival. No refuge ends the campaign.
- Held movement repeats: one immediate move, a 250 ms pause, then one move every
  100 ms while the key, D-pad or stick direction stays held (`controls.Repeater`).
  Repeat is only produced while the board is live, never in menus or dialogs.

## Presentation (2026-09-05 upgrade)

Presentation state lives outside the simulation: `view.View` owns the mouse slide
(`advance(dt)`, 90 ms per cell, walk frame swap and hop), the rolling score and
the record rank; `main.App` owns shake (event 10/4), flash (3/4/9), the room-clear
wipe (5 into MAP), particles keyed to `Board.eventX/eventY`, and the red vignette
while CAUGHT. `art.Art` builds walk frames (`generateFrame(id, 1)`), three crate
variants, eight star rotations, 24 px roster icons, halos and per-theme floors
(`retheme(theme)` runs only when the room theme changes). PNG-skinned sprites keep
a single frame. `sound.Audio` switches between the menu tune and the heist loop in
`configure()` and plays MusicGen stings for room start, death and the exit reveal.

The SPECIAL EFFECTS level (`profile.fx`, FANCY / SIMPLE / OFF) gates per-frame effect
work only; no level changes the art. SIMPLE drops the full-screen passes — shake and
the extra clear it forces, colour flash, the room-clear wipe, the mode-change fade,
the CAUGHT vignette — and the pre-blurred glow halos. OFF also drops particles,
floating score labels, the exit-reveal rings, the bonus pulse ring and the score
tally ramp. `main.App.accents` clears the timers a level cannot use so each drawing
block no-ops on its own; `view.View.fx` carries the level into the board pass. The
title motes belong to the front end and draw at every level.

## Implementation sequence

1. Specify the rules and engine mapping here; author deterministic rule probes.
2. Implement `rules.zia` and `rooms.zia`: grid, pushes, sightlines, enemy turns,
   enclosure, RNG, attrition, exit and ten-room progression.
3. Implement `art.zia` and `view.zia`: procedural pixel art, PNG replacement,
   complete board/HUD, title/help, map, pause, death and ending screens.
4. Implement `main.zia`: edge-triggered input, focus pause, synthesized feedback,
   CLI seed and headless screenshot/smoke modes.
5. Verify type checking, headless rule and artwork probes, native/VM agreement,
   screenshots, repository build/tests, and platform policy checks. Record actual
   results in `README.md`; do not claim untested operating systems or play balance.

The additional presentation requirements are implemented by `menus.zia` (pixel-art
menus and score tables), `profile.zia` (validated atomic persistence), `session.zia`
(testable front-end transitions), `sound.zia` (original synthesized music and
effects), and `controls.zia` (keyboard, any-controller buttons, stick hysteresis).
See README for exact difficulty values, scoring, persistence paths and controls.

## Configuration and errors

No feature toggle is required: this is an independently launched demo. Defaults:
1344 by 872 window, 64px tiles, Classic difficulty, music and sound effects on,
special effects `FANCY`, lane assistance on, initials `MOU`. The 1280 by 704
board sits below a compact status bar. L toggles lanes,
M toggles music, N toggles effects, P/Escape pauses, H opens help. Pause/help do
not spend turns. Settings save immediately but difficulty applies only to the next
run. Controller stick engage/release thresholds are 0.55/0.25; the dominant axis
wins and neutral is required between steps. PNG overrides
are optional; see `assets/README.md` for exact names and resolution order.

Messages: blocked input: `Blocked. No turn spent.`; spotted: `Spotted! The cat is
coming.`; escape: `The cat found another way in.`; bonus: `Bonus! Extra points.`;
exit: `The exit has appeared. Head for the green arch.`; missing optional PNG: silent
procedural fallback; corrupt PNG: `Ignoring unreadable PNG: <path>`; invalid
arguments: `Usage: catnmouse [--seed N] [--smoke | --window-smoke] [--screenshot PATH] [--screen board|menu|settings|scores]`; failed
screenshot: `Could not save screenshot.`; no refuge: `No safe refuge remains.`;
exposure: `Caught in a clear lane!`; exhausted lives: `Out of lives.`.
Window creation uses the runtime's standard graphics failure diagnostic.
Profile read failure: `Profile unreadable. Using defaults for this session.`;
write failure: `Could not save profile. Changes remain in this session.`

## Acceptance tests (Given / When / Then)

- Given a distant cat in the same row/column, when no crate intervenes, then the
  square is exposed; a diagonal is safe and a single crate (generated or dropped)
  stops it. During grace, or for an idle sentry, an exposed square is not lethal.
- Given a crate, when pushed toward cheese/bonus/wall/crate/cat/shown exit, then
  neither it nor the mouse moves and no turn is spent; a hidden exit never blocks.
- Given a roamer enclosed on four sides before twelve cheese, then it respawns
  covered, off the mouse's lanes, holding for GRACE ticks; after twelve cheese the
  final enclosing push captures it. Sentries and cat-only enclosures never count.
- Given the mouse enters a hunting lane, then the state becomes CAUGHT, movement
  is refused, the killer walks one square per CHASE ticks, death follows on
  arrival, and the killer returns to its spotting square.
- Given a stalker, when its cadence elapses, then it moves to a legal neighbour,
  records its previous cell, and drops a crate on the vacated cell after its
  move counter reaches zero; drops never cover cheese nor seal a cheese cell.
- Given a roamer with no legal move, then it respawns after three due moves.
- Given collected cheese, when hundreds of ticks elapse, then no cheese moves;
  the bonus hops on its countdown, disappears on pickup and never returns.
- Given a crowded board, when scatter runs, then it terminates and preserves the
  outstanding total through pending pickups.
- Given a death, when Enter continues, then the room remains changed, the
  respawn is covered and grace restarts; zero lives or zero refuge squares end
  the campaign. Restart costs a life, rebuilds the room and re-rolls placement.
- Given each generated room (ten rooms, dozens of seeds), when loaded, then
  boundaries, no interior walls, one connected floor region, a covered entrance
  with grace, spaced unboxed cats, the crate range and cap, twelve pickups, one
  bonus, a hidden exit and compatible capture objectives validate, nothing moves
  during grace, the same seed reproduces the room, and the zero-attempt repair
  path yields an equally valid room.
- Given random play with drops, then the crate count never exceeds the cap, every
  remaining cheese, the bonus and the shown exit stay reachable after every tick,
  and a boxed cat with nowhere to go never raises the escape event on consecutive ticks.
- Given the objective is met, when the exit is revealed, then it lies on a floor
  cell reachable from the mouse; entering it advances to the map; after room
  ten, victory occurs.
- Given two equal seeds/actions/ticks, when simulated, then state, pickups and
  cat positions agree in both VM and native executions.
- Given absent/corrupt/transparent PNGs, when art loads, then fallback and alpha
  composition work; crates carry a translucent shadow and halos are bounded.
- Given an active run, when menus/settings are used, then no ticks advance and
  changing next-run difficulty does not change current rules.
- Given an ending, when it is processed multiple times, then only one score is
  recorded; each difficulty retains its best ten entries in stable score order.
- Given saved preferences and scores, when loaded into a fresh profile, then
  they round-trip; corrupt JSON is nonfatal and invalid score records are rejected.
- Given a held or drifting stick, when frames advance, then no repeated moves
  occur until it returns to neutral; arrow/WASD and any-controller button bindings
  map to the same session commands.
- Given the macOS package, when remounted read-only, then its ad-hoc bundle
  passes `codesign --verify --deep --strict`, its Applications link and resources
  exist, and headless/window smoke tests run from outside the source checkout.
- Given a published package, when the packaging recipe runs again against the
  same output directory, then it refuses to overwrite the existing artifacts.
- Given a downloaded ad-hoc build, recipients explicitly approve the app using
  macOS Privacy & Security as documented in the ZIP. This distribution choice
  follows Legacy Baseball; it does not claim Developer ID trust or notarization.
