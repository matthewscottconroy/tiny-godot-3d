extends Node3D

# Demo driver. Reads the keys, asks Drivetrain what the car should be doing, and
# puts it on the wheels. Every number on screen comes from the component, so the
# readout and the car cannot disagree.

@onready var _car: VehicleBody3D = $Car
@onready var _chase: Node3D = $Chase
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

var _drive := Drivetrain.new()
var _wheels: Array[VehicleWheel3D] = []
var _assist := true

func _ready() -> void:
	_hint.text = "W/S throttle and brake   A/D steer   Space handbrake   T speed-sensitive steering   R reset"
	for child in _car.get_children():
		if child is VehicleWheel3D:
			_wheels.append(child as VehicleWheel3D)

func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis(&"ui_down", &"ui_up")
	var steer_input := Input.get_axis(&"ui_right", &"ui_left")
	var speed := Drivetrain.forward_speed(_car.linear_velocity, _car.global_transform.basis)

	# Everything the car is told comes from here. The component decides whether
	# backwards means brake or reverse, so no part of the driver has to.
	# Negated, and this is the one line that will cost you an afternoon: a
	# positive `engine_force` pushes a VehicleBody3D toward **+Z**, which is
	# backwards from -Z-is-forward that every other Node3D uses. Press W without
	# this and the car reverses away from the camera.
	_car.engine_force = -_drive.engine_force_for(_drive.throttle_for(throttle, speed), speed)
	_car.brake = _drive.brake_for(throttle, speed)
	if Input.is_key_pressed(KEY_SPACE):
		_car.brake = _drive.max_brake
		_car.engine_force = 0.0
	_car.steering = _drive.steering_for(steer_input, speed) if _assist \
		else clampf(steer_input, -1.0, 1.0) * _drive.max_steer

	_follow(delta)
	_show(speed, steer_input)

func _follow(delta: float) -> void:
	var wanted := _car.global_position
	_chase.global_position = _chase.global_position.lerp(wanted, 1.0 - exp(-6.0 * delta))
	_chase.rotation.y = lerp_angle(_chase.rotation.y, _car.rotation.y, 1.0 - exp(-3.0 * delta))

func _show(speed: float, steer_input: float) -> void:
	var grounded := _wheels_on_ground()
	var full_lock := absf(steer_input) * _drive.max_steer
	_readout.text = "speed %5.1f m/s (%3.0f km/h)\nsteering %.3f rad of a possible %.3f — %.0f%% of full lock\nwheels on the ground %d of %d%s" % [
		speed, speed * 3.6, absf(_car.steering), full_lock,
		100.0 if full_lock <= 0.0001 else absf(_car.steering) / full_lock * 100.0,
		grounded, _wheels.size(),
		"   AIRBORNE — steering does nothing but tip it over" \
			if Drivetrain.airborne(grounded) else ""]
	_status.text = "engine %6.1f   brake %5.2f   %s   speed-sensitive steering %s" % [
		_car.engine_force, _car.brake,
		"braking" if _car.brake > 0.0 else "driving",
		"on" if _assist else "off"]

func _wheels_on_ground() -> int:
	var count := 0
	for wheel in _wheels:
		if wheel.is_in_contact():
			count += 1
	return count

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_T:
			_assist = not _assist
		KEY_R:
			# A rigid body that has flipped over stays flipped over. This is the
			# reset every driving game needs and the clearest argument against
			# VehicleBody3D for anything that is not about driving.
			_car.linear_velocity = Vector3.ZERO
			_car.angular_velocity = Vector3.ZERO
			_car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0))
		_:
			return
