# Gamepad 3D

<!-- tags: physics, camera, ui, component, shows-its-working, needs-gamepad -->

Analogue stick handling in 3D: a radial deadzone that does not jump, a response curve, and camera-relative movement.

## Purpose

A thumbstick at rest does not report zero. It reports a small drifting value
that differs per controller, so every game needs a deadzone — and the obvious
deadzone is wrong in two ways at once, both of which look completely normal from
the outside.

**Per-axis is wrong.** `if abs(x) < 0.2: x = 0` on each axis separately carves a
*square* hole out of a *round* stick. Push diagonally at 0.19 on both axes and
nothing happens, though the stick is 27% deflected and the player can see they
are pushing it.

**Not rescaling is wrong.** Zeroing below the threshold and passing the rest
through unchanged means the instant the stick leaves the deadzone the character
jumps to 20% speed. There is no way to walk slowly, which is most of what an
analogue stick is for.

## Controls

| Input | Action |
|-------|--------|
| Left stick | Move (analogue — a half push is a walk) |
| Right stick | Turn the camera |
| A / cross | Rumble |
| Arrow keys | Move, if there is no controller plugged in |

The two bars at the top left are the stick's raw deflection and what the
character actually got. With the arrow keys they are both all-or-nothing, which
is exactly why a keyboard cannot show what any of this is for.

## How It Works

**The deadzone is radial and rescaled.** `StickInput.deadzone()` takes the
stick's *length*, not its axes, so the dead area is a circle. It then rescales
what is left, so the output runs 0..1 as the stick's own deflection runs from
the inner limit to the outer one. Just outside the zone the character moves
barely at all; halfway between the limits it moves at half speed.

**The outer limit is under 1.0.** A worn stick often cannot reach its own
corners any more. Treating 0.95 as fully pushed means those controllers can
still run.

**Diagonals are clamped.** Sticks over-report at the corners — a diagonal can
measure past 1.0 — and a character that moves 1.4× faster diagonally is the
oldest bug in games.

**The curve bends the middle, not the ends.** `curve()` raises the magnitude to
an exponent, so a small push moves less while a full push still moves fully.
Applied to magnitude only, so aim is untouched. Above 1 gives fine control near
the centre, which is what a camera stick wants.

**Movement is camera-relative and keeps its magnitude.** `to_world()` builds a
flat forward from the camera's yaw and scales it by how far the stick is pushed.
Normalising here is the other common way analogue input gets thrown away — every
push becomes a run, and the stick may as well have been a key.

**Rumble takes a duration.** `Input.start_joy_vibration(pad, weak, strong,
duration)`. Omit the duration and the motors run until something stops them,
which sooner or later means "until the player unplugs the controller".

**The keyboard fallback is deliberate.** A demo that only responds to hardware
half the readers do not own looks broken to them.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Input.get_joy_axis()` | Raw stick and trigger values, -1..1 |
| `Input.get_connected_joypads()` | Whether there is a pad at all, and its device id |
| `Input.is_joy_button_pressed()` | Face buttons |
| `Input.start_joy_vibration()` | Rumble — weak motor, strong motor, duration |
| `JOY_AXIS_LEFT_X` / `JOY_AXIS_RIGHT_Y` | The axis constants, in Godot's naming |
| `CharacterBody3D.look_at()` | Facing the way the stick is pushed |

## Files

| File | What it holds |
|------|---------------|
| `scripts/stick_input.gd` | The `StickInput` component: deadzone, curve, triggers, and the world direction |
| `scripts/main.gd` | Demo driver: reading the pad, the keyboard fallback, rumble, and the bars |
| `scenes/main.tscn` | A floor, some marks to steer between, the player and the HUD |
| `tests/test_logic.gd` | Headless test suite — every stick position fed in by hand |

## Use as a building block

**Copy:** `scripts/stick_input.gd` — the `StickInput` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `StickInput.deadzone(raw, inner := 0.18, outer := 0.95) -> Vector2`
- `StickInput.curve(value, exponent) -> Vector2`
- `StickInput.processed(raw, exponent := 1.0, inner, outer) -> Vector2`
- `StickInput.trigger(raw, inner := 0.1) -> float`
- `StickInput.to_world(value, camera_yaw) -> Vector3`
- `StickInput.any_connected() -> bool`

**Integrate**
1. Read the raw axes and pass them straight to `processed()`. Do not deadzone
   with `Input`'s own action deadzones as well — two deadzones in series give
   you a bigger one that nobody chose.
2. Make `inner` a settings-menu value. Stick wear varies enormously, and a
   number that is right for a new controller is not right for a four-year-old
   one.
3. Keep the magnitude all the way to the velocity. The moment anything calls
   `.normalized()`, the stick has become a key.

**Notes**
- `class_name StickInput` is global to the project — rename it if you already
  define that type.
- Godot's `Input.get_vector()` applies its own deadzone and is fine for menus.
  For character movement it gives you the per-axis behaviour this demo exists to
  avoid.
- Different controllers report their sticks with different rest positions and
  ranges. Godot's controller database normalises most of it, but not all — which
  is why the deadzone is a runtime value rather than a constant.

## Related demos

- [first-person-controller](../first-person-controller) — Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body.
- [shape-cast-3d](../shape-cast-3d) — Sweeping a shape ahead of a character with ShapeCast3D to tell a step it can climb from a wall it cannot.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.
- [character-push](../character-push) — A CharacterBody3D that pushes crates — because move_and_slide() slides past them and does nothing else.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

