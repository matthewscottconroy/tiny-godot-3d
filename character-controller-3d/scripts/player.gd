extends CharacterBody3D

# Applies CharacterMotor's output to a real body. The motor owns the rules; this
# owns the engine plumbing — which is the split that lets the rules be tested.

@onready var _motor := CharacterMotor.new()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Movement is relative to the body's own facing here; see the orbit-camera
	# demo for making it relative to the camera instead.
	var direction := Vector3(input.x, 0.0, input.y)
	direction = direction.normalized() if direction.length() > 0.001 else Vector3.ZERO

	velocity = _motor.step(
		direction,
		Input.is_key_pressed(KEY_SHIFT),
		Input.is_action_just_pressed("ui_accept"),
		is_on_floor(),
		delta)
	move_and_slide()

	# move_and_slide() resolves collisions, so the body's velocity is the truth
	# afterwards — feed it back or the motor keeps accelerating into a wall.
	_motor.velocity = velocity

func motor() -> CharacterMotor:
	return _motor
