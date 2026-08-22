# Spring Arm Camera

<!-- tags: physics, camera, ui, component, shows-its-working, needs-mouse-capture -->

A third-person camera on a SpringArm3D that collides with the level, and eases back out when it clears.

## Purpose

[orbit-camera](../orbit-camera) computes where a camera should be and pulls it
in when you hand it a distance. This demo is the other half: `SpringArm3D` is
the node that *finds* that distance, by sweeping a shape backwards through the
level every physics frame.

What the node does not decide is how quickly the camera should move between the
length it wants and the length it can have. That is the difference between a
camera that feels solid and one that feels drunk, and it is asymmetric: pulling
in must be instant, pushing back out must not be. A camera that eases into a
wall spends the ease inside it, looking at backfaces; a camera that snaps back
out flicks the view every time you pass a lamp post.

## Controls

| Input | Action |
|-------|--------|
| Arrow keys | Move the target (camera-relative) |
| Hold right mouse | Orbit |

Walk backwards into the wall and watch the arm shorten, then walk away and watch
it extend at its own pace.

## How It Works

**The arm does the query.** `SpringArm3D` casts its `shape` — a sphere here —
along its local +Z each physics frame and reports how far it got with
`get_hit_length()`. A sphere rather than a ray because a ray finds the one place
the camera can see through: a raycast that clears a doorframe by a millimetre
still puts the camera's near plane inside the wall.

**`margin` is not optional.** The arm stops `margin` short of what it hit, so
the near plane has somewhere to be. Without it the camera rests exactly on the
surface and clips through.

**The pivot orbits, the arm hangs off it.** Yaw and pitch are applied to a
`Pivot` node; the arm and the camera are its children, so the arm's local +Z is
always "straight back from where we are looking" and the length stays a plain
number rather than a vector to reason about.

**Smoothing is the demo's own.** `ArmSmoothing.recover()` moves the current
length toward what the arm allows, at `in_rate` when shortening and `out_rate`
when extending. The driver passes `0.0` for `in_rate`, which means *be there
now*.

**The smoothing is frame-rate independent.** `lerp(current, target, 0.1)` covers
a tenth of the remaining distance **per frame**, so it behaves differently at
60fps and at 144fps — a bug that only shows up on someone else's machine. The
exponential form `1 - e^(-rate * delta)` covers the same fraction per *second*
at any frame rate, which is why the suite can assert that two half-steps land
exactly where one whole step does.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `SpringArm3D` | Sweeps a shape backwards and reports what stopped it |
| `SpringArm3D.get_hit_length()` | The length the level allows this frame |
| `SpringArm3D.shape` / `margin` | What is swept, and how far short of the hit to stop |
| `SpringArm3D.add_excluded_object()` | Keep the player's own body from blocking the camera |
| `Camera3D.position` | Where the driver puts the camera along the arm |
| `exp()` | Frame-rate-independent smoothing |

## Files

| File | What it holds |
|------|---------------|
| `scripts/arm_smoothing.gd` | The `ArmSmoothing` component: asymmetric, frame-rate-independent length recovery |
| `scripts/main.gd` | Demo driver: pivot, arm, camera, and target movement |
| `scenes/main.tscn` | Floor, two walls, the target, and the camera rig |
| `tests/test_logic.gd` | Headless test suite — including one that drives the real arm into a real wall |
| `tests/frames` | How many frames the suite needs, since it waits on physics |

## Use as a building block

**Copy:** `scripts/arm_smoothing.gd` — the `ArmSmoothing` type. `scripts/main.gd`
is the demo driver and is not needed; the arm itself is a stock Godot node.

**Public API**
- `ArmSmoothing.recover(current, target, in_rate, out_rate, delta) -> float`
- `ArmSmoothing.recover_clamped(current, target, in_rate, out_rate, delta, min_length, max_length) -> float`
- `ArmSmoothing.is_obstructed(current, wanted, tolerance := 0.05) -> bool`

**Integrate**
1. Put a `SpringArm3D` under whatever orbits, give it a shape and a margin, and
   set `spring_length` to the distance you want in the open.
2. Each physics frame, feed `get_hit_length()` into `recover_clamped()` and place
   the camera at that distance along the arm's +Z.
3. Call `arm.add_excluded_object(player.get_rid())` — otherwise the player's own
   collider is the first thing the sweep finds, and the camera lives in their
   head.

**Notes**
- `class_name ArmSmoothing` is global to the project — rename it if you already
  define that type.
- Keep the camera off the arm's child list if you are doing your own smoothing.
  `SpringArm3D` moves its direct children to the hit point itself, and the two
  will fight.
- `is_obstructed()` is what to key a mesh fade off: when the camera is held in
  close, the character usually needs to become transparent or the view is all
  shoulder.

## Related demos

- [orbit-camera](../orbit-camera) — A third-person camera that orbits a target, with pitch limits and camera-relative movement.
- [first-person-controller](../first-person-controller) — Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body.
- [cinematic-camera](../cinematic-camera) — A camera on a Path3D, and the blend between gameplay and cutscene that Godot does not do for you.
- [gamepad-3d](../gamepad-3d) — Analogue stick handling in 3D: a radial deadzone that does not jump, a response curve, and camera-relative movement.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

