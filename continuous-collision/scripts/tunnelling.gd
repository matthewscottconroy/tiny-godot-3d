class_name Tunnelling
extends RefCounted

## Whether a moving body will pass straight through a wall this frame.
##
## Physics engines move a body by teleporting it: position plus velocity times
## delta, then look for overlaps. A bullet at 200 m/s covers 3.3 metres in a
## 60Hz frame, so a 0.2-metre wall spends *no frame at all* with the bullet
## inside it. There is nothing to detect. The bullet is in front of the wall,
## and then it is behind it.
##
## This is tunnelling, and it is not a bug in the engine — it is the cost of
## discrete steps. The fixes all amount to the same idea: check the *path*
## rather than the destination.
##
##   * `continuous_cd` on a `RigidBody3D` makes the engine sweep the shape along
##     its motion. Correct, and the most expensive option.
##   * A raycast from where the body was to where it is going. Cheap, exact for
##     a point, and what most games ship for bullets.
##   * A smaller physics step. Fixes everything, costs everything.
##
## The arithmetic below is what tells you which one you need, and it is worth
## having outside the physics server because the answer is a number you can
## print rather than a thing you squint at.

## How far a body travels in one physics step.
static func travel_per_step(speed: float, hz: float) -> float:
	return speed / maxf(hz, 0.0001)


## Will a body moving this fast skip over a wall this thick?
##
## The comparison everyone gets wrong by a factor of two: what matters is the
## distance covered in *one step* against the wall's thickness, not against the
## distance to it.
static func tunnels(speed: float, hz: float, thickness: float) -> bool:
	return travel_per_step(speed, hz) > maxf(thickness, 0.0)


## The fastest a body can go and still be caught by discrete collision.
##
## Under this, the body is inside the wall for at least one step, which is all
## the engine needs.
static func safe_speed(hz: float, thickness: float) -> float:
	return maxf(thickness, 0.0) * maxf(hz, 0.0001)


## The physics rate that would make this speed safe.
##
## Usually the answer you do *not* want — it is a global cost paid by every body
## in the scene so that one bullet behaves — but it is worth seeing the number.
static func required_hz(speed: float, thickness: float) -> float:
	if thickness <= 0.0:
		return INF
	return speed / thickness


## How many steps a body spends inside a wall of this thickness.
##
## Below 1, it can miss. Around 1 it is a coin toss, decided by where in the
## step the body happened to be — which is the version of this bug that
## reproduces one time in five and gets closed as unrepeatable.
static func steps_inside(speed: float, hz: float, thickness: float) -> float:
	var step := travel_per_step(speed, hz)
	if step <= 0.0:
		return INF
	return thickness / step


## The segment to cast along for a body that moved this way.
##
## From where it was to where it is: the raycast fix in one line. `from` is
## last frame's position — a cast from the *current* position finds only what is
## still ahead, which is everything except the wall it has already passed.
static func sweep(from: Vector3, to: Vector3) -> Vector3:
	return to - from
