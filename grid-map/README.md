# Grid Map

<!-- tags: mesh, ui, component, shows-its-working, good-first-demo -->

Level building with GridMap and a MeshLibrary made in code, from a room drawn as text.

## Purpose

`GridMap` is the 3D counterpart of a tilemap, and it has one prerequisite that
stops people before they start: it will not show anything without a
`MeshLibrary`, which is a resource you are normally expected to author in the
editor from a scene of tile nodes. That indirection makes it hard to see what a
`MeshLibrary` actually *is*.

So this demo builds one in code — three items, three meshes, one collision shape
each — and then paints a room into the map from a picture of the room drawn in
the source file. Both halves are the point: the library is just a list of
meshes with ids, and the cells come from data, because placing them by hand is
fine for one room and unbearable for twenty.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Fewer or more storeys of wall |
| P | Toggle the pillars |

The room itself is the `ROOM` constant at the top of `scripts/main.gd`. Edit the
drawing and the level changes.

## How It Works

**A MeshLibrary is a list of items.** `create_item(id)`, `set_item_mesh()`,
`set_item_name()`, `set_item_shapes()`. That is the whole resource. The editor's
"convert scene to MeshLibrary" produces exactly this, which is worth seeing once.

**Collision belongs to the library, not the map.** `set_item_shapes()` gives
every cell using that item a collider automatically — one shape defined once,
not one per cell. A library item with no shape produces a room the player walks
straight through, and nothing warns about it.

**Cells are integers, and `cell_size` is separate.** `set_cell_item(Vector3i, id)`
places by cell; `cell_size` decides how big a cell is in metres. Mixing the two
up — passing world coordinates to `set_cell_item` — puts one tile a hundred
cells away rather than two metres.

**The room is text.** `GridPlan.parse()` reads a `PackedStringArray` and a
legend into `{Vector3i: item_id}`. Rows run along +Z and columns along +X, so the
drawing reads the same way as the scene does from above. A character not in the
legend leaves the cell empty, which is how the doorway in the bottom wall is
made: it is a space.

**Centring an even room lands half a cell off.** `GridPlan.centred()` divides by
two with integer division, so a 2×2 room straddles the origin instead of sitting
on it. There is no middle cell in an even room; rounding instead would shift the
whole level by one cell, which is much harder to notice.

**Height is stacking.** `GridPlan.raised()` copies a plan up a level, so a
one-level drawing makes walls as tall as you like. The floor and the pillars
stay on the ground.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `GridMap.set_cell_item()` / `get_cell_item()` | Place and read a cell by integer coordinate |
| `GridMap.cell_size` | How big a cell is in metres |
| `GridMap.get_used_cells()` | Every cell that holds something |
| `MeshLibrary.create_item()` / `set_item_mesh()` | Building the tile set in code |
| `MeshLibrary.set_item_shapes()` | Per-item collision, applied to every cell using it |
| `Mesh.surface_set_material()` | Colouring a primitive mesh without a material file |

## Files

| File | What it holds |
|------|---------------|
| `scripts/grid_plan.gd` | The `GridPlan` component: parsing, centring, stacking, merging |
| `scripts/main.gd` | Demo driver: the MeshLibrary, the room drawing, and the painting |
| `scenes/main.tscn` | Camera, lights, and an empty GridMap for the driver to fill |
| `tests/test_logic.gd` | Headless test suite — including one that reads the real map |

## Use as a building block

**Copy:** `scripts/grid_plan.gd` — the `GridPlan` type. `scripts/main.gd` is the
demo driver, though its `_build_library()` is worth stealing separately.

**Public API**
- `GridPlan.parse(lines, legend, level := 0) -> Dictionary`
- `GridPlan.size_of(lines) -> Vector2i`
- `GridPlan.centred(cells, size) -> Dictionary`
- `GridPlan.cells_of(cells, item) -> Array[Vector3i]`
- `GridPlan.raised(cells, height) -> Dictionary`
- `GridPlan.merged(plans) -> Dictionary`
- `GridPlan.EMPTY` — the value `GridMap` uses for an empty cell

**Integrate**
1. Keep the drawings in text files under `res://levels/` rather than in the
   script; `FileAccess.get_file_as_string(path).split("\n")` is the whole loader.
2. Build the legend from your own item ids — `mesh_library.find_item_by_name()`
   if the library was authored in the editor.
3. `set_cell_item()` in a loop is fine for hundreds of cells. For tens of
   thousands, build the level once and leave it: `GridMap` batches by item, so
   the cost is in the changes, not in the size.

**Notes**
- `class_name GridPlan` is global to the project — rename it if you already
  define that type.
- `GridMap` supports 24 discrete orientations per cell via
  `set_cell_item(cell, id, orientation)`. A drawing can carry those too — one
  symbol per rotation of a corner piece is the usual approach.
- Nothing here is a substitute for the editor when you are placing tiles by
  hand. It is for levels that come from data: generated, downloaded, or edited
  as text.

## Related demos

- [multimesh](../multimesh) — Ten thousand instances in one draw call with MultiMeshInstance3D, and a distance cull that costs nothing.
- [terrain-collision](../terrain-collision) — A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

