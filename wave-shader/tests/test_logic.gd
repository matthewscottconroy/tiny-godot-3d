extends Node

# Drives the real WaveField from scripts/wave_field.gd, and checks it against
# the shader it shares its maths with.
#
# The shader itself cannot be run here — a headless renderer has no GPU to run it
# on. What can be checked is the thing that actually breaks: whether the two
# copies are configured from the same numbers, and whether the CPU side behaves
# the way the GPU side is written to.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_a_flat_sea()
	test_the_surface_moves_over_time()
	test_the_surface_varies_across_space()
	test_height_stays_under_the_crest()
	test_swell_scales_everything()
	test_a_wave_repeats_over_its_wavelength()
	test_a_wave_travels_in_its_direction()
	test_normals_are_unit_and_point_up()
	test_normals_lean_away_from_the_slope()
	test_flat_water_has_a_flat_normal()
	test_the_field_is_deterministic()
	test_degenerate_waves()
	test_uniforms_match_the_field()
	test_changing_the_field_changes_the_uniforms()
	test_applying_to_nothing()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[wave-shader] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water.gdshader")
	return material

func test_a_flat_sea() -> void:
	print("no waves")
	var field := WaveField.new(false)
	expect(is_zero_approx(field.height_at(3.0, 4.0, 1.0)), "a field with no waves is flat")
	expect(is_zero_approx(field.crest_height()), "and has no crest")

func test_the_surface_moves_over_time() -> void:
	print("motion")
	var field := WaveField.new()
	var now := field.height_at(2.0, 2.0, 0.0)
	var later := field.height_at(2.0, 2.0, 0.7)
	expect(absf(now - later) > 0.01, "the same point is at a different height a moment later")

func test_the_surface_varies_across_space() -> void:
	print("shape")
	var field := WaveField.new()
	var here := field.height_at(0.0, 0.0, 0.0)
	var there := field.height_at(4.0, -3.0, 0.0)
	expect(absf(here - there) > 0.01, "two points at the same moment are at different heights")

func test_height_stays_under_the_crest() -> void:
	print("bounds")
	var field := WaveField.new()
	var worst := 0.0
	for i in 400:
		var x := float(i % 20) * 1.7 - 17.0
		var z := float(i / 20) * 1.3 - 13.0
		worst = maxf(worst, absf(field.height_at(x, z, i * 0.05)))
	# The crest is the sum of the amplitudes: the surface can only reach it when
	# every wave peaks together, which is exactly what a bounding box has to
	# assume.
	expect(worst <= field.crest_height() + 0.001, "no point ever rises above the crest height")
	expect(worst > field.crest_height() * 0.3, "while the range is genuinely used")

func test_swell_scales_everything() -> void:
	print("swell")
	var calm := WaveField.new()
	var rough := WaveField.new()
	rough.swell = 2.0
	expect(is_equal_approx(rough.height_at(3.0, 1.0, 0.5), calm.height_at(3.0, 1.0, 0.5) * 2.0),
		"twice the swell is twice the height, everywhere")
	var flat := WaveField.new()
	flat.swell = 0.0
	expect(is_zero_approx(flat.height_at(3.0, 1.0, 0.5)), "and no swell is a millpond")

func test_a_wave_repeats_over_its_wavelength() -> void:
	print("wavelength")
	var field := WaveField.new(false)
	field.waves = [WaveField.Wave.new(1.0, 4.0, 0.0, Vector2.RIGHT)]
	var here := field.height_at(0.0, 0.0, 0.0)
	expect(is_equal_approx(field.height_at(4.0, 0.0, 0.0), here),
		"one wavelength along, the surface is back where it was")
	expect(is_equal_approx(field.height_at(8.0, 0.0, 0.0), here), "and again the next one")
	# A quarter of the way along is the crest, three quarters is the trough —
	# the halfway point is back at zero, which is why it is a poor thing to
	# compare against.
	expect(is_equal_approx(field.height_at(1.0, 0.0, 0.0), 1.0),
		"a quarter wavelength along is the crest")
	expect(is_equal_approx(field.height_at(3.0, 0.0, 0.0), -1.0),
		"and three quarters along is the trough")

	# The same wave rotated onto Z, to pin down the other half of the phase:
	# a direction of (0, 1) must read z and ignore x.
	var along_z := WaveField.new(false)
	# Vector2(0, 1), written out: Vector2.UP is (0, -1), and a direction whose
	# y maps to world Z is exactly where that catches people.
	along_z.waves = [WaveField.Wave.new(1.0, 4.0, 0.0, Vector2(0.0, 1.0))]
	expect(is_equal_approx(along_z.height_at(0.0, 1.0, 0.0), 1.0),
		"a wave travelling along Z crests a quarter wavelength along Z")
	expect(is_equal_approx(along_z.height_at(9.0, 1.0, 0.0), 1.0),
		"whatever the X coordinate is")

func test_a_wave_travels_in_its_direction() -> void:
	print("direction")
	var field := WaveField.new(false)
	field.waves = [WaveField.Wave.new(1.0, 4.0, 1.0, Vector2.RIGHT)]
	# A wave heading along +X leaves the perpendicular axis alone: every point
	# with the same x is at the same height, whatever its z.
	expect(is_equal_approx(field.height_at(1.0, 0.0, 0.3), field.height_at(1.0, 9.0, 0.3)),
		"a wave travelling along X is unchanged along Z")
	expect(absf(field.height_at(1.0, 0.0, 0.3) - field.height_at(3.0, 0.0, 0.3)) > 0.1,
		"but does change along X")

func test_normals_are_unit_and_point_up() -> void:
	print("normals")
	var field := WaveField.new()
	var normal := field.normal_at(1.5, -2.0, 0.4)
	expect(is_equal_approx(normal.length(), 1.0), "a normal is a unit vector")
	expect(normal.y > 0.0, "and points out of the water rather than into it")

func test_normals_lean_away_from_the_slope() -> void:
	print("normal direction")
	# One wave along +X, frozen. Between the trough at 3/4 wavelength and the
	# crest at 1/4, the surface climbs in -X... so at x = 0 (rising toward the
	# crest at x = 1) the normal must lean the other way, toward -X.
	var field := WaveField.new(false)
	field.waves = [WaveField.Wave.new(1.0, 8.0, 0.0, Vector2.RIGHT)]
	var normal := field.normal_at(0.0, 0.0, 0.0)
	expect(normal.x < -0.1, "on a slope rising in +X, the normal leans in -X")
	expect(is_zero_approx(normal.z), "and not at all along the axis the wave ignores")
	var downhill := field.normal_at(4.0, 0.0, 0.0)
	expect(downhill.x > 0.1, "half a wavelength along, the slope and the normal reverse")

	# And the same on the other axis, because the two slopes are computed
	# separately and only one of them is exercised by a wave along X.
	var across := WaveField.new(false)
	across.waves = [WaveField.Wave.new(1.0, 8.0, 0.0, Vector2(0.0, 1.0))]
	var z_normal := across.normal_at(0.0, 0.0, 0.0)
	expect(z_normal.z < -0.1, "a wave along Z tilts the normal along Z")
	expect(is_zero_approx(z_normal.x), "and leaves the other axis alone")

func test_flat_water_has_a_flat_normal() -> void:
	print("flat normals")
	var field := WaveField.new(false)
	expect(field.normal_at(0.0, 0.0, 0.0).is_equal_approx(Vector3.UP),
		"still water has a straight-up normal")

func test_the_field_is_deterministic() -> void:
	print("determinism")
	var a := WaveField.new()
	var b := WaveField.new()
	expect(is_equal_approx(a.height_at(2.5, -1.5, 3.25), b.height_at(2.5, -1.5, 3.25)),
		"two fields with the same waves agree exactly")
	expect(is_equal_approx(a.height_at(2.5, -1.5, 3.25), a.height_at(2.5, -1.5, 3.25)),
		"and asking twice gives the same answer — there is no hidden clock")

func test_degenerate_waves() -> void:
	print("degenerate waves")
	var wave := WaveField.Wave.new(1.0, 0.0, 1.0, Vector2.ZERO)
	expect(wave.wavelength > 0.0, "a wavelength of zero is floored rather than dividing by zero")
	expect(is_equal_approx(wave.direction.length(), 1.0),
		"and a direction of nothing becomes a real direction")

func test_uniforms_match_the_field() -> void:
	print("one source of numbers")
	var field := WaveField.new()
	var material := _material()
	field.apply_to(material)
	var uniforms := WaveField.parameters_of(material)
	# The check the whole design exists for. The shader and the GDScript are two
	# implementations of one formula; what keeps them honest is that neither
	# owns the parameters.
	# Guard first: an apply_to() that quietly did nothing would otherwise leave
	# the loop below indexing nulls, and an aborted test proves nothing.
	expect(uniforms["amplitudes"] != null and uniforms["directions"] != null,
		"the material actually received the arrays")
	expect(int(uniforms["wave_count"]) == field.waves.size(), "the shader knows how many waves")
	expect(is_equal_approx(float(uniforms["swell"]), field.swell), "and the swell")
	var mismatches := 0
	for i in field.waves.size():
		if not is_equal_approx(uniforms["amplitudes"][i], field.waves[i].amplitude):
			mismatches += 1
		if not is_equal_approx(uniforms["wavelengths"][i], field.waves[i].wavelength):
			mismatches += 1
		if not is_equal_approx(uniforms["speeds"][i], field.waves[i].speed):
			mismatches += 1
		if not uniforms["directions"][i].is_equal_approx(field.waves[i].direction):
			mismatches += 1
	expect(mismatches == 0, "every wave reaches the shader exactly as the field has it")

func test_changing_the_field_changes_the_uniforms() -> void:
	print("staying in step")
	var field := WaveField.new()
	var material := _material()
	field.apply_to(material)
	field.swell = 2.75
	field.apply_to(material)
	expect(is_equal_approx(float(material.get_shader_parameter("swell")), 2.75),
		"a change pushed through apply_to reaches the shader")
	field.waves = [WaveField.Wave.new(1.0, 3.0, 1.0, Vector2.UP)]
	field.apply_to(material)
	expect(int(material.get_shader_parameter("wave_count")) == 1,
		"and so does a change to the wave set")

func test_applying_to_nothing() -> void:
	print("no material")
	var field := WaveField.new()
	field.apply_to(null)
	expect(WaveField.parameters_of(null).is_empty(),
		"a missing material is ignored rather than erroring")
