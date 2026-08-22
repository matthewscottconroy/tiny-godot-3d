extends Node

# Drives the real CharacterMotor from scripts/motor.gd, and then the real body
# from scripts/player.gd with synthesised input.
#
# mutate-driver: skip — the scene is instantiated to drive player.gd with real input, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _start := Vector3.ZERO

func _ready() -> void:
	test_a_fresh_motor_is_airborne()
	test_gravity_pulls_down()
	test_landing_zeroes_fall()
	test_jump_from_floor()
	test_no_jump_in_midair()
	test_coyote_time_allows_a_late_jump()
	test_coyote_time_expires()
	test_walk_and_run_speeds()
	test_acceleration_is_gradual()
	test_air_control_is_weaker()
	test_reset()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[character-controller-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const STEP := 1.0 / 60.0
const FORWARD := Vector3(0, 0, -1)

func test_a_fresh_motor_is_airborne() -> void:
	print("initial state")
	var m := CharacterMotor.new()
	expect(not m.can_jump(false), "a motor that has never touched the ground cannot jump")
	# The motor arms coyote time on the frame it leaves the floor. If it starts
	# out believing it *was* on the floor, the first airborne frame arms the
	# window and a character spawned in mid-air gets one free jump.
	m.step(Vector3.ZERO, false, false, false, STEP)
	expect(not m.can_jump(false), "and the first airborne frame does not grant one")

func test_gravity_pulls_down() -> void:
	print("gravity")
	var m := CharacterMotor.new()
	m.step(Vector3.ZERO, false, false, false, STEP)
	expect(m.velocity.y < 0.0, "an airborne character accelerates downward")

func test_landing_zeroes_fall() -> void:
	print("landing")
	var m := CharacterMotor.new()
	for i in 30:
		m.step(Vector3.ZERO, false, false, false, STEP)
	expect(m.velocity.y < -1.0, "fall speed built up")
	m.step(Vector3.ZERO, false, false, true, STEP)
	expect(is_zero_approx(m.velocity.y), "landing zeroes it rather than accumulating forever")

func test_jump_from_floor() -> void:
	print("jumping")
	var m := CharacterMotor.new()
	m.step(Vector3.ZERO, false, true, true, STEP)
	expect(m.velocity.y > 0.0, "a grounded jump sends the character up")
	expect(is_equal_approx(m.velocity.y, m.jump_velocity), "at exactly the jump velocity")

func test_no_jump_in_midair() -> void:
	print("no double jump")
	var m := CharacterMotor.new()
	# Fall long enough for coyote time to lapse.
	for i in 30:
		m.step(Vector3.ZERO, false, false, false, STEP)
	var before := m.velocity.y
	m.step(Vector3.ZERO, false, true, false, STEP)
	expect(m.velocity.y < before + 0.001, "pressing jump in mid-air does nothing")

func test_coyote_time_allows_a_late_jump() -> void:
	print("coyote time")
	var m := CharacterMotor.new()
	m.step(Vector3.ZERO, false, false, true, STEP)     # grounded
	m.step(Vector3.ZERO, false, false, false, STEP)    # just walked off
	expect(m.can_jump(false), "a jump is still allowed just after leaving the ground")
	m.step(Vector3.ZERO, false, true, false, STEP)
	expect(m.velocity.y > 0.0, "and it actually fires")

func test_coyote_time_expires() -> void:
	print("coyote time expiry")
	var m := CharacterMotor.new()
	m.step(Vector3.ZERO, false, false, true, STEP)
	var elapsed := 0.0
	while elapsed < m.coyote_time + 0.05:
		m.step(Vector3.ZERO, false, false, false, STEP)
		elapsed += STEP
	expect(not m.can_jump(false), "the window closes")

func test_walk_and_run_speeds() -> void:
	print("walk vs run")
	var walker := CharacterMotor.new()
	var runner := CharacterMotor.new()
	for i in 120:
		walker.step(FORWARD, false, false, true, STEP)
		runner.step(FORWARD, true, false, true, STEP)
	expect(is_equal_approx(walker.horizontal_speed(), walker.walk_speed),
		"walking settles at walk_speed")
	expect(is_equal_approx(runner.horizontal_speed(), runner.run_speed),
		"running settles at run_speed")
	expect(runner.horizontal_speed() > walker.horizontal_speed(), "running is faster")

func test_acceleration_is_gradual() -> void:
	print("acceleration")
	var m := CharacterMotor.new()
	m.step(FORWARD, false, false, true, STEP)
	var after_one := m.horizontal_speed()
	expect(after_one > 0.0, "the character starts moving immediately")
	expect(after_one < m.walk_speed, "but does not reach full speed in one frame")

func test_air_control_is_weaker() -> void:
	print("air control")
	var grounded := CharacterMotor.new()
	var airborne := CharacterMotor.new()
	for i in 10:
		grounded.step(FORWARD, false, false, true, STEP)
		airborne.step(FORWARD, false, false, false, STEP)
	expect(airborne.horizontal_speed() < grounded.horizontal_speed(),
		"steering in the air is weaker than on the ground")
	expect(airborne.horizontal_speed() > 0.0, "but not zero — you can still steer")

func test_reset() -> void:
	print("reset")
	var m := CharacterMotor.new()
	for i in 20:
		m.step(FORWARD, true, false, false, STEP)
	m.reset()
	expect(m.velocity == Vector3.ZERO, "velocity is cleared")
	expect(not m.can_jump(false), "and so is the coyote window")

	# Reset has to forget that we were ever on the floor, not just clear the
	# window. The motor arms coyote time on the frame it *leaves* the ground, so
	# a motor that still believes it was grounded re-arms it on the very next
	# airborne frame — a free mid-air jump after every respawn.
	var grounded := CharacterMotor.new()
	grounded.step(Vector3.ZERO, false, false, true, STEP)
	grounded.reset()
	grounded.step(Vector3.ZERO, false, false, false, STEP)
	expect(not grounded.can_jump(false), "and it does not re-arm on the next airborne frame")

# --- the real body ---------------------------------------------------------
#
# The motor is pure maths and is tested above. player.gd is the other half: it
# reads Input, calls move_and_slide(), and hands the result back. That needs a
# scene and an input device — so the suite makes one, by pressing the actions
# itself.

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real body")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			_start = (_scene.get_node("Player") as Node3D).global_position
			# Input.action_press works without a window or a keyboard: it sets
			# the action's strength directly, which is what Input.get_vector
			# reads.
			Input.action_press(&"ui_up")
		30:
			var player: Node3D = _scene.get_node("Player")
			var moved := _start.distance_to(player.global_position)
			expect(moved > 0.3, "holding a direction moves the body (%.2f m)" % moved)
			expect(player.global_position.z < _start.z,
				"in the direction that was pressed, not the opposite one")
			Input.action_release(&"ui_up")
			_resting_at = player.global_position
		45:
			var player: Node3D = _scene.get_node("Player")
			# It decelerates rather than stopping dead, so the check is that it
			# is settling, not that it froze.
			var drift := _resting_at.distance_to(player.global_position)
			expect(drift < 1.0, "releasing it brings the body to rest (%.2f m of drift)" % drift)
			expect(player.is_on_floor(), "and it is still standing on the floor")
			_report()

var _resting_at := Vector3.ZERO
