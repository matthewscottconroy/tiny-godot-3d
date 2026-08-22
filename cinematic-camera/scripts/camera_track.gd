class_name CameraTrack
extends RefCounted

## Moving a camera along a path, and getting into and out of it without a cut.
##
## Godot will happily move a camera along a `Path3D` — that part is
## `PathFollow3D` and takes one property. What it will not do is get you *there*:
## `make_current()` is an instant cut, and a cut from the player's own camera to
## a cutscene one is jarring in a way that reads as a bug rather than as
## direction.
##
## The fix is a third camera that interpolates between the two transforms, and a
## weight curve to drive it. Both halves are here, because both are the parts
## that get written badly:
##
##   * A **linear** blend starts and stops abruptly. Smoothstep is one line and
##     is the difference between a camera move and a camera lurch.
##   * A blend that runs on `Transform3D.interpolate_with()` handles rotation
##     correctly. Lerping position and Euler angles separately takes the long way
##     round through any rotation over 180°, which looks like the camera has been
##     thrown.

## Seconds a blend takes, in either direction.
var blend_duration := 1.2

## Seconds the whole track takes to traverse once.
var duration := 8.0

## Start again at the beginning when the end is reached.
var looping := true

var _progress := 0.0
var _blend := 0.0
var _target := 0.0


## Advance the camera along the track. Returns the new progress, 0..1.
func advance(delta: float) -> float:
	if duration <= 0.0:
		return _progress
	_progress += maxf(delta, 0.0) / duration
	if _progress >= 1.0:
		_progress = fposmod(_progress, 1.0) if looping else 1.0
	return _progress


## Advance the blend toward whichever camera is wanted. Returns the weight,
## 0 for the gameplay camera and 1 for the cinematic one.
func advance_blend(delta: float) -> float:
	if blend_duration <= 0.0:
		_blend = _target
		return _blend
	var step := maxf(delta, 0.0) / blend_duration
	_blend = move_toward(_blend, _target, step)
	return _blend


## Ask to move to the cinematic camera, or back to the gameplay one.
func set_cinematic(active: bool) -> void:
	_target = 1.0 if active else 0.0


func is_cinematic() -> bool:
	return _target > 0.5


func progress() -> float:
	return _progress


func blend() -> float:
	return _blend


## True while a blend is in flight, which is when the third camera has to be the
## current one.
func is_blending() -> bool:
	return _blend > 0.0 and _blend < 1.0


func reset() -> void:
	_progress = 0.0
	_blend = 0.0
	_target = 0.0


## Ease a linear 0..1 into something that starts and stops gently.
##
## The whole difference between a camera move and a camera lurch, in one line.
static func eased(weight: float) -> float:
	var t := clampf(weight, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Blend two camera transforms.
##
## `Transform3D.interpolate_with()` rather than lerping position and rotation
## separately: it interpolates the basis as a rotation, so a blend across a large
## turn takes the short way round instead of unwinding through the long one.
static func blended(from: Transform3D, to: Transform3D, weight: float) -> Transform3D:
	var t := clampf(weight, 0.0, 1.0)
	if t <= 0.0:
		return from
	if t >= 1.0:
		return to
	return from.interpolate_with(to, eased(t))


## A point slightly further along the track, for the camera to look at.
##
## A camera that looks exactly where it is going has nothing to aim at. Sampling
## ahead and aiming there is what makes a dolly shot feel intentional.
static func look_ahead(progress_value: float, amount: float, loops: bool) -> float:
	var ahead := progress_value + amount
	if loops:
		return fposmod(ahead, 1.0)
	return clampf(ahead, 0.0, 1.0)
