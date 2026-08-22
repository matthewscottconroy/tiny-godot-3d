extends Node3D

# Demo driver. Builds a walk cycle at runtime and plays it on a creature made of
# primitives, with nothing on disk but this script.

const CLIP_NAME := "walk"
const LEG_PATHS: Array[NodePath] = [
	^"Creature/LegFrontLeft",
	^"Creature/LegFrontRight",
	^"Creature/LegBackLeft",
	^"Creature/LegBackRight",
]

@onready var _player: AnimationPlayer = $AnimationPlayer
@onready var _creature: Node3D = $Creature
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _stride := 35.0
var _period := 1.0
var _walking := true

func _ready() -> void:
	_hint.text = "1/2 stride   3/4 tempo   Space stop and start"
	_rebuild()

func _rebuild() -> void:
	# Rebuilt rather than tweaked: an Animation is a cheap resource, and
	# regenerating it is far easier to follow than editing keys in place.
	var clip := ClipBuilder.walk_cycle(LEG_PATHS, _stride, _period)
	# The body bobs twice per cycle — once per pair of legs landing.
	ClipBuilder.add_position_track(clip, ^"Creature/Body", [
		[0.0, Vector3(0, 0.9, 0)],
		[_period * 0.25, Vector3(0, 1.0, 0)],
		[_period * 0.5, Vector3(0, 0.9, 0)],
		[_period * 0.75, Vector3(0, 1.0, 0)],
		[_period, Vector3(0, 0.9, 0)],
	])
	ClipBuilder.install(_player, clip, CLIP_NAME)
	if _walking:
		_player.play(CLIP_NAME)

func _process(delta: float) -> void:
	if _walking:
		# The creature walks in a circle so the legs have somewhere to be going.
		_creature.rotate_y(delta * 0.5)
		_creature.position = Vector3(sin(_creature.rotation.y) * -4.0, 0.0,
			cos(_creature.rotation.y) * -4.0)

	var clip := _player.get_animation(CLIP_NAME)
	_status.text = "%d tracks   %.2fs cycle   stride %.0f°   %s   position in cycle %.2f" % [
		clip.get_track_count(), clip.length, _stride,
		"walking" if _walking else "stopped",
		ClipBuilder.phase_at(_player.current_animation_position, _period, 0.0)]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _stride = maxf(_stride - 5.0, 5.0)
		KEY_2: _stride = minf(_stride + 5.0, 70.0)
		KEY_3: _period = minf(_period + 0.1, 2.5)
		KEY_4: _period = maxf(_period - 0.1, 0.3)
		KEY_SPACE:
			_walking = not _walking
			if _walking:
				_player.play(CLIP_NAME)
			else:
				_player.pause()
			return
		_: return
	_rebuild()
