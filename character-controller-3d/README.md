# Character Controller 3D

<!-- tags: physics, ui, component, shows-its-working, good-first-demo -->

Walking, running, and jumping a `CharacterBody3D` — with the movement rules separated from the body that applies them.

## Purpose

A 3D character controller accretes state fast: gravity, jump, run, air control, coyote time. Written directly into the `CharacterBody3D` it becomes a single `_physics_process` nobody wants to touch, and — more importantly — one that cannot be tested, because exercising it requires a physics world and a scene.

Pulling the rules into a plain object fixes both. `CharacterMotor` takes a direction, some flags, and a delta, and returns a velocity. The body's job shrinks to reading input, calling the motor, and calling `move_and_slide()`. That split is what lets the feel numbers — acceleration, air control, the coyote window — be checked in a headless test.

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | Move |
| Shift | Run |
| Space | Jump |

## How It Works

**Gravity, then jump, then horizontal.** The order matters: the jump check runs after gravity so a jump on the landing frame is not immediately cancelled, and horizontal acceleration runs last because it does not interact with the vertical axis.

**Landing zeroes the fall.** Without this, `velocity.y` accumulates downward forever while grounded and the first step off a ledge is a sudden drop.

**Coyote time is armed on the frame you leave the ground.** The motor tracks `_was_on_floor`, so walking off an edge starts the window rather than ending it — the same technique as the 2D [coyote-time](https://github.com/matthewscottconroy/tiny-godot-games/tree/main/coyote-time) demo.

**Acceleration is `move_toward`, not a multiply.** It approaches the target speed at a constant rate, which is frame-rate independent and stops cleanly instead of asymptotically.

**Air control is a fraction of ground acceleration.** Zero feels rigid, one feels floaty; the export sits between.

**The body feeds velocity back.** After `move_and_slide()` resolves collisions, the body's velocity is the truth — writing it back into the motor stops it accelerating into a wall it cannot pass.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `CharacterBody3D.velocity` | The velocity `move_and_slide()` consumes |
| `move_and_slide()` | Move with collision response |
| `is_on_floor()` | Ground check, valid after `move_and_slide()` |
| `move_toward()` | Constant-rate approach to a target speed |
| `Input.get_vector()` | Two axes as one vector |
| `Vector3.normalized()` | Stop diagonal movement being faster |

## Key Constants

| Property | Default | Meaning |
|----------|---------|---------|
| `walk_speed` / `run_speed` | 4.0 / 7.5 | Target horizontal speeds |
| `jump_velocity` | 5.0 | Upward velocity on jump |
| `gravity` | 18.0 | Higher than real gravity, as games usually are |
| `acceleration` | 12.0 | How fast the target speed is reached |
| `air_control` | 0.35 | Fraction of that acceleration while airborne |
| `coyote_time` | 0.12 | Grace period after leaving the ground |

## Files

| File | What it holds |
|------|---------------|
| `scripts/motor.gd` | The `CharacterMotor` component: gravity, jump, coyote time, acceleration |
| `scripts/player.gd` | The `CharacterBody3D` that applies the motor's output |
| `scripts/main.gd` | Demo driver: the status readout |
| `scenes/main.tscn` | The runnable scene |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/motor.gd` — the `CharacterMotor` type — and `scripts/player.gd` as a starting point for your own body.

**Public API**
- `step(direction, running, jump_pressed, on_floor, delta) -> Vector3`
- `can_jump(on_floor) -> bool`, `horizontal_speed() -> float`, `reset()`
- `velocity: Vector3`
- `walk_speed`, `run_speed`, `jump_velocity`, `gravity`, `acceleration`, `air_control`, `coyote_time`

**Integrate**
1. Create a motor in your `CharacterBody3D`, call `step()` each physics frame, assign the result to `velocity`, then `move_and_slide()`.
2. Write `velocity` back into the motor afterwards.
3. For camera-relative movement, build the direction with the [orbit-camera](../orbit-camera) rig's `movement_direction()` rather than the body's own basis.

**Notes**
- `class_name CharacterMotor` is global to the project — rename it if you already define that type.
- The motor has no opinion about rotation. Facing is a presentation decision and usually wants its own smoothing.
- Jump buffering — remembering a press made slightly too early — is the natural next addition and pairs with the coyote window already here.

## Related demos

- [orbit-camera](../orbit-camera) — A third-person camera that orbits a target, with pitch limits and camera-relative movement.
- [character-push](../character-push) — A CharacterBody3D that pushes crates — because move_and_slide() slides past them and does nothing else.
- [first-person-controller](../first-person-controller) — Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body.
- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

