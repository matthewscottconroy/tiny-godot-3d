# Two Bone IK

<!-- tags: spatial-query, ui, component, shows-its-working -->

Two-bone inverse kinematics: where the knee goes when the foot is planted, and what happens when it cannot reach.

## Purpose

Forward kinematics is "the thigh is at this angle, so the foot ends up over
there". Inverse kinematics is the question you actually have: the foot has to be
*there* — on this step, on that rung, on the ground beneath it — so what angles
put it there?

For a two-bone limb the maths is the law of cosines and fits in twenty lines.
Everything else is the cases the maths does not cover, and each of them renders
as something plausible rather than as an error:

- **Out of reach.** `acos()` of something outside −1..1 returns `NAN`, which
  propagates into a transform and makes the limb vanish. It looks like a missing
  mesh.
- **Too close.** Same problem at the other end of the range — a foot planted
  directly under a crouching hip.
- **Which way the knee bends.** Two mirrored solutions exist and the maths
  prefers neither. Pick wrong and the knee bends backwards, which looks like a
  bad animation.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Lower or raise the hip |
| 3 / 4 | Shorter or longer stride |
| Space | Pause |

Raise the hip until the leg straightens: the readout says **OUT OF REACH** and
the leg stops stretching rather than tearing itself apart.

## How It Works

**The triangle.** Hip, knee, foot. Two sides are the bone lengths, the third is
the distance to the target, and the law of cosines gives the angles. The knee
lands at `root + (direction·cos θ + bendAxis·sin θ) × upper`.

**The range is clamped before anything else.** The target distance is clamped
between `|upper − lower|` (fully folded) and `upper + lower` (fully straight).
Outside that there is no triangle, so the solver produces the nearest one that
exists and reports `reachable = false` — the caller then decides whether to
lean, step, or give up, which is a game decision rather than a maths one.

**The bones never stretch.** The suite asserts it directly: after solving, the
hip-to-knee distance is still the upper length and knee-to-foot is still the
lower. A solver that stretches to reach looks fine in a screenshot and wrong in
motion.

**The pole vector picks the solution.** The knee is placed in the plane
containing the limb and pointing toward the pole. For a leg the pole goes in
front of the character, so knees bend forwards. This is the parameter people
leave out, and then their character's knees invert when it turns around.

**A useless pole still gives a stable answer.** A pole on the limb's own line
indicates nothing; the solver falls back to a fixed perpendicular rather than an
arbitrary one, because an arbitrary choice makes the knee jitter as the limb
passes through that alignment.

**The foot is placed by a raycast.** The target is a circle around the hip,
dropped onto whatever is underneath with a `RayCast3D` — which is what foot
placement on uneven ground actually is. Walk it over the steps and the leg
folds and extends to keep the foot on the surface.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `acos()` / `clampf()` | The law of cosines, and the clamp that keeps it finite |
| `Vector3.cross()` / `dot()` | Building the bend plane from the pole |
| `RayCast3D.force_raycast_update()` | Querying the ground after moving the ray in the same frame |
| `RayCast3D.get_collision_point()` | Where the foot should land |
| `Basis(x, y, z)` | Orienting each bone mesh along its segment |
| `Node3D.scale` | Stretching a capsule to span two points |

## Files

| File | What it holds |
|------|---------------|
| `scripts/limb_solver.gd` | The `LimbSolver` component: the solve, the clamps, the pole, and `aim()` |
| `scripts/main.gd` | Demo driver: the stride, the ground raycast, and drawing the bones |
| `scenes/main.tscn` | A floor with two steps, the rig, and the HUD |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/limb_solver.gd` — the `LimbSolver` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `LimbSolver.solve(root, target, upper, lower, pole) -> Solution`
- `Solution.joint`, `Solution.foot`, `Solution.reachable`, `Solution.bend`
- `LimbSolver.aim(from, to, up := Vector3.UP) -> Basis`
- `LimbSolver.reach_of(upper, lower) -> float`, `LimbSolver.fold_of(upper, lower) -> float`

**Integrate**
1. Work in the limb root's local space — pass `Vector3.ZERO` as the root and the
   target relative to it. Everything then comes back in the same space, ready to
   assign.
2. For a `Skeleton3D`, convert `joint` and `foot` into bone rotations with
   `aim()` and `set_bone_pose_rotation()`. The solve is identical; only the
   application changes.
3. Use `reachable` rather than ignoring it. A leg that cannot reach the ground
   is the signal to lean the hips, play a stretch animation, or stop trying.

**Notes**
- `class_name LimbSolver` is global to the project — rename it if you already
  define that type.
- Real foot placement wants smoothing on top. Snapping the target to the raycast
  every frame makes the foot flicker between surfaces at an edge; lerping the
  target — not the solved joint — is the fix.
- Godot ships `SkeletonIK3D` for skeletons, which does this and more against a
  real rig. This is the version you write when the limb is not a skeleton, or
  when you need to know *why* the knee went where it did.

## Related demos

- [skeleton-3d](../skeleton-3d) — Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for.
- [shape-cast-3d](../shape-cast-3d) — Sweeping a shape ahead of a character with ShapeCast3D to tell a step it can climb from a wall it cannot.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

