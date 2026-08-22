# Screen Shader

<!-- tags: camera, shader, ui, component, shows-its-working -->

A shader that reads the screen behind it — refraction, fresnel, and the thing it cannot see.

## Purpose

`hint_screen_texture` is what glass, heat haze and cloaking are made of: sample
the frame behind this surface, offset it by something, draw that instead. It is
far cheaper than a second camera, and it comes with one hard limitation that
decides how you can use it:

**The screen it reads is the frame *before* this object was drawn.** So a
refracting object cannot see itself, cannot see another refracting object drawn
after it, and cannot see anything the depth prepass has not resolved. Two panes
of glass in a row is the case everyone tries first, and the second pane shows
the world without the first.

The maths is also here in GDScript, because a game that wants to *agree* with
what it is drawing — a bullet that bends where the glass bends it, a shimmer
that matches a damage radius — needs the same numbers on the CPU.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Less or more refraction |
| 3 / 4 | Roughness blur — frosted rather than clear |
| Space | Hold to stop the props moving |
| R | Defaults |

## How It Works

**The normal is the direction to bend in.** `NORMAL.xy` in view space: a surface
facing the camera has no sideways normal and so bends nothing, which is exactly
why glass looks like glass at its edges and like a window in the middle.

**Correct for aspect, or it stretches.** Without dividing the horizontal offset
by the aspect ratio, glass refracts further sideways than vertically on a wide
screen — and changes shape when the player resizes the window.

**`repeat_disable` on the sampler.** An offset that runs off the edge of the
screen wraps the far side of the frame into the glass otherwise, which looks
like a rendering bug and is a sampler flag.

**`depth_draw_never`.** The surface is a lens, not an object: writing depth over
what it is showing hides the thing behind it from everything drawn later.

**Fresnel is most of the look.** Edge-on, everything is a mirror; face-on, glass
is nearly invisible. Schlick's approximation is one `pow()` and it is the
difference between "transparent object" and "glass".

**`filter_linear_mipmap` buys the blur.** `textureLod()` with a level above zero
is frosted glass for free — but only if the sampler has mipmaps to reach for.

**The limitation is on screen.** The readout says which sphere can refract which,
because "can_refract" is a depth comparison and the answer is not symmetric.

**`SCREEN_TEXTURE` no longer exists.** Godot 4 spells it as a uniform with
`hint_screen_texture`; a shader copied from a 3.x tutorial compiles and samples
nothing. The suite asserts the hint is in the file, because that failure is
silent.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `sampler2D : hint_screen_texture` | Reading the frame behind this surface |
| `filter_linear_mipmap` / `repeat_disable` | Mipmaps for the blur; no wrapping at the screen edge |
| `render_mode depth_draw_never` | A lens rather than an object |
| `SCREEN_UV` / `NORMAL` / `VIEW` | Where to sample, which way to bend, how edge-on it is |
| `ShaderMaterial.set_shader_parameter()` | Driving the uniforms from the game |

## Files

| File | What it holds |
|------|---------------|
| `shaders/glass.gdshader` | The shader: offset, blur, fresnel |
| `scripts/refraction.gd` | The `Refraction` component: the same maths, where the game can use it |
| `scripts/main.gd` | Demo driver: two spheres, moving props, and the readout |
| `scenes/main.tscn` | Ground, props, and two glass spheres at different depths |
| `tests/test_logic.gd` | Headless test suite — the arithmetic, and the real material's uniforms |

## Use as a building block

**Copy:** `shaders/glass.gdshader` and `scripts/refraction.gd` together — the
shader is the effect, the component is how the game agrees with it.

**Public API**
- `Refraction.screen_offset(view_normal, strength) -> Vector2`
- `Refraction.aspect_corrected(offset, viewport) -> Vector2`
- `Refraction.fresnel(view_direction, normal, power := 5.0) -> float`
- `Refraction.apparent_position(screen_point, view_normal, strength, viewport) -> Vector2`
- `Refraction.can_refract(this_depth, other_depth) -> bool`
- `Refraction.strength_at(distance, base, fades_from := 8.0) -> float`

**Integrate**
1. Sort your transparent surfaces deliberately. Screen-reading shaders make
   render order visible, and Godot's default sorting is by distance to the
   object's origin — see [transparency-3d](../transparency-3d).
2. Fade the strength with distance. A large screen-space offset on something a
   few pixels across samples half the screen, and reads as noise.
3. Do not stack them. If two panes must both refract, one of them wants a
   `SubViewport` instead — which costs a whole extra render of the scene.
4. Check the Compatibility renderer if you ship to the web. Reading the screen
   costs a copy of the framebuffer there, and it is the difference between
   sixty frames and thirty on a phone.

**Notes**
- `class_name Refraction` is global to the project — rename it if you already
  define that type.
- Refraction here is a screen-space cheat, not physics. There is no index of
  refraction and no bending by depth: something a metre behind the glass is
  offset exactly as much as something twenty metres behind it.
- The blur is a mipmap level, so it is cheap and it is coarse. Frosted glass
  that has to look right at close range wants a real blur pass.
- See [wave-shader](../wave-shader) for the other half of this idea — a shader
  and the GDScript that agrees with it, so things can float on what it draws.

## Related demos

- [lod-and-decals](../lod-and-decals) — Distance bands that drive mesh LOD, decal fade and update rates — with the hysteresis that stops them flickering.
- [transparency-3d](../transparency-3d) — Why transparent objects draw in the wrong order, and the three ways out: sorting, scissor, and hash.
- [wave-shader](../wave-shader) — A water surface displaced in a shader, with the same wave maths in GDScript so things can float on it.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

