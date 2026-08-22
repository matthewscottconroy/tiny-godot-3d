class_name TerrainField
extends RefCounted

## A heightmap sampled from noise, and the mesh built out of it.
##
## The mesh and the height query have to agree. That sounds obvious and is the
## thing that goes wrong: the mesh is built in one loop, the "what is the ground
## height here" function used to place trees and spawn the player is written in
## another, and the two drift apart by a factor or an offset. The player then
## walks half a metre above the hills, and it is genuinely hard to see which of
## the two is wrong.
##
## So there is one function, `height_at()`, and the mesh is built by calling it.
## The suite checks that a vertex of the mesh sits exactly where `height_at()`
## says the ground is — which is the invariant that keeps everything else honest.

## Peak height above and below zero, in metres.
var amplitude := 3.0

## How much ground one noise period covers. Larger is smoother.
var feature_size := 18.0

var _noise := FastNoiseLite.new()


func _init(seed_value: int = 1) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 4
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	_noise.seed = seed_value


func seed_value() -> int:
	return _noise.seed


## The ground height at a world position on the XZ plane.
func height_at(x: float, z: float) -> float:
	# FastNoiseLite returns roughly -1..1, so the amplitude is in metres and the
	# frequency is expressed as a feature size rather than as a raw frequency —
	# "hills about 18 metres across" is a number you can picture.
	return _noise.get_noise_2d(x / feature_size * 100.0, z / feature_size * 100.0) * amplitude


## The surface normal at a point, from the slope either side of it.
##
## Sampled rather than derived from the mesh, so it is available for anything
## placed on the terrain — a tree that should lean with the hill, a decal, a
## footprint — without hunting for the triangle underneath.
func normal_at(x: float, z: float, step: float = 0.5) -> Vector3:
	var dx := height_at(x + step, z) - height_at(x - step, z)
	var dz := height_at(x, z + step) - height_at(x, z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


## How steep the ground is here, 0 for flat and 1 for a cliff.
func slope_at(x: float, z: float, step: float = 0.5) -> float:
	return clampf(1.0 - normal_at(x, z, step).dot(Vector3.UP), 0.0, 1.0)


## Which surface a point is: 0 water, 1 sand, 2 grass, 3 rock.
func region_at(x: float, z: float) -> int:
	return region_for(height_at(x, z), slope_at(x, z), amplitude)


## The same decision as a plain function of height and slope.
##
## Separated so the thresholds can be stated as numbers rather than hunted for
## in the noise: "at a fifth of the way down it is sand" is a rule you can check,
## and "somewhere around here it looked sandy" is not.
##
## Height decides everything except rock, which is a slope rule — a cliff is a
## cliff at any altitude, and colouring by height alone gives you grass growing
## on vertical faces.
static func region_for(height: float, slope: float, amplitude_metres: float) -> int:
	if slope > 0.35:
		return 3
	if height < -amplitude_metres * 0.35:
		return 0
	if height < -amplitude_metres * 0.1:
		return 1
	return 2


## Build a mesh `size` metres across, `resolution` cells per side.
##
## Vertex colours carry the region, so the whole terrain renders with one
## material and no textures.
func build_mesh(size: float, resolution: int) -> ArrayMesh:
	var cells := maxi(resolution, 1)
	var step := size / float(cells)
	var half := size * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in cells + 1:
		for x in cells + 1:
			var px := -half + x * step
			var pz := -half + z * step
			st.set_color(colour_of(region_at(px, pz)))
			st.set_uv(Vector2(float(x) / cells, float(z) / cells))
			st.add_vertex(Vector3(px, height_at(px, pz), pz))

	var row := cells + 1
	for z in cells:
		for x in cells:
			var i := z * row + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + row)
			st.add_index(i + 1)
			st.add_index(i + row + 1)
			st.add_index(i + row)

	# Derived from the geometry rather than from normal_at(): the mesh's shading
	# should match the triangles that were actually built, flat spots and all.
	st.generate_normals()
	return st.commit()


## The colour a region is drawn in.
static func colour_of(region: int) -> Color:
	match region:
		0: return Color(0.16, 0.32, 0.52)
		1: return Color(0.76, 0.70, 0.48)
		3: return Color(0.42, 0.40, 0.38)
		_: return Color(0.28, 0.47, 0.27)


## Vertex and index counts a build will produce, without building it.
static func counts(resolution: int) -> Dictionary:
	var cells := maxi(resolution, 1)
	return {"vertices": (cells + 1) * (cells + 1), "indices": cells * cells * 6}
