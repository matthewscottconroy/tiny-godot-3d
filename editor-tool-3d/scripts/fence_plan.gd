class_name FencePlan
extends RefCounted

## Where the posts go, and which way the rails between them face.
##
## The maths a level-building tool needs is nearly always about *fitting*: a
## fence with a post every two metres along a 9.4-metre path ends with a 1.4-metre
## gap and a post floating past the end, which looks like a bug in the tool
## rather than in the arithmetic. Dividing the length into equal spans instead —
## as close to the wanted spacing as fits — is three lines and the difference
## between a tool people use and a tool people fight.
##
## Keeping it out of the `@tool` script matters more than usual, too. Editor
## scripts run inside the editor, where a mistake can corrupt the scene being
## edited and a test cannot easily reach. Everything that can be worked out
## without touching a node is worked out here, where it is ordinary code.


## Distances along a curve at which to place a post.
##
## Always includes both ends: a fence that stops short of its corner is a fence
## with a hole in it.
static func post_distances(length: float, wanted_spacing: float) -> Array[float]:
	var out: Array[float] = []
	if length <= 0.0:
		out.append(0.0)
		return out
	var spans := maxi(int(round(length / maxf(wanted_spacing, 0.01))), 1)
	var spacing := length / float(spans)
	for i in spans + 1:
		out.append(spacing * i)
	return out


## The spacing that actually gets used, once the length has been divided evenly.
static func fitted_spacing(length: float, wanted_spacing: float) -> float:
	if length <= 0.0:
		return 0.0
	return length / float(maxi(int(round(length / maxf(wanted_spacing, 0.01))), 1))


## How many posts a fence of this length will have.
static func post_count(length: float, wanted_spacing: float) -> int:
	return post_distances(length, wanted_spacing).size()


## The transform for a rail spanning two posts.
##
## Positioned at the midpoint, aimed along the span, and scaled on Z to the
## distance between them — so one unit-long mesh serves every rail whatever the
## curve does.
static func rail_transform(from: Vector3, to: Vector3) -> Transform3D:
	var span := to - from
	var length := span.length()
	if length < 0.0001:
		return Transform3D(Basis(), from)
	var forward := span / length
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.999:
		# A vertical rail: any perpendicular will do for the roll, and a fixed
		# choice keeps the rail from spinning as the curve passes through
		# vertical.
		up = Vector3.FORWARD
	var right := up.cross(forward).normalized()
	# The length goes into the Z column rather than through Basis.scaled(),
	# which multiplies rows and leaves get_scale() reporting something else.
	var basis := Basis(right, forward.cross(right), forward * length)
	return Transform3D(basis, from + span * 0.5)


## The angle a post should face, so it squares up to the fence line.
static func post_yaw(direction: Vector3) -> float:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.0001:
		return 0.0
	return atan2(flat.x, flat.z)
