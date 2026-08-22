extends Node3D

# Demo driver. A fake server on a delay, a client that moves immediately, and a
# wall only the server knows about. The technique is in scripts/prediction.gd.

@onready var _client: MeshInstance3D = $Client
@onready var _server_view: MeshInstance3D = $Server
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

const SPEED := 6.0
const WALL_X := 4.0

var _prediction := Prediction.new()
var _predicted := Vector3(-6, 0.8, 0)
var _shown := Vector3(-6, 0.8, 0)
var _authoritative := Vector3(-6, 0.8, 0)
var _acknowledged := -1
var _latency := 0.12
var _enabled := true
var _queue: Array = []
var _clock := 0.0
var _corrections := 0
var _worst := 0.0

func _ready() -> void:
	_hint.text = "Arrows move   1/2 latency   P prediction on or off   R reset"

func _physics_process(delta: float) -> void:
	_clock += delta
	var move := Vector3(Input.get_axis(&"ui_left", &"ui_right"), 0,
		Input.get_axis(&"ui_up", &"ui_down"))

	if _enabled:
		# Move now, and assume it was right. The alternative is the player's own
		# character lagging behind their own input by a round trip.
		_predicted = _prediction.predict(_predicted, move, delta, SPEED)
	# Off, the client shows only what the server has confirmed — which is what
	# every action game feels like without this.
	_queue.append({"at": _clock + _latency, "sequence": _prediction.last_sequence(),
		"move": move, "delta": delta})
	_receive()

	_shown = Prediction.ease_toward(_shown, _predicted if _enabled else _authoritative, delta)
	_client.position = _shown
	_server_view.position = _authoritative + Vector3(0, -0.3, 2.5)
	_show()

## The server: the same step function, plus the wall the client did not know
## about, running `_latency` behind.
func _receive() -> void:
	while not _queue.is_empty() and _queue[0]["at"] <= _clock:
		var packet: Dictionary = _queue.pop_front()
		_authoritative = Prediction.step(_authoritative, packet["move"], packet["delta"], SPEED)
		# Authority means the server decides. The client never knew this wall was
		# here, and the disagreement is what prediction has to absorb.
		_authoritative.x = minf(_authoritative.x, WALL_X - 0.6)
		_acknowledged = packet["sequence"]

		if not _enabled:
			continue
		var corrected := _prediction.reconcile(_authoritative, _acknowledged, SPEED)
		var error := _predicted.distance_to(corrected)
		_worst = maxf(_worst, error)
		if not Prediction.worth_correcting(_predicted, corrected, _prediction.tolerance):
			continue
		_corrections += 1
		if Prediction.should_snap(_predicted, corrected, _prediction.snap_beyond):
			_shown = corrected
		_predicted = corrected

func _show() -> void:
	_readout.text = "latency %.0f ms each way   prediction %s\ninputs waiting on the server: %d\ncorrections applied %d   worst disagreement %.2f m" % [
		_latency * 1000.0, "on" if _enabled else "off",
		_prediction.pending(), _corrections, _worst]
	_status.text = "client at x %.2f   server says x %.2f   the wall is at x %.1f" % [
		_shown.x, _authoritative.x, WALL_X]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_latency = maxf(_latency - 0.04, 0.0)
		KEY_2:
			_latency = minf(_latency + 0.04, 0.6)
		KEY_P:
			_enabled = not _enabled
			_prediction.reset()
			_predicted = _authoritative
		KEY_R:
			_prediction.reset()
			_predicted = Vector3(-6, 0.8, 0)
			_shown = _predicted
			_authoritative = _predicted
			_queue.clear()
			_corrections = 0
			_worst = 0.0
		_:
			return
