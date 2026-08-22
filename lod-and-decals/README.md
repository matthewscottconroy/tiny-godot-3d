# LOD and Decals

<!-- tags: mesh, lighting, camera, ui, component, shows-its-working -->

Distance bands that drive mesh LOD, decal fade and update rates — with the hysteresis that stops them flickering.

## Purpose

Level of detail is one idea used for several things: which mesh to draw, how
often to run an AI, whether a decal is worth rendering, whether a light casts a
shadow. They are all the same question — *how far away is this?* — and they all
have the same failure mode.

A camera sitting exactly on a boundary switches back and forth every frame. The
mesh pops, the decal strobes, the AI runs at two different rates in alternate
frames. It is the most visible LOD bug there is, it is nearly impossible to
reproduce on purpose, and the fix is one line: to change level you have to go a
little *past* the boundary, not merely reach it.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Move the camera nearer or further |
| 3 / 4 | Less or more hysteresis |
| Space | Stop the camera moving |

The status line shows one digit per prop — the level each one is on. Drop the
hysteresis to zero and park the camera on a boundary to watch the digits
chatter.

## How It Works

**The engine does the mesh switching.** Each prop carries all three meshes at
once, with `visibility_range_begin` and `visibility_range_end` set from the
bands. Godot hides and shows them by distance; there is no per-frame code for
the switch at all.

**`VISIBILITY_RANGE_FADE_SELF` is what makes it not a pop.** Without a fade mode
the swap is instantaneous and visible. With one, the outgoing mesh dissolves as
the incoming one appears — which is most of what separates LOD you notice from
LOD you do not.

**Ranges are contiguous by construction.** `range_for(level)` starts each band
where the previous one ended, and the suite checks the whole chain lines up: a
gap between two ranges is a distance at which the prop is simply invisible.

**Zero means "no far limit".** The last level's `visibility_range_end` is 0,
which Godot reads as unlimited. A number there instead is the version where
distant things vanish over a cliff edge.

**Hysteresis is per direction.** Moving away, you must pass `boundary +
margin`; coming closer, `boundary − margin`. The suite drives a camera wobbling
across a boundary two hundred times and asserts the level changes at most once.

**Decals fade rather than switch.** `distance_fade_begin` and
`distance_fade_length`, from the same bands. The eye notices a thing
*disappearing* far more than it notices one becoming faint — and a decal is a
projection, so it costs real time to render whether you can see it or not.

**The same bands drive the invisible half.** `update_interval()` doubles per
level: an enemy fifty metres away does not need its state machine run sixty
times a second. That is LOD too, and it is usually a bigger saving than the
meshes.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `GeometryInstance3D.visibility_range_begin` / `_end` | The distances a mesh is drawn between |
| `GeometryInstance3D.visibility_range_fade_mode` | Dissolving between levels instead of popping |
| `Decal.distance_fade_begin` / `distance_fade_length` | Fading a projection out with distance |
| `Decal.size` / `texture_albedo` | The box a decal projects within, and what it projects |
| `SphereMesh.radial_segments` / `rings` | Three meshes of decreasing detail, built in code |

## Files

| File | What it holds |
|------|---------------|
| `scripts/lod_bands.gd` | The `LodBands` component: levels, hysteresis, ranges, fade, update rates |
| `scripts/main.gd` | Demo driver: the props, the ranges, and the moving camera |
| `scenes/main.tscn` | A long strip of ground, a decal, and the camera |
| `tests/test_logic.gd` | Headless test suite — including the ranges on the real meshes |

## Use as a building block

**Copy:** `scripts/lod_bands.gd` — the `LodBands` type. `scripts/main.gd` is the
demo driver and is not needed.

**Public API**
- `level_for(distance) -> int` — the naive answer
- `stable_level_for(distance, current) -> int` — the one to use
- `range_for(level) -> Vector2`, `ranges() -> Array[Vector2]`
- `LodBands.fade_alpha(distance, end, length) -> float`
- `update_interval(level, base := 1.0/60.0) -> float`
- `distances`, `hysteresis`

**Integrate**
1. Set the visibility ranges once, when the object is built, and let the engine
   do the switching. `stable_level_for()` is for the things it cannot switch for
   you.
2. Keep the same bands for everything — meshes, decals, AI, shadows. Separate
   sets of numbers per system is how a game ends up with an enemy whose mesh has
   simplified but whose shadow has not.
3. Measure before adding levels. Three levels and a fade cost memory and build
   time; if the far mesh is never on screen for long, one level and a distance
   cull is the better trade.

**Notes**
- `class_name LodBands` is global to the project — rename it if you already
  define that type.
- Godot can generate mesh LODs automatically on import for real models. This
  demo builds three spheres by hand because it ships no assets — the mechanism
  it demonstrates is the same one the imported LODs use.
- Decals are not free: each one is a projection rendered over whatever it
  touches. Fading them out is a real saving, not a cosmetic one.

## Related demos

- [screen-shader](../screen-shader) — A shader that reads the screen behind it — refraction, fresnel, and the thing it cannot see.
- [animation-in-code](../animation-in-code) — Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk.
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [level-streaming](../level-streaming) — Loading and freeing chunks around a moving player, with the keep-radius that stops them thrashing at a boundary.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

