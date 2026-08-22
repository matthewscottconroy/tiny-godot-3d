# Cinematic Camera

<!-- tags: camera, ui, component, shows-its-working -->

A camera on a Path3D, and the blend between gameplay and cutscene that Godot does not do for you.

## Purpose

Moving a camera along a path is the easy half: a `Path3D`, a `PathFollow3D`, and
one property. The half nobody mentions is getting *into* it. `make_current()` is
an instant cut, and cutting from the player's own camera to a cutscene one reads
as a bug rather than as direction.

The fix is a third camera that interpolates between the two transforms, plus a
weight curve to drive it. Both halves are small, and both are usually written
badly: a linear blend lurches at each end, and lerping position and Euler angles
separately takes the long way round through any large rotation — which looks
like the camera has been thrown across the level.

## Controls

| Key | Action |
|-----|--------|
| Space | Start or end the cutscene |
| T | Aim at the subject, or along the track |
| 1 / 2 | Slower or faster traverse |
| L | Loop the track, or stop at the end |

## How It Works

**Three cameras, three states.** The gameplay rig runs the whole time and never
knows a cutscene is happening. The cinematic camera rides the path. A third,
otherwise idle camera is made current only *while blending*, and is given the
interpolated transform. At weight 0 and weight 1 the real cameras take over
again, so there is nothing to drift.

**`Transform3D.interpolate_with()`, not two lerps.** It interpolates the basis
as a rotation, so a blend across a 170° turn takes the 85° short way rather than
unwinding through 275°. The suite asserts exactly that, because the wrong
version looks fine for small turns and catastrophic for large ones.

**Smoothstep, not linear.** `t² (3 − 2t)`: the first tenth of the blend covers
much less than a tenth of the distance, so the camera leaves and arrives gently.
One line, and the entire difference between a camera move and a camera lurch.

**Progress is a ratio.** `PathFollow3D.progress_ratio` is 0..1 along the baked
curve, so the track keeps its progress in the same units — no conversion, and
looping is `fposmod`.

**The curve is built in code.** `Curve3D.add_point()` with in and out handles;
without handles a `Curve3D` is a polyline and the camera turns in visible steps.

**Aiming ahead of yourself.** A dolly that looks exactly where it is going has
nothing to aim at. `look_ahead()` samples a point further along the track, which
is what makes a fly-through feel intentional rather than drifting. Press `T` to
compare that with aiming at the subject, which is what a cutscene about someone
usually wants.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Path3D` / `Curve3D.add_point()` | The track, with handles that round the corners |
| `PathFollow3D.progress_ratio` | Where along it, as 0..1 |
| `Curve3D.sample_baked()` | A point further along, for the camera to aim at |
| `Camera3D.current` | Which camera the viewport uses |
| `Transform3D.interpolate_with()` | Blending two camera transforms correctly |
| `Node3D.look_at_from_position()` | Placing and aiming in one call |

## Files

| File | What it holds |
|------|---------------|
| `scripts/camera_track.gd` | The `CameraTrack` component: progress, blend weight, easing, transform blending |
| `scripts/main.gd` | Demo driver: the curve, the three cameras, and the state machine between them |
| `scenes/main.tscn` | Ground, pillars, a subject, and the camera rigs |
| `tests/test_logic.gd` | Headless test suite — including the real curve and follower |

## Use as a building block

**Copy:** `scripts/camera_track.gd` — the `CameraTrack` type. `scripts/main.gd`
is the demo driver and is not needed.

**Public API**
- `advance(delta) -> float`, `progress() -> float`
- `set_cinematic(active)`, `advance_blend(delta) -> float`, `blend() -> float`
- `is_cinematic() -> bool`, `is_blending() -> bool`, `reset()`
- `CameraTrack.eased(weight) -> float`
- `CameraTrack.blended(from, to, weight) -> Transform3D`
- `CameraTrack.look_ahead(progress, amount, loops) -> float`
- `blend_duration`, `duration`, `looping`

**Integrate**
1. Keep one spare `Camera3D` for blending and make it current only while
   `is_blending()`. Handing a real camera an interpolated transform means
   fighting whatever owns it.
2. Blend *transforms*, not properties. If the two cameras have different fields
   of view, lerp `fov` alongside — with the same eased weight, or the two
   diverge visibly.
3. Do not stop the gameplay rig during a cutscene. It has to be somewhere sane
   to blend back to, and freezing it is how a cutscene ends with the camera in
   the floor.

**Notes**
- `class_name CameraTrack` is global to the project — rename it if you already
  define that type.
- `PathFollow3D` can orient the camera for you via `rotation_mode`, which is
  right for a rollercoaster and wrong for a dolly aimed at an actor. This demo
  sets it to none and aims the camera itself.
- For shake on top of a cinematic camera, add it on a child node —
  see [camera-shake-3d](../camera-shake-3d). The same rule applies: one node,
  one owner.

## Related demos

- [spring-arm-camera](../spring-arm-camera) — A third-person camera on a SpringArm3D that collides with the level, and eases back out when it clears.
- [camera-shake-3d](../camera-shake-3d) — Camera shake as an offset a rig can carry, with trauma that decays and noise that is the same every run.
- [animation-tree](../animation-tree) — An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching.
- [area-trigger-3d](../area-trigger-3d) — Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

