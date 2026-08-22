extends Node3D

# Demo driver. Orbits a camera past a row of lights and lets the budget decide
# which of them are allowed to cast shadows.

const ORBIT_SPEED := 0.35
const ORBIT_RADIUS := 12.0
const ORBIT_HEIGHT := 5.0

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _lights: Node3D = $Lights
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _budget := ShadowBudget.new()
var _slots := 2
var _sticky := true
var _angle := 0.0
var _orbiting := true

func _ready() -> void:
	_hint.text = "1/2 shadow budget   S sticky slots   D sun shadows   Space pause the orbit"

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _slots = maxi(_slots - 1, 0)
		KEY_2: _slots = mini(_slots + 1, _lights.get_child_count())
		KEY_S:
			_sticky = not _sticky
			_budget.reset()
		KEY_D: _sun.shadow_enabled = not _sun.shadow_enabled
		KEY_SPACE: _orbiting = not _orbiting
		_: return

func _process(delta: float) -> void:
	if _orbiting:
		_angle += delta * ORBIT_SPEED
	_camera.position = Vector3(sin(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, cos(_angle) * ORBIT_RADIUS)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	var lights := _lights.get_children()
	var positions: Array[Vector3] = []
	for light in lights:
		positions.append((light as Light3D).global_position)

	# Sticky is the version you would ship; the stateless one is here to make
	# the flicker it prevents visible by turning it off.
	var flags := (_budget.update(positions, _camera.global_position, _slots) if _sticky
		else _budget.casters(positions, _camera.global_position, _slots))
	var casting := 0
	for i in lights.size():
		(lights[i] as Light3D).shadow_enabled = flags[i]
		if flags[i]:
			casting += 1

	_status.text = "%d lights   budget %d   casting %d   %s   sun shadows %s" % [
		lights.size(), _slots, casting,
		"sticky" if _sticky else "nearest-wins",
		"on" if _sun.shadow_enabled else "off"]
