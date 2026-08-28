# Joints

<!-- tags: physics, mesh, ui, component, shows-its-working -->

A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.

## Purpose

A door can be an animation. A door on a hinge joint is a door: it swings when
you walk into it, stops when something is in the way, and knocks over whatever is
behind it — all for free, because the solver is doing it.

The catch is what a `HingeJoint3D` actually offers. Limits, which the solver
enforces, and a motor, which applies torque toward a target **velocity**. There
is no target *angle*, and almost every door, hatch and drawbridge wants one.
Writing the loop that turns an angle into a velocity is where the trouble is:

- **Buzzing.** Drive at full speed until the angle matches exactly and the motor
  overshoots, reverses, overshoots again. The door vibrates against its own
  motor forever, and it looks like a door.
- **The long way round.** Angles wrap. A hinge at 179° told to reach −179° should
  move two degrees, not three hundred and fifty-eight.
- **Fighting the limits.** A motor still driving into a limit the solver is
  holding is two systems pushing at each other for as long as the game runs.

## Controls

| Key | Action |
|-----|--------|
| 1 | Close the door |
| 2 | Open it |
| 3 | Halfway |
| Space | Shove it — an impulse, which the motor then has to argue with |

## How It Works

**The joint holds two bodies, not one.** `node_a` and `node_b` are `NodePath`s to
the frame and the door. A joint whose paths do not resolve constrains nothing at
all and says nothing about it — which is the single most common reason a joint
"does not work".

**A hinge takes away five degrees of freedom.** The door keeps one: rotation
about the hinge axis. It cannot fall over, drift out of its frame or spin, and
the test asserts exactly that after forty physics frames.

**The limits live in one place.** The joint's limits and `HingeControl`'s are set
from the same numbers, in `_ready()`. Two places that must agree is one place too
many — and when they disagree, the motor spends the game pushing against a limit
the solver is holding.

**The motor is driven from an angle the controller works out.**
`drive_toward()` takes the current angle and the wanted one, takes the short way
round, eases down within `approach` radians, and returns exactly zero inside
`tolerance`. That last number is what stops the buzz.

**A pin joint is a point, not an orientation.** The chain is six rigid bodies,
each pinned to the one above. That is precisely what a chain link is — a shared
point, free rotation — and it is why a chain built out of hinges swings like a
ladder instead.

**Joints are built after the bodies are in the tree.** The chain is assembled in
code: body, `add_child`, joint, `add_child`, *then* `node_a` and `node_b`.
Setting the paths first gives you a joint that resolves nothing.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `HingeJoint3D.node_a` / `node_b` | The two bodies the joint holds together |
| `HingeJoint3D.set_flag()` (`FLAG_USE_LIMIT`, `FLAG_ENABLE_MOTOR`) | Turning the limits and motor on |
| `HingeJoint3D.set_param()` (`PARAM_LIMIT_*`, `PARAM_MOTOR_*`) | The angles, the target velocity, the torque budget |
| `PinJoint3D` | A shared point with free rotation — a chain link |
| `RigidBody3D.apply_impulse()` | Shoving the door, so the motor has something to argue with |
| `wrapf()` | Angles that wrap, and the short way round |

## Files

| File | What it holds |
|------|---------------|
| `scripts/hinge_control.gd` | The `HingeControl` component: angle to motor velocity, limits, openness |
| `scripts/main.gd` | Demo driver: the door's joint setup and the chain it builds |
| `scenes/main.tscn` | Ground, a frame, a door, the hinge, and the chain's anchor |
| `tests/test_logic.gd` | Headless test suite — including the real joints holding real bodies |
| `tests/frames` | How many frames the suite needs, since it waits on physics |

## Use as a building block

**Copy:** `scripts/hinge_control.gd` — the `HingeControl` type. `scripts/main.gd`
is the demo driver, though its chain builder is worth stealing on its own.

**Public API**
- `HingeControl.normalise_angle(angle) -> float`
- `HingeControl.shortest_delta(from, to) -> float`
- `clamp_angle(angle) -> float`, `drive_toward(current, target) -> float`
- `is_open(current, threshold := 0.6) -> bool`, `openness(current) -> float`
- `at_limit(current, epsilon := 0.02) -> bool`
- `min_angle`, `max_angle`, `speed`, `tolerance`, `approach`

**Integrate**
1. Set the joint's limits from the controller's properties, not the other way
   round and not twice.
2. Read the current angle from the moving body's rotation about the hinge axis,
   and feed `drive_toward()`'s result straight into
   `PARAM_MOTOR_TARGET_VELOCITY`.
3. `PARAM_MOTOR_MAX_IMPULSE` is the torque budget, and it is the difference
   between a door that shoves the player aside and one that gives way. Tune it
   before tuning the speed.

**Notes**
- `class_name HingeControl` is global to the project — rename it if you already
  define that type.
- For a door that should be *held* shut rather than driven shut, set the limits
  to the closed position and leave the motor off. The solver is stronger and
  cheaper than any motor loop.
- `Generic6DOFJoint3D` does everything the specific joints do and asks you to
  configure every axis to get there. Reach for it when the motion genuinely does
  not fit a hinge, a pin or a slider — not before.

## Related demos

- [audio-3d](../audio-3d) — Positional audio with AudioStreamPlayer3D, and a hearing model the game logic can share with it.
- [audio-buses](../audio-buses) — Audio buses built at runtime: sliders that are decibels, a mute that is not a volume, and a reverb you walk into.
- [six-dof-joint](../six-dof-joint) — The joint that does everything, and how to say which of its six axes you meant.
- [terrain-collision](../terrain-collision) — A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

