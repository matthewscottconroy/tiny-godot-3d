class_name ShadowBudget
extends RefCounted

## Which lights are allowed to cast shadows this frame.
##
## A light is cheap. A light that casts shadows is not: every shadow-casting
## omni light renders the scene six times into a cube map, and a spot light
## once. Twenty lit lamp posts are fine; twenty shadow-casting lamp posts are a
## different game entirely.
##
## The usual fix is a budget — only the few nearest the camera cast — and the
## usual bug in that fix is flicker. Two lights at almost the same distance swap
## the last slot back and forth as the camera drifts, and a shadow appearing and
## disappearing is far more noticeable than a shadow that was never there. The
## margin below is what stops that: a light has to be meaningfully closer than
## the one it displaces, not merely closer.

## How much nearer a light must be to take a slot from the one holding it, in
## metres. Zero means "swap on any difference", which is where the flicker is.
var switch_margin := 1.5

## Lights beyond this distance never cast, however few there are. A shadow you
## cannot resolve costs the same as one you can.
var max_distance := 30.0

var _current: Array[int] = []


## Light indices ordered by distance from the viewer, nearest first.
##
## Ties keep their original order, so an unchanged scene produces an unchanged
## answer rather than one that depends on the sort's internals.
static func ranked(positions: Array[Vector3], viewer: Vector3) -> Array[int]:
	var order: Array[int] = []
	for i in positions.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := viewer.distance_squared_to(positions[a])
		var db := viewer.distance_squared_to(positions[b])
		if is_equal_approx(da, db):
			return a < b
		return da < db)
	return order


## Which lights should cast shadows, as one flag per light.
##
## Stateless: this is the answer for a scene seen from `viewer` with no history.
## Use `update()` for the frame-to-frame version, which resists flicker.
func casters(positions: Array[Vector3], viewer: Vector3, budget: int) -> Array[bool]:
	var flags: Array[bool] = []
	flags.resize(positions.size())
	flags.fill(false)
	if budget <= 0:
		return flags
	var chosen := 0
	for index in ranked(positions, viewer):
		if chosen >= budget:
			break
		if viewer.distance_to(positions[index]) > max_distance:
			continue                       # too far to be worth resolving
		flags[index] = true
		chosen += 1
	return flags


## The same answer, but sticky: a light already casting keeps its slot unless a
## rival is `switch_margin` metres nearer.
func update(positions: Array[Vector3], viewer: Vector3, budget: int) -> Array[bool]:
	var flags: Array[bool] = []
	flags.resize(positions.size())
	flags.fill(false)
	if budget <= 0:
		_current = []
		return flags

	var kept: Array[int] = []
	for index in _current:
		# An incumbent can have been deleted, or moved out of range.
		if index < positions.size() and viewer.distance_to(positions[index]) <= max_distance:
			kept.append(index)
	kept = kept.slice(0, budget)

	var chosen := kept.duplicate()
	for index in ranked(positions, viewer):
		if chosen.size() >= budget:
			break
		if chosen.has(index):
			continue
		if viewer.distance_to(positions[index]) > max_distance:
			continue
		chosen.append(index)

	# Everything is placed; now let a clearly nearer light displace the worst
	# incumbent. One swap per call, so a busy scene settles instead of churning.
	var challenger := _best_outsider(positions, viewer, chosen)
	if challenger != -1:
		var weakest := _worst_insider(positions, viewer, chosen)
		if weakest != -1:
			var gain := viewer.distance_to(positions[chosen[weakest]]) \
				- viewer.distance_to(positions[challenger])
			if gain > switch_margin:
				chosen[weakest] = challenger

	for index in chosen:
		flags[index] = true
	_current = chosen
	return flags


func casting() -> Array[int]:
	return _current.duplicate()


func reset() -> void:
	_current = []


func _best_outsider(positions: Array[Vector3], viewer: Vector3, chosen: Array[int]) -> int:
	for index in ranked(positions, viewer):
		if chosen.has(index):
			continue
		if viewer.distance_to(positions[index]) > max_distance:
			continue
		return index
	return -1


func _worst_insider(positions: Array[Vector3], viewer: Vector3, chosen: Array[int]) -> int:
	var worst := -1
	var worst_distance := -1.0
	for slot in chosen.size():
		var distance := viewer.distance_to(positions[chosen[slot]])
		if distance > worst_distance:
			worst_distance = distance
			worst = slot
	return worst
