class_name HeightField
extends RefCounted

## A grid of heights, shared by the mesh you see and the shape you collide with.
##
## `HeightMapShape3D` is the cheap way to collide with terrain: no triangles, no
## BVH, just a grid of heights and some arithmetic. It has one property that
## catches everybody:
##
## **Its samples are one unit apart, always.** There is no spacing parameter. A
## 65×65 height map is 64 units across, and if your terrain mesh is 40 metres
## across you must *scale the collision node* to match. Nothing warns; the
## collider simply sits at a different size from the ground, and things land in
## mid-air or sink to their knees — which reads as a physics bug rather than as a
## units bug.
##
## The other half is agreement. The mesh and the shape have to come from the same
## heights, in the same order, or the terrain you see and the terrain you stand
## on are two subtly different landscapes.

## Godot's height maps are row-major, depth (Z) outermost.
##
## Getting the order wrong transposes the terrain: hills appear where valleys
## are, which looks plausible and collides wrongly.
static func build(cells: int, spacing: float, height: Callable) -> PackedFloat32Array:
	var side := maxi(cells, 1) + 1
	var data := PackedFloat32Array()
	data.resize(side * side)
	if not height.is_valid():
		return data
	var half := float(maxi(cells, 1)) * spacing * 0.5
	for z in side:
		for x in side:
			var world_x := -half + float(x) * spacing
			var world_z := -half + float(z) * spacing
			data[z * side + x] = float(height.call(world_x, world_z))
	return data


## The shape itself, sized to the grid.
##
## `map_width` and `map_depth` are counts of samples, not metres — a 65×65 map is
## 64 units across, and the scale below is what turns those units into metres.
static func shape_for(cells: int, spacing: float, height: Callable) -> HeightMapShape3D:
	var side := maxi(cells, 1) + 1
	var shape := HeightMapShape3D.new()
	shape.map_width = side
	shape.map_depth = side
	shape.map_data = build(cells, spacing, height)
	return shape


## The scale a collision node needs so a one-unit-per-sample shape covers the
## same ground as a mesh built at `spacing` metres per cell.
##
## The line everyone leaves out. X and Z scale by the spacing; Y stays at 1,
## because the heights are already in metres.
static func scale_for(spacing: float) -> Vector3:
	var side := maxf(spacing, 0.0001)
	return Vector3(side, 1.0, side)


## Read a height back out of the grid, by grid coordinate.
static func at(data: PackedFloat32Array, side: int, x: int, z: int) -> float:
	if side <= 0 or data.is_empty():
		return 0.0
	var cx := clampi(x, 0, side - 1)
	var cz := clampi(z, 0, side - 1)
	return data[cz * side + cx]


## Read a height back out by world position, interpolating between samples.
##
## The check that the shape and the mesh agree: this should return what the
## height function returns, everywhere.
static func sample(data: PackedFloat32Array, side: int, spacing: float,
		world_x: float, world_z: float) -> float:
	if side <= 1 or data.is_empty():
		return 0.0
	var step := maxf(spacing, 0.0001)
	var half := float(side - 1) * step * 0.5
	# Clamped in metres rather than in samples: outside the terrain reads as its
	# edge, and the arithmetic below never sees a position a million metres out.
	var fx := (clampf(world_x, -half, half) + half) / step
	var fz := (clampf(world_z, -half, half) + half) / step
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	# No clamping here: `at()` clamps, and at the far edge the weight is zero
	# anyway, so the neighbour that does not exist contributes nothing.
	var x1 := x0 + 1
	var z1 := z0 + 1
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	# Both rows interpolate along X, and the two results interpolate along Z.
	# Using tz on the second row is the classic bilinear typo: it agrees with
	# the source function along the diagonals and nowhere else.
	var top := lerpf(at(data, side, x0, z0), at(data, side, x1, z0), tx)
	var bottom := lerpf(at(data, side, x0, z1), at(data, side, x1, z1), tx)
	return lerpf(top, bottom, tz)


## The lowest and highest points, as (min, max). For a camera, a bounding box, or
## deciding where the water goes.
static func extent(data: PackedFloat32Array) -> Vector2:
	if data.is_empty():
		return Vector2.ZERO
	var lowest := data[0]
	var highest := data[0]
	for value in data:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	return Vector2(lowest, highest)
