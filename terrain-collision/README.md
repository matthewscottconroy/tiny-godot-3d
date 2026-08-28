# Terrain Collision

<!-- tags: physics, mesh, ui, procedural, component, shows-its-working -->

A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.

## Purpose

`HeightMapShape3D` is the cheap way to collide with terrain: no triangles, no
acceleration structure, just a grid of heights and some arithmetic. A trimesh
collider built from the same terrain costs far more memory and is slower to
query.

It has one property that catches everybody. **Its samples are one unit apart,
always.** There is no spacing parameter. A 65×65 height map is 64 units across,
and if your terrain mesh is 80 metres across you must scale the collision body
to match. Nothing warns you. The collider simply covers different ground from
the mesh, and things land in mid-air or sink to their knees — which reads as a
physics bug rather than as a units bug, and gets debugged in the wrong place.

## Controls

| Key | Action |
|-----|--------|
| Space | Drop a ball |
| W | Use the wrong scale — one unit per sample |
| R | Clear the balls |

With the correct scale the balls sit on the hills. Press `W` and drop more:
they land on a landscape that is a quarter of the size, in the middle of the
one you can see.

## How It Works

**One height function, two consumers.** The mesh and the height map are both
built by calling `_height()`. Anything else — sampling noise twice, or building
the collider from the mesh — is two subtly different landscapes waiting to
diverge, and only one of them is the one you can see.

**Cells versus samples.** Eight cells is nine samples along each edge.
`map_width` and `map_depth` are sample counts, and using the cell count shrinks
the collider by exactly one cell — a strip of missing ground along two edges.

**The grid is row-major, depth outermost.** `data[z * side + x]`. Transposing it
puts the hills where the valleys are, which is entirely plausible-looking and
collides wrongly everywhere.

**`scale_for(spacing)` is the line everyone leaves out.** The body scales by the
spacing on X and Z, and by **one** on Y — the heights are already in metres, and
scaling them too makes the terrain taller as well as wider.

**`sample()` is how you check the two agree.** It reads a height back out of the
grid by world position, bilinearly. The suite compares it against the source
function at twenty-five points, and that assertion caught a real bug while this
demo was being written: the second row of the bilinear interpolation used the Z
weight instead of the X one, which agrees with the source along the diagonals
and nowhere else.

**And the test drops a real ball.** It falls, settles, and its resting height is
compared with the height function. That is the property the whole demo is about,
and it is checkable without looking at anything.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `HeightMapShape3D.map_width` / `map_depth` / `map_data` | The collider: sample counts and a flat array of heights |
| `Node3D.scale` on the collision body | Turning one-unit samples into metres |
| `SurfaceTool` | The visible mesh, built from the same heights |
| `FastNoiseLite.get_noise_2d()` | The terrain itself |
| `RigidBody3D` | The balls that prove the alignment |

## Files

| File | What it holds |
|------|---------------|
| `scripts/height_field.gd` | The `HeightField` component: the grid, the shape, the scale, and sampling back |
| `scripts/main.gd` | Demo driver: the mesh, the collider, and the droppable balls |
| `scenes/main.tscn` | A camera, a sun, and an empty terrain for the driver to fill |
| `tests/test_logic.gd` | Headless test suite — including a real ball landing on real terrain |
| `tests/frames` | How many frames the suite needs, since a ball has to fall |

## Use as a building block

**Copy:** `scripts/height_field.gd` — the `HeightField` type. `scripts/main.gd`
is the demo driver and is not needed.

**Public API**
- `HeightField.build(cells, spacing, height: Callable) -> PackedFloat32Array`
- `HeightField.shape_for(cells, spacing, height) -> HeightMapShape3D`
- `HeightField.scale_for(spacing) -> Vector3`
- `HeightField.at(data, side, x, z) -> float`
- `HeightField.sample(data, side, spacing, world_x, world_z) -> float`
- `HeightField.extent(data) -> Vector2`

**Integrate**
1. Build the mesh and the shape from the same function, in the same order. If
   they ever disagree, the visible terrain is the one that is wrong, because it
   is not the one physics uses.
2. Scale the *body*, not the shape. `HeightMapShape3D` has no size of its own;
   the transform of whatever holds it is the only place the scale can live.
3. For a streamed world, one height map per chunk with the same spacing — see
   [level-streaming](../level-streaming). The seams line up automatically
   because both chunks sample the same function.

**Notes**
- `class_name HeightField` is global to the project — rename it if you already
  define that type.
- Height maps cannot represent overhangs, caves or arches: one height per column,
  by definition. Those need a separate collider — usually a convex shape or a
  trimesh for the specific piece of geometry.
- `create_trimesh_collision()` on the mesh is quicker to write and much more
  expensive to keep. It is the right answer for a small, fixed piece of level
  and the wrong one for terrain.

## Related demos

- [terrain-splatting](../terrain-splatting) — Texturing terrain by slope and height, with weights that add up and edges that do not band.
- [grid-map](../grid-map) — Level building with GridMap and a MeshLibrary made in code, from a room drawn as text.
- [noise-terrain](../noise-terrain) — A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

