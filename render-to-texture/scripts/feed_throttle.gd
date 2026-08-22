class_name FeedThrottle
extends RefCounted

## How often a second camera has to redraw, and at what size.
##
## A `SubViewport` rendering the world onto a screen is a whole extra render of
## the scene: culling, shadows, transparency, the lot. One is affordable. A
## corridor of eight security monitors is the same scene rendered nine times a
## frame, and it is why render-to-texture has a reputation.
##
## Almost none of that cost is necessary. A monitor across the room does not need
## sixty updates a second at full resolution; a monitor behind the player does
## not need any. The savings are enormous and the logic is small — which is the
## whole reason to write it down rather than leave every screen on
## `UPDATE_ALWAYS`.

## Distances at which the feed drops to the next rate down.
var near_distance := 8.0
var far_distance := 25.0

## Updates per second at each band.
var near_hz := 60.0
var mid_hz := 15.0
var far_hz := 5.0

var _time_since_update := 0.0


## The rate a feed at this distance should run at, in hertz. Zero means never.
func rate_for(distance: float, visible: bool) -> float:
	if not visible:
		# Off screen or behind a wall: not "slower", but *not at all*. This is
		# the saving that dwarfs the others.
		return 0.0
	if distance <= near_distance:
		return near_hz
	if distance <= far_distance:
		return mid_hz
	return far_hz


## Should the feed redraw this frame?
##
## Call once per frame; it accumulates time internally so the caller does not
## have to keep a timer per screen.
func should_update(distance: float, visible: bool, delta: float) -> bool:
	var rate := rate_for(distance, visible)
	if rate <= 0.0:
		_time_since_update = 0.0
		return false
	_time_since_update += maxf(delta, 0.0)
	if _time_since_update < 1.0 / rate:
		return false
	_time_since_update = 0.0
	return true


## The resolution a feed at this distance is worth rendering at.
##
## A monitor twenty metres away covers a few dozen pixels on screen; rendering it
## at 1024² and then minifying it is work thrown away.
static func resolution_for(distance: float, base: Vector2i, near: float = 8.0,
		far: float = 25.0) -> Vector2i:
	var scale := 1.0
	if distance > far:
		scale = 0.25
	elif distance > near:
		scale = 0.5
	# Never below 32 pixels: a viewport smaller than that costs nothing to
	# render and looks like a fault rather than a distant screen.
	return Vector2i(maxi(int(base.x * scale), 32), maxi(int(base.y * scale), 32))


## Godot's own update mode for a feed in this state.
##
## `UPDATE_ALWAYS` is the one everyone reaches for and the one that costs. The
## others exist precisely for this decision.
static func update_mode_for(visible: bool, continuous: bool) -> int:
	if not visible:
		return SubViewport.UPDATE_DISABLED
	return SubViewport.UPDATE_ALWAYS if continuous else SubViewport.UPDATE_ONCE


## How much of a full-rate feed this one costs, 0..1. For a HUD, and for
## deciding whether another screen fits in the budget.
func cost_of(distance: float, visible: bool) -> float:
	if near_hz <= 0.0:
		return 0.0
	return clampf(rate_for(distance, visible) / near_hz, 0.0, 1.0)


func reset() -> void:
	_time_since_update = 0.0
