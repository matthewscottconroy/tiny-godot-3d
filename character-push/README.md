# Character Push

<!-- tags: physics, ui, component, shows-its-working -->

A CharacterBody3D that pushes crates — because `move_and_slide()` slides past them and does nothing else.

## Purpose

`move_and_slide()` does not push anything. A `CharacterBody3D` walking into a
crate stops, slides along it, and leaves it exactly where it was. That is
correct: a character body is kinematic, and the solver has no idea what it
weighs or how hard it meant to walk.

Making it push is a loop over the slide collisions with an impulse applied to
whatever was hit. The loop is four lines. The impulse is where the work is, and
there are four ways to get it wrong that all present as *physics* being broken:

- Pushing when you were not pushing — a collision is any contact, including
  standing next to something.
- Pushing the floor, which launches the character.
- Ignoring mass, so a barrel and a boulder shove identically.
- Pushing every frame of a contact, which accelerates the crate into orbit.

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | Walk |
| P | Pushing on or off — off is what `move_and_slide()` does by itself |
| R | Put the crates back |

The three crates weigh 4, 20 and 120 units. The light one skids, the heavy one
barely shifts.

## How It Works

**Use the velocity you *wanted*.** `move_and_slide()` overwrites `velocity` with
what actually happened — blocked head-on by a crate, that is zero. Compute the
push from the velocity you set *before* calling it, or the shove only ever works
at an angle. This demo's own test caught exactly that: the crate did not move,
and nothing was obviously wrong.

**Only the component into the surface counts.** `velocity · normal` — walking
along a wall collides every frame and must move nothing. Standing still likewise.

**The floor is a collision too.** Anything flat enough to stand on is excluded by
slope, with the same threshold `CharacterBody3D.floor_max_angle` uses. Push the
floor and the character launches itself.

**The impulse is momentum, not a magic number.** The crate should end up moving
at a share of the speed the character walked into it, and the impulse that
achieves that is `mass × speed`. The share comes from the two masses. So a
heavier crate takes a *bigger* impulse and ends up moving *slower* — which is
the pair of facts that makes mass feel real.

**Sustained contact does not accelerate.** A contact lasts many frames, and an
impulse applied on every one of them puts the crate in the air. Passing the
body's current velocity in and asking only for the *difference* turns a
multi-frame shove into a steady push, and a crate already running ahead of the
character is never dragged along.

**Impulses are applied at the contact point.** `apply_impulse()` takes an offset;
passing the contact makes the crate turn as it slides, which is most of what
separates a shove from a conveyor belt. The offset is clamped, because a long
lever arm spins a crate like a top.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `CharacterBody3D.get_slide_collision_count()` / `get_slide_collision()` | Everything the last move ran into |
| `KinematicCollision3D.get_normal()` / `get_position()` / `get_collider()` | What was hit, where, and which way it faces |
| `RigidBody3D.apply_impulse(impulse, offset)` | The shove, at a point rather than at the centre |
| `RigidBody3D.mass` / `linear_velocity` | The two numbers the impulse is computed from |
| `CharacterBody3D.velocity` | Set before the move, overwritten by it |

## Files

| File | What it holds |
|------|---------------|
| `scripts/push_force.gd` | The `PushForce` component: what to push, how hard, and where |
| `scripts/main.gd` | Demo driver: walking, and the loop over slide collisions |
| `scenes/main.tscn` | A floor, three crates of different mass, and the character |
| `tests/test_logic.gd` | Headless test suite — including a real character shoving a real crate |
| `tests/frames` | How many frames the suite needs, since it waits on physics |

## Use as a building block

**Copy:** `scripts/push_force.gd` — the `PushForce` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `PushForce.should_push(normal, velocity, max_slope := 45.0) -> bool`
- `PushForce.impulse_for(normal, velocity, character_mass, body_mass, body_velocity, strength, max_slope) -> Vector3`
- `PushForce.flat_impulse_for(…) -> Vector3` — the same, with the vertical part removed
- `PushForce.offset_of(contact_point, body_origin, max_offset := 1.0) -> Vector3`

**Integrate**
1. Capture `velocity` before `move_and_slide()` and pass that in. This is the
   whole difference between a push that works and one that does not.
2. Use `flat_impulse_for()` unless you want crates lifted. Wall normals on
   anything sloped have a small vertical component, and it accumulates.
3. Pass the body's `linear_velocity`. Without it, a sustained contact is an
   accelerating one.

**Notes**
- `class_name PushForce` is global to the project — rename it if you already
  define that type.
- The character is not pushed *back*. Real mutual interaction means also
  subtracting momentum from the character, which for a kinematic body means
  editing the velocity you were about to use — worth doing for heavy objects,
  and a good way to make a light character feel light.
- A character standing on a `RigidBody3D` is a different problem again: it wants
  `AnimatableBody3D` under it, or a platform that carries the character
  explicitly.

## Related demos

- [shape-cast-3d](../shape-cast-3d) — Sweeping a shape ahead of a character with ShapeCast3D to tell a step it can climb from a wall it cannot.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.
- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.
- [first-person-controller](../first-person-controller) — Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

