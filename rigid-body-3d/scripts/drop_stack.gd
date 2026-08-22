class_name DropStack
extends RefCounted

## Where a stack of boxes starts, and how hard a blast hits each one.
##
## The physics itself belongs to the engine — that is the whole point of a
## RigidBody3D — so the part worth writing, and the only part worth testing, is
## the arithmetic around it: where the bodies begin, and what impulse each one
## receives when something goes off nearby.
##
## Keeping that out of the driver means the falloff can be checked as numbers.
## An explosion whose strength is wrong by a factor of two still looks like an
## explosion, which is exactly the kind of bug a screenshot never catches.


## The positions of a pyramid `rows` deep, widest at the bottom.
##
## Row 0 is the base and has `rows` boxes; each row above has one fewer and sits
## `spacing` higher, centred on the row below. Returns bottom row first.
static func pyramid(rows: int, spacing: float, base_y: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for row in maxi(rows, 0):
		var count := rows - row
		# Centre the row on x = 0: n boxes span (n - 1) gaps, so the first sits
		# half a span to the left. Without this the stack leans as it grows.
		var first := -0.5 * float(count - 1) * spacing
		for i in count:
			out.append(Vector3(first + float(i) * spacing, base_y + float(row) * spacing, 0.0))
	return out


## The impulse a blast at `centre` delivers to a body at `position`.
##
## Linear falloff: full strength at the centre, nothing at `radius` and beyond.
## Inverse-square is more physical and much worse to tune — it is either
## imperceptible or it launches everything into orbit.
static func impulse_at(centre: Vector3, position: Vector3, strength: float,
		radius: float) -> Vector3:
	var offset := position - centre
	var distance := offset.length()
	if distance >= radius or radius <= 0.0:
		return Vector3.ZERO
	var falloff := 1.0 - distance / radius
	# A body sitting exactly on the blast has no direction to be pushed in.
	# Straight up is the useful answer; normalising a zero vector is not.
	var direction := Vector3.UP if distance < 0.0001 else offset.normalized()
	return direction * strength * falloff


## The same blast, with some of it redirected upward.
##
## A purely radial impulse shoves a stack sideways and it slides. Lifting part of
## it off the ground is what makes the boxes tumble, which is what an explosion
## is supposed to look like.
static func impulse_with_lift(centre: Vector3, position: Vector3, strength: float,
		radius: float, lift: float) -> Vector3:
	var impulse := impulse_at(centre, position, strength, radius)
	if impulse == Vector3.ZERO:
		return impulse
	return impulse + Vector3.UP * impulse.length() * lift
