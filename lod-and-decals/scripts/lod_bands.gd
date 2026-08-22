class_name LodBands
extends RefCounted

## Distance bands, and the hysteresis that stops them flickering.
##
## Level of detail is one idea used for several things: which mesh to draw, how
## often to run an AI, whether a decal is worth rendering, whether a light casts
## a shadow. All of them are the same question — *how far away is this?* — and
## all of them have the same failure mode.
##
## A player standing exactly on a boundary switches back and forth every frame.
## The mesh pops, the shadow strobes, the AI runs at two different rates in
## alternate frames. It is the single most visible LOD bug, it is nearly
## impossible to reproduce deliberately, and it is fixed by making the boundary
## depend on which side you are already on: you must go a little *past* it to
## change, not merely reach it.
##
## Godot's own `visibility_range_begin` / `visibility_range_end` do the mesh case
## for you, with a fade to cover the switch. This produces the numbers to put in
## them — and answers the same question for everything the engine does not do.

## Where each level ends, in metres, nearest first. Level 0 runs from the camera
## to `distances[0]`, level 1 from there to `distances[1]`, and so on.
var distances: Array[float] = [12.0, 30.0, 70.0]

## How far past a boundary you have to go before the level changes.
var hysteresis := 2.0


## The level for a distance, ignoring which level we are on now.
##
## The naive answer, and the one that flickers on a boundary.
func level_for(distance: float) -> int:
	for i in distances.size():
		if distance < distances[i]:
			return i
	return distances.size()


## The level to use, given the level currently in use.
##
## Changing level requires crossing the boundary *plus* the hysteresis, so a
## camera hovering on a threshold stays where it is.
func stable_level_for(distance: float, current: int) -> int:
	var level := clampi(current, 0, distances.size())
	# Moving further away: only step out past the boundary plus the margin.
	if level < distances.size() and distance > distances[level] + hysteresis:
		return level_for(distance)
	# Coming closer: only step in once well inside the boundary below.
	if level > 0 and distance < distances[level - 1] - hysteresis:
		return level_for(distance)
	return level


## The begin/end pair for a level, as `GeometryInstance3D` wants them.
##
## Level 0 begins at 0 — a mesh with `visibility_range_begin = 0` is visible from
## the camera outward, which is what "the close-up mesh" means.
func range_for(level: int) -> Vector2:
	var index := clampi(level, 0, distances.size())
	var begin := 0.0 if index == 0 else distances[index - 1]
	var end := 0.0 if index >= distances.size() else distances[index]
	# An end of 0 means "no far limit" to Godot, which is what the last level
	# wants: it draws from its beginning to the horizon.
	return Vector2(begin, end)


## Every level's range, for setting up a whole LOD chain at once.
func ranges() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for level in distances.size() + 1:
		out.append(range_for(level))
	return out


## How opaque something should be at this distance, fading out over `length`
## metres before `end`.
##
## Decals and small props are better faded than switched: the eye notices a
## thing vanishing far more than it notices one becoming faint.
static func fade_alpha(distance: float, end: float, length: float) -> float:
	if end <= 0.0:
		return 1.0                        # no far limit: always solid
	if distance >= end:
		return 0.0
	var fade_length := maxf(length, 0.0001)
	if distance <= end - fade_length:
		return 1.0
	return clampf((end - distance) / fade_length, 0.0, 1.0)


## How often something at this distance should update, in seconds.
##
## The other half of LOD, and the half nobody sees: an enemy fifty metres away
## does not need its state machine run sixty times a second.
func update_interval(level: int, base_interval: float = 1.0 / 60.0) -> float:
	return base_interval * pow(2.0, float(clampi(level, 0, distances.size())))
