extends Node

# Drives the real Splat from scripts/splat.gd, and then reads the weights back
# out of the real mesh — because "the shader mixes what the CPU decided" is only
# true if the weights actually reached the vertex colours.
#
# mutate-driver: skip — the scene is instantiated to build a real terrain mesh, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_slope_of_flat_ground()
	test_slope_of_a_wall()
	test_slope_is_direction_blind()
	test_bands_are_smooth()
	test_a_band_with_no_width()
	test_low_ground_is_sand()
	test_middle_ground_is_grass()
	test_the_rule_covers_its_own_ground()
	test_high_ground_is_snow()
	test_a_cliff_is_rock_at_any_height()
	test_the_weights_add_up()
	test_nothing_claimed_this_point()
	test_the_dominant_material()
	test_moving_the_snow_line()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[terrain-splatting] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_slope_of_flat_ground() -> void:
	print("flat ground")
	expect(is_zero_approx(Splat.slope_of(Vector3.UP)), "level ground has no slope")

func test_slope_of_a_wall() -> void:
	print("a wall")
	expect(absf(Splat.slope_of(Vector3.RIGHT) - PI * 0.5) < 0.001,
		"a vertical face is a quarter turn from flat")
	var gentle := Splat.slope_of(Vector3(0.3, 1, 0).normalized())
	expect(gentle > 0.0 and gentle < PI * 0.25, "and a gentle rise is somewhere in between")

func test_slope_is_direction_blind() -> void:
	print("which way it faces")
	# A north-facing cliff and a south-facing one are both cliffs.
	expect(is_equal_approx(Splat.slope_of(Vector3(1, 1, 0).normalized()),
		Splat.slope_of(Vector3(-1, 1, 0).normalized())),
		"two slopes facing opposite ways are equally steep")

func test_bands_are_smooth() -> void:
	print("bands")
	# A hard cutoff at a height draws a line around the hill at that height, and
	# terrain does not have lines on it.
	expect(is_zero_approx(Splat.band(0.0, 2.0, 6.0)), "below the band, nothing")
	expect(is_equal_approx(Splat.band(9.0, 2.0, 6.0), 1.0), "above it, everything")
	var middle := Splat.band(4.0, 2.0, 6.0)
	expect(middle > 0.2 and middle < 0.8, "and part-way through, part-way (%.2f)" % middle)
	expect(Splat.band(3.0, 2.0, 6.0) < middle, "rising smoothly rather than in a step")

func test_a_band_with_no_width() -> void:
	print("a band with no width")
	expect(is_zero_approx(Splat.band(1.0, 5.0, 5.0)), "a zero-width band is a hard cutoff below")
	expect(is_equal_approx(Splat.band(9.0, 5.0, 5.0), 1.0), "and above, rather than dividing by zero")

func test_low_ground_is_sand() -> void:
	print("the water line")
	var weights := Splat.weights_for(0.2, 0.0)
	expect(Splat.dominant(weights) == 0, "flat ground at the water line is sand")
	expect(weights.a < 0.01, "with no snow on it")

func test_middle_ground_is_grass() -> void:
	print("the middle")
	var weights := Splat.weights_for(6.0, 0.05)
	expect(Splat.dominant(weights) == 1, "flat ground half way up is grass")
	# Against the raw weights, not the normalised ones. The fallback in
	# `normalise()` also answers "grass", so a rule that claims nothing at all
	# here would pass the assertion above while being completely broken.
	expect(Splat.raw_weights(6.0, 0.05).g > 0.5,
		"and grass actually claimed it, rather than falling through to the fallback")

func test_the_rule_covers_its_own_ground() -> void:
	print("no gaps")
	# The fallback is a safety net, and a safety net that catches things in
	# ordinary use is a hole. Nothing across the terrain's whole range should
	# ever reach it.
	var uncovered := 0
	for height in [0.0, 1.0, 2.0, 4.0, 6.0, 9.0, 11.0, 13.0, 17.0]:
		for slope in [0.0, 0.2, 0.4, 0.55, 0.7, 1.0, 1.4]:
			var raw := Splat.raw_weights(height, slope)
			if raw.r + raw.g + raw.b + raw.a < 0.05:
				uncovered += 1
	expect(uncovered == 0, "every height and slope is claimed by something (%d gaps)" % uncovered)

func test_high_ground_is_snow() -> void:
	print("the tops")
	var weights := Splat.weights_for(15.0, 0.05)
	expect(Splat.dominant(weights) == 3, "flat ground above the snow line is snow")
	expect(weights.r < 0.01, "and there is no sand at the summit")

func test_a_cliff_is_rock_at_any_height() -> void:
	print("cliffs")
	# Rock is driven by slope and everything else by height, which is what makes
	# a cliff look like a cliff whatever altitude it is at.
	expect(Splat.dominant(Splat.weights_for(1.0, 1.2)) == 2, "a cliff at the water line is rock")
	expect(Splat.dominant(Splat.weights_for(16.0, 1.2)) == 2, "and so is one at the summit")
	expect(Splat.dominant(Splat.weights_for(16.0, 0.0)) != 2,
		"while flat ground at the same height is not")

func test_the_weights_add_up() -> void:
	print("normalising")
	# Four materials each contributing 0.6 is a surface 2.4 times too bright,
	# and the error is worst exactly where two bands meet.
	for height in [0.0, 1.5, 3.0, 6.0, 11.0, 12.0, 18.0]:
		for slope in [0.0, 0.5, 0.6, 1.2]:
			var w := Splat.weights_for(height, slope)
			var total := w.r + w.g + w.b + w.a
			expect(absf(total - 1.0) < 0.001,
				"%.0f m at %.1f rad adds up to one (%.3f)" % [height, slope, total])

func test_nothing_claimed_this_point() -> void:
	print("gaps")
	# A hole in the weights should look like ordinary ground, not like a missing
	# texture.
	var empty := Splat.normalise(Color(0, 0, 0, 0))
	expect(is_equal_approx(empty.g, 1.0), "a point nothing claimed falls back to grass")
	expect(is_equal_approx(empty.r + empty.g + empty.b + empty.a, 1.0), "and still adds up to one")

func test_the_dominant_material() -> void:
	print("one answer")
	# For a footstep sound or a particle effect: the things that need one answer
	# rather than four.
	expect(Splat.dominant(Color(0.1, 0.2, 0.6, 0.1)) == 2, "the largest weight wins")
	expect(Splat.material_name(2) == "rock", "and it has a name")
	expect(Splat.material_name(99) == "snow", "an index off the end is clamped, not a crash")

func test_moving_the_snow_line() -> void:
	print("moving the lines")
	var high := Splat.weights_for(11.0, 0.0, 1.5, 18.0)
	var low := Splat.weights_for(11.0, 0.0, 1.5, 8.0)
	expect(low.a > high.a, "dropping the snow line puts snow on ground that had none")

# --- the real mesh ---------------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			print("the real terrain")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			_check_the_mesh()
			_report()

func _check_the_mesh() -> void:
	var terrain: MeshInstance3D = _scene.get_node("Terrain")
	expect(terrain.mesh != null, "the demo built a terrain mesh")
	var arrays := terrain.mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	expect(colours.size() == vertices.size(),
		"with a weight on every vertex (%d of %d)" % [colours.size(), vertices.size()])

	# Every vertex, not a sample: a single vertex whose weights do not add up is
	# a single bright patch, and those are exactly what nobody notices in review.
	var worst := 0.0
	for colour in colours:
		worst = maxf(worst, absf(colour.r + colour.g + colour.b + colour.a - 1.0))
	expect(worst < 0.01, "and every one of them normalised (worst %.4f off)" % worst)

	# The shader has to be reading those weights, or the CPU's decision goes
	# nowhere.
	var material := terrain.material_override as ShaderMaterial
	expect(material != null and material.shader != null, "the terrain has a shader on it")
	expect(material.shader.code.contains("COLOR"),
		"and the shader mixes by the vertex colour it was given")

	# Changing a line has to rebuild the mesh, not just the readout.
	var before := (terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray)[0]
	_scene.set("_snow_line", 3.0)
	_scene.call("_build")
	var after := (terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray)[0]
	expect(after != before, "dropping the snow line rebuilt the weights in the mesh")
