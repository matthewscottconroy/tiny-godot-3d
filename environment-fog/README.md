# Environment and Fog

<!-- tags: lighting, ui, component, shows-its-working -->

A day-night cycle driven by a WorldEnvironment: sun angle, sky, ambient light and fog from one clock.

## Purpose

A 3D scene with correct geometry, correct materials and one directional light
still looks like nothing. What makes it look like *somewhere* is the
`WorldEnvironment`: ambient light, sky colour, fog. Those are a dozen properties
that have to move together, and the usual way they get moved together is a
hundred lines of `lerp` inside `_process` that nobody can check and nobody dares
change.

This demo puts all of it behind one number — the hour — with each property as a
named curve. "The sun is up at 6am", "ambient never reaches zero", "dawn and
dusk are symmetric" then stop being things you squint at and become assertions.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Wind the clock back or forward an hour |
| 3 / 4 | Slow down or speed up time |
| Space | Stop the clock |
| F | Fog on or off |

## How It Works

**One clock in, every property out.** `SkyCycle` is entirely static functions of
the hour: `sun_height()`, `sun_direction()`, `sun_energy()`, `sun_colour()`,
`ambient_energy()`, `fog_density()`, `horizon_colour()`. The driver reads them
and assigns. Nothing in the driver decides anything, so a sunset that looks wrong
is wrong in one testable place.

**No state at all.** The cycle holds nothing between calls, which means the sky
at 3am tomorrow is exactly the sky at 3am today, a save file only has to store
the clock, and rewinding time is free.

**The sun moves on a cosine.** A triangle wave gives a sun that crosses the sky
at constant speed; a cosine slows it near noon and hurries it at the horizon,
which is why real middays are long and real sunsets are brief.

**Light energy is not a switch.** Sunrise ramps over three hours centred on 6am
and sunset does the same in reverse. The suite checks those ramps are symmetric —
an off-by-one in one of them shows up only as "dusk feels wrong somehow".

**Sunlight reddens near the horizon.** Real light goes orange low in the sky
because it passes through more atmosphere. Blending toward orange as the sun
drops is most of what makes a sunset read as one, and the same colour bleeds into
the sky and the fog through `horizon_colour()`.

**Ambient light never reaches zero.** A midnight with no ambient is not dark, it
is invisible, and players read a black screen as the game having failed to load.
The floor here is 0.08.

**Fog is a night thing.** It thickens overnight and burns off by day. Fog also
does the job of hiding the far plane, which is why the towers march off into the
distance — with fog off (`F`) they end abruptly at nothing.

**A dark sun still costs a shadow pass.** `light_energy = 0` does not stop the
shadow map being rendered. The driver switches `shadow_enabled` off with the
sun, which is free and saves the whole pass overnight.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `WorldEnvironment` / `Environment` | The scene's sky, ambient light and fog |
| `Environment.ambient_light_energy` / `ambient_light_color` | What lights the parts the sun cannot reach |
| `Environment.fog_enabled` / `fog_density` / `fog_light_color` | Distance fog |
| `Environment.background_color` | The sky when there is no sky texture |
| `DirectionalLight3D.light_energy` / `light_color` | The sun's brightness and colour |
| `Node3D.look_at_from_position()` | Aiming a light along a direction vector |
| `fposmod()` | A clock that wraps in both directions |

## Files

| File | What it holds |
|------|---------------|
| `scripts/sky_cycle.gd` | The `SkyCycle` component: every sky property as a function of the hour |
| `scripts/main.gd` | Demo driver: runs the clock and assigns the results |
| `scenes/main.tscn` | Ground, towers receding into the fog, the sun, and the environment |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/sky_cycle.gd` — the `SkyCycle` type. `scripts/main.gd` is the
demo driver and is not needed.

**Public API**
- `SkyCycle.normalise(hours) -> float`, `SkyCycle.clock(hours) -> String`
- `sun_height()`, `sun_direction()`, `sun_energy()`, `sun_colour()`
- `ambient_energy()`, `fog_density()`, `horizon_colour()`, `is_daytime()`
- `SkyCycle.SUNRISE`, `SUNSET`, `TWILIGHT`

**Integrate**
1. Keep one float — the hour — as the game's time of day, and advance it
   wherever your other timers live. Everything else is derived.
2. Assign the sky properties once per frame. They are cheap; what is not cheap
   is the shadow map, which is why the sun's `shadow_enabled` follows its energy.
3. `is_daytime()` is the hook for everything else on a schedule: shops, patrols,
   spawns. Take the decision from the same clock rather than a second one.

**Notes**
- `class_name SkyCycle` is global to the project — rename it if you already
  define that type.
- This uses a flat `background_color` rather than a `ProceduralSkyMaterial`, so
  the whole sky is one property and the demo stays readable. A real game usually
  wants the procedural sky, whose sun position is driven by the same
  `DirectionalLight3D` this already aims.
- Volumetric fog (`volumetric_fog_enabled`) looks far better for light shafts and
  costs considerably more. Distance fog is the one to reach for first.

## Related demos

- [volumetric-fog](../volumetric-fog) — Fog with light in it: the settings that make it appear, and the three reasons it usually does not.
- [lights-and-shadows](../lights-and-shadows) — The three 3D light types side by side, and a shadow budget that keeps the expensive ones near the camera.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

