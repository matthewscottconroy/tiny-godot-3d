extends Node3D

# Demo driver. Builds a greybox level out of CSG boxes from a room plan, and
# bakes it to a mesh on request.

const HEIGHT := 3.0
const ROOMS: Array[Rect2] = [
	Rect2(-8, -6, 8, 7),
	Rect2(0, -6, 6, 7),
	Rect2(0, 1, 6, 6),
	Rect2(-8, 1, 8, 6),
]

@onready var _csg: CSGCombiner3D = $Level
@onready var _baked: MeshInstance3D = $Baked
@onready var _camera: Camera3D = $Camera3D
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _plan := RoomPlan.new()
var _angle := 0.0
var _orbiting := true
var _showing_baked := false
var _nodes := 0

func _ready() -> void:
	_hint.text = "1/2 door width   B bake to a mesh   Space pause the orbit"
	_build()

func _build() -> void:
	for child in _csg.get_children():
		child.queue_free()
	_nodes = 0

	# Each room is a solid block with a smaller block taken out of it. That is
	# the standard CSG way to make a hollow, and it is why the operation order
	# matters: the subtractions have to come after the thing they cut.
	for room in ROOMS:
		_add_box(_plan.shell_box(room, HEIGHT), RoomPlan.centre_of(room, HEIGHT * 0.5),
			CSGShape3D.OPERATION_UNION)
	for room in ROOMS:
		_add_box(_plan.hollow_box(room, HEIGHT - _plan.wall),
			RoomPlan.centre_of(room, HEIGHT * 0.5 + _plan.wall * 0.5),
			CSGShape3D.OPERATION_SUBTRACTION)

	# Doors come from the plan rather than from a list of positions: move a room
	# and the doorway follows it.
	for pair in RoomPlan.doorways(ROOMS):
		var a := ROOMS[pair.x]
		var b := ROOMS[pair.y]
		var at = RoomPlan.door_between(a, b)
		if at == null:
			continue
		var horizontal := RoomPlan.door_is_horizontal(a, b)
		_add_box(_plan.door_box(horizontal),
			Vector3((at as Vector2).x, _plan.door_height * 0.5, (at as Vector2).y),
			CSGShape3D.OPERATION_SUBTRACTION)

	_showing_baked = false
	_baked.visible = false
	_csg.visible = true

func _add_box(size: Vector3, position: Vector3, operation: int) -> void:
	var box := CSGBox3D.new()
	box.size = size
	box.position = position
	box.operation = operation
	_csg.add_child(box)
	_nodes += 1

## The other half of the workflow: greybox with CSG, then bake.
##
## CSG is re-evaluated whenever anything in the tree changes, which is fine while
## you are dragging boxes around and wasteful for a level that has stopped
## changing.
func _bake() -> void:
	var mesh := _csg.bake_static_mesh()
	_baked.mesh = mesh
	_showing_baked = mesh != null
	_baked.visible = _showing_baked
	_csg.visible = not _showing_baked

func _process(delta: float) -> void:
	if _orbiting:
		_angle += delta * 0.25
	_camera.position = Vector3(sin(_angle) * 22.0, 16.0, cos(_angle) * 22.0)
	_camera.look_at(Vector3(-1, 0, -1), Vector3.UP)

	var faces := 0
	if _baked.mesh != null:
		faces = _baked.mesh.get_faces().size() / 3
	_status.text = "%d rooms   %d doorways   %d CSG nodes   %s%s" % [
		ROOMS.size(), RoomPlan.doorways(ROOMS).size(), _nodes,
		"showing the baked mesh" if _showing_baked else "showing live CSG",
		"   (%d triangles)" % faces if faces > 0 else ""]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_plan.door_width = maxf(_plan.door_width - 0.2, 0.6)
			_build()
		KEY_2:
			_plan.door_width = minf(_plan.door_width + 0.2, 3.0)
			_build()
		KEY_B: _bake()
		KEY_SPACE: _orbiting = not _orbiting
		_: return
