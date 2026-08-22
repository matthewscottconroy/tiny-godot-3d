extends Node3D

# Demo driver. Bakes the navigation mesh at startup, then walks an agent round a
# route, drawing the path it is currently following.

const SPEED := 3.5
const WAYPOINTS: Array[Vector3] = [
	Vector3(8.0, 0.0, 8.0),
	Vector3(-8.0, 0.0, 8.0),
	Vector3(-8.0, 0.0, -8.0),
	Vector3(8.0, 0.0, -8.0),
]

@onready var _region: NavigationRegion3D = $NavigationRegion3D
@onready var _body: CharacterBody3D = $Agent
@onready var _agent: NavigationAgent3D = $Agent/NavigationAgent3D
@onready var _line: MeshInstance3D = $PathLine
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _route := RouteFollower.new(WAYPOINTS)
var _path_mesh := ImmediateMesh.new()
var _running := true

func _ready() -> void:
	_hint.text = "Space pause   R restart the route   B rebake the navigation mesh"
	_line.mesh = _path_mesh
	_place_markers()
	_bake()
	# The navigation map is synchronised at the end of a physics frame, so a
	# path requested during _ready comes back empty. Waiting one frame is the
	# whole fix, and skipping it is the most common navigation complaint there
	# is.
	await get_tree().physics_frame
	_agent.target_position = _route.current()

func _bake() -> void:
	# Baking at runtime parses collision shapes, not visual meshes — the mesh
	# path is editor-only. A region whose obstacles have no collider bakes a
	# navigation mesh straight over them, and the agent walks through walls.
	#
	# `false` bakes on this thread. The level is small, and the result is wanted
	# now; the threaded default needs `await _region.bake_finished` before the
	# mesh is worth looking at.
	_region.bake_navigation_mesh(false)

	# The part that is not in the tutorials. Baking fills the NavigationMesh
	# resource in place, and the region only hands its mesh to the navigation
	# server when the property is *assigned*. Skip this line and everything
	# looks right — polygons in the resource, the region on the map, no errors —
	# while every path query comes back empty and the agent stands still.
	_region.navigation_mesh = _region.navigation_mesh

func _place_markers() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 0.1
	for point in WAYPOINTS:
		var marker := MeshInstance3D.new()
		marker.mesh = mesh
		marker.position = point + Vector3.UP * 0.05
		add_child(marker)

func _physics_process(delta: float) -> void:
	if not _running or _route.finished():
		return

	# A path can come back empty, and the usual reason is that it was asked for
	# before the navigation map finished synchronising — which happens on the
	# first frame, after a re-bake, and any time the region changes. Asking
	# again when the path is empty is the fix. Assigning target_position every
	# frame regardless is not: that re-paths constantly, which is both slow and
	# jittery.
	if _agent.get_current_navigation_path().is_empty():
		_agent.target_position = _route.current()

	# The agent hands back the next corner of the path, not the destination.
	# Steering straight at the destination is what walks an agent into a wall.
	var next := _agent.get_next_path_position()
	var to := next - _body.global_position
	to.y = 0.0
	var direction := to.normalized() if to.length() > 0.001 else Vector3.ZERO

	_body.velocity = direction * SPEED
	_body.move_and_slide()

	if _route.update(_body.global_position):
		_agent.target_position = _route.current()

	_draw_path()
	_status.text = "waypoint %d of %d   %d lap(s)   %d corner(s) left   %s" % [
		_route.index() + 1, WAYPOINTS.size(), _route.laps(),
		_agent.get_current_navigation_path().size() - _agent.get_current_navigation_path_index(),
		"running" if _running else "paused"]

## Draw the remaining path as a line, so what the agent is following is visible.
func _draw_path() -> void:
	var path := _agent.get_current_navigation_path()
	_path_mesh.clear_surfaces()
	if path.size() < 2:
		return
	_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in path:
		_path_mesh.surface_add_vertex(point + Vector3.UP * 0.2)
	_path_mesh.surface_end()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: _running = not _running
		KEY_R:
			_route.reset()
			_agent.target_position = _route.current()
		KEY_B: _bake()
		_: return
