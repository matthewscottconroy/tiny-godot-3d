# Six DOF Joint

<!-- tags: physics, mesh, ui, component, shows-its-working -->

The joint that does everything, and how to say which of its six axes you meant.

## Purpose

Godot's other joints are named after what they do: a hinge hinges, a slider
slides. `Generic6DOFJoint3D` is named after its *mechanism* — six degrees of
freedom, three linear and three angular, each independently free, limited or
locked — and configuring it means holding all six in your head at once while
ticking about twenty boxes.

Which is why it has a reputation for producing a joint that does nothing, or
everything. Both have the same cause, and it is the one thing to take away from
this demo:

**There is no "locked" flag. A locked axis is one whose limit is *enabled* with
a range of zero.** A joint with no limits enabled is a ball joint that also
slides — six axes, all free — and that is what you get by dropping the node in
and changing nothing.

## Controls

| Key | Action |
|-----|--------|
| 1–6 | Door, drawer, shoulder, ball, unconstrained, weld |
| Space | Shove it |
| R | Rebuild |

## How It Works

**Say what you mean, then translate.** `DofSpec.door()` is a door: one limited
angular axis, five locked. `drawer()` is one limited linear axis. The spec is
readable; the twenty flag-and-parameter writes it turns into are not, and they
are generated rather than typed.

**Locked is a limit of zero.** `limit_enabled()` returns true for locked *and*
limited axes and false only for free ones, which reads backwards until you
remember there is no third state in the engine. `bounds()` writes zero for a
locked axis whatever is in the range array.

**The two useless extremes are both one keystroke away.** Six degrees of freedom
is the default and almost never intended; zero is a weld — two bodies that could
have been one. `degrees_of_freedom()` puts the number on screen so neither
happens by accident.

**A shoulder is a ball joint with limits.** That is the whole difference, and it
matters: an arm that can rotate freely about its own length is a broken arm.

**Both ends have to be attached.** A joint with one of `node_a` or `node_b`
missing is silently inert — no error, no warning, and a body that simply falls.

**Locked does not mean welded.** The limits are solved, not enforced: shove the
door here and it moves 1.2 metres on its free axis and about 0.27 of a metre on
the five that are locked. The suite asserts the *ratio* rather than pretending
the locked axes are rigid, because they are not.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Generic6DOFJoint3D.set_flag_x/y/z()` | Enabling a limit per axis — the flag that actually locks things |
| `set_param_x/y/z()` with `PARAM_*_LOWER_LIMIT` / `_UPPER_LIMIT` | The range, or the zero that locks it |
| `Joint3D.node_a` / `node_b` | The two ends; one missing is a silent no-op |
| `FLAG_ENABLE_LINEAR_LIMIT` / `FLAG_ENABLE_ANGULAR_LIMIT` | The two families of limit |
| `RigidBody3D.apply_impulse()` | Something to test the constraint with |

## Files

| File | What it holds |
|------|---------------|
| `scripts/dof_spec.gd` | The `DofSpec` component: six axes, named presets, and what to write |
| `scripts/main.gd` | Demo driver: building the joint and applying a spec to it |
| `scenes/main.tscn` | Ground, a static anchor, and an empty rig to build into |
| `tests/test_logic.gd` | Headless test suite — including reading the flags back off a real joint |
| `tests/frames` | Frames the suite needs, since a shoved body has to actually swing |

## Use as a building block

**Copy:** `scripts/dof_spec.gd` — the `DofSpec` type. `scripts/main.gd`'s
`_apply()` is the translation layer and is worth taking with it.

**Public API**
- `DofSpec.door(swing := PI * 0.6)`, `drawer(travel := 0.6)`, `ball()`,
  `shoulder(reach, twist)`, `unconstrained()`
- `linear`, `angular` — `Freedom.LOCKED` / `LIMITED` / `FREE` per axis
- `linear_range`, `angular_range`
- `degrees_of_freedom() -> int`, `is_weld() -> bool`
- `limit_enabled(kind, axis) -> bool`, `bounds(kind, axis) -> Vector2`
- `describe() -> String`

**Integrate**
1. Start from a weld and unlock what you need. Starting from the default means
   working out which of six axes is letting the thing float away.
2. Use the named joints where they fit. A `HingeJoint3D` is one property and
   cannot be misconfigured in five other dimensions — see
   [joints-3d](../joints-3d). Reach for the 6DOF when nothing else has the shape.
3. Put the spec in a resource, not in code. The point of separating it is that a
   designer can change what a joint means without touching twenty setters.
4. Add motors and springs after the axes are right. `PARAM_LINEAR_SPRING_*` and
   the motor parameters are another dozen numbers, and they behave very
   differently on an axis that is limited than on one that is free.

**Notes**
- `class_name DofSpec` is global to the project — rename it if you already
  define that type.
- The axes are the *joint's* axes, not the world's or the body's. A joint
  rotated 90° about Y locks a different direction than the same spec on an
  unrotated one, which is the second-commonest surprise here.
- Precision falls off with mass ratio. A light body on a heavy anchor holds
  well; a heavy body hanging off a light one drifts on its locked axes, and no
  amount of limit tightening fixes it — that is a solver iteration setting.
- See [joints-3d](../joints-3d) for hinges and pin joints, and
  [ragdoll-3d](../ragdoll-3d) for what a skeleton's worth of cone joints looks
  like.

## Related demos

- [ragdoll-3d](../ragdoll-3d) — The hand-off from animation to physics, and the blend back that stops it snapping.
- [vehicle-3d](../vehicle-3d) — A VehicleBody3D that drives, the arithmetic that keeps it drivable, and the sign that catches everyone.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.
- [terrain-collision](../terrain-collision) — A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

