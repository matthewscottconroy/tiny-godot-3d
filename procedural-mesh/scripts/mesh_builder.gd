## Builds meshes in code with SurfaceTool.
##
## Three things have to be right or the result looks wrong rather than missing:
## winding order decides which side of a triangle is visible, normals decide how
## it lights, and indices decide whether vertices are shared or duplicated. This
## builds a grid and a ring so both cases are visible, and returns ArrayMesh
## resources you can hand straight to a MeshInstance3D.
class_name MeshBuilder
extends RefCounted

## A flat subdivided grid on the XZ plane, centred on the origin.
##
## `height` is sampled per vertex, so passing a noise function turns the same
## code into terrain.
static func grid(size: float, subdivisions: int, height: Callable = Callable()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n := maxi(subdivisions, 1)
	var step := size / float(n)
	var half := size * 0.5

	for z in n + 1:
		for x in n + 1:
			var px := -half + x * step
			var pz := -half + z * step
			var py := 0.0
			if height.is_valid():
				py = float(height.call(px, pz))
			st.set_uv(Vector2(float(x) / n, float(z) / n))
			st.add_vertex(Vector3(px, py, pz))

	# Two triangles per cell, wound counter-clockwise when seen from above so
	# the surface faces up. Reversing these makes the mesh invisible from the
	# side you are looking at, which reads as "my mesh did not load".
	var row := n + 1
	for z in n:
		for x in n:
			var i := z * row + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + row)

			st.add_index(i + 1)
			st.add_index(i + row + 1)
			st.add_index(i + row)

	# Derive normals from the geometry rather than assuming they point up —
	# with a height function they do not.
	st.generate_normals()
	return st.commit()

## A ring of quads — a tube with open ends, useful for pipes and arches.
static func ring(radius: float, thickness: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var count := maxi(segments, 3)
	for i in count:
		var angle := TAU * float(i) / float(count)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		st.set_uv(Vector2(float(i) / count, 0.0))
		st.add_vertex(dir * radius + Vector3.UP * thickness * 0.5)
		st.set_uv(Vector2(float(i) / count, 1.0))
		st.add_vertex(dir * radius - Vector3.UP * thickness * 0.5)

	for i in count:
		var a := i * 2
		var b := i * 2 + 1
		# Wrap the last segment back to the first, which is what closes the ring.
		var c := ((i + 1) % count) * 2
		var d := ((i + 1) % count) * 2 + 1
		st.add_index(a); st.add_index(b); st.add_index(c)
		st.add_index(c); st.add_index(b); st.add_index(d)

	st.generate_normals()
	return st.commit()

## Vertex and index counts a grid will produce, without building it.
static func grid_counts(subdivisions: int) -> Dictionary:
	var n := maxi(subdivisions, 1)
	return {"vertices": (n + 1) * (n + 1), "indices": n * n * 6}
