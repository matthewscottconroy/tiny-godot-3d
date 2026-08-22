# Volumetric Fog

<!-- tags: lighting, camera, ui, component, shows-its-working -->

Fog with light in it: the settings that make it appear, and the three reasons it usually does not.

## Purpose

Distance fog is a colour blended in by depth. It is cheap, and it cannot have a
light shaft in it, because nothing is actually *there*. Volumetric fog fills a
grid of froxels in front of the camera, marches light through it, and produces
shafts, glows and haze that respond to the lights in the scene.

It also has a reputation for doing nothing at all when switched on. The reasons
are always the same three, and all three are on screen here.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Thinner or thicker |
| 3 / 4 | Shorter or longer fog volume |
| S | Light shafts on or off |
| F | Volumetric fog on or off |
| R | Defaults |

## How It Works

**It is Forward+ only.** The Mobile and Compatibility renderers ignore the
setting — no warning, no fallback. The status line names the renderer, and the
suite asserts the project is on one that has the feature at all.

**The lights have to opt in.** `light_volumetric_fog_energy` is what makes a
light contribute to the fog volume. Without it the fog is a grey soup with no
shafts in it and nothing says why. Press S to see exactly that.

**The volume ends.** `volumetric_fog_length` is how far the froxel grid reaches
— 64 metres by default. Beyond it there is no fog at all, and on anything larger
than a room the seam is visible. The readout says how much of the volume the
furthest pillar is using; the pillars at 56 metres are there to make the edge
obvious when you shorten it.

**Extinction is exponential.** `transmittance()` is Beer-Lambert: twice the
distance lets through the *square* as much light, which is why doubling the
density does far more than halve the visibility. The suite asserts that
relationship rather than just the direction.

**Design in metres, not in density.** "You can see forty metres" is a decision;
`density_for()` turns it into the number the Environment wants.
`visibility()` turns it back, and the two round-trip.

**Height fog is what makes it weather.** `height_density()` thins the fog with
height so it reads as ground mist rather than a uniform soup — and it takes a
floor height, because the interesting mist sits in a valley or on a river rather
than at y = 0.

**Reaching further is cheap; more detail is not.** `froxel_count()` is an
order-of-magnitude number that tells "make the fog denser" apart from "make the
fog reach further" before you profile.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Environment.volumetric_fog_enabled` / `_density` / `_albedo` | The fog itself |
| `Environment.volumetric_fog_length` | How far the froxel grid reaches |
| `Light3D.light_volumetric_fog_energy` | The setting that puts shafts in it |
| `Environment.volumetric_fog_gi_inject` | Bounced light in the fog, for when the sun is not enough |
| `ProjectSettings` `rendering/renderer/rendering_method` | Whether any of this will be drawn |

## Files

| File | What it holds |
|------|---------------|
| `scripts/volumetrics.gd` | The `Volumetrics` component: extinction, visibility, height fog, cost |
| `scripts/main.gd` | Demo driver: the settings, a moving lamp, and the readout |
| `scenes/main.tscn` | Pillars marching away into the distance, a sun, and a lamp |
| `tests/test_logic.gd` | Headless test suite — the model, and the real Environment's settings |

## Use as a building block

**Copy:** `scripts/volumetrics.gd` — the `Volumetrics` type. `scripts/main.gd`
is the demo driver.

**Public API**
- `Volumetrics.transmittance(density, distance) -> float`
- `Volumetrics.visibility(density, threshold := 0.05) -> float`
- `Volumetrics.density_for(visible_distance, threshold := 0.05) -> float`
- `Volumetrics.height_density(base, height, floor_height := 0.0, falloff := 6.0) -> float`
- `Volumetrics.supported(rendering_method) -> bool`
- `Volumetrics.within_volume(distance, volume_length) -> float`
- `Volumetrics.froxel_count(resolution, depth_slices) -> int`

**Integrate**
1. Set the density from a visibility distance, not by eye. The number that
   matters to a level is "how far can you see", and it is the one you can
   discuss with a designer.
2. Check the renderer at startup and fall back to distance fog. On Mobile the
   volumetric settings do nothing, and a level lit for fog looks wrong without
   it — see [environment-fog](../environment-fog) for the cheap version.
3. Give lights a volumetric energy deliberately. Every light contributing to the
   fog is more work, and most of them do not need to.
4. Keep the volume as short as the level allows. The far edge is the artefact
   people see first, and the fix is usually to fade the fog out before it
   rather than to extend the grid.

**Notes**
- `class_name Volumetrics` is global to the project — rename it if you already
  define that type.
- The maths here is the physical model the renderer approximates, not what it
  does exactly. Use it to choose numbers, not to predict pixels.
- `volumetric_fog_gi_inject` is what makes fog pick up bounced light. It is off
  by default and it is the difference between a shaft and a lit room.
- Fog is a compositing decision as much as a lighting one: see
  [transparency-3d](../transparency-3d) for what it does to glass, and
  [lights-and-shadows](../lights-and-shadows) for the budget the lights come out
  of.

## Related demos

- [environment-fog](../environment-fog) — A day-night cycle driven by a WorldEnvironment: sun angle, sky, ambient light and fog from one clock.
- [wave-shader](../wave-shader) — A water surface displaced in a shader, with the same wave maths in GDScript so things can float on it.
- [lights-and-shadows](../lights-and-shadows) — The three 3D light types side by side, and a shadow budget that keeps the expensive ones near the camera.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

