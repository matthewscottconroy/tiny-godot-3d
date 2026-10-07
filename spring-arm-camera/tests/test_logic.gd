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
var _probe: SpringArm3D = null
var _shortest_on_spawn := INF
var _blocker: StaticBody3D = null

func _ready() -> void:
	test_pulling_in_is_immediate()
	test_pushing_out_is_gradual()
	test_it_never_overshoots()
	test_it_gets_there_eventually()
	test_it_is_frame_rate_independent()
	test_nothing_happens_without_time()
	test_clamping_to_the_arms_limits()
	test_obstruction_is_reported()
	test_the_pivot_sits_above_the_target()
	test_the_ground_basis_is_flat()
	test_movement_is_camera_relative()
	test_a_vertical_rig_does_not_stop_movement()

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

# --- the rig the arm hangs off ---------------------------------------------

func test_the_pivot_sits_above_the_target() -> void:
	print("pivot")
	var pivot := SpringRig.pivot_position(Vector3(2.0, 0.7, -3.0), 1.2)
	expect(is_equal_approx(pivot.y, 1.9), "the pivot is raised to head height, not centred")
	expect(is_equal_approx(pivot.x, 2.0) and is_equal_approx(pivot.z, -3.0),
		"and follows the target on the ground plane")

func test_the_ground_basis_is_flat() -> void:
	print("ground basis")
	# A rig pitched steeply down. Un-flattened, "forward" would point into the
	# floor and holding forward would walk the character underground.
	var pitched := Basis.from_euler(Vector3(-0.9, 0.0, 0.0))
	var basis := SpringRig.ground_basis(pitched)
	var forward: Vector3 = basis["forward"]
	var right: Vector3 = basis["right"]
	expect(is_zero_approx(forward.y), "forward is flattened onto the ground plane")
	expect(is_zero_approx(right.y), "and so is right")
	expect(is_equal_approx(forward.length(), 1.0), "forward is a unit vector")
	expect(is_zero_approx(forward.dot(right)), "and right is perpendicular to it")

func test_movement_is_camera_relative() -> void:
	print("camera-relative movement")
	# Yawed a quarter turn: "forward" for the player is now world -X, because
	# the camera is looking that way. This is the sign that a demo gets wrong
	# and nobody notices, because walking still happens — just sideways.
	var yawed := Basis.from_euler(Vector3(0.0, PI / 2.0, 0.0))
	var forward := SpringRig.move_direction(yawed, Vector2(0.0, -1.0))
	expect(forward.x < -0.9, "pushing up walks away from a quarter-turned camera")
	var strafe := SpringRig.move_direction(yawed, Vector2(1.0, 0.0))
	expect(strafe.z < -0.9, "and pushing right strafes to the camera's right")
	expect(is_zero_approx(forward.dot(strafe)), "the two are perpendicular")
	expect(SpringRig.move_direction(yawed, Vector2.ZERO) == Vector3.ZERO,
		"no input is no direction, rather than a normalised zero")

func test_a_vertical_rig_does_not_stop_movement() -> void:
	print("degenerate rig")
	# Straight down, the flattened forward is zero and normalising it gives
	# (0, 0, 0) rather than an error — movement silently stops. The demo clamps
	# well short of this, but an adopter who raises the limit would not.
	var straight_down := Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0))
	var direction := SpringRig.move_direction(straight_down, Vector2(0.0, -1.0))
	expect(is_equal_approx(direction.length(), 1.0),
		"a vertical rig still yields a usable direction")

# --- the real arm ----------------------------------------------------------

## An arm with one body squarely in its sweep, away from the demo's scene.
##
## Built here rather than driven through main.gd: the point is what the *engine*
## does with an exclusion, and a bare arm states that in one number.
func _build_exclusion_probe() -> void:
	print("exclusions")
	var root := Node3D.new()
	root.position = Vector3(0.0, 100.0, 0.0)      # clear of the demo's level
	add_child(root)

	_blocker = StaticBody3D.new()
	_blocker.position = Vector3(0.0, 100.0, 2.0)  # 2 m along the arm's +Z sweep
	var blocker_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.5)
	blocker_shape.shape = box
	_blocker.add_child(blocker_shape)
	add_child(_blocker)

	_probe = SpringArm3D.new()
	_probe.spring_length = 5.0
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	_probe.shape = sphere
	root.add_child(_probe)

func _physics_process(_delta: float) -> void:
	_frame += 1

	# Watch the camera over the frames right after the scene loads. SpringArm3D
	# answers 0 until it has swept once, and a driver that believes that number
	# yanks the camera to its minimum and then eases it out — a second of
	# spring-out at the start of every single run, with nothing logged.
	if _scene != null and _frame <= 6:
		var spawn_camera: Camera3D = _scene.get_node("Pivot/Camera3D")
		_shortest_on_spawn = minf(_shortest_on_spawn, spawn_camera.position.z)

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
			expect(is_equal_approx(_shortest_on_spawn, arm.spring_length),
				"and the camera sat at that length from the first frame, rather "
				+ "than springing out from the minimum (shortest %.2f)" % _shortest_on_spawn)
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
			_build_exclusion_probe()
		17:
			# The character's own collider is in the sweep's way, and the arm
			# has no idea it is special: it stops on it like any other body.
			expect(_probe.get_hit_length() < _probe.spring_length,
				"an unexcluded body in the sweep shortens the arm (%.2f of %.1f)"
				% [_probe.get_hit_length(), _probe.spring_length])
			_probe.add_excluded_object(_blocker.get_rid())
		20:
			# Same body, same position — the arm now sweeps straight past it.
			# This is the whole reason the demo calls add_excluded_object().
			expect(is_equal_approx(_probe.get_hit_length(), _probe.spring_length),
				"excluding it lets the arm reach its full length again")
			_probe.remove_excluded_object(_blocker.get_rid())
		23:
			expect(_probe.get_hit_length() < _probe.spring_length,
				"and removing the exclusion puts it back in the way")
			_report()
