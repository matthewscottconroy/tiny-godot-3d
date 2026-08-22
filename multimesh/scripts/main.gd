extends Node3D

# Demo driver. Fills a MultiMesh with a scattered field and culls it by distance
# with a single integer per frame.

const CULL_STEP := 8.0

@onready var _instances: MultiMeshInstance3D = $Instances
@onready var _camera: Camera3D = $Camera3D
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _field := ScatterField.new(1)
var _sorted: Array[Transform3D] = []
var _wanted := 4000
var _radius := 40.0
var _angle := 0.0
var _orbiting := true
var _culling := true

func _ready() -> void:
	_hint.text = "1/2 instances   3/4 cull radius   C culling on/off   N new seed   Space pause"
	_rebuild()

func _rebuild() -> void:
	# Sorted once, here. The per-frame cost of the cull is then one comparison
	# per instance at worst, and usually far less because the list is ordered.
	_sorted = ScatterField.sorted_by_distance(_field.transforms(_wanted), Vector3.ZERO)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _instances.multimesh.mesh
	multimesh.instance_count = _sorted.size()
	for i in _sorted.size():
		multimesh.set_instance_transform(i, _sorted[i])
	_instances.multimesh = multimesh

func _process(delta: float) -> void:
	if _orbiting:
		_angle += delta * 0.12
	_camera.position = Vector3(sin(_angle) * 34.0, 14.0, cos(_angle) * 34.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	# The instances are sorted around the origin rather than around the camera,
	# which is what a static field of scenery wants: the sort is done once and
	# the cull is measured from the middle of the field.
	var visible_count := _sorted.size()
	if _culling:
		visible_count = ScatterField.visible_within(_sorted, Vector3.ZERO, _radius)
	# One assignment. No nodes created, freed, hidden or shown.
	_instances.multimesh.visible_instance_count = visible_count

	_status.text = "%d instances   drawing %d   radius %.0f m   culling %s   one draw call" % [
		_sorted.size(), visible_count, _radius, "on" if _culling else "off"]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_wanted = maxi(_wanted - 1000, 500)
			_rebuild()
		KEY_2:
			_wanted = mini(_wanted + 1000, _field.capacity())
			_rebuild()
		KEY_3: _radius = maxf(_radius - CULL_STEP, CULL_STEP)
		KEY_4: _radius += CULL_STEP
		KEY_C: _culling = not _culling
		KEY_N:
			_field.set_seed(_field.seed_value() + 1)
			_rebuild()
		KEY_SPACE: _orbiting = not _orbiting
		_: return
