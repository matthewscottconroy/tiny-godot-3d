class_name StickInput
extends RefCounted

## Turning what a thumbstick reports into what a character should do.
##
## A stick at rest does not report zero. It reports a small, drifting,
## controller-specific value, so every game needs a deadzone — and the obvious
## deadzone is wrong in two ways at once.
##
## **Per-axis is wrong.** `if abs(x) < 0.2: x = 0` applied to each axis
## separately carves a *square* hole out of a *round* stick. Push diagonally at
## 0.19 on each axis and nothing happens, though the stick is 27% deflected.
## Worse, sliding around the edge of that square makes movement stutter as each
## axis crosses its threshold independently.
##
## **Not rescaling is wrong.** Zeroing everything below the threshold and passing
## the rest through unchanged means the instant the stick leaves the deadzone the
## character jumps from standing still to 20% speed. There is no way to walk
## slowly, which is most of what an analogue stick is *for*.
##
## Both fixes are here, and both are three lines. What they are not is guessable
## from the picture: a game with a square deadzone looks completely normal.

## The stick is treated as centred below this deflection.
const DEFAULT_INNER := 0.18

## Deflection at which the stick counts as fully pushed. Slightly under 1.0
## because a worn stick often cannot reach its own corners any more.
const DEFAULT_OUTER := 0.95


## Apply a radial deadzone, rescaled so movement starts from zero.
##
## Returns a vector whose length runs 0..1 as the stick's own deflection runs
## from `inner` to `outer`. Direction is never changed — only magnitude.
static func deadzone(raw: Vector2, inner: float = DEFAULT_INNER,
		outer: float = DEFAULT_OUTER) -> Vector2:
	var deflection := raw.length()
	if deflection <= inner or outer <= inner:
		return Vector2.ZERO
	var scaled := (deflection - inner) / (outer - inner)
	return raw.normalized() * minf(scaled, 1.0)


## Bend the response so small pushes mean smaller movements.
##
## `exponent` of 1 changes nothing. Above 1 gives finer control near the centre,
## which is what a camera stick wants; below 1 makes it twitchier. Applied to the
## magnitude only, so aiming a direction is unaffected.
static func curve(value: Vector2, exponent: float) -> Vector2:
	var magnitude := value.length()
	if magnitude <= 0.0 or exponent <= 0.0:
		return Vector2.ZERO if magnitude <= 0.0 else value
	return value.normalized() * pow(minf(magnitude, 1.0), exponent)


## The stick, deadzoned and curved in one step — what a caller usually wants.
static func processed(raw: Vector2, exponent: float = 1.0, inner: float = DEFAULT_INNER,
		outer: float = DEFAULT_OUTER) -> Vector2:
	return curve(deadzone(raw, inner, outer), exponent)


## A trigger, which is one axis and has the same two problems.
static func trigger(raw: float, inner: float = 0.1) -> float:
	if raw <= inner or inner >= 1.0:
		return 0.0
	return clampf((raw - inner) / (1.0 - inner), 0.0, 1.0)


## Turn a stick vector into a world direction, relative to where the camera looks.
##
## `camera_yaw` is the camera's Y rotation in radians. Stick up (`-y`) means
## "away from the camera", which is the only mapping that feels right in a
## third-person game and the one that is easiest to get backwards.
static func to_world(value: Vector2, camera_yaw: float) -> Vector3:
	if value == Vector2.ZERO:
		return Vector3.ZERO
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := forward.cross(Vector3.UP).normalized()
	# The magnitude survives: a stick half pushed is a character walking, not
	# running. Normalising here is the other common way analogue input is thrown
	# away.
	return forward * -value.y + right * value.x


## True when a controller is actually plugged in.
##
## Worth asking rather than assuming: a demo that only responds to a pad looks
## broken to someone who does not have one.
static func any_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()
