extends Node

# Drives the real StepProbe from scripts/step_probe.gd, then runs the real
# character into the real steps.
#
# mutate-driver: skip — the scene is instantiated to sweep a real ShapeCast3D, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _start := Vector3.ZERO

const MAX_STEP := 0.45

func _ready() -> void:
	test_flat_ground_is_ground()
	test_a_gentle_slope_is_still_ground()
	test_a_steep_slope_is_not()
	test_the_slope_limit_is_where_it_says()
	test_a_low_lip_is_a_step()
	test_a_tall_lip_is_a_wall()
	test_a_surface_overhead_is_a_ceiling()
	test_a_missing_normal_is_refused()
	test_slope_degrees()
	test_stepping_onto_a_surface()
	test_the_step_target_lifts_and_nudges()
	test_the_step_target_needs_a_direction()
	test_measuring_a_rise()
	test_naming()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[shape-cast-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

## A normal tilted `degrees` from straight up.
func _sloped(degrees: float) -> Vector3:
	return Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(degrees))

func test_flat_ground_is_ground() -> void:
	print("ground")
	expect(StepProbe.classify(Vector3.UP, 0.0, 0.0, MAX_STEP) == StepProbe.Surface.GROUND,
		"a flat surface underfoot is ground")
	expect(StepProbe.is_walkable(Vector3.UP), "and is walkable")

func test_a_gentle_slope_is_still_ground() -> void:
	print("ramps")
	expect(StepProbe.classify(_sloped(30.0), 0.2, 0.0, MAX_STEP) == StepProbe.Surface.GROUND,
		"a 30 degree ramp is something you walk up, not a step")
	expect(StepProbe.is_walkable(_sloped(44.0)), "and so is anything under the limit")

func test_a_steep_slope_is_not() -> void:
	print("steep")
	expect(not StepProbe.is_walkable(_sloped(60.0)), "a 60 degree face is not walkable")
	expect(StepProbe.classify(_sloped(90.0), 2.0, 0.0, MAX_STEP) == StepProbe.Surface.WALL,
		"and a vertical one well above the feet is a wall")

func test_the_slope_limit_is_where_it_says() -> void:
	print("the limit")
	# Exactly at the limit counts as walkable, which has to match
	# CharacterBody3D.floor_max_angle or the character disagrees with itself
	# about what it is standing on.
	expect(StepProbe.is_walkable(_sloped(45.0), 45.0), "exactly at the limit is walkable")
	expect(not StepProbe.is_walkable(_sloped(45.5), 45.0), "just past it is not")
	expect(StepProbe.is_walkable(_sloped(70.0), 80.0), "and a raised limit takes in more")

func test_a_low_lip_is_a_step() -> void:
	print("steps")
	# A vertical face whose top is within reach. This is the case
	# move_and_slide() cannot tell from a wall, and the reason a character stops
	# dead at a kerb.
	expect(StepProbe.classify(Vector3.FORWARD, 0.3, 0.0, MAX_STEP) == StepProbe.Surface.STEP,
		"a vertical lip below the step limit is a step")
	expect(StepProbe.classify(Vector3.FORWARD, MAX_STEP, 0.0, MAX_STEP) == StepProbe.Surface.STEP,
		"and one exactly at the limit still is")

func test_a_tall_lip_is_a_wall() -> void:
	print("walls")
	expect(StepProbe.classify(Vector3.FORWARD, MAX_STEP + 0.01, 0.0, MAX_STEP)
		== StepProbe.Surface.WALL, "a lip just past the limit is a wall")
	expect(StepProbe.classify(Vector3.FORWARD, 0.0, 0.0, MAX_STEP) == StepProbe.Surface.WALL,
		"and a vertical face level with the feet is a wall, not a zero-height step")
	# The same geometry with a taller character's step limit becomes climbable,
	# which is the point of the parameter.
	expect(StepProbe.classify(Vector3.FORWARD, 0.6, 0.0, 0.8) == StepProbe.Surface.STEP,
		"while a bigger character climbs the same lip")
	# Feet at zero is the case that hides an addition where a subtraction
	# belongs — a character standing on a platform is the normal one.
	expect(StepProbe.classify(Vector3.FORWARD, 5.3, 5.0, MAX_STEP) == StepProbe.Surface.STEP,
		"a low lip five metres up is still a step")
	expect(StepProbe.classify(Vector3.FORWARD, 5.9, 5.0, MAX_STEP) == StepProbe.Surface.WALL,
		"and a tall one there is still a wall")

func test_a_surface_overhead_is_a_ceiling() -> void:
	print("ceilings")
	expect(StepProbe.classify(Vector3.DOWN, 2.0, 0.0, MAX_STEP) == StepProbe.Surface.CEILING,
		"a surface facing down is a ceiling")
	expect(StepProbe.classify(_sloped(160.0), 2.0, 0.0, MAX_STEP) == StepProbe.Surface.CEILING,
		"and so is a sloped one, whatever its angle")

func test_a_missing_normal_is_refused() -> void:
	print("no normal")
	# A zero normal means the query told us nothing. Treating that as ground is
	# how a character walks up the inside of the level.
	expect(StepProbe.classify(Vector3.ZERO, 0.1, 0.0, MAX_STEP) == StepProbe.Surface.WALL,
		"a hit with no normal is treated as a wall rather than assumed walkable")
	expect(not StepProbe.is_walkable(Vector3.ZERO), "and is never walkable")

func test_slope_degrees() -> void:
	print("measuring slope")
	expect(is_zero_approx(StepProbe.slope_degrees(Vector3.UP)), "flat ground is zero degrees")
	expect(absf(StepProbe.slope_degrees(_sloped(35.0)) - 35.0) < 0.01, "a ramp reads its angle")
	expect(absf(StepProbe.slope_degrees(Vector3.FORWARD) - 90.0) < 0.01, "and a wall reads 90")

func test_stepping_onto_a_surface() -> void:
	print("stepping onto")
	# The question asked of the *downward* cast: not "what did I hit" but "can I
	# stand on top of that".
	expect(StepProbe.can_step_onto(Vector3.UP, 0.3, 0.0, MAX_STEP),
		"a flat top within the step limit can be stepped onto")
	expect(not StepProbe.can_step_onto(Vector3.UP, 0.8, 0.0, MAX_STEP),
		"one above the limit cannot")
	expect(not StepProbe.can_step_onto(_sloped(70.0), 0.3, 0.0, MAX_STEP),
		"and neither can a top too steep to stand on, however low it is")
	expect(not StepProbe.can_step_onto(Vector3.UP, 0.0, 0.0, MAX_STEP),
		"a surface level with the feet is not a step")
	# Stepping "up" onto something lower would teleport the character down
	# through the floor it is already standing on.
	expect(not StepProbe.can_step_onto(Vector3.UP, -0.5, 0.0, MAX_STEP),
		"and a surface below them is a drop, not a step")
	# Feet are almost never at y = 0 — the character is usually already standing
	# on something. The rise is a difference, not a height.
	expect(StepProbe.can_step_onto(Vector3.UP, 5.3, 5.0, MAX_STEP),
		"a step is measured from the feet, wherever they are")
	expect(not StepProbe.can_step_onto(Vector3.UP, 5.9, 5.0, MAX_STEP),
		"and one too tall is still too tall five metres up")

func test_the_step_target_lifts_and_nudges() -> void:
	print("stepping up")
	var from := Vector3(0, 1.0, 5)
	var target := StepProbe.step_target(from, 1.4, Vector3(0, 0, -1), 0.02, 0.05)
	expect(is_equal_approx(target.y, 1.42), "the target is the step top plus the clearance")
	# A lift alone leaves the capsule inside the step's face, and the next frame
	# pushes it straight back off — which reads as the step rejecting you.
	expect(target.z < from.z, "and it moves forward past the lip, not only upward")
	expect(is_equal_approx(target.x, from.x), "without drifting sideways")

func test_the_step_target_needs_a_direction() -> void:
	print("degenerate direction")
	var target := StepProbe.step_target(Vector3(0, 1, 0), 1.4, Vector3.ZERO)
	expect(is_equal_approx(target.y, 1.42), "with no direction it still lifts")
	expect(is_zero_approx(target.z), "and nudges nowhere rather than producing a NAN")
	var vertical := StepProbe.step_target(Vector3(0, 1, 0), 1.4, Vector3.UP)
	expect(is_zero_approx(vertical.z), "a purely vertical direction has no forward part either")

func test_measuring_a_rise() -> void:
	print("measuring a rise")
	expect(is_equal_approx(StepProbe.rise_of(0.4, 0.0), 0.4), "a rise from the ground is its height")
	# Feet at zero is the case that hides an addition where a subtraction
	# belongs, so the interesting assertions are the ones further up.
	expect(is_equal_approx(StepProbe.rise_of(5.4, 5.0), 0.4),
		"and five metres up it is still the difference, not the height")
	expect(StepProbe.rise_of(4.0, 5.0) < 0.0, "a surface below the feet reads as a drop")

func test_naming() -> void:
	print("names")
	expect(StepProbe.name_of(StepProbe.Surface.STEP) == "step", "surfaces have readable names")
	expect(StepProbe.name_of(StepProbe.Surface.CEILING) == "ceiling", "all of them")

# --- the real sweep --------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real sweep")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			_start = (_scene.get_node("Player") as Node3D).global_position
		100:
			var player: Node3D = _scene.get_node("Player")
			var probe: ShapeCast3D = _scene.get_node("Player/Probe")
			expect(probe.shape != null, "the probe sweeps a shape rather than a ray")
			# The character starts just short of the steps and walks toward -Z,
			# over a 0.2m step and a 0.6m one before meeting a 1.6m wall.
			expect(player.global_position.z < _start.z - 2.0,
				"the character has walked into the steps (%.1f m)"
				% (_start.z - player.global_position.z))
			expect(player.global_position.y > _start.y + 0.05,
				"and is standing higher than it started, having climbed at least one")
			_report()
