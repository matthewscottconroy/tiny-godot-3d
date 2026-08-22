extends Node3D

# Demo driver. A door in a corridor, and the two entirely different ways an
# obstacle can affect what walks past it. The footprint arithmetic is in
# scripts/carving.gd.

@onready var _region: NavigationRegion3D = $Region
@onready var _door: Node3D = $Region/Door
@onready var _obstacle: NavigationObstacle3D = $Region/Door/Obstacle
@onready var _agent: Node3D = $Agent
@onready var _nav: NavigationAgent3D = $Agent/Nav
@onready var _path_view: MeshInstance3D = $Path
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

const DOOR_SIZE := Vector3(4, 2.2, 0.4)
const FROM := Vector3(0, 0, 7)
const TO := Vector3(0, 0, -7)

var _shut := true
var _avoidance := false
var _stale := false
var _path := PackedVector3Array()
var _pushed := 0.0
var _repath_in := 0

func _ready() -> void:
	_hint.text = "Space open/shut the door   R re-bake   A carve or avoidance   G reset the walker"
	_nav.velocity_computed.connect(_on_velocity_computed)
	_apply_door()
	_rebake()

func _apply_door() -> void:
	# Setting the outline is not the same as changing the mesh. Nothing here
	# affects a single path until the region is baked again — which is the whole
	# point of the R key.
	_obstacle.vertices = Carving.box_footprint(DOOR_SIZE, 0.5) if _shut \
		else PackedVector3Array()
	_obstacle.radius = Carving.avoidance_radius(DOOR_SIZE, 0.5) if _shut else 0.0
	_obstacle.carve_navigation_mesh = not _avoidance
	_obstacle.affect_navigation_mesh = not _avoidance
	_obstacle.avoidance_enabled = _avoidance
	_door.visible = _shut
	_stale = true
	_show()

func _rebake() -> void:
	# `false` is not a detail. Baking is threaded by default, so the mesh you
	# read back on the next line is the one from before; this cost three
	# confused probe runs before it was noticed.
	_region.bake_navigation_mesh(false)
	_region.navigation_mesh = _region.navigation_mesh
	_stale = false
	# And the path is asked for two frames later, not now. A re-baked region
	# reaches the navigation map on a later sync, so a path queried in the same
	# frame is found on the *old* mesh — even after map_force_update(). It looks
	# exactly like the bake having done nothing.
	_repath_in = 2

func _repath() -> void:
	NavigationServer3D.map_force_update(get_world_3d().navigation_map)
	_path = NavigationServer3D.map_get_path(
		get_world_3d().navigation_map, FROM, TO, true)
	_nav.target_position = TO
	_draw_path()
	_show()

func _draw_path() -> void:
	var mesh := ImmediateMesh.new()
	if _path.size() >= 2:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in _path:
			mesh.surface_add_vertex(point + Vector3.UP * 0.15)
		mesh.surface_end()
	_path_view.mesh = mesh

func _show() -> void:
	_readout.text = "door %s   mode %s\npath %d points, %.1f m, swinging %.1f m off the straight line%s" % [
		"shut" if _shut else "open",
		"avoidance (the mesh is untouched)" if _avoidance else "carve (needs a re-bake)",
		_path.size(), path_length(), path_swing(),
		"\nthe mesh is stale — press R to bake it" if _stale else ""]
	_status.text = "footprint %.1f m²   avoidance radius %.2f m   walker pushed %.2f m off the line" % [
		Carving.area(_obstacle.vertices), _obstacle.radius, _pushed]

func path_length() -> float:
	var total := 0.0
	for i in range(1, _path.size()):
		total += _path[i].distance_to(_path[i - 1])
	return total

## How far the path leaves the straight line — the visible proof it rerouted.
func path_swing() -> float:
	var widest := 0.0
	for point in _path:
		widest = maxf(widest, absf(point.x))
	return widest

func _physics_process(delta: float) -> void:
	if _repath_in > 0:
		_repath_in -= 1
		if _repath_in == 0:
			_repath()
	if _nav.is_navigation_finished():
		return
	var wanted := _agent.global_position.direction_to(_nav.get_next_path_position()) * 3.0
	# With avoidance on, this velocity is a *request*: the server answers through
	# velocity_computed with one that does not walk into the obstacle.
	_nav.set_velocity(wanted)
	if not _avoidance:
		_move(wanted, delta)

func _on_velocity_computed(safe: Vector3) -> void:
	_move(safe, get_physics_process_delta_time())

func _move(velocity: Vector3, delta: float) -> void:
	_agent.global_position += velocity * delta
	_pushed = maxf(_pushed, absf(_agent.global_position.x))
	_show()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_shut = not _shut
			_apply_door()
		KEY_R:
			_rebake()
		KEY_A:
			_avoidance = not _avoidance
			_apply_door()
			_rebake()
		KEY_G:
			_agent.global_position = FROM + Vector3.UP * 0.4
			_pushed = 0.0
			_repath()
		_:
			return
