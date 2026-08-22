class_name GridPlan
extends RefCounted

## A room drawn as text, turned into cells for a GridMap.
##
## `GridMap` stores an item id per integer cell, and how those cells are chosen
## is left entirely to you. Placing them by hand in the editor is fine for one
## room and unbearable for twenty; the usual answer is a compact level format,
## and the most compact one that a person can still read is a picture:
##
##     #####
##     #...#
##     #.o.#
##     ##.##
##
## Everything here is integer arithmetic over that picture. It is worth keeping
## out of the driver because grid bugs are so quiet: a plan that is off by one
## cell, or centred on the wrong axis, builds a room that looks completely
## reasonable until the player walks through a wall that is not where it appears.

## Returned for a cell with nothing in it. GridMap uses the same value.
const EMPTY := -1


## Parse a drawing into `{Vector3i: item_id}`.
##
## `legend` maps a character to an item id. Characters not in it — spaces, and
## anything else — leave the cell empty, so a drawing can be padded and
## commented without the parser needing to know.
##
## Rows run along +Z and columns along +X, so the picture reads the same way on
## screen as it does from above with the camera looking down -Z.
static func parse(lines: PackedStringArray, legend: Dictionary, level: int = 0) -> Dictionary:
	var cells := {}
	for z in lines.size():
		var row := lines[z]
		for x in row.length():
			var symbol := row[x]
			if legend.has(symbol):
				cells[Vector3i(x, level, z)] = int(legend[symbol])
	return cells


## The size of the drawing in cells, as (columns, rows).
##
## Taken from the longest row rather than the first, because a drawing with
## trailing spaces trimmed is the normal case, not an error.
static func size_of(lines: PackedStringArray) -> Vector2i:
	var widest := 0
	for line in lines:
		widest = maxi(widest, line.length())
	return Vector2i(widest, lines.size())


## Shift a plan so the drawing is centred on the origin.
##
## Integer division truncates, which for an even-sized room means it sits half a
## cell off centre. That is the correct answer for a grid — there is no cell at
## the middle of an even room — and it is worth knowing rather than discovering.
static func centred(cells: Dictionary, size: Vector2i) -> Dictionary:
	var offset := Vector3i(size.x / 2, 0, size.y / 2)
	var out := {}
	for cell in cells:
		out[(cell as Vector3i) - offset] = cells[cell]
	return out


## Every cell holding a given item.
static func cells_of(cells: Dictionary, item: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for cell in cells:
		if cells[cell] == item:
			out.append(cell)
	out.sort()
	return out


## A second storey of the same plan, `height` cells up.
##
## Stacking is the cheapest way to get a room with walls taller than one cell,
## and doing it here keeps the drawing one level deep and readable.
static func raised(cells: Dictionary, height: int) -> Dictionary:
	var out := {}
	for cell in cells:
		out[(cell as Vector3i) + Vector3i(0, height, 0)] = cells[cell]
	return out


## Merge plans, later ones winning where they overlap.
static func merged(plans: Array[Dictionary]) -> Dictionary:
	var out := {}
	for plan in plans:
		for cell in plan:
			out[cell] = plan[cell]
	return out
