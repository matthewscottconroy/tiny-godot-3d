# Raycast Picking

<!-- tags: spatial-query, camera, ui, signals, component, shows-its-working -->

Turning a mouse position into a world ray, and asking the physics space what it hit.

## Purpose

A click is two pixels. Everything in the scene is three-dimensional. Bridging
that is the most-asked 3D question there is, and it has three parts people get
wrong separately: building the ray from the camera rather than guessing at it,
running the query at a moment when the physics server will answer, and deciding
what a click that hits nothing means.

The last one matters more than it sounds. In most games a click on empty floor
is not a miss — it is a move order, a build site, a waypoint. That answer is a
ray-plane intersection, and it has two degenerate cases that quietly place things
behind the camera if you do not handle them.

## Controls

| Input | Action |
|-------|--------|
| Left click | Select the box under the cursor, or place the marker on the floor |
| Shift + left click | Add to (or remove from) the selection |

## How It Works

**The camera builds the ray.** `project_ray_origin()` gives a point on the near
plane under the cursor, `project_ray_normal()` the direction through it. Both
come from the camera's own projection, so zoom, field of view and viewport size
are already accounted for — this is why the ray is asked for rather than
constructed.

**The query waits for a physics frame.** `_unhandled_input()` only records where
the click was; the `intersect_ray()` happens in `_physics_process()`. The space
state is not safe to touch outside it, and reaching for it during input is how
you get *"can't change this state while flushing queries"* — an error whose text
never mentions the click that caused it.

**A hit is a dictionary, or nothing.** `intersect_ray()` returns `{}` on a miss,
so `hit.get("collider")` is the safe read. The driver then checks group
membership: the floor is a collider too, and treating everything with a shape as
selectable means the level itself is selectable.

**A miss still has an answer.** `ScenePicker.ground_point()` intersects the same
ray with the horizontal plane at `y = 0`. It returns `null` for a ray parallel to
the plane, which would divide by zero, and for one pointing away from it, which
has a mathematically valid solution *behind* the camera. Returning a point in
either case puts your marker somewhere nobody clicked.

**Selection is its own small problem.** Replace on click, add-or-remove on
shift-click, no duplicates, no signal when nothing actually changed, and a
`prune()` for the case where something selected gets freed — a selected enemy
dying, which otherwise leaves a freed reference to trip over later.

**Highlighting needs one material per box.** The driver makes a
`StandardMaterial3D` per node in `_ready()`. Boxes sharing a material means
tinting one tints all of them, which is the version of this bug everyone writes
once.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Camera3D.project_ray_origin()` / `project_ray_normal()` | Screen position to world ray |
| `World3D.direct_space_state` | The physics server's query interface |
| `PhysicsDirectSpaceState3D.intersect_ray()` | What the ray hits first |
| `PhysicsRayQueryParameters3D.create()` | The query, including mask and exclusions |
| `Node.is_in_group()` | Separating "has a collider" from "is selectable" |
| `MeshInstance3D.material_override` | A per-instance material, so highlighting is local |

## Files

| File | What it holds |
|------|---------------|
| `scripts/picker.gd` | The `ScenePicker` component: ground-plane maths and the selection set |
| `scripts/main.gd` | Demo driver: the ray, the query, and the highlight |
| `scenes/main.tscn` | Three pickable boxes, a floor, a marker, and the HUD |
| `tests/test_logic.gd` | Headless test suite — including one that fires a real ray at the real scene |

## Use as a building block

**Copy:** `scripts/picker.gd` — the `ScenePicker` type. `scripts/main.gd` is the
demo driver and is not needed.

**Public API**
- `ScenePicker.ground_point(from, direction, plane_y) -> Vector3` or `null`
- `select(node)`, `toggle(node)`, `clear()`, `prune()`
- `is_selected(node) -> bool`, `selected() -> Array[Node3D]`, `count() -> int`
- `signal selection_changed(count: int)`

**Integrate**
1. Build the ray in `_physics_process`, not in input handling. Record the click
   position and use it on the next physics frame.
2. Put selectable things in a group, or give them their own collision layer and
   pass a `collision_mask` to `PhysicsRayQueryParameters3D`. A mask is cheaper —
   the server rejects the rest before any work happens.
3. Call `prune()` whenever things can be destroyed, or connect to their
   `tree_exiting` and drop them as they go.

**Notes**
- `class_name ScenePicker` is global to the project — rename it if you already
  define that type.
- `ground_point()` returns `Variant`, because `null` is a meaningful answer and
  Vector3 has no "no such point" value. Check for `null` before using it.
- To pick `Area3D`s as well as bodies, set `collide_with_areas = true` on the
  query — it is off by default, which is a long-lived source of confusion.
- For a click that should ignore the object holding the camera, add it to the
  query's `exclude` array rather than filtering the result afterwards.

## Related demos

- [lights-and-shadows](../lights-and-shadows) — The three 3D light types side by side, and a shadow budget that keeps the expensive ones near the camera.
- [rigid-body-3d](../rigid-body-3d) — RigidBody3D boxes that fall, stack, and scatter — impulses versus setting a transform.
- [continuous-collision](../continuous-collision) — A fast projectile that goes straight through a wall, and the three ways to stop it.
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

