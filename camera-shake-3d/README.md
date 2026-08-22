# Camera Shake

<!-- tags: ui, procedural, component, shows-its-working -->

Camera shake as an offset a rig can carry, with trauma that decays and noise that is the same every run.

## Purpose

In 2D, shake is usually written straight into the camera's offset, and that
works because a 2D camera's transform belongs to the camera script.

In 3D it almost never does. The transform belongs to an orbit rig, a spring arm,
a cutscene track, a vehicle mount — something that rewrites it every frame.
Shake that writes the camera's transform fights all of them, and the symptom is
a camera that snaps back to a stale position the instant anything else moves it.

So this produces an **offset** and nothing else, and the demo shows where to put
it: a child node nothing else touches.

## Controls

| Key | Action |
|-----|--------|
| 1 | Footstep (0.2 trauma) |
| 2 | Hit (0.5) |
| 3 | Explosion (1.0) |
| R | Continuous rumble |
| Space | Pause the orbit |

Hold the rumble on and the trauma climbs to its ceiling and stays there rather
than compounding.

## How It Works

**Trauma, not amplitude.** Callers add trauma; the shake is `trauma²`. That one
curve makes a footstep nearly invisible and an explosion violent without anyone
tuning two separate numbers, and it means callers only ever pass "how bad was
that", which is a thing they know.

**Trauma decays, so a shake always ends.** Linearly, at `decay` per second.
Nothing has to remember to stop it, and a system that forgets to add more simply
returns to still.

**Repeated hits accumulate to a ceiling.** Trauma is clamped to 1. Without that,
a firefight multiplies into something unwatchable — which is why the continuous
rumble in the demo *tops up* rather than sets.

**The noise is seeded.** `FastNoiseLite` with a fixed seed, sampled on separate
rows for each axis. `randf()` would make replays, networked play and this
demo's own test suite impossible — and "the camera shakes differently every
time" is not a feature anyone asked for.

**Rotation matters more than translation.** A rolling, pitching camera reads as
impact far better than a sliding one, and unlike translation it cannot push the
near plane through a wall. Both are provided; the roll is the one to lean on.

**The offset goes on a child node.** `Pivot → Mount → Shaker → Camera3D`. The
rig writes `Mount`, the shake writes `Shaker`, and nothing writes both. That
separation is the whole design: two systems that both want to move the camera
need two nodes, not one property and a merge rule.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `FastNoiseLite.get_noise_2d()` | Smooth, seeded, uncorrelated shake channels |
| `FastNoiseLite.seed` | A shake that is the same in a replay as it was live |
| `Node3D.position` / `rotation` | The offset, applied to a node of its own |
| `Node3D.look_at()` | The rig aiming the mount — the transform the shake must not touch |
| `clampf()` | The trauma ceiling |

## Files

| File | What it holds |
|------|---------------|
| `scripts/shake.gd` | The `Shake` component: trauma, decay, and the noise offsets |
| `scripts/main.gd` | Demo driver: an orbit rig that owns the transform, and a shaker that does not |
| `scenes/main.tscn` | Ground, towers to judge the motion against, and the four-node camera rig |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/shake.gd` — the `Shake` type. `scripts/main.gd` is the demo
driver and is not needed.

**Public API**
- `Shake.new(seed_value := 1)`, `add(amount)`, `advance(delta)`, `reset()`
- `offset() -> Vector3`, `rotation_offset() -> Vector3`
- `trauma() -> float`, `shake_amount() -> float`, `is_shaking() -> bool`
- `decay`, `max_offset`, `max_roll`, `frequency`

**Integrate**
1. Put a node between whatever positions the camera and the camera itself, and
   write only that node from the shake. Never merge the two into one transform.
2. Call `add()` from wherever the impact happens — a hit, a landing, a
   detonation — and pass the same 0..1 scale everywhere so the curve stays
   meaningful.
3. Scale `max_offset` down for a first-person camera. What reads as a knock from
   six metres back is nausea from behind the eyes.

**Notes**
- `class_name Shake` is global to the project — rename it if you already define
  that type.
- One `Shake` per camera, not per source. Sources add trauma; the camera owns
  the shaking.
- If the camera can end up inside geometry, drop `max_offset` to zero and shake
  with rotation alone. A rotation cannot move the near plane through a wall.

## Related demos

- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [cinematic-camera](../cinematic-camera) — A camera on a Path3D, and the blend between gameplay and cutscene that Godot does not do for you.
- [accessibility-3d](../accessibility-3d) — Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.
- [noise-terrain](../noise-terrain) — A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

