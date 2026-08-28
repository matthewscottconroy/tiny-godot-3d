class_name AimConstraint
extends RefCounted

## Turning a bone toward something, without fighting the animation that set it.
##
## Procedural pose changes — a head that follows the player, a gun hand that
## tracks a target, a spine that leans into a turn — all have the same problem:
## they have to happen *after* the animation has written the pose, and *before*
## the skeleton is drawn. Write them from `_process()` and you are racing the
## `AnimationMixer`: sometimes you win and the animation looks broken, sometimes
## it wins and your change does nothing. Which one depends on node order, which
## is why it "works on my machine".
##
## `SkeletonModifier3D` is the supported answer. Godot calls
## `_process_modification()` at exactly the right point in the skeleton's update,
## and gives you an `influence` to fade the effect in and out.
##
## What is left is the arithmetic, and two rules that are easy to get wrong:
##
##   * **Clamp the turn, and clamp it as an angle.** A head that can rotate 180
##     degrees to look behind is an owl. Clamping the *result* rather than the
##     angle gives a head that snaps to the limit and stays there.
##   * **Blend from the animated pose, not from the rest pose.** The animation is
##     what the character was already doing; fading a modifier in from the rest
##     pose makes the character straighten up as it fades.

## The rotation that turns `forward` toward a target direction.
##
## Both in the same space — usually the bone's parent. Mixing spaces here is the
## reason a head-look works while the character faces one way and not another.
static func aim(forward: Vector3, to_target: Vector3) -> Quaternion:
	var from := forward.normalized()
	var to := to_target.normalized()
	var dot := clampf(from.dot(to), -1.0, 1.0)
	var axis := from.cross(to)
	if not axis.is_zero_approx():
		return Quaternion(axis.normalized(), acos(dot))

	# No axis to turn about, which is three cases at once: already aligned,
	# exactly opposite, or one of the vectors is nothing at all. Only the middle
	# one is a real turn, and it is the only one where the dot product is
	# negative — so the same check separates all three.
	if dot >= 0.0:
		return Quaternion.IDENTITY
	# Exactly backwards: every perpendicular axis is a valid half turn, so one
	# has to be chosen rather than computed.
	var perpendicular := from.cross(Vector3.UP)
	if perpendicular.is_zero_approx():
		perpendicular = from.cross(Vector3.RIGHT)
	return Quaternion(perpendicular.normalized(), PI)


## The same rotation, but never turning further than `limit` radians.
##
## Clamped as an angle rather than by clamping the result: a head that snaps to
## its limit and stays there is what the other way looks like.
static func aim_within(forward: Vector3, to_target: Vector3, limit: float) -> Quaternion:
	var wanted := aim(forward, to_target)
	var angle := wanted.get_angle()
	if angle <= limit or angle < 0.000001:
		return wanted
	return Quaternion(wanted.get_axis(), limit)


## Is the target within reach at all? For the caller that wants to *stop* looking
## rather than look as far as it can — a head that gives up and faces front beats
## one straining sideways at its limit.
static func within_reach(forward: Vector3, to_target: Vector3, limit: float) -> bool:
	return aim(forward, to_target).get_angle() <= limit


## Blend a modifier's rotation in by its influence, from the animated pose rather
## than the rest pose. Fading in from rest makes the character straighten up as
## the modifier arrives, which reads as a glitch rather than as a look.
static func blended(animated: Quaternion, aimed: Quaternion,
		influence: float) -> Quaternion:
	return animated.slerp(aimed, clampf(influence, 0.0, 1.0))


## How much influence to use, given how long the modifier has been fading.
##
## Frame-rate independent, so a look that takes a quarter of a second takes a
## quarter of a second on every machine.
static func fade(current: float, wanted: float, delta: float,
		rate: float = 8.0) -> float:
	return clampf(lerpf(current, wanted, 1.0 - exp(-maxf(rate, 0.0) * delta)), 0.0, 1.0)
