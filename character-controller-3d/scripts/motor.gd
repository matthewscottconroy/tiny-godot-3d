## The movement rules for a 3D character, separated from the body that applies
## them: gravity, jumping with coyote time, and acceleration toward a target
## velocity.
##
## Keeping this out of the CharacterBody3D means the same rules drive the player,
## an AI-controlled character, and a test — and it is the only way to check the
## feel numbers without a scene.
class_name CharacterMotor
extends RefCounted

var walk_speed := 4.0
var run_speed := 7.5
var jump_velocity := 5.0
var gravity := 18.0
var acceleration := 12.0      ## how fast horizontal velocity approaches target
var air_control := 0.35       ## fraction of that acceleration while airborne
var coyote_time := 0.12       ## grace period after leaving the ground

var velocity := Vector3.ZERO
var _coyote := 0.0
var _was_on_floor := false

## True while a jump is still permitted after walking off an edge.
func can_jump(on_floor: bool) -> bool:
	return on_floor or _coyote > 0.0

## Advance one frame. `direction` is a normalised world-space heading.
func step(direction: Vector3, running: bool, jump_pressed: bool,
		on_floor: bool, delta: float) -> Vector3:
	# Coyote time: refresh while grounded, arm it on the frame we leave.
	if on_floor:
		_coyote = coyote_time
	elif _was_on_floor:
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	if not on_floor:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		# Zero it on landing rather than letting gravity accumulate forever.
		velocity.y = 0.0

	if jump_pressed and can_jump(on_floor):
		velocity.y = jump_velocity
		_coyote = 0.0

	var speed := run_speed if running else walk_speed
	var target := direction * speed
	var rate := acceleration * (1.0 if on_floor else air_control)
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	_was_on_floor = on_floor
	return velocity

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func reset() -> void:
	velocity = Vector3.ZERO
	_coyote = 0.0
	_was_on_floor = false
