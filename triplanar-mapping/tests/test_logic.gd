extends Node

# Drives the real Triplanar from scripts/triplanar_mapping.gd, then instantiates
# the real scene to check the ridge it builds is actually steep — a demo about
# cliffs whose "cliff" is a gentle slope would pass every assertion above and
# teach nothing.
#
# mutate-driver: skip — the scene is instantiated to inspect a real generated mesh, not main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_weights_are_a_blend()
	test_flat_ground_is_the_up_projection()
	test_a_wall_is_projected_from_the_side()
	test_sharpness_tightens_the_seam()
	test_a_degenerate_normal_falls_back_to_up()
	test_the_dominant_axis_is_the_heaviest_weight()
	test_each_projection_drops_its_own_axis()
	test_the_stretch_a_flat_uv_costs()
	test_when_it_is_worth_paying_for()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[triplanar-mapping] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const WALL := Vector3(1, 0, 0)
const GROUND := Vector3(0, 1, 0)
const SLOPE_45 := Vector3(0.7071, 0.7071, 0.0)

func test_weights_are_a_blend() -> void:
	print("weights")
	# Not a sum: three samples averaged by weights that do not total one come out
	# darker or brighter than the texture, which reads as bad lighting.
	for normal in [GROUND, WALL, SLOPE_45, Vector3(0.3, 0.5, -0.8)]:
		var w := Triplanar.weights(normal)
		expect(is_equal_approx(w.x + w.y + w.z, 1.0),
			"the three projections sum to one for %v" % normal)

func test_flat_ground_is_the_up_projection() -> void:
	print("flat ground")
	var w := Triplanar.weights(GROUND)
	expect(is_equal_approx(w.y, 1.0), "flat ground is drawn entirely by the Y projection")
	expect(is_zero_approx(w.x) and is_zero_approx(w.z), "and not at all by the other two")

func test_a_wall_is_projected_from_the_side() -> void:
	print("a wall")
	# The whole point. A wall's Y projection sees almost none of it, so leaning on
	# Y is what smears the texture down the face.
	var w := Triplanar.weights(WALL)
	expect(is_equal_approx(w.x, 1.0), "a wall facing X is drawn by the X projection")
	expect(is_zero_approx(w.y), "with nothing from the one that would stretch it")

func test_sharpness_tightens_the_seam() -> void:
	print("sharpness")
	# At 45° two projections are equally valid, so the weight is split evenly
	# whatever the sharpness. The sharpness shows up just off 45°.
	var even := Triplanar.weights(SLOPE_45, 4.0)
	expect(absf(even.x - even.y) < 0.001, "an exact 45 degrees splits evenly")

	var tilted := Vector3(0.6, 0.8, 0.0)
	var soft := Triplanar.weights(tilted, 1.0)
	var hard := Triplanar.weights(tilted, 12.0)
	expect(hard.y > soft.y,
		"off 45 degrees, a higher sharpness hands more to the leading projection")
	expect(is_equal_approx(hard.x + hard.y + hard.z, 1.0), "and still sums to one")

func test_a_degenerate_normal_falls_back_to_up() -> void:
	print("no normal at all")
	# A zero normal has no axis to favour. Dividing by the total would be a
	# division by zero, and the surface would come out black rather than wrong.
	var w := Triplanar.weights(Vector3.ZERO)
	expect(is_equal_approx(w.y, 1.0), "a zero normal is treated as ground")
	expect(is_equal_approx(w.x + w.y + w.z, 1.0), "rather than as nothing at all")

func test_the_dominant_axis_is_the_heaviest_weight() -> void:
	print("dominant axis")
	# The cheap single-projection approximation has to agree with the blend, or
	# a footstep sound picks one surface while the shader draws another.
	for normal in [GROUND, WALL, Vector3(0, 0, -1), Vector3(0.2, 0.3, 0.93)]:
		var w := Triplanar.weights(normal)
		var heaviest := 0
		if w.y >= w.x and w.y >= w.z:
			heaviest = 1
		elif w.z >= w.x and w.z >= w.y:
			heaviest = 2
		expect(Triplanar.dominant_axis(normal) == heaviest,
			"dominant_axis agrees with the blend for %v" % normal)

func test_each_projection_drops_its_own_axis() -> void:
	print("projections")
	var point := Vector3(2.0, 3.0, 5.0)
	# Reading world position rather than UV is the mechanism; each projection
	# uses the two axes it does not look along.
	expect(Triplanar.planar_uv(point, 0) == Vector2(5.0, 3.0), "the X projection reads Z and Y")
	expect(Triplanar.planar_uv(point, 1) == Vector2(2.0, 5.0), "the Y projection reads X and Z")
	expect(Triplanar.planar_uv(point, 2) == Vector2(2.0, 3.0), "the Z projection reads X and Y")
	# On every axis, at a scale that is not one. At scale 1.0 multiplying and
	# dividing by it are the same number, so two of these three projections
	# could scale the wrong way with nothing above noticing.
	expect(Triplanar.planar_uv(point, 0, 2.0) == Vector2(10.0, 6.0),
		"the X projection scales by the factor rather than dividing by it")
	expect(Triplanar.planar_uv(point, 1, 2.0) == Vector2(4.0, 10.0),
		"and so does the Y projection")
	expect(Triplanar.planar_uv(point, 2, 2.0) == Vector2(4.0, 6.0),
		"and the Z projection")

func test_the_stretch_a_flat_uv_costs() -> void:
	print("stretch")
	expect(is_equal_approx(Triplanar.stretch_factor(GROUND), 1.0),
		"flat ground does not stretch a top-down projection at all")
	expect(absf(Triplanar.stretch_factor(SLOPE_45) - sqrt(2.0)) < 0.01,
		"a 45 degree slope stretches it by root two")
	# Vertical is a division by zero in the honest formula, and unbounded either
	# side of it, so it is clamped rather than printed as INF.
	expect(Triplanar.stretch_factor(WALL) >= 99.0, "a vertical face is clamped, not infinite")
	expect(is_finite(Triplanar.stretch_factor(WALL)), "and is a number a HUD can show")

func test_when_it_is_worth_paying_for() -> void:
	print("worth it")
	# Three samples instead of one is the cost, so the judgement matters.
	expect(not Triplanar.needs_triplanar(GROUND), "flat ground does not need three samples")
	expect(Triplanar.needs_triplanar(WALL), "a wall does")
	expect(Triplanar.needs_triplanar(SLOPE_45), "and so does a 45 degree slope")

# --- the real ridge ---------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real ridge")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			var terrain: MeshInstance3D = _scene.get_node("Terrain")
			expect(terrain.mesh != null, "the driver generated a mesh")
			var arrays := terrain.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			expect(normals.size() == vertices.size(), "with a normal for every vertex")

			# A demo about cliffs needs a cliff. If the ridge were gentle the
			# flat-UV mode would look almost correct and the comparison the whole
			# demo rests on would show nothing.
			# Sign first. Measuring only abs(n.y) is happy with a mesh wound
			# inside out, which is backface-culled and invisible — and every
			# other assertion here still passes.
			var upward := 0
			for n in normals:
				if n.normalized().y > 0.0:
					upward += 1
			expect(upward == normals.size(),
				"every normal points up, so the terrain is not wound inside out "
				+ "(%d of %d)" % [upward, normals.size()])

			var steepest := 1.0
			for n in normals:
				steepest = minf(steepest, absf(n.normalized().y))
			expect(steepest < 0.35,
				"the ridge has genuinely steep faces (shallowest normal.y %.2f)" % steepest)
			expect(Triplanar.needs_triplanar(Vector3(sqrt(1.0 - steepest * steepest), steepest, 0.0)),
				"steep enough that a flat UV visibly stretches there")

			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			expect(uvs.size() == vertices.size(),
				"and it carries the flat UVs the comparison switches away from")
			_report()
