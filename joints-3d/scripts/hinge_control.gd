class_name HingeControl
extends RefCounted

## Driving a hinge toward an angle without fighting it.
##
## A `HingeJoint3D` gives you two things: limits, which the solver enforces, and
## a motor, which applies torque toward a target *velocity*. Note what is missing
## — there is no target *angle*. Almost every door, hatch and drawbridge wants
## one, and writing the loop that turns an angle into a velocity is where the
## trouble starts:
##
##   * **Buzzing.** Drive at full speed until the angle matches exactly and the
##     motor overshoots, reverses, overshoots again. The door vibrates against
##     its own motor and the physics server heats up.
##   * **The long way round.** Angles wrap. A door at 179° asked to reach -179°
##     should move two degrees, not three hundred and fifty-eight.
##   * **Fighting the limits.** A motor still driving into a limit the solver is
##     enforcing is two systems pushing against each other forever.
##
## All three are arithmetic, and none of them is visible in a screenshot: a
## buzzing door looks like a door.

## The hinge's own limits, in radians. Keep them equal to the joint's.
var min_angle := 0.0
var max_angle := PI * 0.55

## How fast the motor drives, in radians per second.
var speed := 2.5

## Inside this many radians of the target, stop driving. This is the number that
## stops the buzz — without it the motor never agrees that it has arrived.
var tolerance := 0.02

## Slow down within this many radians of the target, so it settles rather than
## slamming.
var approach := 0.35


## Wrap an angle into -PI..PI.
static func normalise_angle(angle: float) -> float:
	return wrapf(angle, -PI, PI)


## The shortest signed distance from `from` to `to`, taking wrapping into account.
static func shortest_delta(from: float, to: float) -> float:
	return normalise_angle(to - from)


## Keep an angle inside the hinge's limits.
func clamp_angle(angle: float) -> float:
	return clampf(angle, min_angle, max_angle)


## The motor velocity to apply, given where the hinge is and where it should be.
##
## Zero when close enough, eased down near the target, and always taking the
## short way round.
func drive_toward(current: float, target: float) -> float:
	var wanted := clamp_angle(target)
	var delta := shortest_delta(current, wanted)
	if absf(delta) <= tolerance:
		return 0.0
	var scale := 1.0
	if approach > 0.0:
		scale = clampf(absf(delta) / approach, 0.2, 1.0)
	return signf(delta) * speed * scale


## True once the hinge has swung far enough to matter.
##
## "Open" is a game question, not a physics one: a door ajar by two degrees is
## shut as far as the player is concerned, and as far as an AI pathing through it
## should be concerned too.
func is_open(current: float, threshold: float = 0.6) -> bool:
	return absf(current - min_angle) >= threshold


## How far through its travel the hinge is, 0 closed to 1 fully open.
func openness(current: float) -> float:
	var span := max_angle - min_angle
	if absf(span) < 0.0001:
		return 0.0
	return clampf((current - min_angle) / span, 0.0, 1.0)


## Is the hinge pressed against one of its limits?
##
## Worth knowing, because a motor still driving into a limit is two systems
## pushing at each other for as long as the game runs.
func at_limit(current: float, epsilon: float = 0.02) -> bool:
	return current <= min_angle + epsilon or current >= max_angle - epsilon
