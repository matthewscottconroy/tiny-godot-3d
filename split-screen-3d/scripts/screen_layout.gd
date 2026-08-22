class_name ScreenLayout
extends RefCounted

## Cutting a window into one rectangle per player.
##
## Splitting a screen is arithmetic, and it is arithmetic with two traps that
## only show up on hardware:
##
##   * **Rounding.** A 1081-pixel-tall window split in two is 540 and 540, and
##     the missing row is a permanent one-pixel line down the middle of the
##     screen. The fix is to give the remainder to the last pane rather than
##     halving twice.
##   * **Aspect ratio.** Half a screen is not a small screen — it is a screen of
##     a different shape. A camera that keeps its vertical field of view sees
##     *less* horizontally in a narrow pane and more in a wide one, and a
##     two-player game where the players see different amounts is a two-player
##     game with an argument in it.
##
## Both are decided here rather than in the driver, so both can be checked.

## How a two-player screen is cut.
enum Split {
	HORIZONTAL,   ## one pane above the other — the usual choice for driving
	VERTICAL,     ## side by side — better when the action is vertical
}


## One rectangle per player, covering the whole of `size` with no gaps.
##
## Supports one to four players. Three is the awkward one: two panes on top and
## one below, which is what everyone does and nobody likes.
static func rects(players: int, size: Vector2i, split: Split = Split.HORIZONTAL) -> Array[Rect2i]:
	var count := clampi(players, 1, 4)
	var out: Array[Rect2i] = []
	if count == 1:
		out.append(Rect2i(Vector2i.ZERO, size))
		return out

	if count == 2:
		if split == Split.HORIZONTAL:
			var top := size.y / 2
			out.append(Rect2i(0, 0, size.x, top))
			# The remainder goes to the last pane, so an odd height leaves no
			# unpainted row between them.
			out.append(Rect2i(0, top, size.x, size.y - top))
		else:
			var left := size.x / 2
			out.append(Rect2i(0, 0, left, size.y))
			out.append(Rect2i(left, 0, size.x - left, size.y))
		return out

	var half_y := size.y / 2
	var half_x := size.x / 2
	if count == 3:
		out.append(Rect2i(0, 0, half_x, half_y))
		out.append(Rect2i(half_x, 0, size.x - half_x, half_y))
		out.append(Rect2i(0, half_y, size.x, size.y - half_y))
		return out

	out.append(Rect2i(0, 0, half_x, half_y))
	out.append(Rect2i(half_x, 0, size.x - half_x, half_y))
	out.append(Rect2i(0, half_y, half_x, size.y - half_y))
	out.append(Rect2i(half_x, half_y, size.x - half_x, size.y - half_y))
	return out


## The aspect ratio of a pane, width over height.
static func aspect_of(rect: Rect2i) -> float:
	if rect.size.y <= 0:
		return 0.0
	return float(rect.size.x) / float(rect.size.y)


## The vertical field of view that keeps the *horizontal* one the same.
##
## Godot's default `KEEP_HEIGHT` holds the vertical angle fixed, so a
## half-height pane shows the same amount vertically and the same amount
## horizontally — meaning a player in a letterbox pane sees less of the world
## than one on a full screen. Widening the vertical angle to hold the horizontal
## one constant is usually what a split-screen game wants.
static func matched_fov(base_fov_degrees: float, base_aspect: float, pane_aspect: float) -> float:
	if base_aspect <= 0.0 or pane_aspect <= 0.0:
		return base_fov_degrees
	# Convert the vertical angle to the horizontal one at the original aspect,
	# then back again at the new one.
	var half := deg_to_rad(clampf(base_fov_degrees, 1.0, 179.0)) * 0.5
	var horizontal := atan(tan(half) * base_aspect)
	return clampf(rad_to_deg(atan(tan(horizontal) / pane_aspect) * 2.0), 1.0, 179.0)


## Do these rectangles between them cover every pixel exactly once?
##
## Used by the suite, and worth having: a gap is a stripe of unpainted window
## and an overlap is one pane drawn over another.
static func covers(rects_in: Array[Rect2i], size: Vector2i) -> bool:
	var area := 0
	for rect in rects_in:
		area += rect.size.x * rect.size.y
		if rect.position.x < 0 or rect.position.y < 0:
			return false
		if rect.end.x > size.x or rect.end.y > size.y:
			return false
	if area != size.x * size.y:
		return false
	for i in rects_in.size():
		for j in range(i + 1, rects_in.size()):
			if rects_in[i].intersects(rects_in[j]):
				return false
	return true
