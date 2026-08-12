## A third-person camera rig that orbits a target.
##
## The maths people get wrong here is not the orbit — it is the order. Yaw then
## pitch, applied to a fixed offset, keeps the camera upright; doing it the other
## way round rolls the horizon as you look up. And pitch must be clamped short of
## straight up and straight down, because at exactly vertical the look-at basis
## becomes degenerate and the view snaps.
##
## The rig is pure maths over an anchor position, so it can be tested without a
## viewport and reused for a spring arm, a cinematic camera, or a minimap.
class_name OrbitRig
extends RefCounted

## Distance from the target.
var distance := 6.0
var min_distance := 1.5
var max_distance := 20.0

## Yaw is unbounded (it wraps); pitch is clamped away from the poles.
var yaw := 0.0
## Positive pitch raises the camera above the target (looking down on it).
var pitch := 0.35
var min_pitch := -1.2     # just short of looking straight up from below
var max_pitch := 1.4      # just short of looking straight down

var sensitivity := 0.005

## Where the camera should sit, given the point it is orbiting.
func position_for(target: Vector3) -> Vector3:
	return target + offset()

## The camera's offset from the target: a fixed back-vector, pitched then yawed.
func offset() -> Vector3:
	var back := Vector3(0.0, 0.0, distance)
	# Pitch about X first, then yaw about Y. Reversing these rolls the horizon.
	# Negated so that positive pitch lifts the camera rather than dropping it.
	back = back.rotated(Vector3.RIGHT, -pitch)
	back = back.rotated(Vector3.UP, yaw)
	return back

## Apply a mouse delta.
func look(relative: Vector2) -> void:
	yaw -= relative.x * sensitivity
	pitch = clampf(pitch + relative.y * sensitivity, min_pitch, max_pitch)

func zoom(steps: float) -> void:
	distance = clampf(distance + steps, min_distance, max_distance)

## The horizontal facing the player should move along — the camera's forward
## flattened onto the ground plane. Movement that uses the un-flattened forward
## drifts into the floor as you look down.
func ground_basis() -> Dictionary:
	var forward := -offset()
	forward.y = 0.0
	if forward.length() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	return {"forward": forward, "right": forward.cross(Vector3.UP).normalized()}

## Turn a 2D input vector into a world-space direction relative to the camera.
func movement_direction(input: Vector2) -> Vector3:
	var b := ground_basis()
	var dir: Vector3 = b["forward"] * -input.y + b["right"] * input.x
	return dir.normalized() if dir.length() > 0.0001 else Vector3.ZERO

## Pull the camera in if something is between it and the target, so the view
## never ends up inside a wall. `hit_distance` is however far a ray got.
func pulled_in(hit_distance: float, padding: float = 0.3) -> Vector3:
	var wanted := offset()
	var limit := maxf(hit_distance - padding, min_distance)
	if limit >= wanted.length():
		return wanted
	return wanted.normalized() * limit
