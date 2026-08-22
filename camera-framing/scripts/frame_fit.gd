class_name FrameFit
extends RefCounted

## Keeping several things on screen at once.
##
## Following one target is a lerp. Following four — a party, a squad, two players
## in a brawler — is a different question: where does the camera go, and how far
## back, so that everyone is inside the frustum with a bit of room to spare?
##
## It is arithmetic, and it has three parts people get wrong:
##
##   * **The centre is the middle of the bounds, not the average.** Average four
##     players, three of whom are standing together, and the camera drifts toward
##     the group and leaves the fourth off screen.
##   * **The limiting axis is usually the vertical one.** Godot's `fov` is the
##     *vertical* angle, and on a wide screen the horizontal one is wider. Fit to
##     the vertical and the horizontal takes care of itself; fit to the
##     horizontal and things fall off the top.
##   * **Zoom has to be clamped and smoothed.** An unclamped fit puts the camera
##     in orbit when someone falls down a hole, and an unsmoothed one snaps every
##     time a player jumps.

## Limits on how far back the camera will go.
var min_distance := 6.0
var max_distance := 40.0

## Extra room around the group, as a fraction of the fitted radius.
var padding := 0.25

## How quickly the camera converges, as a fraction of the remaining distance per
## second. Frame-rate independent, in the same way as spring-arm-camera's.
var smoothing := 4.0

var _distance := 0.0
var _focus := Vector3.ZERO
var _started := false


## The box containing every point.
static func bounds_of(points: Array[Vector3]) -> AABB:
	if points.is_empty():
		return AABB()
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


## The point the camera should look at: the middle of the bounds.
##
## Not the average. Averaging pulls the camera toward whichever cluster has the
## most members and leaves the outlier off the edge of the screen — which is the
## one player who needed the camera.
static func focus_of(points: Array[Vector3]) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var box := bounds_of(points)
	return box.position + box.size * 0.5


## The radius of a sphere around the group, from its centre.
static func radius_of(points: Array[Vector3]) -> float:
	if points.size() < 2:
		return 0.0
	return bounds_of(points).size.length() * 0.5


## How far back a camera needs to be to fit a sphere of `radius`.
##
## `fov_degrees` is Godot's vertical field of view. On a screen wider than it is
## tall the horizontal angle is larger, so the vertical one is what binds — but
## on a tall screen it is the other way round, which is why the aspect is a
## parameter rather than an assumption.
static func distance_for(radius: float, fov_degrees: float, aspect: float) -> float:
	if radius <= 0.0:
		return 0.0
	var vertical := deg_to_rad(clampf(fov_degrees, 1.0, 179.0)) * 0.5
	var limiting := vertical
	if aspect > 0.0 and aspect < 1.0:
		# Taller than it is wide: the horizontal angle is the narrower one.
		limiting = atan(tan(vertical) * aspect)
	return radius / maxf(sin(limiting), 0.0001)


## Where the camera should be and how far back, smoothed toward the answer.
##
## Returns `{"focus": Vector3, "distance": float}`. The caller decides the
## direction — this has no opinion about whether the camera is overhead, behind,
## or on a rail.
func update(points: Array[Vector3], fov_degrees: float, aspect: float,
		delta: float) -> Dictionary:
	var wanted_focus := focus_of(points)
	var wanted_distance := clampf(
		distance_for(radius_of(points) * (1.0 + padding), fov_degrees, aspect),
		min_distance, max_distance)

	if not _started:
		# The first frame snaps. Easing in from wherever the camera happened to
		# be left is a swoop nobody asked for at the start of every level.
		_focus = wanted_focus
		_distance = wanted_distance
		_started = true
	elif delta > 0.0:
		# A smoothing of zero means "no smoothing" — arrive now. Treating it as
		# "never move" would be a camera that silently stops following.
		var weight := 1.0 if smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
		_focus = _focus.lerp(wanted_focus, weight)
		_distance = lerpf(_distance, wanted_distance, weight)
	return {"focus": _focus, "distance": _distance}


## The unsmoothed answer, for a cut rather than a move.
func snap(points: Array[Vector3], fov_degrees: float, aspect: float) -> Dictionary:
	_started = false
	return update(points, fov_degrees, aspect, 0.0)


func focus() -> Vector3:
	return _focus


func distance() -> float:
	return _distance
