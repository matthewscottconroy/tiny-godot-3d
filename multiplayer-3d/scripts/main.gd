extends Node3D

# Demo driver. Hosts or joins on localhost, sends its own position ten times a
# second, and draws everyone else out of a StateBuffer.
#
# Run two copies: press H in one, J in the other.

const PORT := 47212
const SEND_HZ := 10.0
const SPEED := 4.0

@onready var _self_pawn: Node3D = $Pawns/Local
@onready var _pawns: Node3D = $Pawns
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _buffers := {}          ## peer id -> StateBuffer
var _remote_pawns := {}     ## peer id -> Node3D
var _send_timer := 0.0
var _clock := 0.0
var _interpolate := true
var _message := "not connected — H to host, J to join 127.0.0.1"

func _ready() -> void:
	_hint.text = "H host   J join   arrows move   I interpolation on/off (watch the stutter)"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _process(delta: float) -> void:
	_clock += delta

	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_self_pawn.position += Vector3(input.x, 0.0, input.y) * SPEED * delta

	# Sending on a timer rather than every frame is the whole reason the buffer
	# exists: ten packets a second is plenty of data and nothing like enough
	# frames.
	_send_timer -= delta
	if _send_timer <= 0.0 and multiplayer.has_multiplayer_peer():
		_send_timer = 1.0 / SEND_HZ
		_broadcast_position.rpc(_clock, _self_pawn.position)

	for id in _buffers:
		var pawn: Node3D = _remote_pawns.get(id)
		if pawn == null:
			continue
		var buffer: StateBuffer = _buffers[id]
		# Interpolated: where they were a moment ago, drawn smoothly.
		# Otherwise: wherever the last packet said, which is the stutter.
		pawn.position = buffer.sample(_clock) if _interpolate else buffer.latest()

	_status.text = "%s   |   %d peer(s)   %s   clock %.1fs" % [
		_message, _buffers.size(),
		"interpolating" if _interpolate else "snapping to the last packet",
		_clock]

## Unreliable and unordered, because position updates are: a packet that arrives
## late is worthless, and waiting for it holds up the ones behind it.
@rpc("any_peer", "call_remote", "unreliable")
func _broadcast_position(time: float, position: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _buffers.has(sender):
		return
	(_buffers[sender] as StateBuffer).push(time, position)

func _on_peer_connected(id: int) -> void:
	_buffers[id] = StateBuffer.new()
	var pawn := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	pawn.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(fmod(float(id) * 0.13, 1.0), 0.6, 0.9)
	pawn.material_override = material
	pawn.position = Vector3(0, 0.5, 0)
	_pawns.add_child(pawn)
	_remote_pawns[id] = pawn
	_message = "peer %d joined" % id

func _on_peer_disconnected(id: int) -> void:
	_buffers.erase(id)
	if _remote_pawns.has(id):
		(_remote_pawns[id] as Node).queue_free()
		_remote_pawns.erase(id)
	_message = "peer %d left" % id

func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 8)
	if error != OK:
		_message = "could not host on %d (error %d) — is something else using it?" % [PORT, error]
		return
	multiplayer.multiplayer_peer = peer
	_message = "hosting on %d, id %d" % [PORT, multiplayer.get_unique_id()]

func _join() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client("127.0.0.1", PORT)
	if error != OK:
		_message = "could not connect (error %d)" % error
		return
	multiplayer.multiplayer_peer = peer
	_message = "connecting to 127.0.0.1:%d…" % PORT

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_H: _host()
		KEY_J: _join()
		KEY_I: _interpolate = not _interpolate
		_: return
