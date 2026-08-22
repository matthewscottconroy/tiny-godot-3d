class_name ArmSmoothing
extends RefCounted

## How fast a camera arm changes length — fast in, slow out.
##
## `SpringArm3D` finds the obstruction for you and reports the length it will
## allow. What it does not do is decide how quickly to move between the length
## you want and the length you can have, and that decision is most of what makes
## a third-person camera feel good or terrible.
##
## The rule is asymmetric. Pulling *in* has to be immediate: a camera that eases
## into a wall spends the ease inside the wall, showing the level's backfaces.
## Pushing *back out* has to be gradual, or every doorway and lamp post the
## camera brushes past snaps the view.
##
## Frame-rate independence is the other half. `lerp(current, target, 0.1)` moves
## a tenth of the way *per frame*, so the camera behaves differently at 60fps and
## 144fps. The exponential form below covers the same fraction per second at any
## frame rate, which is why two half-steps land exactly where one whole step does.

## Length the arm should be at after `delta`, given where it is and what it wants.
##
## `in_rate` and `out_rate` are in "fraction of the remaining distance per
## second", not metres per second. A rate of 0 or less means jump there now.
static func recover(current: float, target: float, in_rate: float, out_rate: float,
		delta: float) -> float:
	if is_equal_approx(current, target) or delta <= 0.0:
		return current
	var rate := out_rate if target > current else in_rate
	if rate <= 0.0:
		return target
	# 1 - e^(-rate*t) is the fraction covered in time t. Composing two intervals
	# multiplies the *remaining* fractions, which is exactly what makes it
	# frame-rate independent.
	return current + (target - current) * (1.0 - exp(-rate * delta))


## The same, clamped to the arm's own limits — the camera never ends up inside
## the character, and never further out than the arm allows.
static func recover_clamped(current: float, target: float, in_rate: float,
		out_rate: float, delta: float, min_length: float, max_length: float) -> float:
	var wanted := clampf(target, min_length, max_length)
	return clampf(recover(current, wanted, in_rate, out_rate, delta), min_length, max_length)


## True when the arm is being held shorter than it would like to be.
##
## Worth having as a named thing rather than a comparison inline: it is what a
## HUD, a fade-out of the character's mesh, or a "do not fire" rule keys off.
static func is_obstructed(current: float, wanted: float, tolerance: float = 0.05) -> bool:
	return current < wanted - tolerance
