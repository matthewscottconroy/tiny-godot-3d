extends Node

# Drives the real Drivetrain from scripts/drivetrain.gd, and then drives the real
# VehicleBody3D — because a drivetrain that produces the right numbers and a car
# that will not move are two different kinds of working.
#
# mutate-driver: skip — the scene is instantiated to drive a real VehicleBody3D, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _start := Vector3.ZERO

func _ready() -> void:
	test_steering_at_a_standstill()
	test_steering_shrinks_with_speed()
	test_some_steering_always_remains()
	test_steering_is_symmetric()
	test_engine_force_falls_off()
	test_reverse_is_not_negative_throttle()
	test_braking_and_throttle_are_exclusive()
	test_forward_speed_is_signed()
	test_airborne()
	test_degenerate_settings()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[vehicle-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_steering_at_a_standstill() -> void:
	print("steering, stopped")
	var drive := Drivetrain.new()
	expect(is_equal_approx(drive.steering_for(1.0, 0.0), drive.max_steer),
		"parked, the wheels go to full lock")

func test_steering_shrinks_with_speed() -> void:
	print("steering, moving")
	var drive := Drivetrain.new()
	var parked := drive.steering_for(1.0, 0.0)
	var rolling := drive.steering_for(1.0, 12.0)
	var fast := drive.steering_for(1.0, 40.0)
	# Full lock at motorway speed is a spin. Every driving game shrinks the lock
	# with speed and none of them mention it.
	expect(rolling < parked, "at 12 m/s there is less lock available")
	expect(fast < rolling, "and at 40 m/s less again")
	expect(is_equal_approx(fast, drive.max_steer * drive.min_steer_fraction),
		"bottoming out at the fraction that was asked for")

func test_some_steering_always_remains() -> void:
	print("the floor")
	var drive := Drivetrain.new()
	# A car that cannot be steered at all above 30 m/s is worse than one that
	# spins: the player thinks the controls have stopped working.
	expect(drive.steering_for(1.0, 500.0) > 0.0,
		"there is still lock available at any speed")

func test_steering_is_symmetric() -> void:
	print("symmetry")
	var drive := Drivetrain.new()
	expect(is_equal_approx(drive.steering_for(-1.0, 15.0), -drive.steering_for(1.0, 15.0)),
		"left and right get the same lock")
	# Reversing is still moving: the lock should shrink going backwards too.
	expect(is_equal_approx(drive.steering_for(1.0, -20.0), drive.steering_for(1.0, 20.0)),
		"and reversing at 20 m/s steers like driving at 20 m/s")

func test_engine_force_falls_off() -> void:
	print("engine force")
	var drive := Drivetrain.new()
	expect(is_equal_approx(drive.engine_force_for(1.0, 0.0), drive.max_engine_force),
		"from a standstill, everything the engine has")
	expect(drive.engine_force_for(1.0, 20.0) < drive.max_engine_force,
		"less of it at half the top speed")
	expect(is_zero_approx(drive.engine_force_for(1.0, drive.top_speed)),
		"and nothing at the top speed, which is why there is one")
	expect(is_zero_approx(drive.engine_force_for(1.0, 100.0)),
		"— and none beyond it either, rather than a negative push")

func test_reverse_is_not_negative_throttle() -> void:
	print("reverse")
	var drive := Drivetrain.new()
	# Pulling back while rolling forward is the brake. It is only reverse once
	# the car has actually stopped, or it reverses out from under the player the
	# moment they tap the brake.
	expect(Drivetrain.is_braking(-1.0, 8.0), "back while rolling forward is braking")
	expect(not Drivetrain.is_braking(-1.0, 0.0), "back while stopped is reverse")
	expect(not Drivetrain.is_braking(-1.0, -5.0), "and back while already reversing is more reverse")
	expect(not Drivetrain.is_braking(1.0, 8.0), "forward is never braking")

func test_braking_and_throttle_are_exclusive() -> void:
	print("brake or throttle")
	var drive := Drivetrain.new()
	expect(drive.brake_for(-1.0, 8.0) > 0.0, "braking asks for brake force")
	expect(is_zero_approx(drive.throttle_for(-1.0, 8.0)),
		"and no throttle at the same time, because a car that does both has no brakes")
	expect(is_zero_approx(drive.brake_for(-1.0, 0.0)), "reversing is not braking")
	expect(drive.throttle_for(-1.0, 0.0) < 0.0, "it is throttle, backwards")
	expect(is_zero_approx(drive.brake_for(1.0, 8.0)), "and accelerating never brakes")

func test_forward_speed_is_signed() -> void:
	print("which way")
	var basis := Basis.IDENTITY
	# -Z is forward in Godot. `linear_velocity.length()` cannot tell forwards
	# from backwards, which is the one thing the reverse decision needs.
	expect(is_equal_approx(Drivetrain.forward_speed(Vector3(0, 0, -10), basis), 10.0),
		"moving down -Z is ten metres a second forwards")
	expect(is_equal_approx(Drivetrain.forward_speed(Vector3(0, 0, 10), basis), -10.0),
		"and the other way is ten backwards")
	expect(is_zero_approx(Drivetrain.forward_speed(Vector3(10, 0, 0), basis)),
		"sliding sideways is no speed at all, forwards")
	var turned := Basis(Vector3.UP, PI * 0.5)
	expect(is_equal_approx(Drivetrain.forward_speed(Vector3(-10, 0, 0), turned), 10.0),
		"and a car facing another way has its own idea of forwards")

func test_airborne() -> void:
	print("airborne")
	expect(not Drivetrain.airborne(4), "four wheels down is driving")
	expect(not Drivetrain.airborne(2), "two is a bumpy corner")
	expect(Drivetrain.airborne(1), "one is a jump")
	expect(Drivetrain.airborne(0), "and none is definitely a jump")

func test_degenerate_settings() -> void:
	print("degenerate settings")
	var drive := Drivetrain.new()
	drive.full_lock_speed = 0.0
	expect(not is_nan(drive.steering_for(1.0, 10.0)),
		"a zero full-lock speed does not divide by zero")
	drive.top_speed = 0.0
	expect(not is_nan(drive.engine_force_for(1.0, 10.0)),
		"and neither does a zero top speed")

# --- the real car ----------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real car")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			var car: VehicleBody3D = _scene.get_node("Car")
			_start = car.global_position
			# Through the demo's own input path rather than by poking
			# engine_force: main.gd rewrites that every tick, so anything set
			# behind its back lasts exactly no time at all.
			Input.action_press(&"ui_up")
		95:
			Input.action_release(&"ui_up")
			_check_car()
			_report()

func _check_car() -> void:
	var car: VehicleBody3D = _scene.get_node("Car")
	var travelled := _start.distance_to(car.global_position)
	var speed := Drivetrain.forward_speed(car.linear_velocity, car.global_transform.basis)

	expect(travelled > 1.0, "the car actually drove somewhere (%.1f m)" % travelled)
	# Forwards, signed. A positive engine_force pushes a VehicleBody3D toward
	# +Z — backwards by Godot's own convention — so this assertion is the one
	# that catches the missing negation in the driver.
	expect(speed > 1.0, "and is moving forwards under its own power (%.1f m/s)" % speed)

	# Suspension is the reason to use VehicleBody3D at all: the body rides above
	# the wheels rather than sitting on the ground.
	var wheels_down := 0
	for child in car.get_children():
		if child is VehicleWheel3D and (child as VehicleWheel3D).is_in_contact():
			wheels_down += 1
	expect(wheels_down >= 3, "with its wheels on the ground (%d of 4)" % wheels_down)
	expect(not Drivetrain.airborne(wheels_down), "so it is not airborne")
	expect(car.global_position.y > 0.2,
		"and the body rides above the ground on its suspension (%.2f m)" % car.global_position.y)

	# The car is a rigid body, which is the whole trade: it stays upright here,
	# and nothing in the engine guarantees that.
	expect(car.global_transform.basis.y.dot(Vector3.UP) > 0.8,
		"it is still the right way up, which is a rigid body's choice rather than a promise")
