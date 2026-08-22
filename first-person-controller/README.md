# First Person Controller

<!-- tags: physics, ui, component, shows-its-working, needs-mouse-capture -->

Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body.

## Purpose

A first-person camera is four small decisions that each have an obviously wrong
answer, and the wrong answers all still run.

Rotate the whole body with pitch and the collider tilts with it. Move along the
camera's real forward and looking at the floor walks you into it. Let pitch reach
straight up and the view snaps. Bob the head from the input rather than from the
distance actually covered and the camera keeps bobbing while you walk into a
wall.

None of those show up in a screenshot, and all of them are numbers — so they
live in a plain `RefCounted` where a test can state what they should be.

## Controls

| Input | Action |
|-------|--------|
| Left click | Capture the mouse |
| Mouse | Look around |
| W A S D / arrow keys | Move |
| Space | Jump |
| Escape | Release the mouse |

## How It Works

**Yaw turns the body, pitch turns the head.** `rotation.y` on the
`CharacterBody3D`, `rotation.x` on a `Head` node above it. Pitching the body
would tilt the capsule collider and, worse, tilt the basis everything else is
computed from.

**Movement uses a yaw-only forward.** `FirstPersonRig.forward()` is built from
`yaw` alone — `Vector3(-sin(yaw), 0, -cos(yaw))` — so it is flat by
construction rather than flattened afterwards. Looking down cannot affect where
walking takes you.

**Pitch is clamped short of vertical.** At exactly ±90° the look basis has no
unique answer, and the view rolls or snaps as it crosses. `±1.4` radians is
about 80°, which is as far as anyone needs to look.

**The mouse is captured, not read.** `MOUSE_MODE_CAPTURED` hides the cursor and
delivers relative motion with no screen edge to run into. Reading the cursor's
position instead works until the player reaches the side of their monitor.

**Bob is driven by distance covered.** The driver measures the body's actual
horizontal speed after `move_and_slide()` and hands that to `advance()`. Walking
into a wall covers no distance, so the head stops bobbing — which is what your
eyes expect and what an input-driven bob gets wrong.

**The bob is two waves.** The vertical rise runs at twice the stride frequency,
because a stride is two footfalls; the sideways sway runs at once per stride,
because you lean onto alternate feet. Both are sines starting at zero, so a
player standing still has their head exactly where the scene puts it.

**The view model rides the camera.** The small box parented to the `Camera3D`
stays put in view while the world moves past it — the cheapest possible
demonstration of why weapon models are camera children rather than world objects.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Input.mouse_mode` / `MOUSE_MODE_CAPTURED` | Unbounded relative mouse movement |
| `InputEventMouseMotion.relative` | The frame's mouse delta, in pixels |
| `CharacterBody3D.move_and_slide()` | Move against the level and resolve collisions |
| `CharacterBody3D.is_on_floor()` | Gate jumping and bobbing on being grounded |
| `Input.is_key_pressed()` | Reading WASD, which `ui_*` does not cover |
| `clampf()` | The pitch limits |

## Files

| File | What it holds |
|------|---------------|
| `scripts/first_person_rig.gd` | The `FirstPersonRig` component: look angles, movement basis, head bob |
| `scripts/main.gd` | Demo driver: the body, the head, mouse capture, gravity |
| `scenes/main.tscn` | A floor, three blocks to walk around, the player, and the HUD |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/first_person_rig.gd` — the `FirstPersonRig` type.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `look(relative: Vector2)`, `forward() -> Vector3`, `right() -> Vector3`
- `movement_direction(input: Vector2) -> Vector3`
- `advance(horizontal_distance: float)`, `head_offset() -> Vector3`
- `travelled() -> float`, `reset()`
- `sensitivity`, `yaw`, `pitch`, `min_pitch`, `max_pitch`, `bob_height`, `bob_sway`, `stride`

**Integrate**
1. Build a body → head → camera chain. Apply `rig.yaw` to the body and
   `rig.pitch` to the head, every physics frame.
2. Feed `movement_direction()` into your velocity, then call `move_and_slide()`.
3. After moving, pass the horizontal distance actually covered to `advance()` and
   set the head's local position to its rest height plus `head_offset()`.

**Notes**
- `class_name FirstPersonRig` is global to the project — rename it if you
  already define that type.
- `sensitivity` belongs in a settings menu, and an "invert look" option is one
  sign change in `look()`. Both are things players expect to be able to set.
- The bob is deliberately small. If it is noticeable while playing rather than
  only when switched off, it is too big.
- This controller has no acceleration: velocity is set outright, so it stops
  dead. See [character-controller-3d](../character-controller-3d) for a motor
  that accelerates, with coyote time and air control.

## Related demos

- [gamepad-3d](../gamepad-3d) — Analogue stick handling in 3D: a radial deadzone that does not jump, a response curve, and camera-relative movement.
- [spring-arm-camera](../spring-arm-camera) — A third-person camera on a SpringArm3D that collides with the level, and eases back out when it clears.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.
- [vehicle-3d](../vehicle-3d) — A VehicleBody3D that drives, the arithmetic that keeps it drivable, and the sign that catches everyone.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

