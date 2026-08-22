# Camera Framing

<!-- tags: camera, ui, component, shows-its-working -->

A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.

## Purpose

Following one target is a lerp. Following four — a squad, a party, two players in
a brawler — is a different question with three parts, and each part has an
obvious wrong answer that looks fine until it does not.

**Where does the camera look?** Not at the average position: average four
players, three of whom are standing together, and the camera drifts toward the
group and leaves the fourth off the edge of the screen. Which is, reliably, the
player who needed the camera.

**How far back?** Far enough that the group fits in the frustum — which means
knowing which axis binds. Godot's `fov` is the *vertical* angle, and on a wide
screen the horizontal one is wider, so fitting vertically is enough. On a tall
screen it is the other way round.

**How fast does it change?** Unclamped, one player falling down a hole puts the
camera in orbit. Unsmoothed, every jump snaps it.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Fewer or more pawns |
| 3 / 4 | Gather them or spread them out |
| Space | Stop them moving |

## How It Works

**The focus is the middle of the bounds.** `FrameFit.focus_of()` builds an
`AABB` around every point and takes its centre. The suite states the difference
outright: three players at 0, 1, 2 and one at 30 give a focus of 15 and an
average of 8.25, and the camera that uses the average loses the outlier.

**The distance comes from the fitted radius and the field of view.**
`radius / sin(half_fov)` — the distance at which a sphere of that radius exactly
fills the frustum. Doubling the radius doubles the distance, which the suite
also pins, because a fit that is merely *monotonic* can still be wrong by a
factor.

**The aspect ratio only matters on a tall screen.** At 1:1 and wider the
vertical angle binds and the aspect changes nothing; below 1:1 the horizontal
angle is narrower and the camera has to back further off. Assuming the wide case
is fine right up until someone plays in a portrait window.

**The first frame snaps.** Easing in from wherever the camera happened to be
left is a swoop at the start of every level that nobody asked for. After that,
`update()` eases with `1 - exp(-rate·delta)`, which covers the same fraction per
*second* at any frame rate — two half-steps land exactly where one whole step
does, as in [spring-arm-camera](../spring-arm-camera).

**The component has no opinion about direction.** It returns a focus and a
distance; the demo decides the camera sits up and back. That split is what lets
the same maths drive an overhead RTS camera, a side-on brawler and a chase
camera without a flag for each.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `AABB.expand()` | Growing a box to contain every target |
| `Camera3D.fov` | The vertical field of view the fit is computed against |
| `Viewport.size` | Where the aspect ratio comes from |
| `Camera3D.look_at()` | Aiming at the focus once the position is decided |
| `exp()` | Frame-rate-independent smoothing |

## Files

| File | What it holds |
|------|---------------|
| `scripts/frame_fit.gd` | The `FrameFit` component: bounds, focus, fitted distance, smoothing |
| `scripts/main.gd` | Demo driver: the wandering pawns and the camera angle |
| `scenes/main.tscn` | A large floor with markers, and the camera |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/frame_fit.gd` — the `FrameFit` type. `scripts/main.gd` is the
demo driver and is not needed.

**Public API**
- `FrameFit.bounds_of(points) -> AABB`, `focus_of(points) -> Vector3`, `radius_of(points) -> float`
- `FrameFit.distance_for(radius, fov_degrees, aspect) -> float`
- `update(points, fov_degrees, aspect, delta) -> {focus, distance}`
- `snap(points, fov_degrees, aspect) -> {focus, distance}`
- `focus()`, `distance()`, `min_distance`, `max_distance`, `padding`, `smoothing`

**Integrate**
1. Feed it the positions you actually care about framing. A dead player, a
   spectator or a projectile in the list will drag the camera to the far side of
   the level.
2. Clamp `max_distance` to something the level can afford to show. Beyond a
   point the right answer is to stop framing everyone and split the screen — see
   [split-screen-3d](../split-screen-3d).
3. Call `snap()` on a teleport or a scene change, and `update()` every frame
   otherwise. A smoothed camera crossing a level boundary is a long, slow pan
   through the geometry between.

**Notes**
- `class_name FrameFit` is global to the project — rename it if you already
  define that type.
- The fit uses a bounding *sphere*, which is conservative for a group in a line:
  four players spread along one axis get more room than they strictly need. A
  frustum-corner fit is tighter and considerably more code.
- For an orthographic camera the distance does not matter; the equivalent is
  `Camera3D.size`, and it is the radius directly rather than through a tangent.

## Related demos

- [render-to-texture](../render-to-texture) — A security monitor: a second camera rendered onto a screen in the world, and the update mode that keeps it affordable.
- [camera-shake-3d](../camera-shake-3d) — Camera shake as an offset a rig can carry, with trauma that decays and noise that is the same every run.
- [split-screen-3d](../split-screen-3d) — Two players, two viewports, one world — and the shared World3D that makes the second view show anything at all.
- [multiplayer-3d](../multiplayer-3d) — Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

