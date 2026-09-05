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
respawn, and the exact capture rule were unspecified. This implementation uses:

- A 20 by 11 board (including its outer walls), 64 by 64 pixel cells, cardinal
  single-cell movement, twelve cheese pieces per room,
  ten authored rooms, and five lives shared across the Classic campaign.
- Turn-based play: one fresh arrow/WASD/D-pad press or left-stick deflection
  moves or pushes; Space or controller X waits.
  Holding a key never spends extra turns. Invalid moves spend no turn.
- Walls and crates stop all four cardinal sightlines. Other cats and cheese do
  not stop sightlines. Cats cannot share the mouse's tile; contact has no special
  damage rule. Only an unobstructed row or column causes a loss.
- One crate can be pushed into empty floor; no chain pushing, pulling, undo,
  crate destruction, or pushing onto cheese, cats, or the exit.
- A mobile cat enclosed on four cardinal sides by walls/crates is removed
  immediately, before exposure is checked. At least one side must be a crate.
  Other cats do not count as enclosure. Stationary sentries cannot be captured.
- Amber sentries stay put. On Classic/Fierce, blue stalkers move every second
  turn; violet prowlers every turn. Cozy uses three/two turns respectively.
  Mobile cats choose the empty neighbor with the shortest Manhattan
  distance to the mouse, using a deterministic rotating tie order. They can
  sidestep obstacles and never push crates. Cats may stand on cheese, in which
  case a gold badge preserves pickup visibility. Their cadence is visible.
- Exposure is checked after the mouse's push/move, and after each individual
  cat move. Entering an exposed lane cannot be rescued by a cat moving away.
  A life loss stops the rest of the turn. Surviving mice collect cheese after
  the cat phase, then the relocation counter advances.
- On Classic, remaining cheese relocates every 10 turns initially, then 8, then 6. The
  countdown is visible. Placement samples empty floor without replacement,
  excluding the mouse, cats, crates, walls, and exit. Collected cheese stays
  collected. Cheese may be exposed or temporarily inaccessible; a later
  relocation can rescue it. If the board is crowded, unplaced cheese remains
  pending and is retried at the next relocation; it is never silently collected.
- Seeded integer randomness makes a run reproducible. New campaigns get a fresh
  seed; tests and `--seed N` can choose a repeatable seed.
- After a death, Enter respawns at the safe empty square nearest the original
  entrance. Crates, cats, collected cheese and turn counter persist. Cheese at
  the refuge is collected on arrival. No safe refuge ends the campaign.
  An explicit surrender confirmation also costs one life without resetting the
  board. There is no room restart; a new campaign is offered only at game over
  or victory.
- Clear rooms contain only mobile cats, making "all cats" satisfiable. The exit
  opens at twelve cheese and, when required, zero cats. Entering it after a
  surviving turn advances to the linear house-map interstitial. Room ten leads
  to a victory screen. Lives carry between rooms.

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
1344 by 872 window, 64px tiles, Classic difficulty, music/effects/motion on,
lane assistance on, initials `MOU`. The 1280 by 704
board sits below a compact status bar. L toggles lanes,
M toggles music, N toggles effects, P/Escape pauses, H opens help. Pause/help do
not spend turns. Settings save immediately but difficulty applies only to the next
run. Controller stick engage/release thresholds are 0.55/0.25; the dominant axis
wins and neutral is required between steps. PNG overrides
are optional; see `assets/README.md` for exact names and resolution order.

Messages: blocked input: `Blocked. No turn spent.`; missing optional PNG: silent
procedural fallback; corrupt PNG: `Ignoring unreadable PNG: <path>`; invalid
arguments: `Usage: catnmouse [--seed N] [--smoke | --window-smoke] [--screenshot PATH] [--screen board|menu|settings|scores]`; failed
screenshot: `Could not save screenshot.`; no refuge: `No safe refuge remains.`;
exposure: `Caught in a clear lane!`; exhausted lives: `Out of lives.`.
Window creation uses the runtime's standard graphics failure diagnostic.
Profile read failure: `Profile unreadable. Using defaults for this session.`;
write failure: `Could not save profile. Changes remain in this session.`

## Acceptance tests (Given / When / Then)

- Given a distant cat in the same row/column, when no wall/crate intervenes,
  then the square is lethal; a diagonal is safe and a single blocker stops it.
- Given a crate, when pushed toward cheese/wall/crate/cat/exit, then neither
  it nor the mouse moves and no turn is spent.
- Given three enclosed sides, when the fourth closes with a crate, then a
  mobile cat disappears; a sentry and enclosure by other cats survive.
- Given an exposed destination, when its cat would move away this turn, then
  the mouse still loses a life before the cat phase.
- Given mobile cats, when a turn is spent, then their documented cadence,
  collision rules and intermediate exposure checks apply.
- Given collected cheese, when relocation occurs, then collected totals persist
  and all active pickups occupy distinct eligible squares.
- Given a crowded board, when relocation runs, then it terminates and preserves
  the outstanding total through pending pickups.
- Given a death, when Enter continues, then the room remains changed and the
  respawn is safe; zero lives or zero refuge squares end the campaign.
- Given each authored room, when loaded, then boundaries, one safe mouse/exit,
  twelve pickups and compatible capture objectives validate.
- Given an open exit, when the mouse enters, then a map transition occurs;
  after room ten, victory occurs. Locked exits do not complete rooms.
- Given two equal seeds/actions, when simulated, then state and pickups agree
  in both VM and native executions.
- Given absent/corrupt/transparent PNGs, when art loads, then fallback and alpha
  composition work; screenshot generation requires no window or audio device.
- Given an active run, when menus/settings are used, then no turns advance and
  changing next-run difficulty does not change current rules.
- Given an ending, when it is processed multiple times, then only one score is
  recorded; each difficulty retains its best ten entries in stable score order.
- Given saved preferences and scores, when loaded into a fresh profile, then
  they round-trip; corrupt JSON is nonfatal and invalid score records are rejected.
- Given a held or drifting stick, when frames advance, then no repeated turns
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
