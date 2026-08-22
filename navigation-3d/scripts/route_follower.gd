class_name RouteFollower
extends RefCounted

## A list of places to visit, and the rule for deciding you have arrived at one.
##
## `NavigationAgent3D` answers "which way to the next corner" and nothing else.
## Everything around that — where the agent is going, when it counts as having
## got there, what it does next — is the game's, and it is where the bugs are.
##
## Two of them in particular:
##
##   * Comparing full 3D distance to a waypoint. The waypoint is usually on the
##     floor and the body's origin is not, so an agent can stand exactly on a
##     marker and never be closer than its own half-height. It circles forever.
##   * An arrival radius smaller than a frame's movement. The agent steps over
##     the waypoint, never registers it, and turns round to try again.

## Where to go, in order.
var waypoints: Array[Vector3] = []

## How close counts as arrived, in metres, measured on the ground plane.
var arrive_distance := 0.6

## Start again at the first waypoint after the last, rather than stopping.
var looping := true

var _index := 0
var _laps := 0


func _init(points: Array[Vector3] = []) -> void:
	waypoints = points


## The waypoint being walked to, or `Vector3.ZERO` if there is no route.
func current() -> Vector3:
	if waypoints.is_empty() or finished():
		return Vector3.ZERO
	return waypoints[_index]


## Is `position` close enough to the current waypoint to count?
##
## Horizontal distance only: the height difference between a body's origin and
## the floor is not progress, and including it makes the radius mean something
## different for every agent size.
func arrived(position: Vector3) -> bool:
	if waypoints.is_empty() or finished():
		return false
	var to := current() - position
	return Vector2(to.x, to.z).length() <= arrive_distance


## Move on to the next waypoint. Wraps, or finishes, depending on `looping`.
##
## Advancing a route that has already finished is a no-op: the clamp below puts
## the index straight back where it was, so there is no second guard to keep
## correct.
func advance() -> void:
	if waypoints.is_empty():
		return
	_index += 1
	if _index >= waypoints.size():
		if looping:
			_index = 0
			_laps += 1
		else:
			_index = waypoints.size()      # one past the end: finished


## Advance if we have arrived. Returns true when the waypoint changed, which is
## the moment a caller would want to re-target the navigation agent.
func update(position: Vector3) -> bool:
	if not arrived(position):
		return false
	advance()
	return true


## True once a non-looping route has been walked to the end.
func finished() -> bool:
	return not looping and _index >= waypoints.size()


func index() -> int:
	return mini(_index, maxi(waypoints.size() - 1, 0))


func laps() -> int:
	return _laps


func reset() -> void:
	_index = 0
	_laps = 0
