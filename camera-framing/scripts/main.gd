extends Node3D

# Demo driver. Wanders a handful of pawns around and keeps the camera far enough
# back to hold all of them, from a fixed angle.

const ANGLE := Vector3(0.0, 0.55, 1.0)   ## the direction the camera sits in

@onready var _camera: Camera3D = $Camera3D
@onready var _pawns: Node3D = $Pawns
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _fit := FrameFit.new()
var _time := 0.0
var _spread := 1.0
var _moving := true

func _ready() -> void:
	_hint.text = "1/2 fewer or more pawns   3/4 spread them out   Space stop them moving"
	for i in 4:
		_add_pawn()

func _add_pawn() -> void:
	var pawn := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.6
	pawn.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(fmod(_pawns.get_child_count() * 0.17, 1.0), 0.6, 0.9)
	pawn.material_override = material
	_pawns.add_child(pawn)

func _process(delta: float) -> void:
	if _moving:
		_time += delta

	var points: Array[Vector3] = []
	for i in _pawns.get_child_count():
		var pawn := _pawns.get_child(i) as Node3D
		# Each wanders its own circle, so the group spreads and gathers.
		var phase := _time * (0.3 + i * 0.11) + i * 2.1
		var radius := (3.0 + i * 1.5) * _spread
		pawn.position = Vector3(cos(phase) * radius, 0.9, sin(phase * 1.3) * radius)
		points.append(pawn.position)

	var size: Vector2i = get_viewport().size
	var aspect := float(size.x) / maxf(float(size.y), 1.0)
	var result := _fit.update(points, _camera.fov, aspect, delta)
	var focus: Vector3 = result["focus"]
	var distance: float = result["distance"]

	# The fit says where to look and how far back; the direction is the demo's
	# own choice, which is the split that lets the same component drive an
	# overhead RTS camera and a side-on brawler.
	_camera.position = focus + ANGLE.normalized() * distance
	_camera.look_at(focus, Vector3.UP)

	_status.text = "%d pawns   radius %.1f m   distance %.1f m   focus (%.1f, %.1f)" % [
		points.size(), FrameFit.radius_of(points), distance, focus.x, focus.z]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			if _pawns.get_child_count() > 1:
				_pawns.get_child(_pawns.get_child_count() - 1).queue_free()
		KEY_2:
			if _pawns.get_child_count() < 8:
				_add_pawn()
		KEY_3: _spread = maxf(_spread - 0.25, 0.25)
		KEY_4: _spread = minf(_spread + 0.25, 3.0)
		KEY_SPACE: _moving = not _moving
		_: return
