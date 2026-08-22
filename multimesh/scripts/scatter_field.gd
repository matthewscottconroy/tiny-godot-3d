class_name ScatterField
extends RefCounted

## Where a crowd of instances goes, and how many of them are worth drawing.
##
## `MultiMesh` draws any number of copies of one mesh in a single call, which
## makes the interesting question "which copies, where" rather than "how do I
## make it fast". Two parts to that, and both are arithmetic:
##
##   * **Placement.** Pure random scattering clumps — it leaves bald patches and
##     piles three trees on one spot. A jittered grid keeps the randomness and
##     loses the clumping: one instance per cell, displaced within it.
##   * **Culling.** `MultiMesh.visible_instance_count` truncates the list, so it
##     only helps if the instances are *ordered* by whether you want them. Sort
##     by distance once and the cull becomes a single integer per frame.
##
## Everything here is deterministic for a given seed, which is what makes a
## scattered field reproducible between runs — and testable at all.

## The square the field covers, in metres, centred on the origin.
var area := 60.0

## One instance per cell of this size. Smaller is denser.
var cell := 2.0

## Instance scale is picked between these.
var min_scale := 0.7
var max_scale := 1.4

var _seed := 1


func _init(seed_value: int = 1) -> void:
	_seed = seed_value


func set_seed(value: int) -> void:
	_seed = value


func seed_value() -> int:
	return _seed


## How many cells the area divides into. The count comes from the field, not
## from a number someone picked — density and area are the things you tune.
func capacity() -> int:
	var per_side := maxi(int(area / maxf(cell, 0.001)), 1)
	return per_side * per_side


## Transforms for up to `count` instances, in grid order.
##
## Each instance sits in its own cell, displaced by up to half a cell so the
## grid never shows, rotated about Y only — a tree leaning off the vertical
## reads as a bug — and scaled within the range.
func transforms(count: int, height: Callable = Callable()) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var per_side := maxi(int(area / maxf(cell, 0.001)), 1)
	var wanted := mini(maxi(count, 0), per_side * per_side)
	var half := area * 0.5

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed

	for index in wanted:
		var gx := index % per_side
		var gz := index / per_side
		var jitter_x := rng.randf_range(-0.5, 0.5) * cell
		var jitter_z := rng.randf_range(-0.5, 0.5) * cell
		var x := -half + (gx + 0.5) * cell + jitter_x
		var z := -half + (gz + 0.5) * cell + jitter_z
		var y := 0.0
		if height.is_valid():
			y = float(height.call(x, z))

		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * rng.randf_range(min_scale, max_scale))
		out.append(Transform3D(basis, Vector3(x, y, z)))
	return out


## The same transforms, nearest to `viewer` first.
##
## Sorting is what makes `visible_instance_count` a cull rather than an
## arbitrary truncation. Done once when the field is built, not per frame.
static func sorted_by_distance(items: Array[Transform3D], viewer: Vector3) -> Array[Transform3D]:
	var out := items.duplicate()
	out.sort_custom(func(a: Transform3D, b: Transform3D) -> bool:
		return viewer.distance_squared_to(a.origin) < viewer.distance_squared_to(b.origin))
	return out


## How many of a distance-sorted list are within `radius`.
##
## The answer is an index, because the list is sorted: everything before it is
## in range and everything after it is not. That is the whole per-frame cost.
static func visible_within(sorted: Array[Transform3D], viewer: Vector3, radius: float) -> int:
	if radius <= 0.0:
		return 0
	var limit := radius * radius
	var count := 0
	for item in sorted:
		if viewer.distance_squared_to(item.origin) > limit:
			break
		count += 1
	return count
