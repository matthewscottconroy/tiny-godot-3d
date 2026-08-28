# Portal 3D

<!-- tags: camera, ui, component, shows-its-working -->

A portal you can see through and walk through, and the transform that puts the second camera in the right place.

## Purpose

A portal is a second camera rendered onto a surface — the same machinery as the
security monitor in [render-to-texture](../render-to-texture), with one
difference that changes everything: the second camera's transform is *derived*
from the player's, through the pair of portals, rather than bolted to a wall.

Get that transform right and the illusion is total. Get it wrong and the view is
plausible but subtly sliding, which is worse than obviously broken, because
nobody can say what is wrong with it.

## Controls

| Key | Action |
|-----|--------|
| ↑ / ↓ | Walk |
| ← / → | Turn |
| C | Near-plane clipping on the far camera |
| V | Skip rendering portals you are standing behind |
| R | Back to the first room |

## How It Works

**The transform reads right to left.** Take the player into the entry portal's
space, turn it around, and put it back out in the exit portal's space:
`exit * flip * entry⁻¹ * viewer`. Every portal implementation is that line and
some bookkeeping.

**The virtual camera stands *behind* the exit.** That is the trick, and it looks
wrong written down: what the far camera sees through the far opening is exactly
what the player sees through the near one, which only works from behind. The
suite asserts the distance and the sign.

**The half-turn is not optional.** Without it the far camera looks into the back
of the exit portal, and the view is that portal's own back wall — which reads as
the portal simply not working.

**A SubViewport with no world renders nothing.** `view.world_3d = get_world_3d()`
is the line between a portal and a black rectangle, and there is no error to
explain its absence.

**Do not draw a portal you are behind.** It costs an entire extra scene render
to produce something nobody can see. Press V to turn the check off and watch the
readout admit it.

**Clip the far camera at the exit.** Anything nearer than the exit portal is
between it and the camera: in front of the view, behind the opening, and so it
appears floating in the doorway. `near_plane_for()` is the fix in one line.

**Walking through is a sign change, not a proximity test.** Something moving
quickly passes the plane in a single frame without ever being near it, and a
distance check misses it entirely. The suite crosses twenty metres in one step
to prove the point.

**And the wall beside a portal is still a wall.** The crossing has to be inside
the opening, or the player teleports by walking into the plasterwork three
metres to the left.

**Entry and exit can be the same portal.** The transform reduces to the viewer,
turned around — which is a mirror, and is why mirrors and portals are the same
code with different arguments.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `SubViewport.world_3d` | The line between a portal and a black rectangle |
| `SubViewport.get_texture()` | What goes on the portal surface |
| `Camera3D.near` | Clipping away what sits between the exit and its camera |
| `Transform3D.affine_inverse()` | Taking the player into a portal's space |
| `SubViewport.render_target_update_mode` | Not rendering a portal nobody can see |

## Files

| File | What it holds |
|------|---------------|
| `scripts/portal_view.gd` | The `PortalView` component: the transform, the sides, the crossing |
| `scripts/main.gd` | Demo driver: two rooms, two portals, and a walker |
| `scenes/main.tscn` | Both rooms, both portal surfaces, and their viewports |
| `tests/test_logic.gd` | Headless test suite — including walking the real player through |

## Use as a building block

**Copy:** `scripts/portal_view.gd` — the `PortalView` type. `scripts/main.gd` is
the demo driver, though `_aim()` and `_check_crossing()` are the parts worth
adapting.

**Public API**
- `PortalView.camera_transform(viewer, entry, exit) -> Transform3D`
- `PortalView.side_of(portal, point) -> float`
- `PortalView.is_facing(portal, viewer_position, margin := 0.0) -> bool`
- `PortalView.crossed(portal, before, after) -> bool`
- `PortalView.within_opening(portal, point, half_size) -> bool`
- `PortalView.near_plane_for(camera, exit, minimum := 0.05) -> float`
- `PortalView.resolution_for(distance, base, full_within := 6.0, smallest := 128) -> Vector2i`
- `PortalView.flip() -> Transform3D`

**Integrate**
1. Carry the player's velocity through the transform as well as their position,
   or they arrive facing the right way and moving the wrong one.
2. Two portals that can see each other need a recursion limit. One extra level
   is usually enough to sell it; each one is another full scene render.
3. Use `resolution_for()` rather than a fixed viewport size. A portal across the
   room is a few dozen pixels of screen and a full render of the world.
4. An oblique near plane (`Projection.create_frustum` and friends) clips exactly
   at the portal surface rather than parallel to it. The simple version here is
   right when the player is roughly square-on and drifts when they are not.

**Notes**
- `class_name PortalView` is global to the project — rename it if you already
  define that type.
- The player here is a plain `Node3D`. A `CharacterBody3D` walking through needs
  the teleport to happen outside `move_and_slide()`, or the body resolves the
  collision it was mid-way through against the wrong room.
- Portal surfaces should be unshaded. A lit portal picks up the lighting of the
  room it is in, on top of an image that already has the other room's lighting
  baked into it.
- This is the recursive case's simple cousin — see
  [render-to-texture](../render-to-texture) for what a second camera costs, and
  [split-screen-3d](../split-screen-3d) for two views of one world.

## Related demos

- [split-screen-3d](../split-screen-3d) — Two players, two viewports, one world — and the shared World3D that makes the second view show anything at all.
- [camera-clipping](../camera-clipping) — Why the wall you stand against disappears, and what the near plane costs to fix it.
- [render-to-texture](../render-to-texture) — A security monitor: a second camera rendered onto a screen in the world, and the update mode that keeps it affordable.
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

