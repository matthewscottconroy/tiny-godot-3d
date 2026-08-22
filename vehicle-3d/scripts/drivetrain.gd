class_name Drivetrain
extends RefCounted

## Turning driving input into engine force, brake force and a steering angle.
##
## `VehicleBody3D` is a `RigidBody3D` with raycast wheels. It gives you real
## suspension, real weight transfer and a car that rolls down a hill on its own —
## and in exchange it is a rigid body, which means it can also flip over, get
## wedged, and do everything else a physics object does when nobody is watching.
##
## That trade is the thing to decide early. A racing game wants it. A driving
## section in a platformer usually wants a `CharacterBody3D` that fakes the whole
## thing, because "the car got stuck upside down" is not a bug you can fix.
##
## What the engine does *not* give you is the part that makes a car drivable, and
## all of it is arithmetic:
##
##   * **Steering has to shrink with speed.** Full lock at 120 km/h is a spin.
##     Every driving game does this and none of them mention it.
##   * **Engine force has to fall off near top speed**, or the car accelerates
##     forever and top speed is decided by drag alone.
##   * **Reverse is not negative throttle.** Pulling back while rolling forward
##     is the brake; it is only reverse once the car has stopped.

## Radians of lock at a standstill.
var max_steer := 0.6

## The speed, in m/s, at which lock has fallen to `min_steer_fraction`.
var full_lock_speed := 25.0

## How much lock is left at speed. Not zero: a car you cannot steer at all on a
## motorway is worse than one that spins.
var min_steer_fraction := 0.25

## Newtons. A 900kg car needs thousands of these to accelerate like a car:
## force divided by mass is the acceleration, and 300N moves 900kg at walking
## pace eventually.
var max_engine_force := 3200.0
var max_brake := 40.0

## Top speed in m/s, where engine force reaches zero.
var top_speed := 40.0


## The steering angle to ask the front wheels for.
##
## The interpolation is on speed, not on time: it responds instantly to a change
## in speed and does not need a state variable.
func steering_for(input: float, speed: float) -> float:
	var t := clampf(absf(speed) / maxf(full_lock_speed, 0.0001), 0.0, 1.0)
	var scale := lerpf(1.0, clampf(min_steer_fraction, 0.0, 1.0), t)
	return clampf(input, -1.0, 1.0) * max_steer * scale


## Engine force for this throttle at this speed.
##
## Falls to nothing at `top_speed`, so the car has a top speed you chose rather
## than one that emerges from drag.
func engine_force_for(throttle: float, speed: float) -> float:
	var t := clampf(absf(speed) / maxf(top_speed, 0.0001), 0.0, 1.0)
	return clampf(throttle, -1.0, 1.0) * max_engine_force * (1.0 - t)


## Is this backwards input a brake, or reverse?
##
## Rolling forward, it is the brake. Stopped, it is reverse. Getting this wrong
## gives a car that reverses out from under itself the moment you tap the brake.
static func is_braking(input: float, forward_speed: float, stopped_below: float = 0.5) -> bool:
	if input >= 0.0:
		return false
	return forward_speed > stopped_below


## Brake force for this input at this speed.
func brake_for(input: float, forward_speed: float) -> float:
	if not is_braking(input, forward_speed):
		return 0.0
	return absf(clampf(input, -1.0, 0.0)) * max_brake


## Throttle to send to the engine, once braking has taken its share.
##
## Zero while braking: a car that brakes and accelerates at once is a car whose
## brakes do not work.
func throttle_for(input: float, forward_speed: float) -> float:
	if is_braking(input, forward_speed):
		return 0.0
	return clampf(input, -1.0, 1.0)


## Speed along the car's own forward axis, signed.
##
## `linear_velocity.length()` cannot tell forwards from backwards, which is the
## one thing the reverse decision needs to know.
static func forward_speed(velocity: Vector3, basis: Basis) -> float:
	return velocity.dot(-basis.z)


## With this many of four wheels on the ground, is the car airborne?
##
## Three wheels is a bumpy corner. One is a jump, and steering input in the air
## does nothing but tip the car over.
static func airborne(wheels_on_ground: int) -> bool:
	return wheels_on_ground <= 1
