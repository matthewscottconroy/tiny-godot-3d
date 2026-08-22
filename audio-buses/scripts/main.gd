extends Node3D

# Demo driver. Builds a music and an effects bus at runtime, plus a reverb bus
# an Area3D moves the sound into.

const MUSIC := &"Music"
const EFFECTS := &"Effects"
const REVERB := &"Reverb"

@onready var _music: AudioStreamPlayer = $Music
@onready var _blip: AudioStreamPlayer3D = $Emitter/Blip
@onready var _room: Area3D = $Room
@onready var _emitter: Node3D = $Emitter
@onready var _status: Label = $HUD/StatusLabel
@onready var _levels: Label = $HUD/LevelList
@onready var _hint: Label = $HUD/TitleLabel

var _mixer := BusMixer.new()
var _selected := 0
var _time := 0.0
var _blip_timer := 0.0
var _in_room := false

func _ready() -> void:
	_hint.text = "1/2 select a bus   3/4 its volume   M mute   S solo   the box is a reverb zone"
	_mixer.ensure_bus(MUSIC)
	_mixer.ensure_bus(EFFECTS)
	_mixer.ensure_bus(REVERB)
	# A reverb is an effect on a bus, not a property of a sound. Anything routed
	# through this bus is in the room; anything else is not.
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.9
	reverb.wet = 0.55
	_mixer.add_effect(REVERB, reverb)

	_mixer.set_level(MUSIC, 0.5)
	_mixer.set_level(EFFECTS, 0.8)
	_mixer.set_level(REVERB, 0.8)

	_music.stream = _tone(110.0, true)
	_music.bus = MUSIC
	_blip.stream = _tone(660.0, false)
	_blip.bus = EFFECTS
	_music.play()

	_room.body_entered.connect(_on_room_changed.bind(true))
	_room.body_exited.connect(_on_room_changed.bind(false))

## A tone built in code, so the demo ships no audio files.
func _tone(frequency: float, looping: bool) -> AudioStreamWAV:
	var rate := 22050
	var frames := rate / 2
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var fade := 1.0 if looping else 1.0 - float(i) / float(frames)
		data.encode_s16(i * 2, int(sin(TAU * frequency * float(i) / float(rate)) * 12000.0 * fade))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream

func _on_room_changed(_body: Node, entered: bool) -> void:
	_in_room = entered
	# Routing, not re-authoring: the same sound goes down a different bus.
	_blip.bus = REVERB if entered else EFFECTS

func _process(delta: float) -> void:
	_time += delta
	_emitter.position = Vector3(sin(_time * 0.5) * 6.0, 1.0, cos(_time * 0.5) * 3.0)
	_blip_timer -= delta
	if _blip_timer <= 0.0:
		_blip_timer = 0.8
		_blip.play()
	_refresh()

func _refresh() -> void:
	var names := _mixer.buses()
	var lines := PackedStringArray()
	for i in names.size():
		lines.append("%s %-8s %5.0f%%%s" % [
			">" if i == _selected else " ", names[i], _mixer.level_of(names[i]) * 100.0,
			"   MUTED" if _mixer.is_muted(names[i]) else ""])
	_levels.text = "\n".join(lines)
	_status.text = "%s   |   emitter is %s   |   solo: %s" % [
		"selected: %s" % names[_selected] if _selected < names.size() else "no bus",
		"in the reverb room" if _in_room else "in the open",
		_mixer.soloed() if _mixer.soloed() != &"" else "none"]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var names := _mixer.buses()
	if names.is_empty():
		return
	var bus := names[_selected]
	match key.keycode:
		KEY_1: _selected = (_selected - 1 + names.size()) % names.size()
		KEY_2: _selected = (_selected + 1) % names.size()
		KEY_3: _mixer.set_level(bus, maxf(_mixer.level_of(bus) - 0.1, 0.0))
		KEY_4: _mixer.set_level(bus, minf(_mixer.level_of(bus) + 0.1, 1.0))
		KEY_M: _mixer.set_muted(bus, not _mixer.is_muted(bus))
		KEY_S:
			if _mixer.soloed() == bus:
				_mixer.clear_solo()
			else:
				_mixer.solo(bus)
		_: return
	_refresh()

func _exit_tree() -> void:
	# The AudioServer is global: buses added at runtime outlive the scene that
	# made them unless something takes them away again.
	_mixer.remove_all()
