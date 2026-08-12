extends Node3D

# Demo driver. Rebuilds the mesh from MeshBuilder whenever the parameters
# change, so the effect of subdivision and the height function is visible.

@onready var _grid: MeshInstance3D = $Grid
@onready var _ring: MeshInstance3D = $Ring
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/HintLabel

var _subdivisions := 12
var _wavy := true
var _spin := 0.0

func _ready() -> void:
	_hint.text = "1/2 subdivisions   H toggle height function   (wireframe: View > Display Overdraw in the editor)"
	_rebuild()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _subdivisions = maxi(_subdivisions - 2, 1)
		KEY_2: _subdivisions = mini(_subdivisions + 2, 48)
		KEY_H: _wavy = not _wavy
		_: return
	_rebuild()

func _process(delta: float) -> void:
	_spin += delta * 0.4
	_ring.rotation.y = _spin

func _rebuild() -> void:
	var height := Callable()
	if _wavy:
		height = func(x: float, z: float) -> float:
			return sin(x * 0.6) * 0.5 + cos(z * 0.5) * 0.4
	_grid.mesh = MeshBuilder.grid(10.0, _subdivisions, height)
	_ring.mesh = MeshBuilder.ring(1.6, 0.5, 24)

	var counts := MeshBuilder.grid_counts(_subdivisions)
	_status.text = "subdivisions %d    vertices %d    indices %d    height %s" % [
		_subdivisions, counts["vertices"], counts["indices"], "on" if _wavy else "off"]
