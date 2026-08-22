# Navigation Obstacle

<!-- tags: mesh, navigation, ui, component, shows-its-working -->

Why a NavigationObstacle3D does not change the path, and the two mechanisms that do.

## Purpose

The obvious expectation is that dropping a `NavigationObstacle3D` on a crate
makes paths go round it. It does not, and nothing warns you.

`carve_navigation_mesh` is a **bake-time** property. Setting the outline at
runtime changes nothing about any path, because the mesh those paths are found
on has not changed. That is the single most confusing thing about this node, and
this demo exists to say it out loud and then show both of the things that *do*
work:

- **Carve, then re-bake.** Exact, and it changes the path itself. Costs a bake.
- **Avoidance.** The mesh and the path are untouched; agents with avoidance
  enabled steer around the obstacle in velocity space. Cheap, approximate, and
  the only option for anything that moves.

What decides between them is not how big the obstacle is. It is how often it
moves.

## Controls

| Key | Action |
|-----|--------|
| Space | Open or shut the door — and watch the path *not* change |
| R | Re-bake, which is when it changes |
| A | Switch between carving and avoidance |
| G | Send the walker back to the start |

## How It Works

**Setting the outline does nothing on its own.** Press Space and the door shuts,
the obstacle gets a four-sided footprint, `carve_navigation_mesh` is true — and
the path is still the straight 14 metres. The demo says "the mesh is stale"
rather than pretending; the suite asserts the path is unchanged at that moment,
because that is the behaviour, not a bug to be papered over.

**The obstacle must be inside what the region parses.** A `NavigationObstacle3D`
that is a *sibling* of the `NavigationRegion3D` is invisible to the bake, and
the carve silently does nothing. Here the door is a child of the region.

**`bake_navigation_mesh()` is threaded by default.** The mesh you read back on
the next line is the one from before. Pass `false` for a synchronous bake — this
cost three confused runs before it was noticed, and it looks identical to the
carve not working.

**A re-baked region reaches the map a couple of frames later.** Even after
`NavigationServer3D.map_force_update()`, a path queried in the same frame is
found on the old mesh. The driver waits two frames before re-pathing, and says
why; the suite does the same, which is why it is stable.

**Winding does not matter here.** Godot normalises the outline, so unlike a lot
of polygon work you cannot get this one backwards. The suite states it as a fact
— both windings carve the same area — rather than leaving it as a thing to
worry about.

**The footprint has to be bigger than the door.** An agent is not a point. A
hole exactly the size of the door leaves a strip along its edge that is walkable
on the mesh and too narrow to walk down. `box_footprint()` takes the agent
radius as a margin.

**Avoidance is a different mechanism entirely.** Switch with A: the mesh is
untouched, the path still goes straight through the door, and the *walker* is
pushed aside by `NavigationAgent3D`'s avoidance. The velocity you set becomes a
request; the answer arrives on `velocity_computed`.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `NavigationObstacle3D.vertices` | The outline, in the obstacle's local space |
| `carve_navigation_mesh` / `affect_navigation_mesh` | Bake-time carving — not a runtime effect |
| `NavigationObstacle3D.avoidance_enabled` / `.radius` | The runtime mechanism, which moves agents rather than paths |
| `NavigationRegion3D.bake_navigation_mesh(false)` | A bake that has finished by the time it returns |
| `NavigationAgent3D.velocity_computed` | Where an avoidance-corrected velocity comes back |
| `NavigationServer3D.map_get_path()` | Asking the map directly, without an agent in the way |

## Files

| File | What it holds |
|------|---------------|
| `scripts/carving.gd` | The `Carving` component: footprints, areas, and the carve-or-avoid decision |
| `scripts/main.gd` | Demo driver: the door, the re-bake, and the walker |
| `scenes/main.tscn` | A floor region, a door inside it, and an agent with avoidance on |
| `tests/test_logic.gd` | Headless test suite — including a real carve of a real mesh |
| `tests/frames` | Frames the suite needs, since a navigation map takes several to come up |

## Use as a building block

**Copy:** `scripts/carving.gd` — the `Carving` type. `scripts/main.gd` is the
demo driver, though `_rebake()` is the part worth taking.

**Public API**
- `Carving.box_footprint(size, margin := 0.0) -> PackedVector3Array`
- `Carving.contains(polygon, point) -> bool`
- `Carving.area(polygon) -> float`
- `Carving.signed_area(polygon) -> float`
- `Carving.avoidance_radius(size, margin := 0.0) -> float`
- `Carving.should_carve(speed, moving_above := 0.05) -> bool`

**Integrate**
1. Decide per obstacle, by how often it moves. A door that opens twice a level
   is a carve. A door a player can swing is avoidance, or it is a bake every
   time they touch it.
2. Bake off the main thread for anything large — the default *is* threaded, and
   `bake_finished` is how you find out it landed. The synchronous version here
   is for a demo that has to be deterministic.
3. Give the margin the same agent radius the mesh was baked with. They are two
   separate numbers in two separate places and they have to agree.
4. Avoidance does not stop an agent walking into a wall. It steers around
   *obstacles*, and the mesh is still what keeps it on the floor.

**Notes**
- `class_name Carving` is global to the project — rename it if you already
  define that type.
- The navigation mesh's `cell_size` must match the map's, or Godot warns about
  rasterisation errors on every assignment. They are set in two different
  places and default differently.
- Avoidance costs per agent, not per obstacle, and it is simulated on the
  server. A hundred agents avoiding one crate is a hundred agents' worth of work.
- See [navigation-3d](../navigation-3d) for the region, the bake, and the three
  ways a path silently comes back empty.

## Related demos

- [navigation-3d](../navigation-3d) — Baking a NavigationRegion3D at runtime and driving an agent along the path it finds.
- [save-load-3d](../save-load-3d) — Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

