# Camera Clipping

<!-- tags: physics, spatial-query, camera, ui, component, shows-its-working -->

Why the wall you stand against disappears, and what the near plane costs to fix it.

## Purpose

A camera does not see from a point. It sees from a rectangle a short distance in
front of itself — the near plane — and anything nearer than that rectangle is
not drawn. Stand close enough to a wall and part of that rectangle is *inside*
it, so the wall is clipped away and the player is looking into the room behind.

Two fixes are common and one of them is a trap:

- **Keep the camera far enough from geometry**, using the near plane's own size
  to decide how far. That is the right one, and it is three lines.
- **Make the near plane tiny.** It works, and it quietly destroys depth
  precision — the z-fighting turns up somewhere else entirely, which is why
  nobody connects the two.

## Controls

| Key | Action |
|-----|--------|
| A / D | Walk into the wall |
| 1 / 2 | Near plane in or out |
| 3 / 4 | Field of view |
| G | The guard on or off |
| R | Reset |

## How It Works

**The near plane starts at 0.25 m here, not Godot's 0.05.** At 0.05 a character
with a 0.35 m body radius never gets close enough for this to happen: the body
stops first. It shows up with a large near plane, a wide field of view, or any
camera that can get nearer to a wall than the body can — a lean, a crouch, a
spring arm that has collapsed.

**The size of the plane comes from the field of view.** `half_height()` is
`near * tan(fov / 2)`, and Godot's `fov` is the *vertical* one — so a wider
window makes the plane wider without making it taller. A wide-angle first-person
camera clips more than a cinematic one at the same distance from the same wall.

**What you need is the radius of the sphere that encloses it.** Keep the
camera's origin that far from anything solid and no corner of the plane can be
inside it, whichever way the camera is facing. That is `safe_distance()`.

**So the query is a sphere, not a ring of rays.** "Keep the origin this far from
anything solid" *is* a sphere test. A handful of rays only finds the surfaces
they happen to point at, and a wall met at 45 degrees goes straight between them.
`get_rest_info()` with a sphere of the safe radius returns the nearest contact
and its normal in one call.

**Push along the surface normal, not along the view.** Backing the camera off
along its own forward vector is what puts a first-person camera inside the
character's head.

**And the trap, priced.** Depth precision scales with the ratio of far to near,
so halving the near plane costs as much precision as doubling the view distance.
The status line prints both that multiplier and how much of the depth buffer the
first metre already uses — around 95% at these settings, which is why distant
geometry is what starts z-fighting.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Camera3D.near` / `.fov` | The rectangle that gets stuck in walls |
| `PhysicsShapeQueryParameters3D` + `get_rest_info()` | The nearest surface and its normal, in one query |
| `SphereShape3D` | The right shape for "how close is anything" |
| `Camera3D.far` | The other end of the precision ratio |
| `Viewport.get_visible_rect()` | The aspect the plane's width depends on |

## Files

| File | What it holds |
|------|---------------|
| `scripts/near_plane.gd` | The `NearPlane` component: sizes, safe distances, and the precision cost |
| `scripts/main.gd` | Demo driver: walking into a wall, and the guard that stops the clip |
| `scenes/main.tscn` | A wall, a prop behind it, and a first-person body |
| `tests/test_logic.gd` | Headless test suite — including walking the real body into the real wall |
| `tests/frames` | Frames the suite needs, since the player has to walk four metres |

## Use as a building block

**Copy:** `scripts/near_plane.gd` — the `NearPlane` type. `scripts/main.gd`'s
`_keep_the_near_plane_clear()` is the part worth adapting.

**Public API**
- `NearPlane.half_height(fov_degrees, near) -> float`
- `NearPlane.half_width(fov_degrees, near, aspect) -> float`
- `NearPlane.radius(fov_degrees, near, aspect) -> float`
- `NearPlane.safe_distance(fov_degrees, near, aspect, margin := 0.05) -> float`
- `NearPlane.would_clip(distance, fov_degrees, near, aspect, margin := 0.05) -> bool`
- `NearPlane.pushed_out(position, surface, normal, fov_degrees, near, aspect, margin) -> Vector3`
- `NearPlane.near_precision_share(near, far) -> float`
- `NearPlane.precision_cost(from_near, to_near) -> float`

**Integrate**
1. Recompute the safe distance when the field of view changes. A zoom, a sprint
   FOV kick or an aim-down-sights all resize the near plane, and a distance
   cached at startup is wrong for all three.
2. Do it after the body has moved, in `_physics_process`. A camera corrected in
   `_process` is corrected against last frame's world.
3. Prefer moving the camera to shrinking the near plane. If you must shrink it,
   pull the far plane in by the same factor and you have paid nothing.
4. A third-person camera has the same problem and a different fix — see
   [spring-arm-camera](../spring-arm-camera), where the arm collides and the
   near plane comes along for the ride.

**Notes**
- `class_name NearPlane` is global to the project — rename it if you already
  define that type.
- The depth-precision figures here are for a standard hyperbolic depth buffer.
  Godot 4's Forward+ renderer uses reverse-Z, which is far better behaved — the
  ratio still matters, but the numbers are a guide to the shape of the problem
  rather than a measurement of it.
- Pushing the camera out moves the player's viewpoint, which they can feel. A
  small margin and a smoothed push read better than a large one and a snap.
- None of this applies to an orthogonal camera, which has no near-plane
  rectangle in the same sense.

## Related demos

- [portal-3d](../portal-3d) — A portal you can see through and walk through, and the transform that puts the second camera in the right place.
- [render-to-texture](../render-to-texture) — A security monitor: a second camera rendered onto a screen in the world, and the update mode that keeps it affordable.
- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.
- [vehicle-3d](../vehicle-3d) — A VehicleBody3D that drives, the arithmetic that keeps it drivable, and the sign that catches everyone.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

