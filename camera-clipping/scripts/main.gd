extends Node3D

# Demo driver. Walk into the wall and the camera stops short of clipping through
# it — or does not, with the guard off. The arithmetic is in scripts/near_plane.gd.

@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Player/Camera3D
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

# The near plane starts at 0.25 rather than Godot's 0.05, because at 0.05 a
# character with a 0.35m radius never gets close enough for this to happen — the
# body stops first. It shows up with a large near plane, a wide field of view, or
# any camera that can get nearer to a wall than the body can: a lean, a crouch,
# a spring arm that has collapsed.

var _guard := true
var _closest := INF
var _pushed := 0.0

func _ready() -> void:
	_hint.text = "A/D walk into the wall   1/2 near plane   3/4 field of view   G guard on or off   R reset"

func _physics_process(delta: float) -> void:
	var move := Input.get_axis(&"ui_left", &"ui_right")
	_player.velocity = Vector3(move * 3.0, 0, 0)
	_player.move_and_slide()

	_camera.position = Vector3(0, 0.7, 0)
	_closest = _distance_to_wall()
	_pushed = 0.0
	if _guard:
		_keep_the_near_plane_clear()
	_show()

## How close the nearest solid thing is to the camera.
##
## A sphere query rather than a ring of rays: "keep the camera's origin this far
## from anything solid" *is* a sphere test, and a handful of rays only finds the
## surfaces they happen to point at. A wall met at 45 degrees goes straight
## between them.
func _nearest_surface() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = NearPlane.safe_distance(_camera.fov, _camera.near, _aspect())
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _camera.global_position)
	query.exclude = [_player.get_rid()]
	return space.get_rest_info(query)

func _distance_to_wall() -> float:
	var rest := _nearest_surface()
	if rest.is_empty():
		return INF
	return _camera.global_position.distance_to(rest["point"])

## Push the camera back along the surface normal until the near plane clears it.
func _keep_the_near_plane_clear() -> void:
	var rest := _nearest_surface()
	if rest.is_empty():
		return
	var moved := NearPlane.pushed_out(_camera.global_position, rest["point"],
		rest["normal"], _camera.fov, _camera.near, _aspect())
	_pushed = moved.distance_to(_camera.global_position)
	_camera.global_position = moved

func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return float(size.x) / maxf(float(size.y), 1.0)

func _show() -> void:
	var aspect := _aspect()
	var safe := NearPlane.safe_distance(_camera.fov, _camera.near, aspect)
	# No second test against `would_clip()`: the sphere above is cast at exactly
	# the safe distance, so anything it found is already inside it.
	var clipping := _closest < INF
	_readout.text = "near plane %.3f m at %.0f° — its corners reach %.3f m from the camera\nkeep the camera %.3f m clear of anything solid   nearest surface: %s\nguard %s%s" % [
		_camera.near, _camera.fov, NearPlane.radius(_camera.fov, _camera.near, aspect),
		safe, "nothing near" if _closest == INF else "%.3f m" % _closest,
		"on — pushed %.3f m this frame" % _pushed if _guard else "off",
		"   CLIPPING" if clipping and not _guard else ""]
	_status.text = "halving the near plane costs %.0fx the depth precision; the first metre already uses %.0f%% of it" % [
		NearPlane.precision_cost(_camera.near, _camera.near * 0.5),
		NearPlane.near_precision_share(_camera.near, _camera.far) * 100.0]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_camera.near = maxf(_camera.near - 0.01, 0.005)
		KEY_2:
			_camera.near = minf(_camera.near + 0.01, 0.6)
		KEY_3:
			_camera.fov = maxf(_camera.fov - 5.0, 30.0)
		KEY_4:
			_camera.fov = minf(_camera.fov + 5.0, 110.0)
		KEY_G:
			_guard = not _guard
		KEY_R:
			_player.global_position = Vector3(2, 0.9, 0)
			_camera.near = 0.25
			_camera.fov = 75.0
			_guard = true
		_:
			return
