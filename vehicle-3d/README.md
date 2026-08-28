# Vehicle 3D

<!-- tags: physics, ui, component, shows-its-working -->

A VehicleBody3D that drives, the arithmetic that keeps it drivable, and the sign that catches everyone.

## Purpose

`VehicleBody3D` is a `RigidBody3D` with raycast wheels. It gives you real
suspension, real weight transfer, and a car that rolls down a hill on its own —
and in exchange it *is* a rigid body, so it can also flip over, get wedged under
scenery, and do everything else a physics object does when nobody is watching.

That trade is worth deciding early. A racing game wants it. A driving section in
a platformer usually wants a `CharacterBody3D` faking the whole thing, because
"the car got stuck upside down" is not a bug you can fix — it is a consequence
of the tool.

What the engine does not give you is the part that makes a car *drivable*, and
all of it is arithmetic.

## Controls

| Key | Action |
|-----|--------|
| W / S | Throttle, brake, and reverse once stopped |
| A / D | Steer |
| Space | Handbrake |
| T | Toggle speed-sensitive steering |
| R | Reset — because a rigid body that has flipped stays flipped |

## How It Works

**Positive `engine_force` drives the car toward +Z.** That is backwards from
`-Z is forward`, which every other `Node3D` in Godot uses — `look_at()`,
`Camera3D`, and the `Basis` you would build by hand. Press W without a negation
and the car reverses away from the camera. It is one character in
`scripts/main.gd`, it costs an afternoon, and the suite asserts the car ends up
moving *forwards* precisely so the negation cannot go missing again.

**Steering has to shrink with speed.** Full lock at 120 km/h is a spin. Every
driving game interpolates the available lock down as speed rises and none of
them mention it; `steering_for()` is that interpolation. Press T to feel the
version without it.

**But never to zero.** A car that cannot be steered at all on a straight reads
as broken controls rather than as realism, so the lock bottoms out at a fraction
rather than nothing.

**Engine force falls off toward top speed.** Otherwise the car accelerates until
drag stops it, and top speed is whatever the physics happened to produce rather
than a number you chose.

**Reverse is not negative throttle.** Pulling back while rolling forward is the
*brake*; it is only reverse once the car has stopped. Get this wrong and the car
reverses out from under the player the moment they tap the brake.
`is_braking()` is the whole decision, and `throttle_for()` returns zero while
braking — a car that brakes and accelerates at once has no brakes.

**Forward speed has to be signed.** `linear_velocity.length()` cannot tell
forwards from backwards, which is the one thing the reverse decision needs.
`forward_speed()` projects onto the car's own axis.

**Force is not acceleration.** A 900 kg car needs *thousands* of newtons to
accelerate like a car. The first version of this demo used 260 N and looked like
a bug in the wheels.

**Suspension is the reason to use this node at all.** The body rides above the
wheels rather than sitting on the ground, and the suite checks that it does —
a car whose body is at ground level has wheels that never reached the surface,
which is the other way this node quietly does nothing.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `VehicleBody3D.engine_force` / `.brake` / `.steering` | The three inputs to the whole node |
| `VehicleWheel3D.use_as_traction` / `.use_as_steering` | Which wheels drive and which turn |
| `VehicleWheel3D.is_in_contact()` | Whether a wheel found the ground — how "airborne" is answered |
| `suspension_travel` / `suspension_stiffness` | Why the body rides above the wheels |
| `RigidBody3D.linear_velocity` | Speed, before it is projected onto the car's own forward |

## Files

| File | What it holds |
|------|---------------|
| `scripts/drivetrain.gd` | The `Drivetrain` component: steering, engine force, brake-or-reverse |
| `scripts/main.gd` | Demo driver: input, the chase camera, and the readout |
| `scenes/main.tscn` | Ground, a ramp, and a four-wheeled car built out of primitives |
| `tests/test_logic.gd` | Headless test suite — including driving the real car through its own input |
| `tests/frames` | Frames the suite needs, since a car has to actually accelerate |

## Use as a building block

**Copy:** `scripts/drivetrain.gd` — the `Drivetrain` type. `scripts/main.gd` is
the demo driver, though the negated `engine_force` line is worth taking with it.

**Public API**
- `steering_for(input, speed) -> float`
- `engine_force_for(throttle, speed) -> float`
- `brake_for(input, forward_speed) -> float`
- `throttle_for(input, forward_speed) -> float`
- `Drivetrain.is_braking(input, forward_speed, stopped_below := 0.5) -> bool`
- `Drivetrain.forward_speed(velocity, basis) -> float`
- `Drivetrain.airborne(wheels_on_ground) -> bool`
- `max_steer`, `full_lock_speed`, `min_steer_fraction`, `max_engine_force`, `max_brake`, `top_speed`

**Integrate**
1. Tune `max_engine_force` against your mass, not against a number that looks
   big. Force divided by mass is the acceleration, and that is the only figure
   that means anything.
2. Ignore steering input while airborne. It does nothing except tip the car, and
   `airborne()` is there to make that one line.
3. Give the player a reset. A rigid body that has landed on its roof will stay
   there, and no amount of tuning removes the case.
4. Consider not using this node. If the driving is a set piece rather than the
   game, a `CharacterBody3D` with faked lean and skid is less code, cannot flip,
   and is usually what players read as "better handling".

**Notes**
- `class_name Drivetrain` is global to the project — rename it if you already
  define that type.
- The wheels are `VehicleWheel3D` nodes positioned where the wheels *are*, not
  where the axle is. Their downward raycast is `suspension_travel + wheel_radius`
  long, so a car spawned higher than that above the ground has no wheels on it
  and simply falls.
- There is no gearbox, no differential, and no tyre model here. Godot's vehicle
  is a starting point for arcade driving, not a simulator; anything past that is
  a physics project of its own.
- Wheels are traction *or* steering, or both. Front-wheel drive is one property
  in a different place, which is easier than it sounds and worth trying.

## Related demos

- [continuous-collision](../continuous-collision) — A fast projectile that goes straight through a wall, and the three ways to stop it.
- [six-dof-joint](../six-dof-joint) — The joint that does everything, and how to say which of its six axes you meant.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.
- [first-person-controller](../first-person-controller) — Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

