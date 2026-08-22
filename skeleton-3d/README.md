# Skeleton 3D

<!-- tags: animation, ui, component, shows-its-working -->

Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for.

## Purpose

A skeleton normally arrives inside a `.glb`, which makes it look like something
you cannot open. It is not. A bone is a name, a parent and two transforms, and
all of it can be built from a script in about ten lines. Doing that once is the
quickest way to understand what an imported rig actually contains — and it is
also how you rig a creature the artist never made: a tentacle, a rope, a
segmented tail.

Two facts about the API produce most of the bugs, and both put a limb somewhere
plausible rather than throwing an error:

- **Poses are local to the parent bone.** `set_bone_pose_rotation()` takes a
  rotation relative to the parent's pose, not a world orientation. Hand it a
  world-space rotation and the limb is right only while the character faces one
  way.
- **Rest is not pose.** The rest is where the bone sits with nothing animating
  it; the pose is the offset from that. Writing rests at runtime moves the
  skeleton out from under every animation that refers to it.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Weaker or stronger bend |
| 3 / 4 | Falloff — bend at the tip, or at the root |
| Space | Stop the target moving |
| R | Relax back to the rest pose |

## How It Works

**A chain is `add_bone`, `set_bone_parent`, `set_bone_rest`.** Each bone's rest
is one length from its **parent**, not from the origin — get that wrong and the
chain stretches as it goes. The suite checks both: each rest is one length, and
the fourth bone's global pose is three lengths up because the parents add.

**The target is rotated into the parent's space before use.** `curl()` takes the
target in skeleton space, then multiplies by the inverse of the parent's global
pose basis before asking for a rotation. That is the step people leave out, and
the reason their arm works until the character turns around.

**Bending is partial, per bone.** `bend_toward()` returns the rotation from one
direction to another, scaled by a strength. Applying a fraction at every bone is
what makes a chain curl; applying the whole rotation at each one snaps them all
to the same angle. The falloff decides whether the bend lives at the tip
(tentacle) or the root (arm).

**Turning exactly backwards is handled.** Two opposite directions have no unique
axis to rotate about — the cross product is zero and the obvious code produces a
`NAN` quaternion, which puts the bone somewhere no renderer can show. A fixed
perpendicular is chosen instead.

**`BoneAttachment3D` is how unskinned things ride a skeleton.** Each mesh here
hangs off one, and the attachment copies its bone's pose every frame. A weapon
in a hand, a hat on a head, a segment of shell — none of them need skinning, and
none of them need a script.

**All of it runs headless.** A `Skeleton3D` needs no rendering, so the whole
suite — building, posing, curling, relaxing — is an ordinary test. "Rigs can only
be checked by looking at them" is why so much rig code goes untested, and it is
not true.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Skeleton3D.add_bone()` / `set_bone_parent()` | Building the hierarchy |
| `Skeleton3D.set_bone_rest()` | Where a bone sits with nothing animating it |
| `Skeleton3D.set_bone_pose_rotation()` | The offset from rest — local to the parent |
| `Skeleton3D.get_bone_global_pose()` | Where a bone has actually ended up |
| `Skeleton3D.reset_bone_pose()` | Back to rest, without touching the rest |
| `BoneAttachment3D.bone_idx` | Hanging a node off a bone |

## Files

| File | What it holds |
|------|---------------|
| `scripts/skeleton_rig.gd` | The `SkeletonRig` component: building, bending, curling, relaxing |
| `scripts/main.gd` | Demo driver: the skeleton, the attachments, and the moving target |
| `scenes/main.tscn` | An empty Skeleton3D for the driver to fill, and a target |
| `tests/test_logic.gd` | Headless test suite — real skeletons, no rendering |

## Use as a building block

**Copy:** `scripts/skeleton_rig.gd` — the `SkeletonRig` type. `scripts/main.gd`
is the demo driver and is not needed.

**Public API**
- `SkeletonRig.build_chain(skeleton, count, length, axis := Vector3.UP, prefix := "bone") -> PackedInt32Array`
- `SkeletonRig.bend_toward(from, to, strength, max_angle := PI) -> Quaternion`
- `SkeletonRig.curl(skeleton, bones, target_local, strength, falloff := 1.0, axis := Vector3.UP)`
- `SkeletonRig.relax(skeleton, bones)`
- `SkeletonRig.tip_of(skeleton, bone, length, axis := Vector3.UP) -> Vector3`

**Integrate**
1. Convert your target into the skeleton's space first
   (`skeleton.global_transform.affine_inverse() * world_point`). Everything
   inside a skeleton is in skeleton space or bone space; world space is a
   visitor.
2. Set poses, never rests, at runtime. If a rest genuinely needs to change —
   a procedurally sized creature — do it once, at build time, before anything
   animates.
3. For an imported rig, find bones by name with `find_bone()` rather than by
   index. Indices change when an artist re-exports; names usually do not.

**Notes**
- `class_name SkeletonRig` is global to the project — rename it if you already
  define that type.
- This bends a chain toward a target; it does not solve for a *specific* end
  position. For a two-bone limb that has to reach an exact point, see
  [two-bone-ik](../two-bone-ik).
- `SkeletonModifier3D` is the built-in place to hang procedural pose changes in
  Godot 4.3+, and it runs at the right point in the frame relative to
  `AnimationTree`. Driving poses directly, as here, is simpler and fights
  animation if both are running.

## Related demos

- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.
- [two-bone-ik](../two-bone-ik) — Two-bone inverse kinematics: where the knee goes when the foot is planted, and what happens when it cannot reach.
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [multiplayer-3d](../multiplayer-3d) — Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

