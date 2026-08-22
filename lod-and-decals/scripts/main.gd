extends Node3D

# Demo driver. A row of props, each with three meshes whose visibility ranges
# come from the same bands that drive the decal fade and the update rate.

const PROPS := 8
const SPACING := 9.0

@onready var _props: Node3D = $Props
@onready var _decal: Decal = $Decal
@onready var _camera: Camera3D = $Camera3D
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _bands := LodBands.new()
var _levels: Array[int] = []
var _distance := 10.0
var _moving := true
var _time := 0.0

func _ready() -> void:
	_hint.text = "1/2 move the camera   3/4 hysteresis   Space stop moving   watch the level column"
	_build_props()
	_apply_ranges()

## Three meshes per prop, one per level, all present at once.
##
## The engine hides and shows them by distance — there is no per-frame code for
## the switch, which is the point of visibility ranges.
func _build_props() -> void:
	var meshes := [_sphere(24, 0.6), _sphere(8, 0.6), _sphere(4, 0.6)]
	var colours := [Color(0.4, 0.8, 0.5), Color(0.9, 0.75, 0.3), Color(0.85, 0.4, 0.35)]
	for i in PROPS:
		var prop := Node3D.new()
		prop.position = Vector3(0, 0.8, -float(i) * SPACING)
		_props.add_child(prop)
		for level in 3:
			var view := MeshInstance3D.new()
			view.mesh = meshes[level]
			var material := StandardMaterial3D.new()
			material.albedo_color = colours[level]
			view.material_override = material
			prop.add_child(view)
		_levels.append(0)

func _sphere(segments: int, radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 2)
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh

## Push the bands into every prop's meshes.
##
## `visibility_range_begin` and `_end` are what Godot switches on, and the fade
## mode is what stops the switch being a pop.
func _apply_ranges() -> void:
	var ranges := _bands.ranges()
	for prop in _props.get_children():
		for level in prop.get_child_count():
			var view := prop.get_child(level) as GeometryInstance3D
			var band: Vector2 = ranges[mini(level, ranges.size() - 1)]
			view.visibility_range_begin = band.x
			view.visibility_range_end = band.y
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# The decal fades rather than vanishing: the eye notices a thing disappearing
	# far more than it notices one becoming faint.
	_decal.distance_fade_begin = _bands.distances[0]
	_decal.distance_fade_length = maxf(_bands.distances[1] - _bands.distances[0], 1.0)

func _process(delta: float) -> void:
	if _moving:
		_time += delta
		_distance = 10.0 + (sin(_time * 0.3) * 0.5 + 0.5) * 60.0
	_camera.position = Vector3(0, 2.5, _distance)

	# The same bands, used for something the engine does not do: how often each
	# prop would be updated if it had any thinking to do.
	var changed := 0
	var line := ""
	for i in _props.get_child_count():
		var prop := _props.get_child(i) as Node3D
		var distance := _camera.global_position.distance_to(prop.global_position)
		var level := _bands.stable_level_for(distance, _levels[i])
		if level != _levels[i]:
			changed += 1
			_levels[i] = level
		line += str(level)

	_status.text = "camera %.0f m   levels %s   hysteresis %.1f m   %d change(s) this frame" % [
		_distance, line, _bands.hysteresis, changed]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _distance = maxf(_distance - 4.0, 2.0)
		KEY_2: _distance = minf(_distance + 4.0, 90.0)
		KEY_3: _bands.hysteresis = maxf(_bands.hysteresis - 0.5, 0.0)
		KEY_4: _bands.hysteresis = minf(_bands.hysteresis + 0.5, 8.0)
		KEY_SPACE: _moving = not _moving
		_: return
