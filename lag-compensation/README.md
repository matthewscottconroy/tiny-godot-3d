# Lag Compensation

<!-- tags: ui, component, shows-its-working -->

The server rewinding the world to where a shooter actually saw it, so a hit does not depend on their ping.

## Purpose

[client-prediction](../client-prediction) makes your own character feel
immediate by moving before the server answers. This is the problem that creates
for everybody else.

By the time "I fired at that spot" reaches the server, some tens of
milliseconds have passed and the target has moved on. Judge the shot against
where the target is *now* and the shooter missed — despite having put their
crosshair squarely on what their screen was showing. The game then teaches
players to lead their shots by their own ping, which is both unlearnable and
different on every connection, and it punishes the players with the worst
connections hardest.

Lag compensation makes the server wind the world back to the moment the shooter
was looking at, and ask the question there.

The cost is real and worth stating plainly, because it is the thing players
complain about: the target can be shot *after* they reached cover, because on
the shooter's screen they had not reached it yet. "I was already behind the
wall" is this mechanism working exactly as designed. Every shooter that has it
has made that trade knowingly — a small unfairness to the person being shot, in
exchange for a large one removed from the person shooting.

## Controls

| Key | Action |
|-----|--------|
| Space | Fire at what the shooter can see |
| 1 / 2 | Simulated ping |
| C | Compensation on or off |
| R | Reset |

The red box is where the target really is. The translucent blue one is where
the shooter's screen is showing it. Turn compensation off, raise the ping, and
fire: the shot goes exactly where you aimed and misses anyway.

## How It Works

**The shooter is always looking at the past.** Two delays, and both count. Half
the round trip is how long the shot took to reach the server. The interpolation
delay is the client's own: it renders other players slightly behind the updates
it has received, so their movement is smooth rather than a series of jumps.
What the screen *drew* was already older than what the client had.

Forgetting the second one is the subtle version of this bug. Shots land
consistently a little behind a moving target, and it looks like the hitboxes are
wrong rather than like the clock is.

**The server keeps a short history.** One sample per tick, holding where
everything was. Not forever — a server keeping every position of every player
since the match started runs out of memory long before anyone notices the shots
are fair — so the window is bounded, and it bounds the unfairness too. Rewinding
two seconds to please one player punishes everyone else.

**Rewinding interpolates, and never extrapolates.** At a plausible twenty
updates a second, the nearest sample can be 25ms out, which at running speed is
most of a body width — snapping to it hands back the error the rewind just
removed. Past the ends of the history it clamps instead of extending the motion,
because extrapolating invents a position nobody ever saw, which is the one thing
this whole mechanism exists to avoid.

**Time may not run backwards.** A history recorded out of order cannot be
interpolated, and the bug arrives as shots landing somewhere between two
unrelated moments. A sample older than the newest one is refused.

**Only the position handed to the hit test changes.** The geometry is an
ordinary point-to-ray distance and is the same either way. That is worth seeing:
lag compensation is not a different collision system, it is the same question
asked about a different moment.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Vector3.lerp()` | Interpolating between the two samples either side of the rewound moment |
| `Vector3.dot()` | Distance from the shot line, and whether the target is in front at all |
| `Array.remove_at()` | Dropping samples that have fallen out of the window |
| `Dictionary.duplicate()` | Storing a copy per sample, so the history is not aliased to the caller |

## Files

| File | What it holds |
|------|---------------|
| `scripts/lag_compensation.gd` | The `Rewind` component: the history, the rewind, and the hit test |
| `scripts/main.gd` | Demo driver: the moving target, the simulated ping, and the two answers |
| `scenes/main.tscn` | Camera, light, the live and seen markers, and the shot |
| `tests/test_logic.gd` | Headless test suite — including the claim that rewinding turns the miss into a hit |
| `tests/frames` | How many frames the suite needs, since it watches a real history fill |

## Use as a building block

**Copy:** `scripts/lag_compensation.gd` — the `Rewind` type. `scripts/main.gd`
is the demo driver and is not needed.

**Public API**
- `Rewind.seen_at(now, round_trip, interpolation_delay := 0.1) -> float`
- `rewind.record(time, positions)` — a `Dictionary` of id → `Vector3`
- `rewind.state_at(time) -> Dictionary` — interpolated, clamped to the history
- `rewind.beyond_history(time) -> bool`
- `rewind.oldest()`, `newest()`, `samples()`, `reset()`
- `Rewind.hits(origin, direction, target, radius := 0.5) -> bool`
- `rewind.history_seconds` — how far back to keep

**Integrate**
1. Record on the server, once per tick, not once per frame. Ticks are what the
   clients are told about, so they are the moments worth being able to return
   to.
2. Measure the round trip rather than trusting a number the client sends. A
   client that reports 900ms of lag it does not have is asking to shoot at where
   you were a second ago.
3. Cap `history_seconds` at something you are willing to be shot from — a few
   hundred milliseconds is the usual choice, not the full second used here for
   legibility.
4. Rewind everything the shot could touch, not just players. A crate that has
   since been destroyed still blocked the shot at the moment it was taken.

**Notes**
- `class_name Rewind` is global to the project — rename it if you already define
  that type.
- The history stores positions only, which is enough for this demo. Real hit
  detection rewinds collision shapes, and rotation matters as much as position
  once a target is anything but a sphere.
- This deliberately has no network in it. The arithmetic is the lesson and a
  real socket only makes the numbers harder to read — see
  [multiplayer-3d](../multiplayer-3d) for a real one, and
  [client-prediction](../client-prediction) for the half this pairs with.

## Related demos

- [accessibility-3d](../accessibility-3d) — Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.
- [animation-in-code](../animation-in-code) — Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk.
- [animation-tree](../animation-tree) — An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching.
- [area-trigger-3d](../area-trigger-3d) — Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

