# Render to Texture

<!-- tags: camera, ui, component, shows-its-working -->

A security monitor: a second camera rendered onto a screen in the world, and the update mode that keeps it affordable.

## Purpose

A `SubViewport` with its own camera, sampled as a texture, gives you a security
monitor, a rear-view mirror, a portal, a scrying pool. It is four lines of setup.

It is also **a whole extra render of the scene** — culling, shadows,
transparency, the lot. One is affordable. A corridor of eight monitors is the
same scene rendered nine times a frame, which is why render-to-texture has the
reputation it has.

Almost none of that cost is necessary. A monitor across the room does not need
sixty updates a second at full resolution, and one behind the player does not
need any. Both savings are large and neither is automatic.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Move the viewer closer or further |
| T | Throttling on or off |

The readout counts renders against frames. Walk away with throttling on and the
ratio collapses.

## How It Works

**A SubViewport starts with an empty world.** `feed.world_3d =
get_viewport().world_3d` — without it the screen shows a black rectangle, with
no error to look up. Same trap as [split-screen-3d](../split-screen-3d), and it
catches people twice.

**The texture is `SubViewport.get_texture()`.** Assigned to a
`StandardMaterial3D`'s `albedo_texture`, it is a live `ViewportTexture` — the
screen shows whatever the feed camera sees, this frame.

**Screens are unshaded.** A monitor emits light; it does not reflect it. A lit
material makes the feed dark wherever the room is dark, which is the difference
between a screen and a poster of a screen.

**`UPDATE_ONCE` is what makes a throttle a throttle.** It renders exactly one
frame and then switches itself back to disabled. Setting `UPDATE_ALWAYS` and
hoping is the version that costs; setting `UPDATE_DISABLED` and forgetting is a
frozen image.

**Invisible is not "slower".** A feed nobody can see renders *zero* times, not
five times a second. The suite spends ten simulated seconds out of sight and
asserts not one render happened — that saving dwarfs every other one here.

**Resolution falls with distance too.** A monitor twenty metres away covers a few
dozen pixels; rendering it at full size and minifying is work thrown away. With
a floor, because a viewport a handful of pixels across looks like a fault rather
than a distant screen.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `SubViewport.world_3d` | Which world the feed renders — the line it all depends on |
| `SubViewport.get_texture()` | The live `ViewportTexture` to put on a material |
| `SubViewport.render_target_update_mode` | `ALWAYS`, `ONCE`, `DISABLED` — the whole budget |
| `SubViewport.size` | Render resolution, changeable at runtime |
| `BaseMaterial3D.shading_mode` | Unshaded, so the screen glows |
| `Camera3D.current` | Per viewport, so the feed camera does not steal the main view |

## Files

| File | What it holds |
|------|---------------|
| `scripts/feed_throttle.gd` | The `FeedThrottle` component: rates, resolutions, update modes, cost |
| `scripts/main.gd` | Demo driver: the feed, the screen material, and the throttle |
| `scenes/main.tscn` | A room, a screen, a subject to watch, and the SubViewport |
| `tests/test_logic.gd` | Headless test suite — including the real viewport's wiring |

## Use as a building block

**Copy:** `scripts/feed_throttle.gd` — the `FeedThrottle` type.
`scripts/main.gd` is the demo driver, though its `_ready()` is the four lines of
setup worth stealing.

**Public API**
- `rate_for(distance, visible) -> float`, `should_update(distance, visible, delta) -> bool`
- `FeedThrottle.resolution_for(distance, base, near := 8.0, far := 25.0) -> Vector2i`
- `FeedThrottle.update_mode_for(visible, continuous) -> int`
- `cost_of(distance, visible) -> float`, `reset()`
- `near_distance`, `far_distance`, `near_hz`, `mid_hz`, `far_hz`

**Integrate**
1. One `FeedThrottle` per screen — it keeps its own timer, so a dozen screens do
   not need a dozen timers in the caller.
2. Feed it real visibility. `VisibleOnScreenNotifier3D` on the screen mesh is the
   cheapest source, and it is the difference between saving a little and saving
   nearly everything.
3. Changing `SubViewport.size` reallocates its render target. Doing it every
   frame is worse than the render you were trying to avoid; change it when the
   band changes, as the driver does.

**Notes**
- `class_name FeedThrottle` is global to the project — rename it if you already
  define that type.
- A mirror is this with the feed camera mirrored through the surface's plane,
  and a portal is this with it placed at the far end. The throttling applies
  identically, and matters more, because portals tend to come in pairs.
- Shadows are rendered per view. A feed camera with shadows enabled doubles the
  shadow cost of the scene; turning them off for a distant monitor is usually
  invisible and always cheaper.

## Related demos

- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [camera-clipping](../camera-clipping) — Why the wall you stand against disappears, and what the near plane costs to fix it.
- [portal-3d](../portal-3d) — A portal you can see through and walk through, and the transform that puts the second camera in the right place.
- [split-screen-3d](../split-screen-3d) — Two players, two viewports, one world — and the shared World3D that makes the second view show anything at all.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

