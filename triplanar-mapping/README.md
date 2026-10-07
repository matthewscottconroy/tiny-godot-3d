# Triplanar Mapping

<!-- tags: mesh, camera, shader, ui, component, shows-its-working -->

Texturing a cliff without the vertical smearing a flat UV gives it, by projecting from three axes and blending on the normal.

## Purpose

A heightmap terrain almost always takes its UVs from world X and Z. That is the
obvious choice, it is trivial to generate, and it is correct right up until the
ground stands up. A vertical face has almost no extent in X or Z, so a sliver of
the texture is stretched down the entire height of it — the melted-candle look
that every generated terrain has somewhere in it, and the reason cliffs are the
first thing to give away that a landscape was made by a heightmap.

Triplanar mapping stops deriving coordinates from the surface at all. It
projects the texture three times from world position — along X, along Y, along Z
— and blends the three by how much the surface faces each axis. The cliff is
drawn by a projection that can see its height, so there is nothing to stretch.

It is also the standard answer for anything without usable UVs at all: CSG
output, marching-cubes meshes, procedural rock, a `GridMap` assembled from tiles
that were never unwrapped together.

## Controls

| Key | Action |
|-----|--------|
| Space | Switch between the terrain's flat UVs and the triplanar projection |
| 1 / 2 | Texture scale |
| 3 / 4 | Blend sharpness |
| Arrow keys | Move the probe along the ridge and read the numbers at that slope |
| R | Reset |

Press Space on the steep face and watch the smear disappear. The readout gives
the stretch as a number: `1.0` on the flat, unbounded on the wall.

## How It Works

**The ridge is deliberately steep.** A gentle hill stretches a top-down UV by a
few percent, which teaches nothing — the comparison the demo rests on only shows
up when the ground approaches vertical. `smoothstep` across a narrow band gives
sides steep enough to matter, and the suite fails if they ever stop being.

**A flat UV stretches by `1 / |normal.y|`.** A top-down projection covers
`|normal.y|` of a surface's true area per unit of texture, so that is the factor
by which the texture has to stretch to cover the rest. One on flat ground, root
two at 45°, and unbounded as the face approaches vertical. `stretch_factor()`
clamps it, because infinity is not something to put on a HUD.

**Three projections, each dropping the axis it looks along.** The X projection
reads world Z and Y, the Y projection reads X and Z, the Z projection reads X
and Y. That is why nothing stretches: the wall is sampled by a projection that
still sees its full height.

**The blend is the normal, raised to a power.** Take `abs(normal)`, raise each
component to `sharpness`, divide by the total so the three sum to one. They have
to sum to one — three samples averaged by weights that do not come out darker or
brighter than the texture, which reads as bad lighting rather than as a bug.
`sharpness` decides how quickly one projection takes over from another: at 1 the
blend is a broad wash, and high values tighten it towards a hard seam.

**At exactly 45° the split is even whatever the sharpness.** Two projections are
equally valid there, so the weights are equal by construction. Sharpness shows
up just off 45°, which is where a demo that only tested the symmetric case would
have nothing to say.

**The CPU and the shader do the same arithmetic on purpose.** The weights are in
`scripts/triplanar_mapping.gd` as well as the shader so a suite can state them,
and so anything on the CPU that has to agree with what is drawn can ask the same
question — a footstep sound choosing a surface, a decal choosing an orientation.
A footstep that disagrees with what the player can see is worse than none.

**It costs three samples instead of one.** That is the whole reason this is not
simply the default. `needs_triplanar()` is the judgement an adopter actually has
to make, and on a surface that is nearly flat the answer is no.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `ShaderMaterial.set_shader_parameter()` | Driving the shader from the demo's state |
| `varying` | Handing world position and normal from the vertex stage to the fragment stage |
| `MODEL_MATRIX` | Turning a local vertex into the world position the projections read |
| `SurfaceTool.generate_normals()` | The normals the blend weights are computed from |
| `smoothstep()` | The narrow band that makes the ridge steep rather than rolling |

## Files

| File | What it holds |
|------|---------------|
| `scripts/triplanar_mapping.gd` | The `Triplanar` component: blend weights, projections, and what a flat UV costs |
| `shaders/triplanar.gdshader` | The same blend in the fragment stage, with a flat-UV mode to compare against |
| `scripts/main.gd` | Demo driver: builds the ridge, owns the toggles and the readout |
| `scenes/main.tscn` | Camera, light, the generated terrain and the probe marker |
| `tests/test_logic.gd` | Headless test suite — including a check that the ridge is genuinely steep |
| `tests/frames` | How many frames the suite needs, since it inspects a generated mesh |

## Use as a building block

**Copy:** `scripts/triplanar_mapping.gd` and `shaders/triplanar.gdshader`.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `Triplanar.weights(normal, sharpness := 4.0) -> Vector3` — the three blend weights, summing to one
- `Triplanar.dominant_axis(normal) -> int` — 0 for X, 1 for Y, 2 for Z
- `Triplanar.planar_uv(world_position, axis, scale := 1.0) -> Vector2`
- `Triplanar.stretch_factor(normal, limit := 99.0) -> float`
- `Triplanar.needs_triplanar(normal, tolerance := 1.3) -> bool`

**Integrate**
1. Put the shader on the mesh and feed it `texture_scale` and `sharpness`.
2. Swap the checker for your own texture. Sample it three times with the world
   coordinates above; a single tiling texture is what this is for, since the
   projections have to agree where they meet.
3. Keep the sharpness in one place if anything on the CPU also asks
   `weights()` — the two answers only match while the number does.

**Notes**
- `class_name Triplanar` is global to the project — rename it if you already
  define that type.
- Scale is in world units, not UV units, which is the point: two meshes at the
  same scale line up across the join whether or not they were unwrapped
  together.
- Normal mapping needs more than this. A tangent-space normal map sampled three
  ways has to be reoriented per projection, or the lighting fights the geometry.
  The albedo case here is the one worth showing first.
- See [terrain-splatting](../terrain-splatting) for choosing *which* material a
  point is, which is the question this one does not answer — the two compose:
  splatting picks the texture, triplanar decides how it is projected.

## Related demos

- [terrain-collision](../terrain-collision) — A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.
- [terrain-splatting](../terrain-splatting) — Texturing terrain by slope and height, with weights that add up and edges that do not band.
- [noise-terrain](../noise-terrain) — A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change.
- [procedural-mesh](../procedural-mesh) — Building geometry with `SurfaceTool`: vertices, winding order, indices, and normals.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

