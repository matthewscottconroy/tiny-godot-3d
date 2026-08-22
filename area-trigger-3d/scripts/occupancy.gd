class_name Occupancy
extends RefCounted

## Who is standing in the trigger, and — the part that matters — when that
## changes from nobody to somebody.
##
## `Area3D` gives you `body_entered` and `body_exited`, once per body. Almost
## nothing in a game wants that. A pressure plate wants to know when it becomes
## occupied and when it becomes empty; a door wants to stay open while anyone at
## all is standing in the way. Wiring `body_entered` straight to "open the door"
## gives you a door that slams on the second person through it.
##
## So the transition is the event, and the count is the state:
##
##   entered  →  count 0 → 1  →  emit `occupied`
##   entered  →  count 1 → 2  →  nothing
##   exited   →  count 2 → 1  →  nothing
##   exited   →  count 1 → 0  →  emit `vacated`
##
## The other thing this owns is dwell time — "stand here for three seconds" —
## because a timer started by `body_entered` and cancelled by `body_exited` is
## the same bug in a different shape.

## Fires when the zone goes from empty to occupied.
signal occupied

## Fires when the last occupant leaves.
signal vacated

## Fires every time the count changes at all, for a readout.
signal count_changed(count: int)

var _bodies: Array[Node] = []
var _dwell := {}


## Record a body entering. Returns true if this changed the count.
##
## Godot can report the same body twice — a body straddling two shapes of the
## same area, or re-entering within a frame — and a count that goes to two for
## one crate never comes back to zero.
func enter(body: Node) -> bool:
	if body == null or _bodies.has(body):
		return false
	_bodies.append(body)
	_dwell[body] = 0.0
	count_changed.emit(_bodies.size())
	if _bodies.size() == 1:
		occupied.emit()
	return true


## Record a body leaving. Returns true if this changed the count.
func exit(body: Node) -> bool:
	var index := _bodies.find(body)
	if index == -1:
		return false
	_bodies.remove_at(index)
	_dwell.erase(body)
	count_changed.emit(_bodies.size())
	if _bodies.is_empty():
		vacated.emit()
	return true


func contains(body: Node) -> bool:
	return _bodies.has(body)


func count() -> int:
	return _bodies.size()


func is_occupied() -> bool:
	return not _bodies.is_empty()


func bodies() -> Array[Node]:
	return _bodies.duplicate()


## Advance the dwell timers. Call once per frame with the frame's delta.
func advance(delta: float) -> void:
	for body in _bodies:
		_dwell[body] = float(_dwell.get(body, 0.0)) + maxf(delta, 0.0)


## How long this body has been inside, in seconds.
func dwell(body: Node) -> float:
	return float(_dwell.get(body, 0.0))


## The longest anyone currently inside has been here.
##
## What a "stand on the plate for three seconds" puzzle actually asks: whether
## *someone* has waited, not whether the zone has been busy for three seconds
## with people coming and going.
func longest_dwell() -> float:
	var longest := 0.0
	for body in _bodies:
		longest = maxf(longest, dwell(body))
	return longest


## Drop anything that has been freed while inside.
##
## A body destroyed inside a trigger never emits `body_exited`, so without this
## a plate stays pressed by a crate that no longer exists — and the next
## iteration over the occupants errors somewhere far away from the deletion.
func prune() -> void:
	var kept: Array[Node] = []
	for body in _bodies:
		if is_instance_valid(body):
			kept.append(body)
		else:
			_dwell.erase(body)
	if kept.size() == _bodies.size():
		return
	_bodies = kept
	count_changed.emit(_bodies.size())
	if _bodies.is_empty():
		vacated.emit()


func clear() -> void:
	if _bodies.is_empty():
		return
	_bodies.clear()
	_dwell.clear()
	count_changed.emit(0)
	vacated.emit()
