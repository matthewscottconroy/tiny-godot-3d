# Navigation 3D

<!-- tags: physics, mesh, navigation, ui, component, shows-its-working -->

Baking a NavigationRegion3D at runtime and driving an agent along the path it finds.

## Purpose

Pathfinding in Godot 4 is three cooperating pieces, and every one of them has a
failure mode that produces *silence* rather than an error: a region that bakes an
empty mesh, an agent that returns a path of zero corners, or a body steered at
the destination instead of at the next corner and walked straight into a wall.

This demo shows all three working, and the test suite checks the two that can be
checked headlessly — that the region actually baked polygons, and that the agent
actually moved along the path it was given.

## Controls

| Key | Action |
|-----|--------|
| Space | Pause and resume the agent |
| R | Restart the route from the first waypoint |
| B | Re-bake the navigation mesh |

## How It Works

**Runtime baking parses colliders, not meshes.** `bake_navigation_mesh()` in a
running game reads `StaticBody3D` collision shapes — the visual-mesh path is
editor-only, and asking for it at runtime prints a warning and bakes nothing for
that object. The `NavigationMesh` resource in the scene therefore sets
`geometry_parsed_geometry_type` to static colliders, and every obstacle has a
`CollisionShape3D` as well as a mesh. An obstacle with only a mesh gets baked
straight over, and the agent walks through it.

**Baking fills the resource; assigning it tells the server.** This is the one
that costs an afternoon. `bake_navigation_mesh()` writes polygons into the
`NavigationMesh` resource in place — but the region only hands its mesh to the
navigation server when the property is *assigned*. Bake without re-assigning and
everything looks correct: the resource has polygons, the region is on the map,
nothing errors. Every path query returns empty, and the agent stands still.

```gdscript
_region.bake_navigation_mesh(false)
_region.navigation_mesh = _region.navigation_mesh   # not a no-op
```

With the threaded default, `await _region.bake_finished` first — the resource is
not worth reading until then.

**The cell size has to match the map's.** A `NavigationMesh` baked at one
`cell_size` and assigned to a map using another rasterises with errors along its
edges, and Godot warns about it. The same goes for `agent_radius`, which is
rounded up to whole cells: 0.5 with a cell size of 0.25 is exact, 0.5 with 0.2 is
not, and the warning says so. This collection's test runner fails on warnings,
which is how both were caught here.

**A path asked for too early comes back empty.** The navigation map synchronises
at the end of a physics frame, so anything requested during `_ready()` gets
nothing. `await get_tree().physics_frame` before the first `target_position` is
the entire fix, and its absence is the most common navigation complaint there is.

**Steer at the corner, not at the destination.**
`NavigationAgent3D.get_next_path_position()` returns the next corner of the
current path. That indirection is the whole point of pathfinding: heading
straight for `target_position` is what walking into a wall looks like.

**Arrival is a ground-plane distance.** `RouteFollower.arrived()` ignores Y. A
body's origin sits at its own half-height, so a full 3D distance can never fall
below that — the agent stands on the waypoint, never registers arrival, and
circles it forever.

**The path is drawn.** `ImmediateMesh` in `PRIMITIVE_LINE_STRIP` mode redraws
the remaining corners each frame. Two lines of code, and it turns "the agent is
going somewhere strange" from a mystery into something you can look at.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `NavigationRegion3D.bake_navigation_mesh()` | Build the walkable surface from the scene |
| `NavigationMesh` (`cell_size`, `agent_radius`) | What "walkable" means, in voxels |
| `NavigationAgent3D.target_position` | Where to go |
| `NavigationAgent3D.get_next_path_position()` | The next corner to steer at |
| `NavigationAgent3D.get_current_navigation_path()` | The whole path, for drawing it |
| `ImmediateMesh.surface_begin(PRIMITIVE_LINE_STRIP)` | Drawing the path as a line |
| `SceneTree.physics_frame` | The signal to await before the first path request |

## Files

| File | What it holds |
|------|---------------|
| `scripts/route_follower.gd` | The `RouteFollower` component: waypoints, arrival, looping |
| `scripts/main.gd` | Demo driver: baking, steering, and drawing the path |
| `scenes/main.tscn` | A floor, three walls, the agent, and the navigation region |
| `tests/test_logic.gd` | Headless test suite — including a real bake and a real walk |
| `tests/frames` | How many frames the suite needs, since it waits on navigation |

## Use as a building block

**Copy:** `scripts/route_follower.gd` — the `RouteFollower` type.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `RouteFollower.new(points: Array[Vector3])`
- `current() -> Vector3`, `arrived(position) -> bool`, `advance()`
- `update(position) -> bool` — advances if arrived, returns whether it did
- `finished() -> bool`, `index() -> int`, `laps() -> int`, `reset()`
- `waypoints`, `arrive_distance`, `looping`

**Integrate**
1. Set `agent.target_position` once, then again only when `update()` returns
   true. Assigning it every frame makes the agent re-path constantly, which is
   both slow and jittery.
2. Keep `arrive_distance` larger than the distance the agent covers in one
   frame, or it steps over the waypoint and turns back for it.
3. For a patrol that should pause at each stop, check `update()`'s return value
   and start a timer rather than advancing immediately.

**Notes**
- `class_name RouteFollower` is global to the project — rename it if you already
  define that type.
- Re-baking is not free: it is a full mesh generation, and doing it per frame
  will show. Bake on level load, or when something structural changes.
- The re-assignment after baking is load-bearing, not a superstition — this
  demo's test suite fails without it, which is how it was found.
- For doors and crates that move, `NavigationObstacle3D` carves the mesh without
  a re-bake, which is the right tool for anything dynamic.

## Related demos

- [navigation-obstacle](../navigation-obstacle) — Why a NavigationObstacle3D does not change the path, and the two mechanisms that do.
- [multimesh](../multimesh) — Ten thousand instances in one draw call with MultiMeshInstance3D, and a distance cull that costs nothing.
- [editor-tool-3d](../editor-tool-3d) — A @tool script that builds a fence along a Path3D and updates while you drag the curve in the editor.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

