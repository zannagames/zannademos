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
  single-cell movement, twelve cheese pieces per room, ten randomized rooms, and
  five lives shared across the Classic campaign.
- Real time: `Board.tick()` advances one 100 ms step, driven by the frame clock
  in `main.zia` and explicitly by probes. Menus, pause, help and dialogs never
  tick. The mouse moves only on `Board.step()`, one square per fresh key press;
  Space still spends a "wait" turn for the statistics only.
- Only the outer boundary is fixed. Every interior block is a pushable crate;
  initial crates are brown, cat-dropped crates are pale (tile value 3) and
  behave identically.
- Grace: `GRACE` (15) ticks at room start, after a respawn/resume and after a
  restart, during which no cat moves or hunts. Room generation guarantees no cat
  has a clear lane to the entrance; a respawned cat also gets a 15-tick hold.
- Sightlines: crates and walls occlude; cheese, the bonus and cats do not.
  Roaming cats always hunt (outside grace/hold). Sentries hunt only while
  `searching`, toggled on random timers (idle 20..50 ticks, searching 15..30).
- Catch walk: entering or being caught in a hunting cat's lane sets `CAUGHT`,
  locks movement, and walks the killer one square every `CHASE` (3) ticks until
  it is adjacent (or blocked by a cat/crate), then `lose()` fires and the killer
  returns to where it spotted the mouse.
- Roaming: stalkers step every 9 ticks on Classic (11 Cozy, 8 Fierce) to a random
  legal neighbour, avoiding an immediate reversal when another option exists.
  Prowlers are the same creature two ticks quicker: 7 Classic, 9 Cozy, 6 Fierce.
  `cadence()` derives the prowler from the stalker so the gap cannot drift. Every 14..24 steps a roamer drops a crate on the square it
  just vacated unless that square holds cheese, the bonus, the exit or the mouse,
  or the drop would leave any adjacent item or the mouse with no free neighbour.
- Boxed roamers (four solid sides): captured (+250) once twelve cheese are
  collected, otherwise they respawn to a random covered floor cell that has no
  clear lane to the mouse. A roamer with no legal move for three consecutive
  due moves also respawns. Sentries are never boxed, captured or required for
  the exit; `liveCats()` counts roamers only, and every room's exit requires
  twelve cheese plus zero surviving roamers (`mustClear` is now HUD-only).
- Campaign roster: `rooms.sentries(n)`, `rooms.roamers(n)` and `rooms.roamerKind(n)`
  state each room's cat mix in one place, and `rooms.load` spawns straight from
  them. Sentries first, so the tightest placements are taken while the board is
  emptiest. Rooms 2 and 4 (n = 1, 3) hold four sentries and no roamer, so their
  exit needs only the twelve cheese; rooms 7 and 10 hold four sentries plus one
  and two roamers. Roamers are stalkers below room 7 and prowlers from room 7 on,
  which is how "cats get quicker at level 7" is expressed: a kind change, not a
  per-level speed term.

  | Room | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | Sentries | 0 | 4 | 0 | 4 | 0 | 0 | 4 | 0 | 0 | 4 |
  | Roamers | 1 | 0 | 2 | 0 | 2 | 2 | 1 | 2 | 2 | 2 |

- Spawn placement takes a covered cell at least three squares (Manhattan) from
  every cat already placed. `rooms.spots()` relaxes that gap to two, then to
  zero, and `rooms.cat()` declines to place rather than index an empty list. The
  relaxations are insurance: over 4,000 generated rooms across every room and
  difficulty, the three-square rung always succeeded.
- Cheese scatters once per room and never moves. One star bonus per room hops to
  a random eligible cell every `interval` seconds (the old scatter table) until
  collected; it is worth `BONUS_POINTS` (300).
- The exit is hidden (`ex = ey = -1`) until `exitOpen()`; it is then placed on a
  random floor cell reachable from the mouse, preferring cells at least four
  steps away, and pushes may no longer cover it.
- Quick restart (Backspace / T / LB) costs one life and reloads the current room
  with its original seeded setup; on the last life it ends the run instead.
- Crates and enemy positions are randomized once per new level. The protected
  entrance and crate-count curve retain v1.1.4 balance; the cat mix is the
  roster below. Initial
  floor connectivity is checked as crates are placed. Restart replays the stored
  level seed; deaths preserve the current board and enemy positions.
- Seeded integer randomness makes a run reproducible. New campaigns get a fresh
  seed; tests and `--seed N` can choose a repeatable seed. VM and native traces
  over interleaved steps and ticks must match.
- After a death, Enter respawns the mouse on a random floor cell outside every
  cat lane with at least one free neighbour. Every enemy retains its position. Crates, collected cheese, the bonus and the turn counter persist.
  Cheese at the refuge is collected on arrival. No refuge ends the campaign.
- Held movement repeats: one immediate move, a 250 ms pause, then one move every
  100 ms while the key, D-pad or stick direction stays held (`controls.Repeater`).
  Repeat is only produced while the board is live, never in menus or dialogs.

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
  square is exposed; a diagonal is safe and a single crate (initial or dropped)
  stops it. During grace, or for an idle sentry, an exposed square is not lethal.
- Given a crate, when pushed toward cheese/bonus/wall/crate/cat/shown exit, then
  neither it nor the mouse moves and no turn is spent; a hidden exit never blocks.
- Given a roamer enclosed on four sides before twelve cheese, then it respawns
  covered, off the mouse's lanes, holding for GRACE ticks; after twelve cheese the
  final enclosing push captures it. Sentries and cat-only enclosures never count.
- Given the mouse enters a hunting lane, then the state becomes CAUGHT, movement
  is refused, the killer walks one square per CHASE ticks, death follows on
  arrival, and the killer returns to its spotting square.
- Given any room, when it is generated on any seed and difficulty, then it holds
  exactly `rooms.sentries(n)` sentries and `rooms.roamers(n)` roamers, every
  roamer is `rooms.roamerKind(n)`, and no two cats sit within three squares.
- Given a room with no roamer, then `mustClear` is false and the exit opens on the
  twelfth cheese alone; given any roamer, all of them must be boxed in first.
- Given any difficulty, then a prowler's cadence is exactly two ticks below a
  stalker's, so rooms 7 to 10 move quicker than rooms 1 to 6.
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
  the campaign. Restart costs a life, restores the original room placements.
- Given each generated room, when loaded, then boundaries, no interior walls, a
  covered entrance with grace, twelve pickups, one bonus, a hidden exit and
  compatible capture objectives validate, and nothing moves during grace.
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
