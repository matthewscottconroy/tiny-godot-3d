# Skeleton Modifier

<!-- tags: animation, ui, component, shows-its-working -->

The supported place to change a pose after the animation has set it — and why `_process()` is not it.

## Purpose

Procedural pose changes — a head that follows the player, a gun hand that tracks
a target, a spine that leans into a turn — all have the same problem. They have
to happen *after* the animation has written the pose and *before* the skeleton is
drawn.

Write them from `_process()` and you are racing the `AnimationMixer`: sometimes
you win and the animation looks broken, sometimes it wins and your change does
nothing. Which one depends on node order, which is why it "works on my machine".

`SkeletonModifier3D` is the answer. Godot calls `_process_modification()` at
exactly the right point in the skeleton's update, and gives you an `influence`
to fade the effect in and out.

## Controls

| Key | Action |
|-----|--------|
| L | Look on or off — faded, not switched |
| 1 / 2 | How far the head may turn |
| Space | Stop the target moving |
| R | Reset |

## How It Works

**A modifier must be a child of the skeleton it modifies.** Godot hands it the
skeleton through `get_skeleton()`; one parented anywhere else silently does
nothing.

**A pose written by a modifier does not survive the frame.** The skeleton resets
the pose and reapplies the animation before every pass, so reading
`get_bone_pose_rotation()` from a `_process()` shows you the *animation's* pose,
not the modifier's. That is the same fact that makes `_process()` the wrong place
to write from — and it is why the modifier here records what it read and wrote,
which is the only honest way to observe it from outside.

**Clamp the turn as an angle, not by clamping the result.** A head that can
rotate 180 degrees to look behind is an owl; one that snaps to its limit and
stays there is what clamping the result gives you. `aim_within()` keeps the axis
and shortens the angle, so the head still turns *toward* the target.

**Blend from the animated pose, not from the rest pose.** Fading a modifier in
from rest makes the character straighten up as it arrives, which reads as a
glitch rather than as a look.

**Everything in the parent bone's space.** The target is in the world, the pose
is local to the parent, and mixing them is why a head-look works while the
character faces one way and not another. The suite pins this by putting the
target close and checking the aim is exact — a target three metres away forgives
being aimed from the wrong origin, and a directional check will not catch it.

**One degenerate check, not three.** Already aligned, exactly opposite, and "one
of the vectors is nothing" all reduce to *there is no axis to turn about*, and
the sign of the dot product separates them. Written as three guards, two of them
were unreachable — the general path already returned the same answer.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `SkeletonModifier3D._process_modification()` | The one place a procedural pose change belongs |
| `SkeletonModifier3D.influence` | Fading the effect rather than switching it |
| `SkeletonModifier3D.get_skeleton()` | The skeleton Godot decided this modifier belongs to |
| `Skeleton3D.get_bone_pose_rotation()` | The pose the animation just wrote |
| `Skeleton3D.modifier_callback_mode_process` | Whether modifiers run on idle or physics frames |

## Files

| File | What it holds |
|------|---------------|
| `scripts/aim_constraint.gd` | The `AimConstraint` component: aiming, clamping, blending, fading |
| `scripts/head_look.gd` | The modifier itself — the whole reason this is not a `_process()` script |
| `scripts/main.gd` | Demo driver: a skeleton and an idle animation, both built in code |
| `scenes/main.tscn` | A character, a wandering target, and the modifier hung off the skeleton |
| `tests/test_logic.gd` | Headless test suite — including running the real modifier under a real animation |

## Use as a building block

**Copy:** `scripts/aim_constraint.gd` and `scripts/head_look.gd` together — the
maths and the node that runs it at the right moment.

**Public API**
- `AimConstraint.aim(forward, to_target) -> Quaternion`
- `AimConstraint.aim_within(forward, to_target, limit) -> Quaternion`
- `AimConstraint.within_reach(forward, to_target, limit) -> bool`
- `AimConstraint.blended(animated, aimed, influence) -> Quaternion`
- `AimConstraint.fade(current, wanted, delta, rate := 8.0) -> float`

**Integrate**
1. One modifier per job, stacked in tree order. They run top to bottom, so a
   spine lean above a head-look means the head aims from the leaned spine — which
   is usually what you want, and never what you get by accident.
2. Fade the influence rather than toggling `active`. A head that snaps to a
   target and snaps back reads as a glitch whatever the aim is doing.
3. Give it something to do nothing about. `within_reach()` lets a head give up
   and face front, which looks far better than straining at its limit for ever.
4. Set `modifier_callback_mode_process` to physics if the thing being tracked
   moves in `_physics_process`. Otherwise the aim is always one frame stale, and
   it shows most on the fastest-moving targets.

**Notes**
- `class_name AimConstraint` is global to the project — rename it if you already
  define that type.
- The bone meshes here are moved by hand to show the pose, because they are not
  skinned to anything. A real character has a mesh with weights and needs none
  of that.
- `SkeletonModifier3D` arrived in Godot 4.3+ and is the replacement for
  `SkeletonIK3D` and for hand-rolled `_process()` rigs. If you are following an
  older tutorial, this is what it should have been doing.
- See [two-bone-ik](../two-bone-ik) for a constraint that solves rather than
  aims, and [skeleton-3d](../skeleton-3d) for what a skeleton is underneath all
  of this.

## Related demos

- [two-bone-ik](../two-bone-ik) — Two-bone inverse kinematics: where the knee goes when the foot is planted, and what happens when it cannot reach.
- [ragdoll-3d](../ragdoll-3d) — The hand-off from animation to physics, and the blend back that stops it snapping.
- [skeleton-3d](../skeleton-3d) — Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for.
- [animation-in-code](../animation-in-code) — Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

