extends Node3D

# Demo driver. Turns a click into a world ray, asks the physics space what it
# hit, and hands the answer to ScenePicker.

const RAY_LENGTH := 200.0
const PICKABLE_GROUP := "pickable"
const BASE_COLOUR := Color(0.55, 0.58, 0.65)
const SELECTED_COLOUR := Color(1.0, 0.72, 0.25)

@onready var _camera: Camera3D = $Camera3D
@onready var _marker: MeshInstance3D = $GroundMarker
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _picker := ScenePicker.new()
var _materials: Dictionary = {}
var _pending: Vector2 = Vector2.INF
var _additive := false
var _last := "click something"

func _ready() -> void:
	_hint.text = "Click to select   Shift-click to add   click the floor to clear and place the marker"
	_picker.selection_changed.connect(_on_selection_changed)
	# One material per box, made here rather than in the scene. Sharing a
	# material between the boxes would mean highlighting one highlights all of
	# them, which is the classic version of this bug.
	for node in get_tree().get_nodes_in_group(PICKABLE_GROUP):
		var mesh := (node as Node3D).get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null:
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = BASE_COLOUR
		mesh.material_override = material
		_materials[node] = material
	_refresh_highlights()

func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# The query itself has to wait for a physics frame: the space state is only
	# safe to touch inside _physics_process, and reading it here is the single
	# most common way this ends in an "can't change this state while flushing
	# queries" error.
	_pending = button.position
	_additive = button.shift_pressed

func _physics_process(_delta: float) -> void:
	# Anything the selection is holding may have been freed by something else.
	_picker.prune()
	if _pending == Vector2.INF:
		return
	var screen := _pending
	_pending = Vector2.INF

	# Screen position to world ray: an origin on the near plane and a direction
	# through the pixel. Both come from the camera, so a zoom or a viewport
	# resize needs no work here.
	var from := _camera.project_ray_origin(screen)
	var direction := _camera.project_ray_normal(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * RAY_LENGTH)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var body := hit.get("collider") as Node3D
	if body != null and body.is_in_group(PICKABLE_GROUP):
		if _additive:
			_picker.toggle(body)
		else:
			_picker.select(body)
		_last = "hit %s at %.2f m" % [body.name, from.distance_to(hit["position"])]
	else:
		# Nothing pickable. The click still means something: the point on the
		# floor it was aimed at.
		if not _additive:
			_picker.select(null)
		var ground = ScenePicker.ground_point(from, direction, 0.0)
		if ground == null:
			_last = "aimed at the sky"
		else:
			_marker.position = ground
			_last = "ground at (%.1f, %.1f)" % [_marker.position.x, _marker.position.z]
	_refresh_highlights()

func _on_selection_changed(_count: int) -> void:
	_refresh_highlights()

func _refresh_highlights() -> void:
	for node in _materials:
		var material: StandardMaterial3D = _materials[node]
		material.albedo_color = SELECTED_COLOUR if _picker.is_selected(node) else BASE_COLOUR
	_status.text = "%d selected   %s" % [_picker.count(), _last]
