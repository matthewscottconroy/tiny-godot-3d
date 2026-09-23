extends Node

# Drives the real Volumetrics from scripts/volumetrics.gd, and then checks the
# real Environment — because "the fog is on" is a property nobody can see in a
# headless test, and "the lights were told about it" is one anybody can.

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_transmittance_falls_off_exponentially()
	test_no_fog_hides_nothing()
	test_transmittance_at_zero_distance()
	test_how_far_you_can_see()
	test_choosing_a_density_for_a_distance()
	test_the_round_trip()
	test_clear_air()
	test_ground_mist()
	test_mist_that_sits_somewhere_other_than_zero()
	test_height_fog_with_no_falloff()
	test_the_renderer_it_needs()
	test_the_end_of_the_volume()
	test_what_the_volume_costs()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[volumetric-fog] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_transmittance_falls_off_exponentially() -> void:
	print("extinction")
	# Beer-Lambert. Extinction is exponential, not linear, which is why doubling
	# the density does far more than halve the visibility.
	var near := Volumetrics.transmittance(0.05, 10.0)
	var far := Volumetrics.transmittance(0.05, 20.0)
	expect(near > far, "twice the distance lets less light through")
	expect(absf(far - near * near) < 0.0001,
		"and exactly the square of it, because the falloff is exponential")

func test_no_fog_hides_nothing() -> void:
	print("no fog")
	expect(is_equal_approx(Volumetrics.transmittance(0.0, 1000.0), 1.0),
		"with no density, everything gets through however far away it is")

func test_transmittance_at_zero_distance() -> void:
	print("no distance")
	expect(is_equal_approx(Volumetrics.transmittance(0.5, 0.0), 1.0),
		"and nothing is hidden at no distance at all")
	expect(is_equal_approx(Volumetrics.transmittance(0.5, -5.0), 1.0),
		"a negative distance is treated as none rather than as a light source")

func test_how_far_you_can_see() -> void:
	print("visibility")
	var distance := Volumetrics.visibility(0.03)
	# The number to design with: "you can see 100 metres" is a decision, and
	# density is only how it gets implemented.
	expect(distance > 90.0 and distance < 110.0,
		"at 0.03 per metre you can see about a hundred metres (%.0f)" % distance)
	expect(Volumetrics.visibility(0.06) < distance, "twice the density is less than half of that")

func test_choosing_a_density_for_a_distance() -> void:
	print("designing backwards")
	var density := Volumetrics.density_for(50.0)
	expect(density > 0.0, "a fifty-metre visibility has a density")
	expect(absf(Volumetrics.visibility(density) - 50.0) < 0.001,
		"and it is the one that produces that distance")

func test_the_round_trip() -> void:
	print("round trip")
	for wanted in [10.0, 40.0, 200.0]:
		var density := Volumetrics.density_for(wanted)
		expect(absf(Volumetrics.visibility(density) - wanted) < 0.001,
			"%.0f metres survives the round trip through density" % wanted)

func test_clear_air() -> void:
	print("clear air")
	expect(Volumetrics.visibility(0.0) == INF, "with no fog you can see for ever")
	expect(Volumetrics.density_for(0.0) == INF,
		"and asking to see nothing at all asks for infinite fog rather than dividing by zero")

func test_ground_mist() -> void:
	print("height fog")
	# Ground mist rather than a uniform soup: the thing that makes fog look like
	# weather instead of a fade to grey.
	var at_ground := Volumetrics.height_density(0.1, 0.0)
	var overhead := Volumetrics.height_density(0.1, 12.0)
	expect(is_equal_approx(at_ground, 0.1), "at the ground, the full density")
	expect(overhead < at_ground * 0.2, "twelve metres up, almost none of it")
	expect(overhead > 0.0, "but not nothing, because a hard edge to fog looks like a bug")
	expect(Volumetrics.height_density(0.1, -5.0) == at_ground,
		"and below the floor it does not keep thickening")
	# What `falloff` actually means: the height over which the density drops to
	# about a third. Ordering assertions are satisfied by any curve that goes
	# down — including one that falls off a cliff a metre up — so the constant
	# has to be stated rather than compared against itself.
	expect(absf(Volumetrics.height_density(0.1, 6.0) - 0.1 * exp(-1.0)) < 0.0001,
		"one falloff height up, the density is base/e")
	expect(absf(Volumetrics.height_density(0.1, 12.0) - 0.1 * exp(-2.0)) < 0.0001,
		"and two falloff heights up, base/e squared")

func test_mist_that_sits_somewhere_other_than_zero() -> void:
	print("mist in a valley")
	# Fog that starts at the water line, or at the bottom of a valley. With the
	# floor at zero, adding and subtracting it are the same thing and half this
	# arithmetic goes unchecked.
	var floor_height := -3.0
	expect(is_equal_approx(Volumetrics.height_density(0.1, -3.0, floor_height), 0.1),
		"at the floor of the valley, the full density")
	expect(Volumetrics.height_density(0.1, 3.0, floor_height)
		< Volumetrics.height_density(0.1, 0.0, floor_height),
		"and it thins with height above that floor, not above zero")
	expect(is_equal_approx(Volumetrics.height_density(0.1, -10.0, floor_height), 0.1),
		"below the floor it stays at full density rather than thickening further")

func test_height_fog_with_no_falloff() -> void:
	print("hard-edged fog")
	expect(is_equal_approx(Volumetrics.height_density(0.1, 1.0, 2.0, 0.0), 0.1),
		"with no falloff, below the line is full density")
	expect(is_zero_approx(Volumetrics.height_density(0.1, 3.0, 2.0, 0.0)),
		"and above it is nothing at all")

func test_the_renderer_it_needs() -> void:
	print("renderers")
	# The commonest reason volumetric fog "does not work": the Mobile and
	# Compatibility renderers ignore the setting, silently.
	expect(Volumetrics.supported("forward_plus"), "Forward+ has volumetric fog")
	expect(not Volumetrics.supported("mobile"), "Mobile does not")
	expect(not Volumetrics.supported("gl_compatibility"), "and neither does Compatibility")

func test_the_end_of_the_volume() -> void:
	print("the end of the volume")
	# Past the end of the froxel grid there is no fog at all, and on anything
	# bigger than a room the seam is visible.
	expect(Volumetrics.within_volume(32.0, 64.0) < 1.0, "half way along the volume is inside it")
	expect(Volumetrics.within_volume(100.0, 64.0) > 1.0, "and a hundred metres is beyond it")
	expect(Volumetrics.within_volume(10.0, 0.0) == INF,
		"a volume with no length puts everything outside it")

func test_what_the_volume_costs() -> void:
	print("cost")
	var standard := Volumetrics.froxel_count(Vector2i(128, 72), 64)
	# Reaching further is free; more detail is not. Being able to tell those
	# apart is the point of having the number at all.
	expect(Volumetrics.froxel_count(Vector2i(256, 144), 64) > standard,
		"twice the resolution is more froxels")
	expect(Volumetrics.froxel_count(Vector2i(128, 72), 128) == standard * 2,
		"and twice the depth slices is exactly twice as many")
	expect(Volumetrics.froxel_count(Vector2i(0, 0), 0) >= 1,
		"a degenerate grid still counts as something rather than nothing")

# --- the real environment --------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			print("the real fog")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			# The environment first: the controls press R, and a demo that starts
			# with its shafts off would look identical afterwards.
			_check_the_environment()
			_check_the_controls()
			_check_the_lamp_drifts()
			_report()

func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _check_the_controls() -> void:
	var environment := (_scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	_scene.call("_unhandled_key_input", _key(KEY_R))
	var density: float = _scene.get("_density")
	var length: float = _scene.get("_length")

	_scene.call("_unhandled_key_input", _key(KEY_2))
	expect(_scene.get("_density") > density, "2 makes the fog thicker")
	expect(environment.volumetric_fog_density > density,
		"and it reaches the environment rather than only the readout")
	_scene.call("_unhandled_key_input", _key(KEY_1))
	expect(is_equal_approx(_scene.get("_density"), density), "1 makes it thinner again")

	_scene.call("_unhandled_key_input", _key(KEY_4))
	expect(_scene.get("_length") > length, "4 makes the volume reach further")
	expect(environment.volumetric_fog_length > length, "which the environment hears about too")
	_scene.call("_unhandled_key_input", _key(KEY_3))
	expect(is_equal_approx(_scene.get("_length"), length), "and 3 brings it back")

	_scene.call("_unhandled_key_input", _key(KEY_F))
	expect(not environment.volumetric_fog_enabled, "F turns the fog off entirely")
	_scene.call("_unhandled_key_input", _key(KEY_S))
	expect(not _scene.get("_shafts"), "S takes the light out of it")

	# And R puts every one of those back, which is four separate settings.
	_scene.call("_unhandled_key_input", _key(KEY_R))
	expect(environment.volumetric_fog_enabled and _scene.get("_shafts"),
		"R restores the fog and its shafts")
	expect(is_equal_approx(_scene.get("_density"), density)
		and is_equal_approx(_scene.get("_length"), length),
		"along with the density and the length")

	_scene.call("_unhandled_key_input", _key(KEY_2, true, true))
	expect(is_equal_approx(_scene.get("_density"), density), "a key repeat changes nothing")
	_scene.call("_unhandled_key_input", _key(KEY_2, false))
	expect(is_equal_approx(_scene.get("_density"), density), "and neither does letting go")

## The lamp crosses the fog so you can watch light enter it from the side.
##
## Its rate is the one number here that only exists to be looked at, which is
## exactly why nothing was checking it: every assertion about the fog itself
## holds whether the lamp takes fifteen seconds to cross or half a second.
func _check_the_lamp_drifts() -> void:
	print("the lamp")
	var lamp: OmniLight3D = _scene.get_node("Lamp")
	_scene.set("_time", 0.0)
	_scene.call("_process", 0.0)
	expect(is_zero_approx(lamp.position.x), "the lamp starts at the middle of its sweep")

	# A quarter period at 0.4 rad/s is PI / 0.8 seconds, where it should be at
	# the far end of the sweep. Six times that rate would already be back.
	_scene.call("_process", PI / 0.8)
	expect(absf(lamp.position.x - 5.0) < 0.01,
		"and a quarter of its period later it is at the end of it (%.2f)" % lamp.position.x)

	# within_volume() answers a fraction and the readout states a percentage.
	# Printing the fraction where the percentage belongs turns "68% of the
	# volume" into "0%", which is a different claim about whether the fog
	# reaches the thing you are looking at.
	var readout: Label = _scene.get_node("HUD/ReadoutLabel")
	var camera: Camera3D = _scene.get_node("Camera3D")
	var furthest := 0.0
	for pillar in _scene.get_node("Pillars").get_children():
		furthest = maxf(furthest,
			camera.global_position.distance_to((pillar as Node3D).global_position))
	var share := Volumetrics.within_volume(furthest, _scene.get("_length"))
	expect(share > 0.02, "the furthest pillar is a real fraction of the fog volume")
	expect(readout.text.contains("%.0f%%" % (share * 100.0)),
		"and the readout states that fraction as a percentage")

func _check_the_environment() -> void:
	var world: WorldEnvironment = _scene.get_node("WorldEnvironment")
	var environment := world.environment
	expect(environment.volumetric_fog_enabled, "the environment has volumetric fog switched on")
	expect(environment.volumetric_fog_density > 0.0, "with a density above zero")

	# The setting everyone misses. A light that has not been told about the fog
	# contributes nothing to it, and the result is a grey soup with no shafts —
	# which reads as volumetric fog not working.
	var sun: DirectionalLight3D = _scene.get_node("Sun")
	var lamp: OmniLight3D = _scene.get_node("Lamp")
	expect(sun.light_volumetric_fog_energy > 0.0, "the sun contributes to the fog volume")
	expect(lamp.light_volumetric_fog_energy > 0.0, "and so does the lamp")
	# And by the amount the demo intends. The lamp is deliberately the brighter
	# of the two in fog — it is the one you walk up to — and "greater than zero"
	# is just as true of a lamp half the sun's strength.
	expect(is_equal_approx(lamp.light_volumetric_fog_energy,
			sun.light_volumetric_fog_energy * 2.0),
		"the lamp is twice the sun's contribution, not a fraction of it")

	# Direct light is only half of it: gi_inject is what lets already-bounced
	# light reach the fog, and it is off unless something sets it.
	expect(environment.volumetric_fog_gi_inject > 0.0,
		"and bounced light is injected into the fog volume too")

	# And turning the shafts off has to actually reach the lights, not just the
	# readout.
	_scene.set("_shafts", false)
	_scene.call("_apply")
	expect(is_zero_approx(_scene.get_node("Sun").light_volumetric_fog_energy),
		"turning shafts off takes the light out of the fog")
	expect(is_zero_approx(environment.volumetric_fog_gi_inject),
		"and takes the bounced light out with it")

	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	expect(Volumetrics.supported(method),
		"and the project is on a renderer that has volumetric fog at all (%s)" % method)
