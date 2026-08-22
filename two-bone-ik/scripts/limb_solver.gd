class_name LimbSolver
extends RefCounted

## Where a knee goes when the foot is somewhere specific.
##
## Forward kinematics is "the thigh is at this angle, so the foot ends up over
## there". Inverse kinematics is the question you actually have: the foot has to
## be *there* — on this step, on that rung, on the ground under it — so what
## angles put it there? For a two-bone limb the answer is the law of cosines and
## it fits in twenty lines.
##
## What takes the other forty is everything the maths does not cover:
##
##   * **Out of reach.** The target is further away than the limb is long. There
##     is no solution, and `NAN` is what an unguarded `acos()` returns — which
##     then propagates silently into a transform and makes the whole limb vanish.
##   * **Too close.** The target is inside the fold of the limb. Same problem at
##     the other end of the range.
##   * **Which way the knee bends.** Two solutions exist, mirrored about the line
##     from hip to foot. Nothing in the maths prefers either, and picking the
##     wrong one bends the knee backwards.
##
## The pole vector answers the last one, and it is the parameter people leave out
## and then wonder why legs flip inside out as the character turns.

## Where the joint ended up, and what happened on the way.
class Solution extends RefCounted:
	var joint: Vector3          ## the knee or elbow position
	var foot: Vector3           ## where the end actually reached
	var reachable: bool         ## false if the target was outside the limb's range
	var bend: float             ## interior angle at the joint, radians (PI = straight)

	func _init(joint_position: Vector3, foot_position: Vector3, was_reachable: bool,
			bend_angle: float) -> void:
		joint = joint_position
		foot = foot_position
		reachable = was_reachable
		bend = bend_angle


## Solve for the joint position.
##
## `pole` is a point the joint should bend toward — for a leg, somewhere in front
## of the character. It only has to indicate a direction; its distance is ignored.
static func solve(root: Vector3, target: Vector3, upper: float, lower: float,
		pole: Vector3) -> Solution:
	var upper_length := maxf(upper, 0.0001)
	var lower_length := maxf(lower, 0.0001)
	var to_target := target - root
	var distance := to_target.length()

	# A target on top of the root has no direction to point the limb along.
	# Straight down is as good an answer as any, and it is a finite one.
	var direction := to_target.normalized() if distance > 0.0001 else Vector3.DOWN

	# Clamp into the range the limb can actually reach. Outside it the law of
	# cosines has no solution and acos() returns NAN, which then travels into a
	# transform and takes the limb off screen.
	var reach := upper_length + lower_length
	var fold := absf(upper_length - lower_length)
	var reachable := distance <= reach and distance >= fold
	var solved_distance := clampf(distance, fold, reach)
	var foot := root + direction * solved_distance

	# Law of cosines: the angle at the root of the triangle (root, joint, foot).
	var cosine := (upper_length * upper_length + solved_distance * solved_distance
		- lower_length * lower_length) / (2.0 * upper_length * solved_distance)
	var root_angle := acos(clampf(cosine, -1.0, 1.0))

	# And the interior angle at the joint itself, which is what a rig usually
	# wants: PI when the limb is straight, small when it is folded.
	var joint_cosine := (upper_length * upper_length + lower_length * lower_length
		- solved_distance * solved_distance) / (2.0 * upper_length * lower_length)
	var bend := acos(clampf(joint_cosine, -1.0, 1.0))

	# The bend plane: perpendicular to the limb, pointing at the pole. Without
	# this the two mirrored solutions are equally valid and the knee flips.
	var pole_direction := pole - root
	var bend_axis := pole_direction - direction * pole_direction.dot(direction)
	if bend_axis.length() < 0.0001:
		# The pole is on the limb's own line, so it says nothing about which way
		# the joint should bend. Any perpendicular will do — chosen by which
		# component of the limb is largest, so the choice cannot itself land on
		# the degenerate case it exists to avoid.
		var reference := Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT
		bend_axis = direction.cross(reference)
	bend_axis = bend_axis.normalized()

	var joint := root + (direction * cos(root_angle) + bend_axis * sin(root_angle)) * upper_length
	return Solution.new(joint, foot, reachable, bend)


## The rotation that points a bone's local -Z from `from` to `to`.
##
## Rigs differ about which axis a bone points down; -Z matches Godot's own
## convention for a node that "looks at" something, and `look_at` is exactly
## what a driver would otherwise call.
static func aim(from: Vector3, to: Vector3, up: Vector3 = Vector3.UP) -> Basis:
	var forward := to - from
	if forward.length() < 0.0001:
		return Basis()
	forward = forward.normalized()
	# Godot's Basis takes X, Y, Z, and a node "looking at" something points its
	# -Z there — so the basis is built around +Z pointing backwards.
	var z_axis := -forward
	var x_axis := up.cross(z_axis)
	if x_axis.length() < 0.0001:
		# Aiming straight along the up vector, which then says nothing about
		# roll. Pick an axis that cannot also be parallel — chosen by which
		# component of the aim is largest, so the choice itself never lands on
		# the degenerate case it exists to avoid.
		var fallback := Vector3.RIGHT if absf(z_axis.x) < 0.9 else Vector3.FORWARD
		x_axis = fallback.cross(z_axis)
	x_axis = x_axis.normalized()
	return Basis(x_axis, z_axis.cross(x_axis), z_axis)


## How far a limb of these lengths can reach.
static func reach_of(upper: float, lower: float) -> float:
	return maxf(upper, 0.0001) + maxf(lower, 0.0001)


## The closest a limb of these lengths can fold.
static func fold_of(upper: float, lower: float) -> float:
	return absf(maxf(upper, 0.0001) - maxf(lower, 0.0001))
