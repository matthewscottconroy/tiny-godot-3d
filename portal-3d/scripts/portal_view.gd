class_name PortalView
extends RefCounted

## Where the camera behind a portal goes, and when it is worth drawing at all.
##
## A portal is a second camera rendered onto a surface — the same machinery as
## the security monitor in `render-to-texture`, with one difference that changes
## everything: the second camera's transform is *derived* from the player's,
## through the pair of portals, rather than bolted to a wall.
##
## Get that transform right and the illusion is total. Get it wrong and the view
## is plausible but subtly sliding, which is worse than obviously broken because
## nobody can say what is wrong with it.
##
## Three things beyond the transform decide whether it works:
##
##   * **A portal you are behind should not be drawn.** Rendering the far side
##     while standing behind the surface costs a full extra scene render to
##     produce something nobody can see.
##   * **The far camera has to clip at the portal.** Anything between the exit
##     portal and its camera is in front of the view but behind the opening, so
##     it appears floating in the doorway.
##   * **Walking through is a sign change**, not a proximity test. A player
##     moving fast enough passes the plane in one frame without ever being
##     "near" it.

## The 180-degree turn that makes the far camera look *out* of the exit portal
## rather than into the back of it.
##
## Leave it out and the view is the exit portal's own back wall, which reads as
## the portal simply not working.
static func flip() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)


## Where to put the camera that renders what is through the portal.
##
## Read right to left: take the player's transform into the entry portal's space,
## turn it around, and put it back out in the exit portal's space.
static func camera_transform(viewer: Transform3D, entry: Transform3D,
		exit: Transform3D) -> Transform3D:
	return exit * flip() * entry.affine_inverse() * viewer


## Which side of a portal a point is on, in metres.
##
## Positive is in front, where "front" is the portal's own -Z, the same forward
## every other Node3D uses.
static func side_of(portal: Transform3D, point: Vector3) -> float:
	var normal := -portal.basis.z.normalized()
	return (point - portal.origin).dot(normal)


## Is the viewer in front of this portal, and so able to see through it?
static func is_facing(portal: Transform3D, viewer_position: Vector3,
		margin: float = 0.0) -> bool:
	return side_of(portal, viewer_position) > margin


## Did a movement cross the portal's plane?
##
## A sign change, not a proximity test: something moving quickly passes the plane
## in a single frame without ever being near it, and a distance check misses it
## entirely.
static func crossed(portal: Transform3D, before: Vector3, after: Vector3) -> bool:
	var was := side_of(portal, before)
	var now := side_of(portal, after)
	return was > 0.0 and now <= 0.0


## Is the crossing point inside the portal's opening, rather than through the
## wall beside it?
##
## The half-extents are the opening's own, on its local X and Y.
static func within_opening(portal: Transform3D, point: Vector3, half_size: Vector2) -> bool:
	var local := portal.affine_inverse() * point
	return absf(local.x) <= half_size.x and absf(local.y) <= half_size.y


## How far the far camera must clip to avoid drawing what is behind the exit.
##
## Anything nearer than this is between the exit portal and its camera: in front
## of the view, behind the opening, and so appears floating in the doorway.
static func near_plane_for(camera: Transform3D, exit: Transform3D,
		minimum: float = 0.05) -> float:
	return maxf(absf(side_of(exit, camera.origin)), minimum)


## The resolution to render a portal at, given how much of the screen it covers.
##
## A portal across the room is a few dozen pixels. Rendering it at full
## resolution and minifying it is a whole extra scene render thrown away.
static func resolution_for(distance: float, base: Vector2i, full_within: float = 6.0,
		smallest: int = 128) -> Vector2i:
	var scale := clampf(full_within / maxf(distance, 0.0001), 0.25, 1.0)
	return Vector2i(maxi(int(base.x * scale), smallest), maxi(int(base.y * scale), smallest))
