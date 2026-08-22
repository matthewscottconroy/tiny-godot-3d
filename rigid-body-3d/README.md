# Rigid Body 3D

<!-- tags: physics, mesh, ui, component, shows-its-working, good-first-demo -->

RigidBody3D boxes that fall, stack, and scatter — impulses versus setting a transform.

## Purpose

The first thing to learn about `RigidBody3D` is that you do not move it. The
solver owns its transform between frames; anything you write there is a
teleport, and a teleport discards the body's momentum and skips whatever it
should have collided with on the way. Half the "physics is broken" questions
about Godot are a body being driven by `position` in `_process`.

The second thing is that a blast that looks right and a blast that is right are
different problems. The falloff curve decides whether a stack tumbles or gets
flung out of the level, and it is arithmetic you own — so it belongs somewhere
you can put a number on it, not inline in the driver.

## Controls

| Key | Action |
|-----|--------|
| Space | Detonate at the origin — an impulse per body, with distance falloff |
| T | Teleport every box up two metres by writing `position` |
| R | Rebuild the stack |

## How It Works

**The stack is arithmetic, the falling is not.** `DropStack.pyramid()` returns
the positions of a pyramid `rows` deep: each row has one box fewer than the row
below, sits one spacing higher, and is centred on `x = 0` by starting half a
span to the left. Getting that centring wrong makes a stack that leans, which
looks like a physics bug and is not one. The driver spawns a `RigidBody3D` at
each position and then leaves it alone.

**Every body needs both a mesh and a shape.** `MeshInstance3D` is what you see,
`CollisionShape3D` is what the solver sees, and nothing makes them agree. A body
with no `CollisionShape3D` falls through the floor forever, silently.

**Impulses go through the solver.** `apply_central_impulse()` adds to the body's
momentum, so the engine integrates the result: bodies push each other, tumble,
and come to rest. `DropStack.impulse_at()` supplies the vector — full strength
at the centre, linearly down to nothing at `radius`, and straight up for a body
sitting exactly on the blast, because a zero offset has no direction to
normalise. Linear falloff rather than inverse-square is a deliberate choice:
inverse-square is more physical and nearly impossible to tune, being either
imperceptible or catastrophic.

**Lift is what makes it tumble.** A purely radial impulse slides a stack
sideways. `impulse_with_lift()` adds a fraction of the impulse's own magnitude
upward, so boxes leave the ground and rotate.

**Teleporting is shown, not hidden.** Pressing `T` writes `position` directly.
The boxes appear two metres higher with the velocity they already had, having
passed through anything in between. It is the same operation people reach for to
"move" a rigid body, and seeing it next to the impulse is the point.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `RigidBody3D` | A body the physics engine owns and integrates |
| `RigidBody3D.apply_central_impulse()` | Change momentum without a torque |
| `RigidBody3D.linear_velocity` | Read how fast a body is actually moving |
| `CollisionShape3D` / `BoxShape3D` | What the solver collides with, as opposed to what is drawn |
| `StaticBody3D` | An immovable collider — the floor |
| `MeshInstance3D` / `BoxMesh` | The visible half of each body |

## Files

| File | What it holds |
|------|---------------|
| `scripts/drop_stack.gd` | The `DropStack` component: stack layout and blast falloff |
| `scripts/main.gd` | Demo driver: spawns the bodies, applies impulses, shows the readout |
| `scenes/main.tscn` | Camera, light, floor, and the HUD |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/drop_stack.gd` — the `DropStack` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `DropStack.pyramid(rows: int, spacing: float, base_y: float) -> Array[Vector3]`
- `DropStack.impulse_at(centre, position, strength, radius) -> Vector3`
- `DropStack.impulse_with_lift(centre, position, strength, radius, lift) -> Vector3`

**Integrate**
1. Spawn your bodies at `pyramid()`'s positions, or ignore it and keep only the
   blast maths — the two halves are independent.
2. On detonation, loop your bodies and pass each one's position to
   `impulse_at()`; skip the ones that come back `Vector3.ZERO` rather than
   applying a zero impulse to everything in the level.
3. For anything heavier than a box, scale the strength by mass yourself:
   `apply_central_impulse()` is a momentum change, so an identical impulse moves
   a heavy body less.

**Notes**
- `class_name DropStack` is global to the project — rename it if you already
  define that type.
- The falloff is linear on purpose. If you swap it for inverse-square, clamp the
  near distance or a body at the centre takes an infinite impulse.
- Real destruction usually wants `apply_impulse()` with an offset rather than
  `apply_central_impulse()`, so the blast imparts spin as well. This demo keeps
  the central version so the numbers stay readable.

## Related demos

- [raycast-picking](../raycast-picking) — Turning a mouse position into a world ray, and asking the physics space what it hit.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.
- [continuous-collision](../continuous-collision) — A fast projectile that goes straight through a wall, and the three ways to stop it.
- [terrain-collision](../terrain-collision) — A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

