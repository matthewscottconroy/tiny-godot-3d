# Split Screen

<!-- tags: camera, ui, component, shows-its-working -->

Two players, two viewports, one world — and the shared World3D that makes the second view show anything at all.

## Purpose

Split screen in 3D is one line of insight surrounded by arithmetic.

The line: **a `SubViewport` creates its own empty `World3D` unless you tell it
otherwise.** Add a second viewport to show the same level from another angle and
you get a black rectangle — no error, no warning, nothing to search for, because
nothing is wrong. It is rendering an empty world exactly as asked.

The arithmetic is the rest: rectangles that cover the window with no seam, and a
field of view that means the same thing in a pane of a different shape. Neither
is hard, and both are wrong in a way that only shows up on someone else's
monitor.

## Controls

| Key | Action |
|-----|--------|
| 1 – 4 | That many players |
| S | Horizontal or vertical split |

## How It Works

**Every pane points at the same world.** `view.world_3d = get_viewport().world_3d`
— one line, and the difference between a split screen and two black rectangles.
The level itself lives under a plain `Node3D`; no pane owns it.

**`current` is per viewport.** Each `SubViewport` has its own current camera, so
four cameras can all be current at once without arguing. That is why this works
at all, and it is why `make_current()` inside a `SubViewport` does not steal the
main view.

**The container sizes the viewport.** A `SubViewportContainer` with `stretch`
enabled owns its child's size; assigning `SubViewport.size` as well is refused
with a warning. Set the container's rectangle and let it do the rest.

**The remainder goes to the last pane.** A 1081-pixel-tall window halved twice is
1080, and the missing row is a permanent one-pixel line down the middle of the
screen. `ScreenLayout` gives the odd pixel to the final pane, and the suite
checks the panes cover the window exactly once — no gaps, no overlaps — at every
count and at odd sizes.

**Half a screen is a different shape, not a smaller one.** Godot's default
`KEEP_HEIGHT` holds the *vertical* angle fixed, so a letterbox pane shows the
same amount vertically and the same amount horizontally as a full screen — which
means the player in it sees less of the world. `matched_fov()` converts the
vertical angle to horizontal at the old aspect and back at the new one, so
everyone sees the same width. In a competitive game that is not a nicety.

**Three players is the awkward one.** Two panes on top, one across the bottom:
what everyone does and nobody likes. It is in here because pretending the case
does not exist is how it ends up hard-coded badly later.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `SubViewport.world_3d` | Which world the pane renders — the whole demo |
| `SubViewportContainer.stretch` | Sizing the viewport from the container |
| `Camera3D.current` | Per-viewport, so every pane has its own |
| `Camera3D.fov` / `keep_aspect` | What a pane's shape does to what it shows |
| `Viewport.size_changed` | Re-laying out when the window changes |
| `Rect2i.intersects()` | The suite's check for overlapping panes |

## Files

| File | What it holds |
|------|---------------|
| `scripts/screen_layout.gd` | The `ScreenLayout` component: pane rectangles, aspect, matched field of view |
| `scripts/main.gd` | Demo driver: building the viewports and pointing them at one world |
| `scenes/main.tscn` | The shared world, and an empty Control the panes go into |
| `tests/test_logic.gd` | Headless test suite — including a check that the real panes share a world |

## Use as a building block

**Copy:** `scripts/screen_layout.gd` — the `ScreenLayout` type. `scripts/main.gd`
is the demo driver, though its `_build()` is the part worth reading twice.

**Public API**
- `ScreenLayout.rects(players, size, split := Split.HORIZONTAL) -> Array[Rect2i]`
- `ScreenLayout.aspect_of(rect) -> float`
- `ScreenLayout.matched_fov(base_fov, base_aspect, pane_aspect) -> float`
- `ScreenLayout.covers(rects, size) -> bool`
- `ScreenLayout.Split.HORIZONTAL` / `VERTICAL`

**Integrate**
1. Set `world_3d` on every `SubViewport` before anything else. If a pane is
   black, this is why.
2. Re-run the layout on `size_changed`. A split screen that only lays out once
   is correct until someone resizes the window or the game goes fullscreen.
3. Audio has the same problem as rendering: one `AudioListener3D` for the whole
   game, so pick a listener deliberately — usually player one, or the midpoint.

**Notes**
- `class_name ScreenLayout` is global to the project — rename it if you already
  define that type.
- Split screen multiplies the rendering cost by the number of panes; shadows and
  reflections are drawn per view. A shadow budget helps —
  see [lights-and-shadows](../lights-and-shadows).
- Input for several local players comes from device ids, not from the viewport.
  `InputEvent.device` is the field that tells them apart —
  see [gamepad-3d](../gamepad-3d).

## Related demos

- [portal-3d](../portal-3d) — A portal you can see through and walk through, and the transform that puts the second camera in the right place.
- [render-to-texture](../render-to-texture) — A security monitor: a second camera rendered onto a screen in the world, and the update mode that keeps it affordable.
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [multiplayer-3d](../multiplayer-3d) — Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

