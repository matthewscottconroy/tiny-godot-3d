class_name NearPlane
extends RefCounted

## The camera's near plane: the reason walls vanish when you stand against them.
##
## A camera does not see from a point. It sees from a rectangle a short distance
## in front of itself — the near plane — and anything nearer than that rectangle
## is not drawn. Put the camera's origin 10cm from a wall with a near plane at
## 5cm and part of that rectangle is *inside* the wall, so the wall is clipped
## away and the player is looking into the room behind it.
##
## Two fixes are common and one of them is a trap:
##
##   * **Keep the camera far enough from geometry**, using the near plane's own
##     size to decide how far. This is the right one, and it is the whole of
##     `safe_distance()` below.
##   * **Make the near plane tiny.** It works, and it destroys depth precision:
##     the depth buffer's resolution is distributed by the *ratio* of far to
##     near, so dropping the near plane from 5cm to 5mm costs as much precision
##     as pushing the far plane out ten times as far. The z-fighting shows up
##     somewhere else entirely, which is why nobody connects the two.

## Half the height of the near plane, in metres.
static func half_height(fov_degrees: float, near: float) -> float:
	return near * tan(deg_to_rad(fov_degrees) * 0.5)


## Half its width. Godot's `fov` is the *vertical* field of view by default, so
## the width comes from the aspect ratio rather than from the fov directly.
static func half_width(fov_degrees: float, near: float, aspect: float) -> float:
	return half_height(fov_degrees, near) * maxf(aspect, 0.0001)


## The radius of the sphere that encloses the near plane.
##
## The number that matters: keep the camera's origin this far from anything
## solid and no corner of the near plane can be inside it, whichever way the
## camera is facing.
static func radius(fov_degrees: float, near: float, aspect: float) -> float:
	var h := half_height(fov_degrees, near)
	var w := half_width(fov_degrees, near, aspect)
	return Vector3(w, h, near).length()


## How far the camera must sit from a surface to keep the near plane clear.
##
## The margin is slack for the surface not being perfectly flat and for the
## camera moving between physics steps.
static func safe_distance(fov_degrees: float, near: float, aspect: float,
		margin: float = 0.05) -> float:
	return radius(fov_degrees, near, aspect) + maxf(margin, 0.0)


## Is the camera close enough to this surface to clip through it?
static func would_clip(distance_to_surface: float, fov_degrees: float, near: float,
		aspect: float, margin: float = 0.05) -> bool:
	return distance_to_surface < safe_distance(fov_degrees, near, aspect, margin)


## Where to move a camera that is too close to a surface.
##
## Along the surface normal, only as far as it takes. Moving it back along the
## view direction instead is what puts a first-person camera inside the
## character's own head.
static func pushed_out(position: Vector3, surface: Vector3, normal: Vector3,
		fov_degrees: float, near: float, aspect: float,
		margin: float = 0.05) -> Vector3:
	var away := normal.normalized()
	var distance := (position - surface).dot(away)
	var wanted := safe_distance(fov_degrees, near, aspect, margin)
	if distance >= wanted:
		return position
	return position + away * (wanted - distance)


## How much of the depth buffer's precision is spent on the nearest metre.
##
## A standard perspective depth buffer is hyperbolic: most of its resolution
## goes to what is close. This returns the share consumed by the first metre,
## which is the number that makes "just lower the near plane" look expensive.
static func near_precision_share(near: float, far: float) -> float:
	if near <= 0.0 or far <= near:
		return 1.0
	var one_metre := minf(near + 1.0, far)
	# Hyperbolic depth: 1/near - 1/z over the whole 1/near - 1/far range.
	return (1.0 / near - 1.0 / one_metre) / (1.0 / near - 1.0 / far)


## How much worse the depth precision gets by moving the near plane in.
##
## Precision scales with far/near, so this is the ratio of the two ratios — and
## it is why halving the near plane is not a free fix.
static func precision_cost(from_near: float, to_near: float) -> float:
	if to_near <= 0.0 or from_near <= 0.0:
		return INF
	return from_near / to_near
