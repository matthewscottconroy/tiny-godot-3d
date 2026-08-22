class_name RoomPlan
extends RefCounted

## Rooms, and the doorways between the ones that touch.
##
## CSG is for greyboxing: a level made of boxes added and subtracted, changeable
## in seconds, before anyone has modelled anything. What makes it work as a
## *workflow* rather than a toy is that the shapes come from a plan you can edit
## — rooms as rectangles, doors worked out from which rooms share a wall — rather
## than from thirty nodes dragged into place.
##
## The arithmetic is small and worth having outside the CSG tree, because two
## parts of it are easy to get wrong in ways that look like CSG being flaky:
##
##   * **Rooms that only touch at a corner have no shared wall.** A door there is
##     a hole through the diagonal into nothing.
##   * **A subtraction has to be thicker than the wall it cuts.** A door box
##     exactly as deep as the wall leaves a coplanar face, and coplanar faces in
##     CSG produce z-fighting or nothing at all, depending on the floating point
##     of the day.

## How thick the walls are, in metres.
var wall := 0.4

## Doorways, in metres.
var door_width := 1.6
var door_height := 2.2


## Do these two rooms share a wall long enough to put a door in?
##
## Touching at a corner does not count: there is no wall there, only an edge.
static func shares_wall(a: Rect2, b: Rect2, minimum: float = 1.0) -> bool:
	var overlap_x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var overlap_y := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	# One axis has to overlap by a real length while the other just touches.
	if absf(overlap_x) < 0.001 and overlap_y >= minimum:
		return true
	if absf(overlap_y) < 0.001 and overlap_x >= minimum:
		return true
	return false


## Where the doorway between two rooms goes, as a world position, or `null` if
## they do not share a wall.
static func door_between(a: Rect2, b: Rect2, minimum: float = 1.0) -> Variant:
	if not shares_wall(a, b, minimum):
		return null
	var overlap_x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	if absf(overlap_x) < 0.001:
		# They meet on a vertical wall: the door sits at the shared x, halfway
		# along the length they have in common.
		var x := maxf(a.position.x, b.position.x)
		var y := (maxf(a.position.y, b.position.y) + minf(a.end.y, b.end.y)) * 0.5
		return Vector2(x, y)
	var x2 := (maxf(a.position.x, b.position.x) + minf(a.end.x, b.end.x)) * 0.5
	var y2 := maxf(a.position.y, b.position.y)
	return Vector2(x2, y2)


## Is this doorway in a wall that runs along X?
##
## Which way a door box has to be turned, and the thing that is wrong exactly
## half the time if you guess.
static func door_is_horizontal(a: Rect2, b: Rect2) -> bool:
	var overlap_x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	return absf(overlap_x) >= 0.001


## The box to subtract for a doorway.
##
## Deliberately deeper than the wall: a cut exactly as thick as what it cuts
## leaves coplanar faces, and coplanar faces in CSG are z-fighting or nothing at
## all depending on the floating point of the day.
func door_box(horizontal: bool) -> Vector3:
	var depth := wall * 3.0
	if horizontal:
		return Vector3(door_width, door_height, depth)
	return Vector3(depth, door_height, door_width)


## The box for a room's floor and walls, as an outer shell to add.
##
## The inside is subtracted separately — a room is a solid block with a smaller
## block taken out of it, which is the standard CSG way to make a hollow.
func shell_box(room: Rect2, height: float) -> Vector3:
	return Vector3(room.size.x, height, room.size.y)


func hollow_box(room: Rect2, height: float) -> Vector3:
	return Vector3(maxf(room.size.x - wall * 2.0, 0.1), height,
		maxf(room.size.y - wall * 2.0, 0.1))


## The middle of a room, in world coordinates, at a given height.
static func centre_of(room: Rect2, y: float = 0.0) -> Vector3:
	return Vector3(room.get_center().x, y, room.get_center().y)


## Every pair of rooms that should have a door between them.
static func doorways(rooms: Array[Rect2], minimum: float = 1.0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			if shares_wall(rooms[i], rooms[j], minimum):
				out.append(Vector2i(i, j))
	return out
