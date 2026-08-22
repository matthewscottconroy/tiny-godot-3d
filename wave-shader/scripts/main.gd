extends Node3D

# Demo driver. Feeds one WaveField into both the shader that draws the water and
# the buoys that float on it.

@onready var _water: MeshInstance3D = $Water
@onready var _buoys: Node3D = $Buoys
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _field := WaveField.new()
var _material: ShaderMaterial
var _time := 0.0
var _running := true

func _ready() -> void:
	_hint.text = "1/2 swell   Space freeze   the buoys use the same maths as the shader"
	_material = _water.material_override as ShaderMaterial
	_field.apply_to(_material)

func _process(delta: float) -> void:
	if _running:
		_time += delta

	# The clock is a uniform, not the shader's built-in TIME. One clock, sent to
	# the GPU and used on the CPU, is what keeps the buoys on the water rather
	# than near it — and it is what lets the whole thing freeze.
	_material.set_shader_parameter("time", _time)

	for buoy in _buoys.get_children():
		var node := buoy as Node3D
		var x := node.position.x
		var z := node.position.z
		node.position.y = _field.height_at(x, z, _time)
		# Lean with the surface, the same way a real buoy does.
		var up := _field.normal_at(x, z, _time)
		var back := (Vector3.BACK - up * Vector3.BACK.dot(up)).normalized()
		node.basis = Basis(up.cross(back), up, back)

	_status.text = "%d waves   swell %.2f   crest %.2f m   t %.1fs   %s" % [
		_field.waves.size(), _field.swell, _field.crest_height(), _time,
		"running" if _running else "frozen"]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _field.swell = maxf(_field.swell - 0.25, 0.0)
		KEY_2: _field.swell = minf(_field.swell + 0.25, 3.0)
		KEY_SPACE:
			_running = not _running
			return
		_: return
	# Every change goes through the field, which then updates the shader. The
	# uniforms are never set anywhere else.
	_field.apply_to(_material)
