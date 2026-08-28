# Terrain Splatting

<!-- tags: mesh, shader, ui, procedural, component, shows-its-working -->

Texturing terrain by slope and height, with weights that add up and edges that do not band.

## Purpose

Hand-painting a texture map is what you do when the terrain is authored.
Generated terrain has to decide for itself, and the rule is almost always the
same: sand at the water line, grass where it is flat, rock where it is steep,
snow up high — with rock winning over everything, because a cliff is a cliff
whatever altitude it is at.

The weights are computed on the CPU and baked into the mesh's vertex colours, so
the shader mixes exactly what the game decided. A footstep sound that disagrees
with what the player can see is worse than no footstep sound.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Lower or raise the water line |
| 3 / 4 | Lower or raise the snow line |
| 5 / 6 | How steep counts as a cliff |
| R | Defaults |

## How It Works

**Slope comes from the normal, not from the height.** Two points at the same
height can be a plateau or a cliff face, and the height alone cannot tell you
which. `slope_of()` is the angle between the surface normal and up.

**The normal comes from the height function, not from the mesh.** Sampling
either side is cheaper, smoother, and available to the game logic — which has no
mesh to read when it needs to know what the player is standing on.

**Bands need a width.** A hard cutoff at 12 metres draws a line around the hill
at 12 metres. `band()` is a `smoothstep`, and real transitions are metres deep.

**Rock suppresses the others rather than competing with them.** Without that, a
sea cliff comes out half sand: the two rules tie at the water line and which one
wins is down to the order they happen to be compared in. The suite caught
exactly that.

**The weights have to add up to one.** Four materials each contributing 0.6 is a
surface 2.4 times too bright, and the error is worst precisely where two bands
meet — the transition you were trying to smooth. The suite checks every vertex
of the real mesh, not a sample, because one bad vertex is one bright speck and
nobody notices those in review.

**The fallback is a safety net that should never fire.** A point nothing claims
falls back to grass rather than to black. That hid a real bug once — a broken
rule still produced "grass", and the assertion passed. There is now a separate
test that sweeps the whole height-and-slope range and asserts *something* claims
every part of it.

**One answer, as well as four.** `dominant()` is what a footstep sound, a
particle effect or a readout needs, and it comes from the same weights the
surface is drawn with.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `SurfaceTool.set_color()` | Carrying per-vertex weights into the mesh |
| `COLOR` in a spatial shader | Reading them back out to mix materials |
| `smoothstep()` | Bands with a width instead of contour lines |
| `FastNoiseLite` | The terrain the rule is applied to |
| `ArrayMesh.surface_get_arrays()` | How the suite reads the weights back |

## Files

| File | What it holds |
|------|---------------|
| `shaders/terrain.gdshader` | Four materials mixed by vertex colour |
| `scripts/splat.gd` | The `Splat` component: slope, bands, weights, normalisation |
| `scripts/main.gd` | Demo driver: the terrain, the weights, and a wandering probe |
| `scenes/main.tscn` | Sky, sun, and the mesh to fill in |
| `tests/test_logic.gd` | Headless test suite — including every vertex of the real mesh |

## Use as a building block

**Copy:** `scripts/splat.gd` and `shaders/terrain.gdshader` together — the rule
and the shader that draws it.

**Public API**
- `Splat.slope_of(normal) -> float`
- `Splat.band(value, from, to) -> float`
- `Splat.raw_weights(height, slope, water_line, snow_line, cliff) -> Color`
- `Splat.normalise(weights) -> Color`
- `Splat.weights_for(height, slope, water_line, snow_line, cliff) -> Color`
- `Splat.dominant(weights) -> int`, `Splat.material_name(index) -> String`

**Integrate**
1. Swap the four flat colours for four textures and sample them with the same
   weights. Nothing about the rule changes; only the shader's `fragment()` grows.
2. Keep the rule on the CPU. The moment the shader has its own copy, the ground
   the player hears and the ground they see start to drift apart.
3. Vertex colours are per-vertex, so the transitions are as fine as the mesh is.
   For sharper edges than the topology allows, move the weights into a texture
   the shader samples by UV.
4. Add slope-aware detail last. Triplanar mapping on the rock is what stops
   cliffs looking stretched, and it costs three samples instead of one.

**Notes**
- `class_name Splat` is global to the project — rename it if you already define
  that type.
- Four materials is what fits in one `Color`. More than that wants a second
  vertex attribute or a splat texture, and the normalisation has to cover all of
  them together.
- The height thresholds here are absolute metres. A world with several biomes
  wants them driven by something else — a moisture map, a region index — and the
  same normalisation applies.
- See [noise-terrain](../noise-terrain) for the heightmap itself and
  [terrain-collision](../terrain-collision) for standing on it.

## Related demos

- [noise-terrain](../noise-terrain) — A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change.
- [terrain-collision](../terrain-collision) — A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.
- [procedural-mesh](../procedural-mesh) — Building geometry with `SurfaceTool`: vertices, winding order, indices, and normals.
- [accessibility-3d](../accessibility-3d) — Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

