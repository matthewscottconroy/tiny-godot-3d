class_name Ragdoll
extends RefCounted

## The hand-off between an animated skeleton and a physical one.
##
## A ragdoll is not a mode a character is in. It is a *transition*, twice: from
## animation to physics when they are hit, and back again when they get up. Both
## transitions are where it goes wrong, and neither is about the physics.
##
##   * **Going in, the bodies must start where the pose is.** A simulation that
##     begins from the rest pose snaps the character into a T-shape for one
##     frame — the single most recognisable ragdoll bug there is.
##   * **Momentum carries over.** A character shot while sprinting should fall
##     forwards. Starting the bodies at rest drops them straight down, which
##     reads as the character being switched off rather than hit.
##   * **Coming out, the animation must start from where the bodies are.** Snapping
##     to the first frame of "stand up" is the same bug in reverse.
##
## What is worth having outside the engine is the bookkeeping: when to give up
## and let them lie, how long the blend takes, and whether the thing has settled.

enum State { ANIMATED, SIMULATING, RECOVERING }

## Below this much movement, the ragdoll has stopped.
var settle_speed := 0.35

## And it has to stay stopped for this long, or a body resting on a slope
## reports settled between bounces.
var settle_time := 0.4

## How long the blend back to animation takes.
var recovery_time := 0.45

var _state := State.ANIMATED
var _still_for := 0.0
var _recovered := 0.0


func state() -> State:
	return _state


func is_simulating() -> bool:
	return _state == State.SIMULATING


## Hand over to physics.
func go_limp() -> void:
	_state = State.SIMULATING
	_still_for = 0.0
	_recovered = 0.0


## Watch a simulating ragdoll, and say when it has come to rest.
##
## Returns true on the frame it settles. Speed is the fastest body, not the
## average: an arm still flailing is not a character ready to stand up.
func observe(fastest_body_speed: float, delta: float) -> bool:
	if _state != State.SIMULATING:
		return false
	if fastest_body_speed > settle_speed:
		_still_for = 0.0
		return false
	_still_for += delta
	return _still_for >= settle_time


## Begin blending back toward animation.
func recover() -> void:
	if _state != State.SIMULATING:
		return
	_state = State.RECOVERING
	_recovered = 0.0


## Advance the blend. Returns how much of the animation is in charge, 0 to 1.
func advance_recovery(delta: float) -> float:
	if _state != State.RECOVERING:
		return 1.0 if _state == State.ANIMATED else 0.0
	_recovered += delta
	if _recovered >= recovery_time:
		_state = State.ANIMATED
		return 1.0
	return clampf(_recovered / maxf(recovery_time, 0.0001), 0.0, 1.0)


## How much the animation is in charge right now, without advancing anything.
func animation_weight() -> float:
	match _state:
		State.ANIMATED:
			return 1.0
		State.SIMULATING:
			return 0.0
		_:
			return clampf(_recovered / maxf(recovery_time, 0.0001), 0.0, 1.0)


## The velocity to start the bodies with.
##
## Character velocity plus the hit, because a character shot while sprinting
## should fall forwards. Bodies started at rest drop straight down, which reads
## as the character being switched off rather than hit.
static func launch_velocity(character_velocity: Vector3, impulse: Vector3,
		mass: float = 1.0) -> Vector3:
	return character_velocity + impulse / maxf(mass, 0.0001)


## The fastest of a set of body speeds — the one that decides whether it has
## settled.
static func fastest(speeds: Array[float]) -> float:
	var top := 0.0
	for speed in speeds:
		top = maxf(top, absf(speed))
	return top


func reset() -> void:
	_state = State.ANIMATED
	_still_for = 0.0
	_recovered = 0.0
