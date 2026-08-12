extends Node3D

# Demo driver. Drives the real OrbitRig and applies its result to a Camera3D.

@onready var _camera: Camera3D = $Camera3D
@onready var _target: Node3D = $Target
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/HintLabel

var _rig := OrbitRig.new()
var _captured := false

func _ready() -> void:
	_hint.text = "Hold right mouse to orbit   scroll to zoom   arrows move the target"
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_captured = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _captured else Input.MOUSE_MODE_VISIBLE
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rig.zoom(-0.5)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rig.zoom(0.5)
	elif event is InputEventMouseMotion and _captured:
		_rig.look((event as InputEventMouseMotion).relative)

func _process(delta: float) -> void:
	# Movement is camera-relative: "forward" means away from the camera, which
	# is what the rig's flattened ground basis provides.
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_target.position += _rig.movement_direction(input) * 4.0 * delta
	_apply()

func _apply() -> void:
	_camera.position = _rig.position_for(_target.position)
	_camera.look_at(_target.position, Vector3.UP)
	_status.text = "yaw %.2f   pitch %.2f   distance %.1f" % [_rig.yaw, _rig.pitch, _rig.distance]
