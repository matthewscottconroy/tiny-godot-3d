# CSG Blockout

<!-- tags: mesh, camera, ui, component, shows-its-working -->

Greyboxing a level with CSG: rooms added, doorways subtracted, and the bake that turns it into a mesh.

## Purpose

CSG is for the stage before anyone has modelled anything: a level made of boxes
added together and cut out of each other, changeable in seconds. It is the
fastest way to find out whether a room is the right size, and it is meant to be
thrown away or baked once the answer is yes.

What makes it a workflow rather than a toy is where the boxes come from. Thirty
`CSGBox3D` nodes dragged into place is a level nobody can edit; a plan of rooms
as rectangles, with doorways worked out from which rooms share a wall, is one
you can move a room in and have the doors follow.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Narrower or wider doorways |
| B | Bake the CSG to a static mesh |
| Space | Pause the orbit |

## How It Works

**A room is a solid with a hollow taken out of it.** Add a box the size of the
room, then subtract a smaller one — that is how CSG makes anything hollow, and
it is why the order of operations matters. A subtraction that comes before the
thing it cuts removes nothing.

**Doorways come from the plan.** `RoomPlan.doorways()` finds every pair of rooms
that share a wall; `door_between()` puts the doorway halfway along it. Move a
room and the doors move with it, because nothing stores a door position.

**Corners are not walls.** Two rooms meeting at a single point share no wall,
and a door there is a hole through the diagonal into nothing. `shares_wall()`
requires a real length of overlap — and a minimum, because a two-centimetre
shared wall is not a doorway either.

**Cuts must be thicker than what they cut.** A door box exactly as deep as the
wall leaves coplanar faces, and coplanar faces in CSG give you z-fighting or
nothing at all depending on the floating point of the day. `door_box()` makes
the cut three wall-thicknesses deep.

**Orientation is wrong half the time if you guess.** `door_is_horizontal()`
answers it from the geometry: a door box turned the wrong way cuts *along* the
wall instead of through it.

**CSG is evaluated deferred.** `bake_static_mesh()` in the same frame the tree
was built comes back empty — the suite waits a few frames, and says so, because
this is a puzzling afternoon otherwise.

**Baking is the point of greyboxing.** CSG re-evaluates whenever anything in the
tree changes, which is right while you are dragging boxes and wasteful for a
level that has stopped changing. Bake to a mesh, keep the CSG tree in the
project for the next revision.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `CSGCombiner3D` | The root that evaluates a tree of CSG operations |
| `CSGBox3D.operation` (`UNION` / `SUBTRACTION`) | Adding and cutting |
| `CSGShape3D.use_collision` | A greybox you can walk around in while you edit it |
| `CSGCombiner3D.bake_static_mesh()` | Turning the finished blockout into an ordinary mesh |
| `Rect2.intersects()` / `end` | The room arithmetic behind the plan |

## Files

| File | What it holds |
|------|---------------|
| `scripts/room_plan.gd` | The `RoomPlan` component: shared walls, doorways, and the box sizes |
| `scripts/main.gd` | Demo driver: building the CSG tree and baking it |
| `scenes/main.tscn` | Ground, a camera, an empty combiner and a target for the bake |
| `tests/test_logic.gd` | Headless test suite — including a real bake of the real tree |

## Use as a building block

**Copy:** `scripts/room_plan.gd` — the `RoomPlan` type. `scripts/main.gd` is the
demo driver, though `_build()` is the part worth adapting.

**Public API**
- `RoomPlan.shares_wall(a, b, minimum := 1.0) -> bool`
- `RoomPlan.door_between(a, b, minimum := 1.0) -> Vector2` or `null`
- `RoomPlan.door_is_horizontal(a, b) -> bool`
- `RoomPlan.doorways(rooms, minimum := 1.0) -> Array[Vector2i]`
- `RoomPlan.centre_of(room, y := 0.0) -> Vector3`
- `shell_box(room, height)`, `hollow_box(room, height)`, `door_box(horizontal)`
- `wall`, `door_width`, `door_height`

**Integrate**
1. Keep the plan as data — an array of `Rect2`, or a file — and rebuild the tree
   from it. The moment door positions are stored separately, moving a room
   breaks them.
2. Bake before shipping. `use_collision` on a live CSG tree rebuilds its
   collision shape on every change, which is fine in the editor and not what you
   want in a level that has stopped moving.
3. CSG does not like coincident faces. When two rooms share a wall exactly,
   overlap them slightly rather than butting them together.

**Notes**
- `class_name RoomPlan` is global to the project — rename it if you already
  define that type.
- CSG is not a modelling tool. It is a fast way to be wrong cheaply, which is
  exactly what greyboxing is for; the geometry it produces is not tidy and is
  not meant to ship unbaked.
- A baked mesh has no UVs worth texturing. That is fine for a greybox and is the
  point at which the level goes to someone with a modelling package.

## Related demos

- [procedural-mesh](../procedural-mesh) — Building geometry with `SurfaceTool`: vertices, winding order, indices, and normals.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

