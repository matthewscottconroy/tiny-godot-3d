extends Node3D

# Demo driver. A camera watching the scene from above, rendered onto a screen
# hanging on the wall — and throttled by how far away the viewer is.

const BASE_RESOLUTION := Vector2i(512, 288)

@onready var _feed: SubViewport = $Feed
@onready var _feed_camera: Camera3D = $Feed/FeedCamera
@onready var _screen: MeshInstance3D = $Screen
@onready var _viewer: Camera3D = $Viewer
@onready var _subject: Node3D = $Subject
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _throttle := FeedThrottle.new()
var _throttling := true
var _time := 0.0
var _distance := 6.0
var _updates := 0
var _frames := 0

func _ready() -> void:
	_hint.text = "1/2 move the viewer   T throttling on/off   the screen is a second render of this scene"
	# The line that makes the feed show anything: a SubViewport has its own
	# empty World3D until told otherwise. Same trap as split-screen-3d.
	_feed.world_3d = get_viewport().world_3d
	_feed.size = BASE_RESOLUTION
	_feed_camera.current = true

	# The screen's material samples the viewport's texture. Unshaded, because a
	# monitor emits light rather than reflecting it.
	var material := StandardMaterial3D.new()
	material.albedo_texture = _feed.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen.material_override = material

func _process(delta: float) -> void:
	_frames += 1
	_time += delta
	_subject.position = Vector3(sin(_time * 0.6) * 4.0, 1.0, cos(_time * 0.6) * 4.0)
	_feed_camera.look_at(_subject.global_position, Vector3.UP)
	_viewer.position = Vector3(0, 2.0, _distance)
	_viewer.look_at(_screen.global_position, Vector3.UP)

	var distance := _viewer.global_position.distance_to(_screen.global_position)
	var visible := true

	if _throttling:
		# UPDATE_ONCE renders exactly one frame and then switches itself back to
		# disabled — which is what makes a throttled feed a throttle rather than
		# a slideshow of the same frame.
		if _throttle.should_update(distance, visible, delta):
			_feed.render_target_update_mode = SubViewport.UPDATE_ONCE
			_updates += 1
		var wanted := FeedThrottle.resolution_for(distance, BASE_RESOLUTION)
		if _feed.size != wanted:
			_feed.size = wanted
	else:
		# The version everyone writes first: a full render of the scene every
		# single frame, whether anyone is looking at the screen or not.
		_feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_feed.size = BASE_RESOLUTION
		_updates += 1

	_status.text = "%.1f m away   %s   %.0f Hz   %dx%d   %d renders in %d frames" % [
		distance, "throttled" if _throttling else "every frame",
		_throttle.rate_for(distance, visible) if _throttling else Engine.max_fps,
		_feed.size.x, _feed.size.y, _updates, _frames]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _distance = maxf(_distance - 2.0, 3.0)
		KEY_2: _distance = minf(_distance + 2.0, 40.0)
		KEY_T:
			_throttling = not _throttling
			_updates = 0
			_frames = 0
			_throttle.reset()
		_: return
