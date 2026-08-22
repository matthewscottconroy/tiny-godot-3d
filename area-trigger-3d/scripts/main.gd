extends Node3D

# Demo driver. A pressure plate that opens a door while anything heavy is
# standing on it, and ignores the debris that is on the wrong collision layer.

const OPEN_HEIGHT := 3.2
const CLOSED_HEIGHT := 1.5
const DOOR_SPEED := 4.0
const HOLD_TO_LOCK := 2.0

@onready var _plate: Area3D = $Plate
@onready var _door: Node3D = $Door
@onready var _crate: RigidBody3D = $Crate
@onready var _debris: RigidBody3D = $Debris
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _occupancy := Occupancy.new()
var _locked_open := false
var _events := 0

func _ready() -> void:
	_hint.text = "1 drop the crate   2 drop the debris (wrong layer)   R reset   hold 2s to lock open"
	# The area reports; the Occupancy decides what it means.
	_plate.body_entered.connect(_occupancy.enter)
	_plate.body_exited.connect(_occupancy.exit)
	# Transitions, not per-body events. Connecting a door to body_entered gives
	# you a door that slams shut on the second crate.
	_occupancy.occupied.connect(func() -> void: _events += 1)
	_occupancy.vacated.connect(func() -> void:
		_events += 1
		_locked_open = false)

func _physics_process(delta: float) -> void:
	# A body freed while standing in the area never emits body_exited.
	_occupancy.prune()
	_occupancy.advance(delta)

	if _occupancy.longest_dwell() >= HOLD_TO_LOCK:
		_locked_open = true

	var wanted := OPEN_HEIGHT if (_occupancy.is_occupied() or _locked_open) else CLOSED_HEIGHT
	_door.position.y = move_toward(_door.position.y, wanted, DOOR_SPEED * delta)

	_status.text = "%d on the plate   dwell %.1fs   door %.2f m   %s   %d transitions" % [
		_occupancy.count(), _occupancy.longest_dwell(), _door.position.y,
		"locked open" if _locked_open else ("open" if _occupancy.is_occupied() else "closed"),
		_events]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _drop(_crate, Vector3(0, 4, 0))
		KEY_2: _drop(_debris, Vector3(1.2, 4, 0.6))
		KEY_R:
			_drop(_crate, Vector3(-4, 1, 3))
			_drop(_debris, Vector3(4, 1, 3))
			_locked_open = false
		_: return

func _drop(body: RigidBody3D, position: Vector3) -> void:
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	# A rigid body is the solver's, so moving one means telling the solver.
	# See rigid-body-3d for why writing `position` alone is a teleport.
	body.global_position = position
