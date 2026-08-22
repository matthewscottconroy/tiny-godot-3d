extends Node3D

# Demo driver. Three cubes: one on an authored AnimationPlayer loop, one tweened
# through a Transitions guard, one tweened with no guard at all. Press the key
# quickly and only the third goes strange.

@onready var _authored: MeshInstance3D = $Authored
@onready var _player: AnimationPlayer = $Authored/Player
@onready var _guarded: MeshInstance3D = $Guarded
@onready var _loose: MeshInstance3D = $Loose
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

const HEIGHT := 3.0
const SPEED := 6.0

var _transitions := Transitions.new()
var _loose_tweens: Array[Tween] = []
var _up := false

func _ready() -> void:
	_hint.text = "Space raise or lower — hold it down and watch the red one   R reset"
	_build_authored_loop()
	_player.play(&"bob")

## The AnimationPlayer half: a timeline, built here only so the demo ships no
## binary data. In a real project this is what the animation editor writes.
func _build_authored_loop() -> void:
	var animation := Animation.new()
	animation.length = 2.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, "..:position:y")
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, 0.5)
	animation.track_insert_key(track, 1.0, 0.5 + HEIGHT)
	animation.track_insert_key(track, 2.0, 0.5)
	var library := AnimationLibrary.new()
	library.add_animation(&"bob", animation)
	_player.add_animation_library(&"", library)

func _toggle() -> void:
	_up = not _up
	var target := 0.5 + (HEIGHT if _up else 0.0)

	# Guarded: whatever was moving this property is killed first, so there is
	# always exactly one tween writing it.
	var distance := absf(target - _guarded.position.y)
	_transitions.start(_guarded, ^"position:y", target,
		Transitions.duration_for(distance, SPEED))

	# Unguarded: a new tween every press, all of them still running, all of them
	# writing the same property. Nothing errors.
	var loose := create_tween()
	loose.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	loose.tween_property(_loose, ^"position:y", target,
		Transitions.duration_for(absf(target - _loose.position.y), SPEED))
	_loose_tweens.append(loose)
	_show()

func _show() -> void:
	var alive := 0
	for tween in _loose_tweens:
		if is_instance_valid(tween) and tween.is_valid() and tween.is_running():
			alive += 1
	_readout.text = "blue    AnimationPlayer — an authored loop, the same every time\ngreen   Tween through a guard — %d running\nred     Tween with no guard — %d running" % [
		_transitions.count(), alive]
	_status.text = "heights: authored %.2f   guarded %.2f   loose %.2f%s" % [
		_authored.position.y, _guarded.position.y, _loose.position.y,
		"   ← two tweens are fighting over this one" if alive > 1 else ""]

func _process(_delta: float) -> void:
	_show()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_toggle()
		KEY_R:
			_transitions.stop_all()
			for tween in _loose_tweens:
				if is_instance_valid(tween) and tween.is_valid():
					tween.kill()
			_loose_tweens.clear()
			_guarded.position.y = 0.5
			_loose.position.y = 0.5
			_up = false
			_show()
		_:
			return
