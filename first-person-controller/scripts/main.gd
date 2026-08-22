extends Node3D

# Demo driver. Owns the body, the head and the mouse capture; the rig owns the
# angles and the bob.

const WALK_SPEED := 4.5
const GRAVITY := 18.0
const JUMP_VELOCITY := 5.5
const HEAD_HEIGHT := 1.6

@onready var _body: CharacterBody3D = $Player
@onready var _head: Node3D = $Player/Head
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _rig := FirstPersonRig.new()
var _captured := false

func _ready() -> void:
	_hint.text = "Click to capture the mouse   WASD to move   Space to jump   Escape to release"

func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_set_captured(true)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		_set_captured(false)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _captured:
		_rig.look(motion.relative)

func _set_captured(captured: bool) -> void:
	_captured = captured
	# Captured mode hides the cursor and reports relative motion without the
	# pointer ever reaching a screen edge — which is the reason a first-person
	# camera needs it rather than reading the cursor position.
	Input.mouse_mode = (Input.MOUSE_MODE_CAPTURED if captured
		else Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	# Yaw turns the body, pitch tilts only the head. Pitching the body would
	# tilt the collider and the movement basis with it.
	_body.rotation.y = _rig.yaw
	_head.rotation.x = _rig.pitch

	# Arrow keys come free with Godot's built-in ui_* actions; WASD has to be
	# bound by hand, because ui_* covers the arrows and nothing else.
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input.x += _axis(KEY_A, KEY_D)
	input.y += _axis(KEY_W, KEY_S)
	var direction := _rig.movement_direction(input.limit_length(1.0))

	var velocity := _body.velocity
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	if _body.is_on_floor():
		velocity.y = 0.0
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	_body.velocity = velocity
	_body.move_and_slide()

	# Bob is driven by distance actually covered, not by the input: walking into
	# a wall should not bob, and neither should being pushed.
	var travelled := Vector2(_body.velocity.x, _body.velocity.z).length() * delta
	if _body.is_on_floor():
		_rig.advance(travelled)
	_head.position = Vector3(0.0, HEAD_HEIGHT, 0.0) + _rig.head_offset()

	_status.text = "yaw %.2f   pitch %.2f   walked %.1f m   %s" % [
		_rig.yaw, _rig.pitch, _rig.travelled(),
		"mouse captured" if _captured else "click to capture"]

## -1 / 0 / +1 from two keys. `ui_*` covers the arrow keys only, so a demo that
## claims WASD has to bind those letters itself.
func _axis(negative: Key, positive: Key) -> float:
	return (1.0 if Input.is_key_pressed(positive) else 0.0) \
		- (1.0 if Input.is_key_pressed(negative) else 0.0)
