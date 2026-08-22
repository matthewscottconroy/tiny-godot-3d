extends Node

# Drives the real HeightField from scripts/height_field.gd, then drops a real
# ball onto the real terrain.
#
# mutate-driver: skip — the scene is instantiated to collide with a real HeightMapShape3D, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

const CELLS := 8
const SPACING := 2.0

func _ready() -> void:
	test_the_grid_is_the_right_size()
	test_the_heights_are_the_function()
	test_the_order_is_row_major()
	test_reading_a_height_back()
	test_sampling_between_samples()
	test_sampling_outside_the_grid()
	test_the_shape_matches_the_grid()
	test_the_scale_that_makes_it_line_up()
	test_the_extent()
	test_degenerate_grids()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[terrain-collision] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

## A ramp rather than noise: the expected value at any point is obvious.
func _ramp(x: float, z: float) -> float:
	return x * 0.5 + z * 0.25

func test_the_grid_is_the_right_size() -> void:
	print("size")
	var data := HeightField.build(CELLS, SPACING, _ramp)
	# Cells versus samples: eight cells have nine samples along each edge, and
	# using the cell count as the map size is an off-by-one that shrinks the
	# collider by one cell.
	expect(data.size() == 81, "eight cells is a nine by nine grid of samples")

func test_the_heights_are_the_function() -> void:
	print("the heights")
	var data := HeightField.build(CELLS, SPACING, _ramp)
	var side := CELLS + 1
	var half := float(CELLS) * SPACING * 0.5
	var wrong := 0
	for z in side:
		for x in side:
			var expected := _ramp(-half + float(x) * SPACING, -half + float(z) * SPACING)
			if absf(HeightField.at(data, side, x, z) - expected) > 0.001:
				wrong += 1
	expect(wrong == 0, "every sample is what the height function says")

func test_the_order_is_row_major() -> void:
	print("row order")
	var data := HeightField.build(CELLS, SPACING, _ramp)
	var side := CELLS + 1
	# Godot's height maps are row-major with depth outermost. Transposing them
	# puts hills where the valleys are: plausible, and wrong.
	var along_x := HeightField.at(data, side, side - 1, 0) - HeightField.at(data, side, 0, 0)
	var along_z := HeightField.at(data, side, 0, side - 1) - HeightField.at(data, side, 0, 0)
	expect(along_x > along_z,
		"the X axis climbs faster than Z, as the ramp says — so the grid is not transposed")

func test_reading_a_height_back() -> void:
	print("reading back")
	var data := HeightField.build(CELLS, SPACING, _ramp)
	var side := CELLS + 1
	expect(is_equal_approx(HeightField.at(data, side, 0, 0), _ramp(-8.0, -8.0)),
		"the first sample is the far corner")
	expect(HeightField.at(data, side, 999, 999) == HeightField.at(data, side, side - 1, side - 1),
		"and reading past the edge clamps rather than erroring")

func test_sampling_between_samples() -> void:
	print("sampling")
	var data := HeightField.build(CELLS, SPACING, _ramp)
	var side := CELLS + 1
	# The check that the collider and the mesh describe the same landscape: a
	# sample anywhere should be what the height function returns there.
	var worst := 0.0
	for i in 25:
		var x := -7.0 + float(i) * 0.6
		var z := 3.3 - float(i) * 0.4
		worst = maxf(worst, absf(HeightField.sample(data, side, SPACING, x, z) - _ramp(x, z)))
	expect(worst < 0.01, "sampling the grid agrees with the function it was built from (%.4f)"
		% worst)

func test_sampling_outside_the_grid() -> void:
	print("off the edge")
	var data := HeightField.build(CELLS, SPACING, _ramp)
	var side := CELLS + 1
	var corner := HeightField.at(data, side, side - 1, side - 1)
	expect(is_equal_approx(HeightField.sample(data, side, SPACING, 500.0, 500.0), corner),
		"sampling well off the edge clamps to it rather than running off the array")

func test_the_shape_matches_the_grid() -> void:
	print("the shape")
	var shape := HeightField.shape_for(CELLS, SPACING, _ramp)
	expect(shape.map_width == CELLS + 1 and shape.map_depth == CELLS + 1,
		"the shape is as many samples across as the grid")
	expect(shape.map_data.size() == (CELLS + 1) * (CELLS + 1),
		"and holds all of them")

func test_the_scale_that_makes_it_line_up() -> void:
	print("scale")
	# The line everybody leaves out. HeightMapShape3D samples are one unit
	# apart, always, so a terrain at 2 metres per cell needs its collider
	# scaled by 2 on X and Z — and by 1 on Y, because the heights are already
	# in metres.
	var scale := HeightField.scale_for(SPACING)
	expect(is_equal_approx(scale.x, SPACING) and is_equal_approx(scale.z, SPACING),
		"the horizontal scale is the spacing")
	expect(is_equal_approx(scale.y, 1.0), "while the vertical scale stays at one")
	expect(is_equal_approx(HeightField.scale_for(1.0).x, 1.0),
		"a spacing of one metre needs no scaling at all")

func test_the_extent() -> void:
	print("extent")
	var data := HeightField.build(CELLS, SPACING, _ramp)
	var extent := HeightField.extent(data)
	expect(is_equal_approx(extent.x, _ramp(-8.0, -8.0)), "the lowest point is the low corner")
	expect(is_equal_approx(extent.y, _ramp(8.0, 8.0)), "and the highest is the high one")
	expect(HeightField.extent(PackedFloat32Array()) == Vector2.ZERO,
		"an empty grid has no extent rather than an error")

func test_degenerate_grids() -> void:
	print("degenerate input")
	expect(HeightField.build(0, SPACING, _ramp).size() == 4,
		"zero cells is floored to one, which is four samples")
	expect(HeightField.build(CELLS, SPACING, Callable()).size() == 81,
		"a missing height function gives a flat grid rather than an error")
	expect(is_zero_approx(HeightField.sample(PackedFloat32Array(), 0, SPACING, 0.0, 0.0)),
		"and sampling an empty grid is zero rather than a crash")
	# Both of `at()`'s guards, separately: a height field that has not been built
	# yet gets read by whatever runs first, and neither case may crash.
	expect(is_zero_approx(HeightField.at(PackedFloat32Array(), 4, 1, 1)),
		"reading from an empty grid is flat")
	expect(is_zero_approx(HeightField.at(HeightField.build(2, SPACING, _ramp), 0, 0, 0)),
		"and so is reading from a grid with no side")
	# And both of `sample()`'s, which are a different pair: one sample across is
	# not a grid you can interpolate in, however much data is behind it.
	expect(is_zero_approx(HeightField.sample(HeightField.build(2, SPACING, _ramp), 1,
		SPACING, 0.0, 0.0)), "a one-sample grid has nothing to interpolate between")
	expect(is_zero_approx(HeightField.sample(PackedFloat32Array(), 4, SPACING, 0.0, 0.0)),
		"and a grid with a size but no data is flat")

# --- the real collider -----------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real terrain")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			var body: StaticBody3D = _scene.get_node("Terrain/Body")
			var shape_node: CollisionShape3D = _scene.get_node("Terrain/Body/Shape")
			expect(shape_node.shape is HeightMapShape3D, "the terrain collides with a height map")
			expect(body.scale.x > 1.0,
				"whose body is scaled to match the mesh's spacing (%.2f)" % body.scale.x)
			# Drop a ball from a known place and let it settle.
			var ball := RigidBody3D.new()
			var collider := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.4
			collider.shape = sphere
			ball.add_child(collider)
			ball.name = "TestBall"
			ball.position = Vector3(3.0, 4.5, -2.0)
			_scene.add_child(ball)
		75:
			var ball: RigidBody3D = _scene.get_node("TestBall")
			var driver = _scene
			var ground: float = driver._height(ball.position.x, ball.position.z)
			# The whole point: a ball at rest sits on the ground the mesh draws.
			# A collider of the wrong size leaves it in mid-air or knee-deep.
			expect(ball.position.y < 4.0, "the ball fell")
			expect(absf(ball.position.y - (ground + 0.4)) < 0.4,
				"and came to rest on the surface the mesh shows (%.2f against %.2f)"
				% [ball.position.y, ground + 0.4])
			_report()
