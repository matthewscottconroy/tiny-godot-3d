extends Node3D

# Demo driver. Walks a marker across an endless grid, building chunks as it
# arrives and freeing them behind it.

const CHUNK_SIZE := 16.0

@onready var _player: Node3D = $Player
@onready var _chunks: Node3D = $Chunks
@onready var _camera: Camera3D = $Camera3D
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _grid := ChunkGrid.new()
var _loaded := {}          ## Vector2i -> Node3D
var _time := 0.0
var _moving := true
var _built := 0
var _freed := 0

func _ready() -> void:
	_hint.text = "1/2 load radius   3/4 keep radius   Space stop moving   watch the built/freed counts"
	_grid.chunk_size = CHUNK_SIZE
	_update_chunks()

func _process(delta: float) -> void:
	if _moving:
		_time += delta
	# A long wander, so the player crosses boundaries in both axes.
	_player.position = Vector3(sin(_time * 0.25) * 60.0, 0.6, cos(_time * 0.17) * 45.0)
	_camera.position = _player.position + Vector3(0, 34, 26)
	_camera.look_at(_player.position, Vector3.UP)

	_update_chunks()

	var centre := ChunkGrid.chunk_of(_player.position, CHUNK_SIZE)
	_status.text = "chunk (%d, %d)   %d loaded   load %d / keep %d   %d built, %d freed" % [
		centre.x, centre.y, _loaded.size(), _grid.load_radius, _grid.keep_radius,
		_built, _freed]

func _update_chunks() -> void:
	var loaded_keys: Array[Vector2i] = []
	for key in _loaded:
		loaded_keys.append(key)
	var plan := _grid.plan(_player.position, loaded_keys)

	# Nearest first, and only a couple per frame: a streaming system that builds
	# everything the moment it is asked has moved the stall rather than removed
	# it. See threaded-loading for doing the same thing off the main thread.
	var budget := 2
	for chunk in plan["load"]:
		if budget <= 0:
			break
		budget -= 1
		_loaded[chunk] = _build_chunk(chunk)
		_built += 1

	for chunk in plan["free"]:
		if _loaded.has(chunk):
			(_loaded[chunk] as Node).queue_free()
			_loaded.erase(chunk)
			_freed += 1

## One chunk's worth of scenery, built from its coordinates.
##
## Generated rather than loaded, so the same chunk always looks the same however
## many times it is streamed in — the property a streaming system needs and a
## random one does not have.
func _build_chunk(chunk: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.position = ChunkGrid.origin_of(chunk, CHUNK_SIZE)
	_chunks.add_child(root)

	var ground := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CHUNK_SIZE - 0.4, 0.4, CHUNK_SIZE - 0.4)
	ground.mesh = mesh
	ground.position = Vector3(CHUNK_SIZE * 0.5, 0.0, CHUNK_SIZE * 0.5)
	var material := StandardMaterial3D.new()
	var shade := 0.28 + float((absi(chunk.x) + absi(chunk.y)) % 3) * 0.06
	material.albedo_color = Color(shade, shade * 1.08, shade * 0.95)
	ground.material_override = material
	root.add_child(ground)

	var rng := RandomNumberGenerator.new()
	# Seeded from the coordinates: the same chunk is the same every time it is
	# built, which is what makes streaming invisible.
	rng.seed = hash(chunk)
	for i in 3:
		var prop := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, rng.randf_range(1.0, 3.0), 1.0)
		prop.mesh = box
		prop.position = Vector3(rng.randf_range(2.0, CHUNK_SIZE - 2.0), box.size.y * 0.5,
			rng.randf_range(2.0, CHUNK_SIZE - 2.0))
		root.add_child(prop)
	return root

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _grid.load_radius = maxi(_grid.load_radius - 1, 0)
		KEY_2: _grid.load_radius = mini(_grid.load_radius + 1, 5)
		KEY_3: _grid.keep_radius = maxi(_grid.keep_radius - 1, _grid.load_radius)
		KEY_4: _grid.keep_radius = mini(_grid.keep_radius + 1, 7)
		KEY_SPACE: _moving = not _moving
		_: return
