class_name FirstPersonRig
extends RefCounted

## Where a first-person player is looking, which way that means they walk, and
## how much the view bobs while they do it.
##
## None of this needs a node. Splitting it out is what lets the numbers be
## checked — and in a first-person game the numbers are the whole feel. Look
## sensitivity, the pitch limit, how far the head rises per step: all of them are
## invisible in a screenshot and obvious within two seconds of playing.
##
## The two mistakes this is shaped to prevent:
##
##   * Applying pitch to movement. Look at the floor, walk forward, and a rig
##     that uses the camera's raw forward walks you into it.
##   * Letting pitch reach straight up or down, where the look basis degenerates
##     and the view rolls or snaps.

## Radians per pixel of mouse movement.
var sensitivity := 0.0025

## Yaw is unbounded — turning round and round is fine. Pitch is not.
var yaw := 0.0
var pitch := 0.0
var min_pitch := -1.4      ## just short of straight down
var max_pitch := 1.4       ## just short of straight up

## Head bob. `bob_height` is the peak rise in metres, `stride` the distance in
## metres between one footfall and the next.
var bob_height := 0.06
var bob_sway := 0.03
var stride := 1.6

var _travelled := 0.0


## Apply a mouse delta, in pixels.
##
## Moving the mouse up looks up, hence the negated Y: screen coordinates grow
## downward and pitch grows upward. Getting this backwards is "inverted look",
## which is a preference for some people and a bug when it is not asked for.
func look(relative: Vector2) -> void:
	yaw -= relative.x * sensitivity
	pitch = clampf(pitch - relative.y * sensitivity, min_pitch, max_pitch)


## The direction the body faces: yaw only, flat on the ground plane.
##
## Deliberately ignores pitch. Walking should not be affected by where you are
## looking vertically, and using the camera's real forward means looking down
## walks you into the floor.
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## The rightward direction on the ground, for strafing.
func right() -> Vector3:
	return forward().cross(Vector3.UP).normalized()


## Turn an input vector into a world-space heading.
##
## `input.y` is negative for "forward", matching `Input.get_vector` with the
## usual up/down actions.
func movement_direction(input: Vector2) -> Vector3:
	var direction := forward() * -input.y + right() * input.x
	return direction.normalized() if direction.length() > 0.0001 else Vector3.ZERO


## Record distance walked this frame. Only horizontal movement counts — falling
## down a lift shaft should not bob the camera.
func advance(horizontal_distance: float) -> void:
	_travelled += maxf(horizontal_distance, 0.0)


## The head's offset from its rest position.
##
## Vertical bob runs at twice the stride frequency — the head rises once per
## footfall, and there are two footfalls per stride — while the sideways sway
## runs at once per stride, because you lean onto alternate feet.
func head_offset() -> Vector3:
	if stride <= 0.0:
		return Vector3.ZERO
	var phase := TAU * _travelled / stride
	# Both start at zero, so a player standing still has their head exactly
	# where the scene puts it rather than permanently crouched by bob_height.
	return Vector3(sin(phase) * bob_sway, sin(phase * 2.0) * bob_height, 0.0)


## How far the player has walked, in metres. Mostly useful for a readout.
func travelled() -> float:
	return _travelled


func reset() -> void:
	_travelled = 0.0
	yaw = 0.0
	pitch = 0.0
