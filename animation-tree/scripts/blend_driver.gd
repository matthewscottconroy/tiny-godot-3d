class_name BlendDriver
extends RefCounted

## Turning a speed into a blend position, without the twitching.
##
## An `AnimationTree` blend space takes a number and mixes the clips either side
## of it. Feeding it the character's speed is obvious and nearly right, and the
## three things it gets wrong are all things a player feels rather than sees:
##
##   * **Idle twitch.** A character standing still is never exactly still — a
##     controller drifts, a physics body settles, a slope nudges. Feeding raw
##     speed in makes the idle clip flicker into the walk clip and back, several
##     times a second.
##   * **A snapping blend.** Speed can change instantly; a blend cannot, or the
##     legs change gait between one frame and the next. The blend has to chase
##     the speed rather than equal it.
##   * **A blend that is not the speed ratio.** Blend spaces are usually
##     authored with the walk clip at 1 and the run clip at 2 — not at the metres
##     per second the character happens to move at. Passing raw speed works right
##     up until someone tunes the movement.

## Below this, the character counts as standing still.
var idle_threshold := 0.15

## How fast the blend chases the speed, as a fraction of the remaining distance
## per second.
var smoothing := 8.0

var _blend := 0.0


## Where in the blend space a given speed belongs.
##
## The blend space's own points are at 0 (idle), 1 (walk) and 2 (run), so this
## maps the character's real speeds onto those positions rather than passing
## metres per second into a space that knows nothing about them.
static func position_for(speed: float, walk_speed: float, run_speed: float,
		idle_threshold: float = 0.15) -> float:
	if speed <= idle_threshold:
		return 0.0
	var walk := maxf(walk_speed, 0.0001)
	if speed <= walk:
		# Between standing and walking. Measured from the idle threshold, so the
		# first moving frame is not already a quarter of the way to a walk.
		var span := maxf(walk - idle_threshold, 0.0001)
		return clampf((speed - idle_threshold) / span, 0.0, 1.0)
	var run := maxf(run_speed, walk + 0.0001)
	return clampf(1.0 + (speed - walk) / (run - walk), 1.0, 2.0)


## Advance the blend toward the position that speed asks for.
##
## Frame-rate independent, so the gait change takes the same time on any machine.
func update(speed: float, walk_speed: float, run_speed: float, delta: float) -> float:
	var wanted := position_for(speed, walk_speed, run_speed, idle_threshold)
	if delta <= 0.0:
		return _blend
	var weight := 1.0 if smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
	_blend = lerpf(_blend, wanted, weight)
	return _blend


## What the blend is now, without advancing it.
func blend() -> float:
	return _blend


## Put the blend where it belongs immediately — a respawn, or a cut.
func snap(speed: float, walk_speed: float, run_speed: float) -> float:
	_blend = position_for(speed, walk_speed, run_speed, idle_threshold)
	return _blend


func reset() -> void:
	_blend = 0.0


## Which clip is doing most of the work, for a footstep sound or a HUD.
static func dominant_clip(blend_position: float) -> String:
	if blend_position < 0.5:
		return "idle"
	if blend_position < 1.5:
		return "walk"
	return "run"


## How fast the animation should play to match the ground.
##
## The other half of a blend space: if the walk clip was authored at 2 m/s and
## the character moves at 3, the feet slide. Scaling the playback rate to the
## ratio is what "foot sliding" fixes usually mean.
static func time_scale_for(speed: float, clip_speed: float,
		limits: Vector2 = Vector2(0.6, 1.8)) -> float:
	if clip_speed <= 0.0001 or speed <= 0.0:
		return 1.0
	return clampf(speed / clip_speed, limits.x, limits.y)
