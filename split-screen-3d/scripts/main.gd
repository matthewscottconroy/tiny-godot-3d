extends Node3D

# Demo driver. Builds one SubViewport per player, all looking into the same
# World3D, and lays them out with ScreenLayout.

const BASE_FOV := 70.0
const SPEED := 4.0

@onready var _panes: Control = $UI/Panes
@onready var _world: Node3D = $World
@onready var _status: Label = $UI/StatusLabel
@onready var _hint: Label = $UI/TitleLabel

var _players := 2
var _split := ScreenLayout.Split.HORIZONTAL
var _views: Array[SubViewport] = []
var _cameras: Array[Camera3D] = []
var _pawns: Array[Node3D] = []
var _time := 0.0

func _ready() -> void:
	_hint.text = "1-4 players   S horizontal or vertical split   the panes share one world"
	_build()
	get_viewport().size_changed.connect(_layout)

func _build() -> void:
	for child in _panes.get_children():
		child.queue_free()
	for pawn in _pawns:
		pawn.queue_free()
	_views.clear()
	_cameras.clear()
	_pawns.clear()

	for i in _players:
		var container := SubViewportContainer.new()
		container.stretch = true
		_panes.add_child(container)

		var view := SubViewport.new()
		view.handle_input_locally = false
		# The line the whole demo exists for. A SubViewport makes its own empty
		# World3D unless told otherwise, so a second view of "the same scene"
		# renders a black rectangle — no error, no warning, nothing to search
		# for. Every pane has to be pointed at the world the level is in.
		view.world_3d = get_viewport().world_3d
		container.add_child(view)

		var camera := Camera3D.new()
		camera.fov = BASE_FOV
		# Each viewport needs its own current camera. `current` is per viewport,
		# not global, which is why this works at all.
		view.add_child(camera)
		camera.current = true

		var pawn := _make_pawn(i)
		_world.add_child(pawn)

		_views.append(view)
		_cameras.append(camera)
		_pawns.append(pawn)
	_layout()

func _make_pawn(index: int) -> Node3D:
	var pawn := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.6
	pawn.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(float(index) / 4.0, 0.6, 0.9)
	pawn.material_override = material
	pawn.position = Vector3(index * 3.0 - 4.5, 0.9, 0.0)
	return pawn

func _layout() -> void:
	var size: Vector2i = get_viewport().size
	var rects := ScreenLayout.rects(_players, size, _split)
	var base_aspect := float(size.x) / maxf(float(size.y), 1.0)
	for i in _views.size():
		var container := _panes.get_child(i) as Control
		container.position = rects[i].position
		container.size = rects[i].size
		# The container sizes its viewport: with `stretch` on, assigning the
		# SubViewport's own size as well is refused, with a warning.
		# Half a screen is not a small screen, it is a differently shaped one.
		# Widening the vertical angle keeps everyone seeing the same width.
		_cameras[i].fov = ScreenLayout.matched_fov(
			BASE_FOV, base_aspect, ScreenLayout.aspect_of(rects[i]))

func _process(delta: float) -> void:
	_time += delta
	for i in _pawns.size():
		# Each pawn wanders its own circle, so the panes never agree — which is
		# the point of a split screen.
		var phase := _time * (0.4 + i * 0.15) + i * 1.7
		_pawns[i].position = Vector3(cos(phase) * (3.0 + i), 0.9, sin(phase) * (3.0 + i))
		var camera := _cameras[i]
		camera.position = _pawns[i].position + Vector3(0, 3.0, 6.0)
		camera.look_at(_pawns[i].position, Vector3.UP)

	var first_fov := _cameras[0].fov if not _cameras.is_empty() else 0.0
	_status.text = "%d player(s)   %s split   pane %dx%d   fov %.0f°   one World3D, %d views" % [
		_players,
		"horizontal" if _split == ScreenLayout.Split.HORIZONTAL else "vertical",
		_views[0].size.x if not _views.is_empty() else 0,
		_views[0].size.y if not _views.is_empty() else 0,
		first_fov, _views.size()]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_players = key.keycode - KEY_1 + 1
			_build()
		KEY_S:
			_split = (ScreenLayout.Split.VERTICAL if _split == ScreenLayout.Split.HORIZONTAL
				else ScreenLayout.Split.HORIZONTAL)
			_layout()
		_: return
