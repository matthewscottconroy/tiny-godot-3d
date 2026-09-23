extends Node3D

# Demo driver. Builds a ridge with genuinely steep sides, textures it with
# scripts/../shaders/triplanar.gdshader, and lets you switch between the
# terrain's own UVs and a triplanar projection to see what each does to a cliff.
#
# The ridge is generated rather than modelled so the demo ships no assets, and
# its UVs are derived from world X and Z — the ordinary way to texture a
# heightmap, and exactly the choice that smears on a vertical face.

const SIZE := 12.0
const RESOLUTION := 48
const RIDGE_HEIGHT := 3.0

@onready var _camera: Camera3D = $Camera3D
@onready var _terrain: MeshInstance3D = $Terrain
@onready var _probe: MeshInstance3D = $Probe
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _material := ShaderMaterial.new()
var _triplanar := true
var _scale := 0.6
var _sharpness := 4.0
var _probe_x := 0.0

func _ready() -> void:
	_hint.text = "Space flat UV or triplanar   1/2 texture scale   3/4 blend sharpness   arrows move the probe   R reset"
	_material.shader = load("res://shaders/triplanar.gdshader")
	_terrain.mesh = _build_ridge()
	_terrain.material_override = _material

	# Framed from above and off to the +X side, in code rather than as a
	# transform in the scene, so it stays pointed at the ridge if RIDGE_HEIGHT
	# changes. The ridge runs along Z, so its cliff faces look down X and this is
	# the side they are visible from. Far enough out to keep the flat ground in
	# shot too: the comparison is between the two, and a view of the cliff alone
	# shows only half of it.
	_camera.position = Vector3(10.0, RIDGE_HEIGHT + 6.0, 8.0)
	_camera.look_at(Vector3(0.0, RIDGE_HEIGHT * 0.4, 0.0))

	_apply()

## A ridge: flat ground either side, a steep rise in the middle.
##
## `smoothstep` across a narrow band is what makes the sides steep enough to
## matter — a gentle hill stretches a top-down UV by a few percent and teaches
## nothing. UVs come from X and Z, which is the habit this demo is about.
func _build_ridge() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / float(RESOLUTION)
	var half := SIZE * 0.5

	for z in RESOLUTION + 1:
		for x in RESOLUTION + 1:
			var px := -half + x * step
			var pz := -half + z * step
			surface.set_uv(Vector2(float(x), float(z)) / float(RESOLUTION))
			surface.add_vertex(Vector3(px, _height_at(px, pz), pz))

	var row := RESOLUTION + 1
	for z in RESOLUTION:
		for x in RESOLUTION:
			var i := z * row + x
			# Counter-clockwise seen from above, so the surface faces the sky.
			# Reversed, the terrain is backface-culled and reads as a mesh that
			# did not load — see procedural-mesh, which makes the same point.
			surface.add_index(i)
			surface.add_index(i + 1)
			surface.add_index(i + row)

			surface.add_index(i + 1)
			surface.add_index(i + row + 1)
			surface.add_index(i + row)

	surface.generate_normals()
	return surface.commit()

func _height_at(x: float, z: float) -> float:
	# Steep across X, gently rolling along Z so the ridge is not a flat extrusion.
	var across := smoothstep(1.7, 2.5, absf(x))
	return RIDGE_HEIGHT * (1.0 - across) + sin(z * 0.6) * 0.25 * across

## The surface normal at a point, sampled the same way the mesh was built.
func _normal_at(x: float, z: float) -> Vector3:
	var d := 0.15
	var dx := _height_at(x + d, z) - _height_at(x - d, z)
	var dz := _height_at(x, z + d) - _height_at(x, z - d)
	return Vector3(-dx, 2.0 * d, -dz).normalized()

func _apply() -> void:
	_material.set_shader_parameter("use_triplanar", _triplanar)
	_material.set_shader_parameter("texture_scale", _scale)
	_material.set_shader_parameter("sharpness", _sharpness)
	_show()

func _show() -> void:
	var normal := _normal_at(_probe_x, 0.0)
	_probe.position = Vector3(_probe_x, _height_at(_probe_x, 0.0) + 0.35, 0.0)

	var weights := Triplanar.weights(normal, _sharpness)
	var stretch := Triplanar.stretch_factor(normal)
	var axis_names := ["X", "Y", "Z"]

	_status.text = "%s   scale %.2f   sharpness %.1f\nprobe x %.1f   slope normal (%.2f, %.2f, %.2f)   dominant %s   weights %.2f/%.2f/%.2f\na flat UV stretches the texture %.1fx here — %s" % [
		"triplanar (3 samples)" if _triplanar else "flat UV (1 sample)",
		_scale, _sharpness, _probe_x,
		normal.x, normal.y, normal.z,
		axis_names[Triplanar.dominant_axis(normal)],
		weights.x, weights.y, weights.z,
		stretch,
		"worth the extra samples" if Triplanar.needs_triplanar(normal) else "a flat UV is fine"]

func _process(_delta: float) -> void:
	var move := Input.get_axis(&"ui_left", &"ui_right")
	if not is_zero_approx(move):
		_probe_x = clampf(_probe_x + move * 0.06, -6.0, 6.0)
		_show()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: _triplanar = not _triplanar
		KEY_1: _scale = maxf(_scale - 0.05, 0.05)
		KEY_2: _scale = minf(_scale + 0.05, 2.0)
		KEY_3: _sharpness = maxf(_sharpness - 1.0, 1.0)
		KEY_4: _sharpness = minf(_sharpness + 1.0, 16.0)
		KEY_R:
			_triplanar = true
			_scale = 0.6
			_sharpness = 4.0
			_probe_x = 0.0
		_: return
	_apply()
