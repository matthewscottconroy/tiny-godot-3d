extends Node

# Drives the real CharacterMotor from scripts/motor.gd.

var _pass := 0
var _fail := 0

func _ready() -> void:
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
	_report()

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
