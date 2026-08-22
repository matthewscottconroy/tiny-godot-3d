extends Node3D

# Demo driver. Two rooms, two portals, and a player who can walk from one to the
# other without the rooms touching. The transform is in scripts/portal_view.gd.

@onready var _player: Node3D = $Player
@onready var _portal_a: Node3D = $PortalA
@onready var _portal_b: Node3D = $PortalB
@onready var _camera_a: Camera3D = $PortalA/View/Camera
@onready var _camera_b: Camera3D = $PortalB/View/Camera
@onready var _view_a: SubViewport = $PortalA/View
@onready var _view_b: SubViewport = $PortalB/View
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

const OPENING := Vector2(1.0, 1.5)

var _teleports := 0
var _clip := true
var _cull := true

func _ready() -> void:
	_hint.text = "WASD move   arrows turn   C near-plane clipping   V skip portals you are behind   R reset"
	for view in [_view_a, _view_b]:
		# A SubViewport renders nothing without a world to render. This is the
		# line that turns a black rectangle into a portal.
		view.world_3d = get_world_3d()
	_paint(_portal_a, _view_a)
	_paint(_portal_b, _view_b)

func _paint(portal: Node3D, view: SubViewport) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = view.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(portal.get_node("Surface") as MeshInstance3D).material_override = material

func _process(delta: float) -> void:
	_drive(delta)
	_aim(_camera_a, _portal_a, _portal_b, _view_a)
	_aim(_camera_b, _portal_b, _portal_a, _view_b)
	_show()

func _drive(delta: float) -> void:
	_player.rotation.y += Input.get_axis(&"ui_right", &"ui_left") * 1.6 * delta
	var forward := Input.get_action_strength(&"ui_up") - Input.get_action_strength(&"ui_down")
	if is_zero_approx(forward):
		return
	var before := _player.global_position
	_player.global_position += _player.global_transform.basis * Vector3(0, 0, -forward * 4.0 * delta)
	_check_crossing(before, _player.global_position)

## Walking through: a sign change across the plane, checked against the opening
## so the wall beside a portal is still a wall.
func _check_crossing(before: Vector3, after: Vector3) -> void:
	for pair in [[_portal_a, _portal_b], [_portal_b, _portal_a]]:
		var entry: Node3D = pair[0]
		var exit: Node3D = pair[1]
		if not PortalView.crossed(entry.global_transform, before, after):
			continue
		if not PortalView.within_opening(entry.global_transform, after, OPENING):
			continue
		_player.global_transform = PortalView.camera_transform(
			_player.global_transform, entry.global_transform, exit.global_transform)
		_teleports += 1
		return

func _aim(camera: Camera3D, portal: Node3D, other: Node3D, view: SubViewport) -> void:
	var player := _player.get_node("Camera3D") as Camera3D
	# Rendering a portal the player is standing behind costs an entire extra
	# scene render to produce something nobody can see.
	var facing := PortalView.is_facing(portal.global_transform, player.global_position)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
		if facing or not _cull else SubViewport.UPDATE_DISABLED
	if not facing and _cull:
		return
	camera.global_transform = PortalView.camera_transform(
		player.global_transform, portal.global_transform, other.global_transform)
	camera.fov = player.fov
	# Clip at the exit portal, or anything between it and this camera floats in
	# the doorway.
	camera.near = PortalView.near_plane_for(camera.global_transform,
		other.global_transform) if _clip else 0.05

func _show() -> void:
	var player := _player.get_node("Camera3D") as Camera3D
	var side_a := PortalView.side_of(_portal_a.global_transform, player.global_position)
	var distance := player.global_position.distance_to(_portal_a.global_position)
	_readout.text = "portal A is %s you (%.2f m in front)   near plane %.2f m\nportal B rendering: %s\nresolution worth using at this distance: %s" % [
		"facing" if side_a > 0.0 else "behind", side_a, _camera_a.near,
		"yes" if _view_b.render_target_update_mode != SubViewport.UPDATE_DISABLED else "skipped",
		PortalView.resolution_for(distance, Vector2i(512, 768))]
	_status.text = "walked through %d times   clipping %s   culling %s" % [
		_teleports, "on" if _clip else "off", "on" if _cull else "off"]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_C:
			_clip = not _clip
		KEY_V:
			_cull = not _cull
		KEY_R:
			_player.global_transform = Transform3D(Basis.IDENTITY, Vector3(-10, 0, 2))
			_teleports = 0
		_:
			return
