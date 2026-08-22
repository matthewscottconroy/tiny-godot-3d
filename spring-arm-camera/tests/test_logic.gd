extends Node

# Drives the real ArmSmoothing from scripts/arm_smoothing.gd, then checks that
# the scene's SpringArm3D actually shortens when there is a wall behind the
# camera. The second part needs physics frames, so the suite reports from
# _physics_process — see tests/frames for how many it is given.
#
# mutate-driver: skip — the scene is instantiated to drive a real SpringArm3D, not main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_pulling_in_is_immediate()
	test_pushing_out_is_gradual()
	test_it_never_overshoots()
	test_it_gets_there_eventually()
	test_it_is_frame_rate_independent()
	test_nothing_happens_without_time()
	test_clamping_to_the_arms_limits()
	test_obstruction_is_reported()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[spring-arm-camera] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const IN_RATE := 0.0        # instant, as the demo uses it
const OUT_RATE := 3.5
const STEP := 1.0 / 60.0

func test_pulling_in_is_immediate() -> void:
	print("pulling in")
	# A wall appears: the camera has to be there this frame, not on its way.
	# Anything else spends the transition inside the wall.
	expect(is_equal_approx(ArmSmoothing.recover(6.0, 2.0, IN_RATE, OUT_RATE, STEP), 2.0),
		"a zero in-rate snaps to the shorter length in one step")
	var eased := ArmSmoothing.recover(6.0, 2.0, 4.0, OUT_RATE, STEP)
	expect(eased < 6.0 and eased > 2.0, "a finite in-rate eases instead, for when that is wanted")

func test_pushing_out_is_gradual() -> void:
	print("pushing out")
	var after := ArmSmoothing.recover(2.0, 6.0, IN_RATE, OUT_RATE, STEP)
	expect(after > 2.0, "the arm starts extending once the way is clear")
	expect(after < 6.0, "but does not arrive in one frame")
	# The out-rate is what the caller tunes, so it has to actually do something.
	var slower := ArmSmoothing.recover(2.0, 6.0, IN_RATE, 1.0, STEP)
	expect(slower < after, "a lower out-rate extends more slowly")

func test_it_never_overshoots() -> void:
	print("no overshoot")
	# A big delta with a high rate is the case that breaks a naive
	# `current += (target - current) * rate * delta`: it sails past the target
	# and oscillates.
	var jumped := ArmSmoothing.recover(1.0, 5.0, IN_RATE, 20.0, 1.0)
	expect(jumped <= 5.0, "a large step lands at the target at worst, never beyond it")
	expect(jumped > 4.9, "while still covering nearly all of the distance")

func test_it_gets_there_eventually() -> void:
	print("convergence")
	var length := 1.5
	for i in 240:
		length = ArmSmoothing.recover(length, 6.0, IN_RATE, OUT_RATE, STEP)
	expect(absf(length - 6.0) < 0.01, "four seconds of stepping arrives at the target")

func test_it_is_frame_rate_independent() -> void:
	print("frame rate")
	# The reason for the exponential form. `lerp(a, b, 0.1)` per frame covers a
	# different distance per second at 60fps and at 144fps, so the camera feels
	# different on a faster machine.
	var one_step := ArmSmoothing.recover(2.0, 6.0, IN_RATE, OUT_RATE, 0.1)
	var two_halves := ArmSmoothing.recover(2.0, 6.0, IN_RATE, OUT_RATE, 0.05)
	two_halves = ArmSmoothing.recover(two_halves, 6.0, IN_RATE, OUT_RATE, 0.05)
	expect(is_equal_approx(one_step, two_halves),
		"two half-steps land exactly where one whole step does")

func test_nothing_happens_without_time() -> void:
	print("zero delta")
	expect(is_equal_approx(ArmSmoothing.recover(3.0, 6.0, IN_RATE, OUT_RATE, 0.0), 3.0),
		"no time passing means no movement")
	expect(is_equal_approx(ArmSmoothing.recover(4.0, 4.0, IN_RATE, OUT_RATE, STEP), 4.0),
		"and being already there is not a change either")
	# Including in the direction that is otherwise instant: a zero in-rate means
	# "arrive this frame", not "arrive even when no frame has passed".
	expect(is_equal_approx(ArmSmoothing.recover(6.0, 2.0, 0.0, OUT_RATE, 0.0), 6.0),
		"an instant in-rate still does nothing in zero time")

func test_clamping_to_the_arms_limits() -> void:
	print("limits")
	var short := ArmSmoothing.recover_clamped(2.0, 0.1, IN_RATE, OUT_RATE, STEP, 0.8, 6.0)
	expect(is_equal_approx(short, 0.8), "the arm never pulls closer than its minimum")
	var long := ArmSmoothing.recover_clamped(6.0, 9.0, IN_RATE, OUT_RATE, STEP, 0.8, 6.0)
	expect(is_equal_approx(long, 6.0), "nor extends past its maximum")

func test_obstruction_is_reported() -> void:
	print("obstruction")
	expect(ArmSmoothing.is_obstructed(2.0, 6.0), "a held-in arm reads as obstructed")
	expect(not ArmSmoothing.is_obstructed(6.0, 6.0), "a fully extended one does not")
	expect(not ArmSmoothing.is_obstructed(6.0, 5.99),
		"and neither does floating-point noise at full extension")

# --- the real arm ----------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real arm")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		6:
			# Out in the open, nothing behind the camera: the arm reports its
			# full length.
			var arm: SpringArm3D = _scene.get_node("Pivot/SpringArm3D")
			expect(is_equal_approx(arm.get_hit_length(), arm.spring_length),
				"in the open the arm reports its full length")
			# Back the target up towards the wall the scene puts at z = 9, so
			# the camera — which sits behind the target — ends up inside it.
			_scene.get_node("Target").position = Vector3(0.0, 0.7, 7.5)
		14:
			var arm: SpringArm3D = _scene.get_node("Pivot/SpringArm3D")
			var camera: Camera3D = _scene.get_node("Pivot/Camera3D")
			expect(arm.get_hit_length() < arm.spring_length,
				"a wall behind the camera shortens the arm (%.2f of %.1f)"
				% [arm.get_hit_length(), arm.spring_length])
			expect(camera.position.z < arm.spring_length,
				"and the driver moved the camera in to match")
			expect(camera.position.z > 0.0, "without pulling it through the target")
			_report()
