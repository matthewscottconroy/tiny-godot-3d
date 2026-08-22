extends Node3D

# Demo driver. Reads a stick if one is plugged in, falls back to the arrow keys
# if not, and shows what the raw input became at every step.

const SPEED := 6.0
const CURVE := 1.6

@onready var _body: CharacterBody3D = $Player
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _pivot: Node3D = $CameraPivot
@onready var _raw_bar: ColorRect = $HUD/RawBar
@onready var _out_bar: ColorRect = $HUD/OutBar
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _camera_yaw := 0.0
var _rumbled := 0.0

func _ready() -> void:
	_hint.text = "Left stick moves   right stick turns the camera   A/cross rumbles   arrows work too"

func _physics_process(delta: float) -> void:
	var raw := _read_move_stick()
	var processed := StickInput.processed(raw, CURVE)

	# The right stick turns the camera, and movement is expressed relative to
	# where it ends up — the same rule as the orbit-camera demo, driven by an
	# analogue input instead of the mouse.
	var look := StickInput.processed(_read_look_stick(), 2.0)
	_camera_yaw -= look.x * 2.5 * delta
	_pivot.rotation.y = _camera_yaw

	var direction := StickInput.to_world(processed, _camera_yaw)
	_body.velocity = Vector3(direction.x * SPEED, 0.0, direction.z * SPEED)
	_body.move_and_slide()

	if direction.length() > 0.01:
		# Face the way we are going, which is where the analogue magnitude has
		# to be kept: a normalised direction loses "how fast".
		_body.look_at(_body.global_position - direction, Vector3.UP)

	_rumble(delta)
	_draw_bars(raw.length(), processed.length())

	var pad := StickInput.any_connected()
	_status.text = "%s   raw %.2f   processed %.2f   speed %.2f m/s" % [
		"gamepad connected" if pad else "no gamepad — using the arrow keys",
		raw.length(), processed.length(), _body.velocity.length()]

## The left stick, or the arrow keys when nothing is plugged in.
func _read_move_stick() -> Vector2:
	if StickInput.any_connected():
		var pad := Input.get_connected_joypads()[0]
		return Vector2(
			Input.get_joy_axis(pad, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	# Keys are all-or-nothing, so the deadzone has nothing to do — which is
	# exactly why a keyboard cannot show what any of this is for.
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

func _read_look_stick() -> Vector2:
	if not StickInput.any_connected():
		return Vector2.ZERO
	var pad := Input.get_connected_joypads()[0]
	return Vector2(
		Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))

func _rumble(delta: float) -> void:
	_rumbled = maxf(_rumbled - delta, 0.0)
	if not StickInput.any_connected():
		return
	var pad := Input.get_connected_joypads()[0]
	if Input.is_joy_button_pressed(pad, JOY_BUTTON_A) and _rumbled <= 0.0:
		# Weak and strong motors, then a duration. Rumble that never stops is
		# the reason to always pass one.
		Input.start_joy_vibration(pad, 0.4, 0.8, 0.25)
		_rumbled = 0.4

## Two bars: what the stick reported, and what the character got.
func _draw_bars(raw: float, processed: float) -> void:
	_raw_bar.size.x = raw * 240.0
	_out_bar.size.x = processed * 240.0
