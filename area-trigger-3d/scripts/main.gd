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
var _resync_pending := false

func _ready() -> void:
	_hint.text = "1 crate   2 debris (wrong layer)   M switch the plate off   R reset   hold 2s to lock"
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
	# Catching up after the area was switched back on. This has to happen in a
	# physics frame: the overlap list is rebuilt by the physics step, so asking
	# in the input handler that re-enabled monitoring returns nothing.
	if _resync_pending:
		_resync_pending = false
		for body in _plate.get_overlapping_bodies():
			_occupancy.enter(body)

	# A body freed while standing in the area never emits body_exited.
	_occupancy.prune()
	_occupancy.advance(delta)

	if _occupancy.longest_dwell() >= HOLD_TO_LOCK:
		_locked_open = true

	var wanted := OPEN_HEIGHT if (_occupancy.is_occupied() or _locked_open) else CLOSED_HEIGHT
	_door.position.y = move_toward(_door.position.y, wanted, DOOR_SPEED * delta)

	_status.text = "%d on the plate   dwell %.1fs   door %.2f m   %s   %d transitions   plate %s" % [
		_occupancy.count(), _occupancy.longest_dwell(), _door.position.y,
		"locked open" if _locked_open else ("open" if _occupancy.is_occupied() else "closed"),
		_events, "watching" if _plate.monitoring else "switched off"]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _drop(_crate, Vector3(0, 4, 0))
		KEY_2: _drop(_debris, Vector3(1.2, 4, 0.6))
		KEY_M:
			# The cheap way to disable a trigger: one flag, rather than moving
			# it, emptying its mask, or unsubscribing everything. A switched-off
			# area emits nothing — and emits nothing on the way back on either,
			# so what it missed has to be asked for rather than waited for.
			_plate.monitoring = not _plate.monitoring
			if _plate.monitoring:
				_resync_pending = true
			else:
				_occupancy.clear()
		KEY_R:
			_drop(_crate, Vector3(-4, 1, 3))
			_drop(_debris, Vector3(4, 1, 3))
			_locked_open = false
			# A reset that leaves the plate switched off is not a reset.
			if not _plate.monitoring:
				_plate.monitoring = true
				_resync_pending = true
		_: return

func _drop(body: RigidBody3D, position: Vector3) -> void:
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	# A rigid body is the solver's, so moving one means telling the solver.
	# See rigid-body-3d for why writing `position` alone is a teleport.
	body.global_position = position
