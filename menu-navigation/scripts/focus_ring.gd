class_name FocusRing
extends RefCounted

## Moving focus around a menu with a stick, a d-pad, or the arrow keys.
##
## A menu that only works with a mouse is a menu that does not work on a sofa,
## and does not work for anyone who cannot use a mouse. Godot has focus
## neighbours built in — and they are set by hand, per control, per direction,
## which is four properties on every button and a broken menu the first time
## somebody inserts a row.
##
## Working them out from the layout instead is about thirty lines, and it is
## right whatever the menu looks like afterwards.
##
## The parts that are easy to get wrong:
##
##   * **Nearest is not the answer.** The nearest control to a button is often
##     beside it rather than below it, so direction has to filter before
##     distance chooses.
##   * **Something must be focused when the menu opens**, or a gamepad — which
##     has no pointer — does nothing at all and the menu looks frozen.
##   * **Focus is lost when the thing holding it disappears.** Hide or disable a
##     focused control and the menu goes dead, silently.

## How much a candidate has to be *in* the direction rather than beside it: the
## cosine of the widest angle that still counts. 0.35 is about 70 degrees either
## side — forgiving for a ragged layout, tight enough that down never goes
## sideways.
var alignment := 0.35

## Off the end of a column, come back at the other end.
var wrap := true


## The index to focus when the player presses a direction.
##
## Returns -1 when nothing qualifies and wrapping is off, which the caller should
## treat as "stay where you are" rather than "focus nothing".
func next_in_direction(rects: Array[Rect2], from: int, direction: Vector2) -> int:
	if rects.is_empty() or direction.is_zero_approx():
		return -1
	if from < 0 or from >= rects.size():
		return first(rects, direction)
	var wanted := direction.normalized()
	var origin := rects[from].get_center()
	var best := -1
	var best_score := INF
	for i in rects.size():
		if i == from:
			continue
		var offset := rects[i].get_center() - origin
		if offset.is_zero_approx():
			continue
		# Direction first, distance second. The nearest control may well be the
		# one beside this button rather than the one below it.
		if offset.normalized().dot(wanted) < alignment:
			continue
		# Distance along the direction, plus a penalty for drifting off it, so a
		# button directly below beats one below and far to the left.
		var along := offset.dot(wanted)
		var across := absf(offset.dot(Vector2(-wanted.y, wanted.x)))
		var score := along + across * 2.0
		if score < best_score:
			best_score = score
			best = i
	if best == -1 and wrap:
		return furthest_against(rects, from, wanted)
	return best


## Coming off the end: the control furthest back the other way.
func furthest_against(rects: Array[Rect2], from: int, direction: Vector2) -> int:
	var best := -1
	var best_score := -INF
	for i in rects.size():
		if i == from:
			continue
		# Measured from the origin of the coordinate space, not from where focus
		# happens to be: subtracting the current position adds the same constant
		# to every candidate, so it cannot change which one is furthest.
		var score := -rects[i].get_center().dot(direction)
		if score > best_score:
			best_score = score
			best = i
	return best


## What to focus when a menu opens, given the direction the player is heading.
##
## Never -1 for a menu with anything in it: a gamepad has no pointer, so a menu
## with nothing focused looks frozen.
static func first(rects: Array[Rect2], direction: Vector2 = Vector2.DOWN) -> int:
	if rects.is_empty():
		return -1
	var wanted := direction.normalized() if not direction.is_zero_approx() else Vector2.DOWN
	# Seeded from the first candidate rather than from INF: a starting value
	# nothing can beat makes the comparison below unfalsifiable, and the function
	# returns index 0 whichever way round it is written.
	var best := 0
	var best_score := rects[0].get_center().dot(wanted)
	for i in range(1, rects.size()):
		var score := rects[i].get_center().dot(wanted)
		if score < best_score:
			best_score = score
			best = i
	return best


## Where focus should go when the control holding it is no longer usable.
##
## The forgotten case: hide or disable a focused control and the menu goes dead.
## Nothing warns, and nobody notices until a player without a mouse tries it.
static func after_losing(rects: Array[Rect2], lost: int, usable: Array[bool]) -> int:
	if rects.is_empty():
		return -1
	# The next usable one below, then the next usable one above, then anything.
	for i in range(lost + 1, rects.size()):
		if i < usable.size() and usable[i]:
			return i
	for i in range(lost - 1, -1, -1):
		if i < usable.size() and usable[i]:
			return i
	return -1


## A direction from a pressed input, or zero for anything that is not one.
static func direction_of(left: bool, right: bool, up: bool, down: bool) -> Vector2:
	return Vector2(float(right) - float(left), float(down) - float(up))
