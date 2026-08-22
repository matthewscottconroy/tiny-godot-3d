extends Node3D

# Demo driver. A gameplay camera, a camera on a Path3D, and a third one that
# blends between them because Godot's own switch is a cut.

@onready var _path: Path3D = $Path3D
@onready var _follow: PathFollow3D = $Path3D/PathFollow3D
@onready var _gameplay: Camera3D = $GameplayRig/Camera3D
@onready var _cinematic: Camera3D = $Path3D/PathFollow3D/Camera3D
@onready var _blend_camera: Camera3D = $BlendCamera
@onready var _subject: Node3D = $Subject
@onready var _rig: Node3D = $GameplayRig
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _track := CameraTrack.new()
var _angle := 0.0
var _tracking_subject := true

func _ready() -> void:
	_hint.text = "Space cutscene on/off   T aim at subject or along the path   1/2 pace   L looping"
	_path.curve = _build_curve()

## The track, built in code so the demo carries no scene data it cannot explain.
func _build_curve() -> Curve3D:
	var curve := Curve3D.new()
	var points := [
		Vector3(9, 3, 9), Vector3(-9, 5, 7), Vector3(-8, 2.5, -8), Vector3(8, 6, -7),
	]
	for point in points:
		# In and out handles make the corners round; without them a Curve3D is a
		# polyline and the camera turns in steps.
		curve.add_point(point, -point.normalized() * 4.0, point.normalized() * 4.0)
	curve.add_point(points[0], -points[0].normalized() * 4.0, points[0].normalized() * 4.0)
	return curve

func _process(delta: float) -> void:
	_angle += delta * 0.5
	_subject.position = Vector3(sin(_angle) * 3.0, 1.0, cos(_angle) * 3.0)

	# The gameplay camera: an ordinary third-person rig, doing its own thing
	# throughout. It never knows a cutscene is happening.
	_rig.position = _subject.position
	_rig.rotation.y = _angle
	_gameplay.position = Vector3(0, 2.5, 6)
	_gameplay.look_at(_subject.global_position + Vector3.UP, Vector3.UP)

	# The cinematic camera: carried by the path, aiming slightly ahead of itself.
	var progress := _track.advance(delta)
	_follow.progress_ratio = progress
	# Two ways to aim a dolly: at the thing the scene is about, or along the
	# track itself. Looking exactly where it is going gives a camera nothing to
	# aim at, so "along the track" means a point sampled slightly ahead.
	var ahead := CameraTrack.look_ahead(progress, 0.08, _track.looping)
	var aim := _subject.global_position + Vector3.UP
	if not _tracking_subject:
		aim = _path.curve.sample_baked(ahead * _path.curve.get_baked_length())
	_cinematic.look_at_from_position(_follow.global_position, aim, Vector3.UP)

	var weight := _track.advance_blend(delta)
	# Three states: gameplay, cutscene, and the blend between them. Only the
	# middle one needs the third camera, and only while it lasts.
	if weight <= 0.0:
		_gameplay.current = true
	elif weight >= 1.0:
		_cinematic.current = true
	else:
		_blend_camera.global_transform = CameraTrack.blended(
			_gameplay.global_transform, _cinematic.global_transform, weight)
		_blend_camera.current = true

	_status.text = "%s   blend %.2f   track %.2f   aiming at %s   %s" % [
		"cutscene" if _track.is_cinematic() else "gameplay",
		weight, progress,
		"the subject" if _tracking_subject else "%.2f along the path" % ahead,
		"blending" if _track.is_blending() else "settled"]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: _track.set_cinematic(not _track.is_cinematic())
		KEY_1: _track.duration = minf(_track.duration + 2.0, 30.0)
		KEY_2: _track.duration = maxf(_track.duration - 2.0, 2.0)
		KEY_L: _track.looping = not _track.looping
		KEY_T: _tracking_subject = not _tracking_subject
		_: return
