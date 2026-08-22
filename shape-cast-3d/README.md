# Shape Cast

<!-- tags: physics, spatial-query, ui, component, shows-its-working -->

Sweeping a shape ahead of a character with ShapeCast3D to tell a step it can climb from a wall it cannot.

## Purpose

`move_and_slide()` slides a character along whatever it hits. That is right for
walls and wrong for a 10cm kerb: the character stops dead at a lip it should
have walked over, and the bug report always says "the collision is broken".

Telling the two apart needs two questions, and the interesting part is that they
need two different casts. A forward sweep can tell you *that* something is in
the way — it cannot tell you how tall it is, because the contact point can be
anywhere on the obstruction's face. The height comes from a second cast,
straight down from above it.

Why a shape rather than a ray: a ray finds the one gap it happens to point
through. A character is a capsule, and the question is whether *the capsule*
fits — a doorframe cleared by a millimetre in the middle is not cleared at the
shoulders.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Lower or raise the step limit |
| Space | Turn round |

The steps get taller: 0.2 m, 0.6 m, 1.6 m. Raise the limit and the character
climbs one more of them; lower it and it turns back at the first.

## How It Works

**Two casts, two questions.** A `ShapeCast3D` sweeps a small sphere forward at
shin height and answers "is something there". A `RayCast3D` then casts down from
above that point and answers "how high is its top, and could I stand on it".
`StepProbe.can_step_onto()` is the second question written down.

**The forward probe is deliberately off the ground.** Its sphere sits a few
centimetres above the feet, so it never hits the floor the character is standing
on — which would otherwise report an obstruction on every single frame. That
offset also sets the smallest lip worth noticing; anything shorter is left to
the physics engine's own snapping.

**Walkability is a dot product.** `normal · UP` is the cosine of the slope, so
the comparison is against `cos(max_angle)` — no `acos()`, and no `NAN` to guard.
Keep the limit equal to `CharacterBody3D.floor_max_angle` or the character
disagrees with itself about what it is standing on.

**A hit with no normal is a wall.** A zero normal means the query told you
nothing. Treating "no information" as walkable is how a character ends up
walking up the inside of the level.

**A surface below the feet is a drop, not a step.** `can_step_onto()` requires a
positive rise; without that check, stepping "up" onto something lower teleports
the character down through the floor it is on.

**Stepping up is a lift *and* a nudge.** `step_target()` raises the character to
the step's top plus a little clearance and moves it forward past the lip. A lift
alone leaves the capsule intersecting the step's face, and the next frame pushes
it straight back off — which reads as the step rejecting you.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `ShapeCast3D.shape` / `target_position` | What is swept, and how far |
| `ShapeCast3D.force_shapecast_update()` | Re-running the sweep after moving it, in the same frame |
| `ShapeCast3D.get_collision_normal()` / `get_collision_point()` | What was hit, and where |
| `RayCast3D.force_raycast_update()` | The downward probe that finds the top |
| `CharacterBody3D.move_and_slide()` | The movement this sits on top of |
| `Vector3.dot()` | Slope as a cosine, with no inverse trigonometry |

## Files

| File | What it holds |
|------|---------------|
| `scripts/step_probe.gd` | The `StepProbe` component: classification, walkability, and the step-up target |
| `scripts/main.gd` | Demo driver: the two probes and the walking |
| `scenes/main.tscn` | A floor, three steps of increasing height, and the character |
| `tests/test_logic.gd` | Headless test suite — including a real walk into the real steps |
| `tests/frames` | How many frames the suite needs, since it waits on physics |

## Use as a building block

**Copy:** `scripts/step_probe.gd` — the `StepProbe` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `StepProbe.classify(normal, hit_y, feet_y, max_step, max_slope := 45.0) -> Surface`
- `StepProbe.can_step_onto(normal, top_y, feet_y, max_step, max_slope := 45.0) -> bool`
- `StepProbe.is_walkable(normal, max_slope := 45.0) -> bool`
- `StepProbe.slope_degrees(normal) -> float`
- `StepProbe.step_target(position, step_top_y, forward, clearance := 0.02, nudge := 0.05) -> Vector3`
- `StepProbe.rise_of(hit_y, feet_y) -> float`, `StepProbe.name_of(surface) -> String`

**Integrate**
1. Run both probes in `_physics_process`, and call the `force_*_update()`
   methods after moving them — otherwise the answer describes where the probe
   was last frame.
2. Keep the step limit and `floor_max_angle` in one place. Two numbers that
   should agree, in two files, will not.
3. Smooth the lift if it is visible. Teleporting the capsule is correct and
   instant; lerping the *visual* mesh toward the body over a few frames is what
   makes it look like a step rather than a jump.

**Notes**
- `class_name StepProbe` is global to the project — rename it if you already
  define that type.
- A `ShapeCast3D` reports every overlap it finds, sorted by distance. This demo
  reads the first; a character that must ignore its own body or triggers should
  use `add_exception()` or a collision mask instead of filtering afterwards.
- Sweeping is not free. One small sphere per character per frame is nothing;
  one per limb of a crowd is not, and that is the point at which the answer
  becomes a cheaper approximation rather than a better cast.

## Related demos

- [character-push](../character-push) — A CharacterBody3D that pushes crates — because move_and_slide() slides past them and does nothing else.
- [gamepad-3d](../gamepad-3d) — Analogue stick handling in 3D: a radial deadzone that does not jump, a response curve, and camera-relative movement.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.
- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

