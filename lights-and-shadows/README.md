# Lights and Shadows

<!-- tags: lighting, camera, ui, component, shows-its-working -->

The three 3D light types side by side, and a shadow budget that keeps the expensive ones near the camera.

## Purpose

A scene with no light in it renders black. A scene with twenty shadow-casting
lights renders at nine frames per second. Everything interesting about 3D
lighting is between those two, and none of it is visible in a still: the picture
looks the same whether four lights cast shadows or one does — it is the frame
time that differs.

So this demo shows the three light types together, and then shows the thing you
actually end up writing: a policy that decides which lights are allowed to cast
shadows at all.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Shrink or grow the shadow budget |
| S | Toggle sticky slots — off is "nearest always wins" |
| D | Toggle the sun's shadows |
| Space | Pause the orbiting camera |

Turn stickiness off and watch the shadows swap as the camera passes between two
lamps. That flicker is the bug the margin exists to prevent.

## How It Works

**Three light types, three costs.** `DirectionalLight3D` is the sun: parallel
rays, no position, one shadow map for the whole world. `OmniLight3D` radiates in
every direction, so its shadow is a **cube map — six renders of the scene**.
`SpotLight3D` is a cone, and needs one. That ratio is the whole reason a budget
exists: swapping an omni for a spot where the light only shines one way is a
sixfold saving for no visual change.

**Range is not a suggestion.** `omni_range` and `spot_range` bound the light's
influence, and the renderer uses them to decide what the light can possibly
touch. A light with a range of 200 metres "to be safe" is asking the renderer to
consider the entire level.

**The budget picks the nearest few.** `ShadowBudget.casters()` ranks lights by
distance from the camera and gives shadows to the closest, skipping anything
past `max_distance` — a shadow too far away to resolve costs the same as one you
can see.

**The margin is what stops the flicker.** Two lamps at nearly equal distance
swap the last slot back and forth as the camera drifts, and a shadow appearing
and vanishing is far more noticeable than one that was never there.
`ShadowBudget.update()` keeps its incumbents until a rival is `switch_margin`
metres nearer, and swaps at most one per call so a busy scene settles rather
than churns.

**Nothing here is per-frame allocation.** The budget hands back one array of
flags the size of the light list, and the driver copies them onto
`shadow_enabled`. Toggling that property is cheap; what is expensive is the
shadow map it decides to render.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `DirectionalLight3D` | The sun — parallel light, no position |
| `OmniLight3D` / `omni_range` | A point light; its shadow is a cube map |
| `SpotLight3D` / `spot_angle` / `spot_range` | A cone; one shadow map |
| `Light3D.shadow_enabled` | The switch the budget drives |
| `Light3D.light_energy` / `light_color` | Brightness and colour |
| `Camera3D.look_at()` | Aiming the orbiting camera |

## Files

| File | What it holds |
|------|---------------|
| `scripts/shadow_budget.gd` | The `ShadowBudget` component: ranking, the budget, and the anti-flicker margin |
| `scripts/main.gd` | Demo driver: the orbit, and applying the flags to real lights |
| `scenes/main.tscn` | Sun, three omnis, a spot, four pillars to cast onto |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/shadow_budget.gd` — the `ShadowBudget` type.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `ShadowBudget.ranked(positions, viewer) -> Array[int]`
- `casters(positions, viewer, budget) -> Array[bool]` — stateless
- `update(positions, viewer, budget) -> Array[bool]` — sticky, use this one
- `casting() -> Array[int]`, `reset()`
- `switch_margin`, `max_distance`

**Integrate**
1. Collect your lights once, not every frame, and keep the array order stable —
   the flags come back positionally.
2. Call `update()` each frame with the camera's global position and copy the
   flags onto `shadow_enabled`.
3. Call `reset()` when the level changes, or the budget keeps holding slots for
   lights that no longer exist.

**Notes**
- `class_name ShadowBudget` is global to the project — rename it if you already
  define that type.
- Distance is a decent proxy for importance, not a good one. A large light
  behind the player matters less than a small one in front; if that shows, score
  by screen-space size or by whether the light's range intersects the camera
  frustum instead.
- Baked lighting sidesteps all of this for anything static. A budget is for
  lights that move or switch on and off.

## Related demos

- [environment-fog](../environment-fog) — A day-night cycle driven by a WorldEnvironment: sun angle, sky, ambient light and fog from one clock.
- [raycast-picking](../raycast-picking) — Turning a mouse position into a world ray, and asking the physics space what it hit.
- [area-trigger-3d](../area-trigger-3d) — Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.
- [volumetric-fog](../volumetric-fog) — Fog with light in it: the settings that make it appear, and the three reasons it usually does not.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

