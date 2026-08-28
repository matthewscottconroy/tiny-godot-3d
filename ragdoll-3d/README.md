# Ragdoll 3D

<!-- tags: physics, animation, ui, component, shows-its-working -->

The hand-off from animation to physics, and the blend back that stops it snapping.

## Purpose

A ragdoll is not a mode a character is in. It is a *transition*, twice: from
animation to physics when they are hit, and back again when they get up. Both
transitions are where it goes wrong, and neither problem is about the physics.

The simulation itself is a solved problem — Godot has it, and the editor will
generate the bodies for you. What it will not do is decide when to hand over,
what to hand over *with*, or how to take control back.

## Controls

| Key | Action |
|-----|--------|
| Space | Hit it |
| G | Get up |
| 1 / 2 | Less or more momentum going in |
| R | Reset |

## How It Works

**Physical bones hang off a simulator, not off the skeleton.** A
`PhysicalBoneSimulator3D` between them is required in Godot 4, and it caches the
skeleton's bone list when it enters the tree — so one created *before* the bones
exist binds every body against an empty list and errors once per bone. That is
the first thing that happens when you build this in code instead of pressing the
editor's button, and it is why the simulator here is created last.

**Start the bodies where the pose is.** A simulation that begins from the rest
pose snaps the character into a T-shape for one frame: the most recognisable
ragdoll bug there is. The suite measures how far the hips moved on the hand-off
frame and asserts it is small.

**Carry the momentum over.** A character shot while sprinting should fall
forwards. Bodies started at rest drop straight down, which reads as being
switched off rather than hit. `launch_velocity()` is the character's velocity
plus the impulse over the bone's mass.

**Settle on the fastest body, not the average.** An arm still swinging is not a
character ready to stand up, and an average hides exactly that.

**And hold it.** A body resting on a slope reports still between bounces. The
settle test requires the stillness to last, or characters stand up mid-bounce.

**Blend back, do not snap.** Snapping to the first frame of "stand up" is the
going-limp bug in reverse. `advance_recovery()` returns how much the animation
is in charge, and the driver lerps the pose toward the animated one by that
weight.

**During the fall, the bodies are the truth.** The bone poses follow them; read
the pose mid-simulation and you are reading last frame's animation. The suite
reads the `PhysicalBone3D` positions for the same reason.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `PhysicalBoneSimulator3D` | The node the physical bones live under |
| `physical_bones_start_simulation()` / `_stop_simulation()` | The two transitions |
| `PhysicalBone3D.joint_type` / `.bone_name` | What holds a limb to its parent |
| `Skeleton3D.set_bone_pose_position()` | The animated side, and the blend back |
| `PhysicalBone3D.linear_velocity` | Momentum in, and stillness out |

## Files

| File | What it holds |
|------|---------------|
| `scripts/ragdoll.gd` | The `Ragdoll` component: states, settling, recovery, launch velocity |
| `scripts/main.gd` | Demo driver: a skeleton and its physical bones, both built in code |
| `scenes/main.tscn` | Ground, a camera, and an empty skeleton to fill |
| `tests/test_logic.gd` | Headless test suite — including knocking a real skeleton over |
| `tests/frames` | Frames the suite needs, since the character has to actually fall |

## Use as a building block

**Copy:** `scripts/ragdoll.gd` — the `Ragdoll` type. `scripts/main.gd` is the
demo driver, though `_build_physical_bones()` is worth reading before you
generate bodies any other way.

**Public API**
- `go_limp()`, `recover()`, `reset()`
- `observe(fastest_body_speed, delta) -> bool` — true on the frame it settles
- `advance_recovery(delta) -> float`, `animation_weight() -> float`
- `state() -> State`, `is_simulating() -> bool`
- `Ragdoll.launch_velocity(character_velocity, impulse, mass := 1.0) -> Vector3`
- `Ragdoll.fastest(speeds) -> float`
- `settle_speed`, `settle_time`, `recovery_time`

**Integrate**
1. Generate the bodies with the editor's "Create physical skeleton" for a real
   rig. Hand-building them is for demos and for rigs you generated yourself.
2. Give the ragdoll a time limit as well as a settle test. Something wedged in
   geometry never settles, and a character who never gets up is worse than one
   who gets up oddly.
3. Add collision exceptions between bones that overlap at rest, or the character
   explodes on the first frame as the solver pushes them apart.
4. Keep the animated and simulated skeletons the same skeleton. Two of them, one
   for each mode, is the version where the blend is impossible.

**Notes**
- `class_name Ragdoll` is global to the project — rename it if you already
  define that type.
- Seven capsules is a demo. A real ragdoll is closer to fifteen bodies, and the
  cost is in the joints rather than the shapes.
- Blending back is only convincing if the animation you blend *to* is close to
  where the body ended up. Games usually pick a get-up clip based on whether the
  character landed face-up or face-down.
- See [skeleton-3d](../skeleton-3d) for what a skeleton is before any of this,
  and [joints-3d](../joints-3d) for the constraints these bones are made of.

## Related demos

- [six-dof-joint](../six-dof-joint) — The joint that does everything, and how to say which of its six axes you meant.
- [object-pool-3d](../object-pool-3d) — Recycling scene instances instead of allocating them, and the reset step that makes pooling safe.
- [skeleton-3d](../skeleton-3d) — Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for.
- [skeleton-modifier](../skeleton-modifier) — The supported place to change a pose after the animation has set it — and why _process() is not it.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

