# Noise Terrain

<!-- tags: mesh, camera, ui, procedural, component, shows-its-working -->

A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change.

## Purpose

Generated terrain is the point at which `procedural-mesh`'s height callback
stops being a demo parameter and starts being the level. Getting a hilly mesh on
screen is the easy half; the half that bites is that **something else always
needs to know the ground height** — where to put the player, where a tree stands,
where a footprint goes — and that query is usually written as a second piece of
code that samples the noise again.

Then the two drift. A factor here, an offset there, and everything placed on the
terrain hovers half a metre above it or sinks into it. Nothing errors.

So this demo has exactly one height function, and the mesh is built by calling
it. The suite asserts that every vertex of the built mesh sits where that
function says the ground is, which is the invariant everything else rests on.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Fewer or more cells per side |
| 3 / 4 | Lower or higher hills |
| N | Next seed — a new landscape |
| Space | Pause the orbiting camera |

The marker walking a circle over the hills is standing on `height_at()`. If it
ever floats, the mesh and the query have disagreed.

## How It Works

**Noise is sampled as a feature size, not a frequency.** `FastNoiseLite` has a
`frequency` in cycles per unit, which is hard to picture. Dividing the sample
coordinates by a `feature_size` instead means the parameter reads as "hills
about eighteen metres across", which is a number you can choose deliberately.

**Amplitude is in metres.** The noise comes back in roughly −1..1, so multiplying
by an amplitude gives a height with units. The suite checks that no point
exceeds it, and that three times the amplitude is three times the height
everywhere — a scale bug that only shows at the extremes otherwise.

**Normals are sampled, not read off the mesh.** `normal_at()` takes the
difference either side of a point and builds a vector from the two slopes. That
makes the surface orientation available anywhere, without hunting for the
triangle underneath — the demo uses it to lean the marker with the hill.

**Regions are height *and* slope.** Water, sand and grass come from altitude;
rock comes from steepness. Colouring by height alone is what puts grass on a
vertical cliff face, and it looks wrong immediately even though nothing is
broken.

**The colour is in the vertices.** `SurfaceTool.set_color()` per vertex, plus a
`StandardMaterial3D` with `vertex_color_use_as_albedo`. No textures, no
splatmap, no UV work — enough to read the terrain at a glance, and it costs
nothing.

**Normals for shading are generated from the geometry.** `generate_normals()`
rather than `normal_at()`, deliberately: the shading should match the triangles
that were actually built, including the flattening a low resolution introduces.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `FastNoiseLite.get_noise_2d()` | The heightmap itself |
| `FastNoiseLite.seed` / `fractal_octaves` | A new landscape; how much detail it has |
| `SurfaceTool.set_color()` | Per-vertex colour, used as albedo |
| `SurfaceTool.generate_normals()` | Shading normals derived from the built triangles |
| `ArrayMesh.get_aabb()` | Checking the mesh spans what was asked for |
| `Basis(x, y, z)` | Standing the marker up along the surface normal |

## Files

| File | What it holds |
|------|---------------|
| `scripts/terrain_field.gd` | The `TerrainField` component: heights, normals, regions, and the mesh |
| `scripts/main.gd` | Demo driver: rebuilding, the orbit, and the marker on the ground |
| `scenes/main.tscn` | Camera, sun, the terrain, and the vertex-colour material |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/terrain_field.gd` — the `TerrainField` type.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `TerrainField.new(seed_value: int)`, `set_seed()`, `seed_value()`
- `height_at(x, z) -> float`, `normal_at(x, z, step := 0.5) -> Vector3`
- `slope_at(x, z, step := 0.5) -> float`, `region_at(x, z) -> int`
- `build_mesh(size, resolution) -> ArrayMesh`
- `TerrainField.counts(resolution) -> Dictionary`, `TerrainField.colour_of(region)`
- `amplitude`, `feature_size`

**Integrate**
1. Place things with `height_at()` and orient them with `normal_at()`. Never
   sample the noise a second time — that is the drift this is shaped to prevent.
2. For collision, add a `CollisionShape3D` with a
   `HeightMapShape3D`, or `create_trimesh_collision()` on the `MeshInstance3D`
   for a static level. The mesh alone collides with nothing.
3. Chunk it for anything large: one mesh per 64 metres, built around the player.
   `build_mesh()` takes a size and a centre-relative grid, so a chunked version
   is an offset added to the sample coordinates.

**Notes**
- `class_name TerrainField` is global to the project — rename it if you already
  define that type.
- Resolution is quadratic. 128 cells is 16,641 vertices per chunk, and rebuilding
  that every frame will show; rebuild on change, not on tick.
- `TYPE_SIMPLEX_SMOOTH` with four octaves is a reasonable default for ground.
  Ridged or billowy fractals give mountains and dunes respectively, and both are
  one property away.

## Related demos

- [terrain-collision](../terrain-collision) — A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.
- [procedural-mesh](../procedural-mesh) — Building geometry with `SurfaceTool`: vertices, winding order, indices, and normals.
- [accessibility-3d](../accessibility-3d) — Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.
- [camera-shake-3d](../camera-shake-3d) — Camera shake as an offset a rig can carry, with trauma that decays and noise that is the same every run.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

