extends Node3D

# Demo driver. A glass sphere that reads the screen behind it, with the same
# arithmetic available on the CPU so the game can agree with the picture.

@onready var _glass: MeshInstance3D = $Glass
@onready var _second: MeshInstance3D = $SecondPane
@onready var _props: Node3D = $Props
@onready var _camera: Camera3D = $Camera3D
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

var _strength := 0.05
var _blur := 0.0
var _time := 0.0

func _ready() -> void:
	_hint.text = "1/2 refraction strength   3/4 roughness blur   Space pause the props   R defaults"
	_apply()

func _apply() -> void:
	for surface in [_glass, _second]:
		var material := surface.material_override as ShaderMaterial
		material.set_shader_parameter(&"strength", _strength)
		material.set_shader_parameter(&"roughness_blur", _blur)

func _process(delta: float) -> void:
	if not Input.is_key_pressed(KEY_SPACE):
		_time += delta
	for i in _props.get_child_count():
		var prop := _props.get_child(i) as Node3D
		prop.position.x = (-1.6 if i == 0 else 1.6) + sin(_time + float(i) * 2.0) * 1.2
		prop.rotate_y(delta)
	_show()

func _show() -> void:
	# The CPU side of the same maths: where a point directly behind the glass
	# appears to be, in pixels, given the surface normal facing the camera.
	var size: Vector2i = get_viewport().get_visible_rect().size
	var to_camera := (_camera.global_position - _glass.global_position).normalized()
	var edge_normal := to_camera.rotated(Vector3.UP, PI * 0.4)
	var moved := Refraction.apparent_position(Vector2(size) * 0.5, edge_normal, _strength, size)

	_readout.text = "strength %.3f   blur %.1f\nat the edge of the sphere, the screen is sampled %.0f px across and %.0f px down\nfresnel there: %.2f — face-on it is %.2f" % [
		_strength, _blur,
		moved.x - float(size.x) * 0.5, moved.y - float(size.y) * 0.5,
		Refraction.fresnel(to_camera, edge_normal),
		Refraction.fresnel(to_camera, to_camera)]

	# The limitation worth saying out loud: the second sphere is drawn after the
	# first, so the first cannot be in the screen texture it reads.
	var near_depth := _camera.global_position.distance_to(_glass.global_position)
	var far_depth := _camera.global_position.distance_to(_second.global_position)
	_status.text = "the near sphere %s refract the far one; the far one %s refract the near one" % [
		"can" if Refraction.can_refract(near_depth, far_depth) else "cannot",
		"can" if Refraction.can_refract(far_depth, near_depth) else "cannot"]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_strength = maxf(_strength - 0.01, 0.0)
		KEY_2:
			_strength = minf(_strength + 0.01, 0.2)
		KEY_3:
			_blur = maxf(_blur - 0.5, 0.0)
		KEY_4:
			_blur = minf(_blur + 0.5, 4.0)
		KEY_R:
			_strength = 0.05
			_blur = 0.0
		_:
			return
	_apply()
