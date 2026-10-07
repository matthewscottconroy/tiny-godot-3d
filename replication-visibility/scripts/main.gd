extends Node3D

# Demo driver. Builds a MultiplayerSynchronizer in code, points it at the local
# pawn, and hangs a visibility filter off it so distant peers are not sent
# anything.
#
# The thing to notice is what is NOT here: there is no @rpc in this file. The
# whole of multiplayer-3d's broadcast — a timer, an unreliable RPC, a sender id,
# a per-peer buffer — is replaced by naming one property in a
# SceneReplicationConfig. What that leaves you to decide is who should receive
# it, which is scripts/replication_visibility.gd.

const PORT := 8971
const ENTER_RADIUS := 6.0
const EXIT_RADIUS := 8.0
const SPEED := 4.0

@onready var _pawn: Node3D = $Pawn
@onready var _ghost: Node3D = $Ghost
@onready var _bubble: MeshInstance3D = $Bubble
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _sync := MultiplayerSynchronizer.new()
var _relevant := true                 ## last answer, so the filter has hysteresis
var _message := "offline — H to host, J to join"

func _ready() -> void:
	_hint.text = "Arrows move   H host   J join   R go offline   watch the bubble"
	_bubble.scale = Vector3.ONE * EXIT_RADIUS

	# Naming the property is the entire replication setup. `position` is a
	# Vector3 on the pawn; ON_CHANGE rather than ALWAYS so a stationary player
	# costs nothing at all, which is most players most of the time.
	var config := SceneReplicationConfig.new()
	config.add_property(^"Pawn:position")
	config.property_set_replication_mode(^"Pawn:position",
		SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	_sync.replication_config = config
	# root_path defaults to "..", so adding it under Main makes `Pawn:position`
	# resolve to Main/Pawn. Setting it before the node is in the tree is the
	# usual way to get "no path can be resolved between the nodes".
	_sync.replication_interval = 0.05          # 20 updates a second, as sent
	_sync.set_visibility_public(false)         # nobody is told anything by default
	_sync.add_visibility_filter(_should_send_to)
	add_child(_sync)

## Called by the synchronizer, once per peer, to ask whether to send.
##
## The peer's own position is not known here in a demo with one machine, so the
## ghost stands in for "the other player": it is what the filter measures
## against, and moving the pawn in and out of the bubble is the demo.
func _should_send_to(_peer: int) -> bool:
	_relevant = Relevance.stays_relevant(_relevant, _ghost.position, _pawn.position,
		ENTER_RADIUS, EXIT_RADIUS)
	return _relevant

func _physics_process(delta: float) -> void:
	var move := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if move != Vector2.ZERO:
		_pawn.position += Vector3(move.x, 0.0, move.y) * SPEED * delta
	_show()

func _show() -> void:
	var distance := Vector2(_pawn.position.x - _ghost.position.x,
		_pawn.position.z - _ghost.position.z).length()
	var peers := 1 + multiplayer.get_peers().size() if multiplayer.has_multiplayer_peer() else 0
	var interval := Relevance.interval_for(distance, ENTER_RADIUS, 24.0)

	_status.text = "%s\n%.1f m from the other player — %s (enters at %.0f, leaves at %.0f)\nsending every %.0f ms at this distance   %d peer(s)   no RPC in this demo" % [
		_message,
		distance,
		"relevant, replicating" if _relevant else "out of range, sending nothing",
		ENTER_RADIUS, EXIT_RADIUS,
		interval * 1000.0, peers]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_H: _host()
		KEY_J: _join()
		KEY_R: _offline()
		_: return

func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 4) != OK:
		_message = "could not host on %d" % PORT
		return
	multiplayer.multiplayer_peer = peer
	# Authority decides who is allowed to write the replicated property. Leave it
	# wrong and both ends push their own position at each other for ever.
	_sync.set_multiplayer_authority(multiplayer.get_unique_id())
	_message = "hosting on %d as peer %d" % [PORT, multiplayer.get_unique_id()]

func _join() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", PORT) != OK:
		_message = "could not reach 127.0.0.1:%d" % PORT
		return
	multiplayer.multiplayer_peer = peer
	_message = "joining 127.0.0.1:%d" % PORT

func _offline() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_pawn.position = Vector3.ZERO
	_relevant = true
	_message = "offline — H to host, J to join"
