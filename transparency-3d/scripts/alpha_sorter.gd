class_name AlphaSorter
extends RefCounted

## Deciding what order transparent objects are drawn in, and when no order will
## do.
##
## Opaque geometry sorts itself: the depth buffer takes the nearest fragment and
## the order things arrive in does not matter. Transparency has no such luxury —
## a translucent surface has to be blended *over* what is already behind it, so
## it has to be drawn after it. The renderer therefore sorts transparent objects
## back to front, and everything that goes wrong with transparency follows from
## two facts about that sort:
##
##   * **It is per object, not per pixel.** Two transparent objects that
##     intersect cannot be ordered — whichever is drawn second wins along the
##     whole overlap. No amount of sorting fixes it, which is why the answer is
##     usually to stop being transparent (alpha scissor) rather than to sort
##     harder.
##   * **It sorts by depth, not by distance.** An object off to one side can be
##     further away in a straight line while being nearer along the view
##     direction. Sorting by `distance_to()` therefore reorders objects as the
##     camera turns, and the picture flickers between two orderings.
##
## Both are here, as arithmetic, because both are invisible in a screenshot: the
## wrong order is a perfectly plausible picture.

## How far along the camera's view direction a point is.
##
## Not `distance_to()`. Depth is the projection onto the view vector, which is
## what the renderer sorts by and what stays stable as the camera turns.
static func depth_of(point: Vector3, camera_position: Vector3, camera_forward: Vector3) -> float:
	var forward := camera_forward.normalized() if camera_forward.length() > 0.0001 \
		else Vector3.FORWARD
	return (point - camera_position).dot(forward)


## Indices of `points`, furthest first — the order transparency has to be drawn
## in.
static func back_to_front(points: Array[Vector3], camera_position: Vector3,
		camera_forward: Vector3) -> Array[int]:
	var order: Array[int] = []
	for i in points.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := depth_of(points[a], camera_position, camera_forward)
		var db := depth_of(points[b], camera_position, camera_forward)
		if is_equal_approx(da, db):
			return a < b                  # stable, so equal depths do not flicker
		return da > db)
	return order


## `render_priority` values that force a given order, whatever the depth sort
## thinks.
##
## Godot sorts transparent materials by priority first and depth second, so this
## is the override for the cases depth cannot express: a windscreen that must
## always draw over the dashboard behind it, a UI panel in world space.
## Priorities are clamped to the range the renderer accepts.
static func priorities(count: int, first_drawn_first: bool = true) -> Array[int]:
	var out: Array[int] = []
	for i in maxi(count, 0):
		# Lower priority draws earlier. The list is given first-to-last, so the
		# first entry gets the lowest number.
		var value := i if first_drawn_first else count - 1 - i
		out.append(clampi(value - count / 2, -128, 127))
	return out


## Do two axis-aligned boxes overlap along the view direction?
##
## The test for "these two can never be sorted correctly". If the depth ranges of
## two transparent objects overlap, one of them is in front along part of the
## screen and behind along the rest, and a per-object sort has no answer.
static func depth_ranges_overlap(a: AABB, b: AABB, camera_position: Vector3,
		camera_forward: Vector3) -> bool:
	var a_range := _depth_range(a, camera_position, camera_forward)
	var b_range := _depth_range(b, camera_position, camera_forward)
	return a_range.x < b_range.y and b_range.x < a_range.y


## The near and far depth of a box, as (near, far).
static func _depth_range(box: AABB, camera_position: Vector3,
		camera_forward: Vector3) -> Vector2:
	var near := INF
	var far := -INF
	for i in 8:
		var corner := box.get_endpoint(i)
		var depth := depth_of(corner, camera_position, camera_forward)
		near = minf(near, depth)
		far = maxf(far, depth)
	return Vector2(near, far)
