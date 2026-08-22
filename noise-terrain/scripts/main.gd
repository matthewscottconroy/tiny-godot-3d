extends Node3D

# Demo driver. Rebuilds the terrain when a parameter changes, and drops a marker
# on the ground to show that height_at() and the mesh agree.

const SIZE := 40.0

@onready var _terrain: MeshInstance3D = $Terrain
@onready var _marker: MeshInstance3D = $Marker
@onready var _camera: Camera3D = $Camera3D
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _field := TerrainField.new(1)
var _resolution := 48
var _angle := 0.0
var _orbiting := true

func _ready() -> void:
	_hint.text = "1/2 resolution   3/4 amplitude   N new seed   Space pause the camera"
	_rebuild()

func _rebuild() -> void:
	_terrain.mesh = _field.build_mesh(SIZE, _resolution)
	var counts := TerrainField.counts(_resolution)
	_status.text = "seed %d   %d x %d cells   %d vertices   amplitude %.1f m" % [
		_field.seed_value(), _resolution, _resolution, counts["vertices"], _field.amplitude]

func _process(delta: float) -> void:
	if _orbiting:
		_angle += delta * 0.15
	_camera.position = Vector3(sin(_angle) * 34.0, 16.0, cos(_angle) * 34.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	# The marker walks a circle over the terrain, standing on the ground the
	# same height function built the mesh from. If the two ever disagree it
	# floats or sinks, visibly.
	var x := sin(_angle * 2.0) * 12.0
	var z := cos(_angle * 2.0) * 12.0
	_marker.position = Vector3(x, _field.height_at(x, z) + 0.4, z)
	# Standing upright on a slope looks wrong; leaning with the ground means
	# building a basis around the surface normal. Godot's Basis takes its three
	# axes in X, Y, Z order, and Y is the one being replaced here.
	var up := _field.normal_at(x, z)
	var back := (Vector3.BACK - up * Vector3.BACK.dot(up)).normalized()
	_marker.basis = Basis(up.cross(back), up, back)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _resolution = maxi(_resolution - 8, 8)
		KEY_2: _resolution = mini(_resolution + 8, 128)
		KEY_3: _field.amplitude = maxf(_field.amplitude - 0.5, 0.5)
		KEY_4: _field.amplitude = minf(_field.amplitude + 0.5, 8.0)
		KEY_N: _field.set_seed(_field.seed_value() + 1)
		KEY_SPACE:
			_orbiting = not _orbiting
			return
		_: return
	_rebuild()
