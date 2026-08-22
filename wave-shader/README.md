# Wave Shader

<!-- tags: shader, ui, component, shows-its-working -->

A water surface displaced in a shader, with the same wave maths in GDScript so things can float on it.

## Purpose

A vertex shader can move a surface beautifully and cannot tell anyone where it
went. The GPU has the answer; the CPU needs it. A boat has to sit on the water,
a buoy has to bob, a splash has to happen at the surface rather than at `y = 0` —
and none of that can ask the shader.

So the maths exists twice, in GLSL and in GDScript. That duplication is the
honest cost of vertex displacement, and pretending otherwise is how you get a
boat that hovers above the waves.

What the demo is really about is containing the risk. **Neither copy owns the
numbers.** `WaveField` does, and `apply_to()` pushes them into the shader as
uniforms — including the clock. The two can differ in language; they cannot
differ in configuration, which is the drift that actually happens.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Calmer or rougher swell |
| Space | Freeze time |

Freeze it and look at the buoys: they sit exactly on the frozen surface, because
both sides stopped at the same instant.

## How It Works

**A sum of directional sines.** Each wave has an amplitude, a wavelength, a
speed and a direction; the height at a point is the sum of `sin(d·p·k + t·s·k)`
over all of them. Three waves at different scales and angles is enough to stop
the result looking like corrugated iron. Real water uses Gerstner waves, which
also move points *horizontally* into sharper crests — the same structure, more
maths, harder to float things on.

**The clock is a uniform, not `TIME`.** Using the shader's built-in `TIME` would
mean the two copies read two different clocks: they drift, and pausing moves the
water out from under everything on it. The CPU owns the time and sends it, which
is also what makes the freeze work.

**Normals have to move too.** Displacing vertices without recomputing `NORMAL`
leaves the lighting flat, and the whole effect reads as a texture rather than a
surface. The shader samples the height either side of each vertex, exactly as
`WaveField.normal_at()` does — the same trick as
[noise-terrain](../noise-terrain).

**Subdivision is what you are actually paying for.** A `PlaneMesh` displaced in
a vertex shader can only bend where it has vertices. 80×80 subdivisions here;
one big quad would stay perfectly flat no matter what the shader says.

**The suite checks the seam, not the shader.** A headless run has no GPU, so the
shader cannot be executed. What it can check is that every uniform the material
holds matches the field it came from, and that the GDScript side behaves the way
the GLSL is written to — periodicity, direction, crest height, determinism.

**The shader still gets compiled.** Even headless, Godot parses and compiles the
shader when the material loads, so a syntax error or a redefinition fails the
smoke check like any other broken script. That is how the name clash between the
`time` uniform and a function parameter of the same name was found here.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `shader_type spatial` / `void vertex()` | Displacing geometry on the GPU |
| `NORMAL` in the vertex stage | Keeping the lighting attached to the new shape |
| `ShaderMaterial.set_shader_parameter()` | Sending the field's numbers to the shader |
| `ShaderMaterial.get_shader_parameter()` | Reading them back, which is what the suite asserts on |
| `PlaneMesh.subdivide_width` / `subdivide_depth` | Giving the surface vertices to bend at |
| `Basis(x, y, z)` | Leaning a buoy along the surface normal |

## Files

| File | What it holds |
|------|---------------|
| `shaders/water.gdshader` | The GPU half: displacement, normals, depth-tinted colour |
| `scripts/wave_field.gd` | The `WaveField` component: the same maths in GDScript, and `apply_to()` |
| `scripts/main.gd` | Demo driver: one field, feeding the shader and the buoys |
| `scenes/main.tscn` | The water plane, four buoys, a camera and the HUD |
| `tests/test_logic.gd` | Headless test suite — including the uniforms-match-the-field check |

## Use as a building block

**Copy:** `scripts/wave_field.gd` and `shaders/water.gdshader` — they are two
halves of one thing and neither is much use alone.

**Public API**
- `WaveField.new(preset := true)`, `waves: Array[Wave]`, `swell: float`
- `height_at(x, z, time) -> float`, `normal_at(x, z, time, step := 0.25) -> Vector3`
- `crest_height() -> float`
- `apply_to(material: ShaderMaterial)`
- `WaveField.parameters_of(material) -> Dictionary`
- `WaveField.Wave.new(amplitude, wavelength, speed, direction)`

**Integrate**
1. Set every parameter on the field and call `apply_to()`. Never call
   `set_shader_parameter()` for a wave value anywhere else — the moment two
   places can set it, they will disagree.
2. Send the same time value you use on the CPU. One clock.
3. For buoyancy rather than bobbing, sample `height_at()` at two or three points
   under the hull and apply forces from the differences; a single sample gives
   you a boat that floats but never rolls.

**Notes**
- `class_name WaveField` is global to the project — rename it if you already
  define that type.
- `MAX_WAVES` in the shader is a compile-time array size, and GDScript cannot
  exceed it. Four here; raising it costs nothing until the loop actually runs.
- A shader cannot be unit-tested from GDScript. The nearest honest thing is
  what this does: test the CPU copy, and assert that both copies were configured
  from the same source.

## Related demos

- [transparency-3d](../transparency-3d) — Why transparent objects draw in the wrong order, and the three ways out: sorting, scissor, and hash.
- [volumetric-fog](../volumetric-fog) — Fog with light in it: the settings that make it appear, and the three reasons it usually does not.
- [screen-shader](../screen-shader) — A shader that reads the screen behind it — refraction, fresnel, and the thing it cannot see.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

