# Continuous Collision

<!-- tags: physics, spatial-query, mesh, ui, component, shows-its-working -->

A fast projectile that goes straight through a wall, and the three ways to stop it.

## Purpose

Physics engines move a body by teleporting it: position plus velocity times
delta, then look for overlaps. A bullet at 220 m/s covers 3.7 metres in a 60Hz
step, so a 15-centimetre wall spends **no frame at all** with the bullet inside
it. There is nothing to detect. The bullet is in front of the wall, and then it
is behind it.

That is tunnelling, and it is not an engine bug — it is what discrete steps
cost. It matters because the speed at which it starts is far lower than anyone
expects: for that wall at 60Hz, anything faster than **9 metres per second**, or
roughly a jog.

This demo fires the same shot three ways at the same wall and counts which ones
get through.

## Controls

| Key | Action |
|-----|--------|
| Space | Fire one shot down each lane |
| 1 / 2 | Slower or faster |
| 3 | Toggle the physics rate between 60Hz and 240Hz |
| R | Clear and reset the counters |

## How It Works

**The number that decides it is distance per step against wall thickness.** Not
distance to the wall — a wall ten metres away is no harder to hit than one right
here. `Tunnelling.travel_per_step()` and `safe_speed()` are the whole prediction,
and the demo prints both before you fire.

**Lane 1: `continuous_cd`.** One boolean on `RigidBody3D` asks the engine to
sweep the shape along its motion rather than teleport it. Correct, and the most
expensive of the three — it is a shape cast per body per step, so it is for the
few bodies that need it rather than a project-wide default.

**Lane 2: a raycast along the step just taken.** The shot is not a physics body
at all: it moves by hand and casts from where it was to where it is going. Cheap,
exact for something the size of a bullet, and unaffected by speed — the ray is
as long as the step, whatever the step is. This is what most games ship.

**Cast from where it *was*.** A ray from the current position finds what is
still ahead, which is everything except the wall it has already passed. That
one-line mistake looks like the fix not working.

**Lane 3: nothing.** The control, and the one that goes through.

**The blunt fix is the physics rate.** `Engine.physics_ticks_per_second` fixes
everything and costs everything: it is paid by every body in the scene so that
one bullet behaves. `required_hz()` prints what it would take — 1467 steps a
second for the default shot, which settles the argument.

**The intermittent version is worse than the reliable one.** At about one step
inside the wall, whether the hit registers depends on where in the step the shot
happened to start. That is the bug that reproduces one time in five and gets
closed as unrepeatable; `steps_inside()` is what names it.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `RigidBody3D.continuous_cd` | Sweep the shape along its motion instead of teleporting it |
| `PhysicsRayQueryParameters3D.create()` | The from/to segment for the cheap fix |
| `PhysicsDirectSpaceState3D.intersect_ray()` | Asking what is on that segment |
| `Engine.physics_ticks_per_second` | The blunt fix, at a price everything pays |
| `Area3D.body_entered` | Counting what got through |

## Files

| File | What it holds |
|------|---------------|
| `scripts/tunnelling.gd` | The `Tunnelling` component: the arithmetic that predicts it |
| `scripts/swept_shot.gd` | The raycast projectile — the fix most games ship |
| `scripts/main.gd` | Demo driver: three lanes, one wall, and the counters |
| `scenes/main.tscn` | Ground, a thin wall, and the area that counts what got past it |
| `tests/test_logic.gd` | Headless test suite — including three real shots at the real wall |
| `tests/frames` | Frames the suite needs, since the shots have to actually fly |

## Use as a building block

**Copy:** `scripts/tunnelling.gd` for the arithmetic, `scripts/swept_shot.gd`
for the projectile. `scripts/main.gd` is the demo driver.

**Public API**
- `Tunnelling.travel_per_step(speed, hz) -> float`
- `Tunnelling.tunnels(speed, hz, thickness) -> bool`
- `Tunnelling.safe_speed(hz, thickness) -> float`
- `Tunnelling.required_hz(speed, thickness) -> float`
- `Tunnelling.steps_inside(speed, hz, thickness) -> float`
- `Tunnelling.sweep(from, to) -> Vector3`

**Integrate**
1. Work out `safe_speed()` for your thinnest wall once, and treat it as a
   project constant. Everything faster than it needs one of the three fixes,
   and the number is usually low enough to be surprising.
2. Prefer the raycast for projectiles. `continuous_cd` is for the handful of
   bodies that must be real physics — a rolling ball bearing, a falling crate —
   not for every bullet in the game.
3. Cast from the previous position, and store it yourself. `global_position` at
   the top of `_physics_process` is last step's, which is exactly what you want
   — but only if nothing else moved the node first.
4. Raise the physics rate last. It is a global cost for a local problem, and it
   only ever moves the threshold rather than removing it.

**Notes**
- `class_name Tunnelling` is global to the project — rename it if you already
  define that type.
- A ray is a point, not a shape. A projectile with real width needs
  `ShapeCast3D` or `intersect_shape()`, which costs more and behaves the same
  way — see [shape-cast-3d](../shape-cast-3d).
- `continuous_cd` does not help a body that is *teleported*. Setting
  `global_position` directly skips the sweep, because there was no motion to
  sweep along.
- This is the same failure as a fast `CharacterBody3D` passing through a floor,
  and the same fixes apply. `move_and_slide()` sweeps, which is why it is rarer
  there.

## Related demos

- [audio-buses](../audio-buses) — Audio buses built at runtime: sliders that are decibels, a mute that is not a volume, and a reverb you walk into.
- [vehicle-3d](../vehicle-3d) — A VehicleBody3D that drives, the arithmetic that keeps it drivable, and the sign that catches everyone.
- [raycast-picking](../raycast-picking) — Turning a mouse position into a world ray, and asking the physics space what it hit.
- [area-trigger-3d](../area-trigger-3d) — Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

