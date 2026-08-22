class_name Carving
extends RefCounted

## The footprint a `NavigationObstacle3D` cuts out of a navigation mesh, and the
## decision about whether it should cut one at all.
##
## The thing to know before anything else: **an obstacle does not change a path
## by existing.** `carve_navigation_mesh` is a *bake-time* property. Set the
## vertices at runtime and every path still goes straight through the crate,
## because the mesh those paths are found on has not changed. Nothing warns.
##
## So there are two mechanisms, and choosing between them is the real question:
##
##   * **Carve, then re-bake.** Exact, and it changes the path itself. Costs a
##     bake, which is milliseconds you can see, so it suits a door that opens
##     rarely — not one a player swings back and forth.
##   * **Avoidance.** The mesh and the path are untouched; agents with avoidance
##     enabled steer around the obstacle in velocity space. Cheap, approximate,
##     and the only option for anything that moves.
##
## What decides it is not how big the obstacle is. It is how often it moves.

## Signed area of a polygon on the XZ plane, doubled. Negative means clockwise.
##
## Godot normalises the winding of a carving outline, so unlike a lot of polygon
## work this is a measurement rather than a trap — it is here because the *size*
## of a footprint is worth asserting.
static func signed_area(polygon: PackedVector3Array) -> float:
	var total := 0.0
	var count := polygon.size()
	for i in count:
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		total += a.x * b.z - b.x * a.z
	return total


## The area a footprint covers, in square metres.
static func area(polygon: PackedVector3Array) -> float:
	return absf(signed_area(polygon)) * 0.5


## The outline of a box obstacle, in the obstacle's own local space.
##
## Expanded by `margin` on every side, because an agent is not a point: a hole
## exactly the size of the crate leaves a strip along its edge that is walkable
## on the mesh and too narrow for the agent's shoulders. `margin` is the agent
## radius the mesh was baked with.
static func box_footprint(size: Vector3, margin: float = 0.0) -> PackedVector3Array:
	var x := maxf(size.x * 0.5 + margin, 0.01)
	var z := maxf(size.z * 0.5 + margin, 0.01)
	return PackedVector3Array([
		Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(x, 0, z), Vector3(-x, 0, z)])


## Is this point inside the footprint?
##
## A convex test — the point is inside when it is on the same side of every edge
## — rather than a ray-crossing one. Obstacle outlines have to be convex for the
## navigation server anyway, and this way there is no arbitrary ray direction to
## get backwards and no winding to get right.
##
## Y is ignored: an obstacle outline is two-dimensional, however tall the door it
## came from is.
static func contains(polygon: PackedVector3Array, point: Vector3) -> bool:
	var count := polygon.size()
	if count < 3:
		return false
	var side := 0.0
	# Previous-and-current rather than an index and a wrap: the closing edge is
	# the first one visited, so there is no modulo to get wrong.
	var a := polygon[count - 1]
	for b in polygon:
		var cross := (b.x - a.x) * (point.z - a.z) - (b.z - a.z) * (point.x - a.x)
		if absf(cross) < 0.000001:
			a = b                          # exactly on the edge: not a vote either way
			continue
		if side == 0.0:
			side = signf(cross)
		elif signf(cross) != side:
			return false
		a = b
	return true


## The radius for an obstacle that is avoided rather than carved.
##
## The half-diagonal, not the half-width: a circle that only covers the flat
## sides of a box leaves its corners sticking out.
static func avoidance_radius(size: Vector3, margin: float = 0.0) -> float:
	return Vector2(size.x, size.z).length() * 0.5 + maxf(margin, 0.0)


## Carve this obstacle into the mesh, or leave it to avoidance?
##
## Carving means re-baking, and re-baking is not free. Anything that moves has
## to be avoided instead — there is no third option.
static func should_carve(speed: float, moving_above: float = 0.05) -> bool:
	return absf(speed) <= moving_above
