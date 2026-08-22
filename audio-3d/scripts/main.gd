extends Node3D

# Demo driver. Orbits a humming emitter around a listener, and shows what the
# Hearing model predicts alongside what the node is set to do.

const ORBIT_RADIUS := 14.0
const TONE_HZ := 220.0
const UNIT_SIZE := 3.0
const MAX_DISTANCE := 30.0

@onready var _emitter: Node3D = $Emitter
@onready var _player: AudioStreamPlayer3D = $Emitter/AudioStreamPlayer3D
@onready var _listener: Node3D = $Listener
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _model := Hearing.Model.INVERSE
var _angle := 0.0
var _speed := 0.6
var _previous := Vector3.ZERO

func _ready() -> void:
	_hint.text = "1/2 attenuation model   3/4 orbit speed   Space stop the emitter"
	_player.stream = _tone(TONE_HZ)
	_player.unit_size = UNIT_SIZE
	_player.max_distance = MAX_DISTANCE
	_apply_model()
	_player.play()
	_previous = _emitter.global_position

## A one-second looping sine wave, built as 16-bit PCM.
##
## Generated rather than shipped: the collection carries no audio files, and a
## tone is the clearest thing to hear an attenuation curve through anyway.
func _tone(frequency: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := mix_rate
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var value := sin(TAU * frequency * float(i) / float(mix_rate)) * 0.5
		data.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	# Looping matters: a one-shot tone ends after a second and the whole demo
	# goes quiet with nothing to hear the falloff through.
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream

func _apply_model() -> void:
	# The node's model and the Hearing model are set from the same value, which
	# is the entire point: what the player hears and what the game believes are
	# never allowed to be chosen separately.
	match _model:
		Hearing.Model.INVERSE:
			_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		Hearing.Model.INVERSE_SQUARE:
			_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		Hearing.Model.LOGARITHMIC:
			_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		_:
			_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED

func _process(delta: float) -> void:
	_angle += delta * _speed
	_emitter.position = Vector3(sin(_angle) * ORBIT_RADIUS, 1.0, cos(_angle) * ORBIT_RADIUS)

	var velocity := (_emitter.global_position - _previous) / maxf(delta, 0.0001)
	_previous = _emitter.global_position

	var distance := _emitter.global_position.distance_to(_listener.global_position)
	var closing := Hearing.closing_speed(
		_emitter.global_position, velocity, _listener.global_position, Vector3.ZERO)

	_status.text = "%s   %.1f m   %.1f dB   %s   closing %.1f m/s   doppler x%.3f   range %.0f m" % [
		_model_name(), distance,
		Hearing.db_at(distance, UNIT_SIZE, MAX_DISTANCE, _model),
		"audible" if Hearing.is_audible(distance, UNIT_SIZE, MAX_DISTANCE, _model) else "inaudible",
		closing, Hearing.doppler(closing),
		Hearing.range_of(UNIT_SIZE, MAX_DISTANCE, _model)]

func _model_name() -> String:
	match _model:
		Hearing.Model.INVERSE: return "inverse"
		Hearing.Model.INVERSE_SQUARE: return "inverse square"
		Hearing.Model.LOGARITHMIC: return "logarithmic"
		_: return "disabled"

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _model = ((_model - 1) % 4 + 4) % 4 as Hearing.Model
		KEY_2: _model = (_model + 1) % 4 as Hearing.Model
		KEY_3: _speed = maxf(_speed - 0.2, 0.0)
		KEY_4: _speed = minf(_speed + 0.2, 3.0)
		KEY_SPACE:
			if _player.playing:
				_player.stop()
			else:
				_player.play()
			return
		_: return
	_apply_model()
