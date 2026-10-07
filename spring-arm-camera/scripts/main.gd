extends Node3D

# Demo driver. Moves a target around a scene with walls in it, and keeps a
# camera behind it on a SpringArm3D — the node that does the collision query so
# you do not have to.

const MOVE_SPEED := 4.0
const SENSITIVITY := 0.005
const MIN_PITCH := -0.6
const MAX_PITCH := 1.2
const MIN_LENGTH := 0.8
const HEAD_HEIGHT := 1.2         ## where the arm sweeps from, above the target's origin
const PULL_IN_RATE := 0.0        ## instant: never ease into a wall
const PUSH_OUT_RATE := 3.5       ## fraction of the remaining distance per second

@onready var _target: AnimatableBody3D = $Target
@onready var _pivot: Node3D = $Pivot
@onready var _arm: SpringArm3D = $Pivot/SpringArm3D
@onready var _camera: Camera3D = $Pivot/Camera3D
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _yaw := 0.0
var _pitch := 0.35
var _length := 6.0
var _orbiting := false
var _swept := false               ## has the arm actually run a sweep yet?

func _ready() -> void:
	_hint.text = "Arrows move the target   hold right mouse to orbit   walk behind a wall"
	_length = _arm.spring_length

	# The character is the one thing in the level the arm must ignore. Pitch the
	# camera down and the sweep clips the capsule it started next to, the arm
	# stops on the player, and the camera spends the rest of the demo inside
	# their head. A collision layer cannot express it — every *other* body on
	# that layer is exactly what the arm is looking for — so the exclusion is
	# per-object, and it takes an RID rather than a node.
	_arm.add_excluded_object(_target.get_rid())

func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT:
		_orbiting = button.pressed
		Input.mouse_mode = (Input.MOUSE_MODE_CAPTURED if _orbiting
			else Input.MOUSE_MODE_VISIBLE)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _orbiting:
		_yaw -= motion.relative.x * SENSITIVITY
		_pitch = clampf(_pitch + motion.relative.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)

func _physics_process(delta: float) -> void:
	_move_target(delta)

	# The pivot is what orbits; the arm hangs off it and the camera rides the
	# arm's direction. Rotating the arm itself would work too, but keeping the
	# arm's local -Z as "straight back" is what makes the length a plain number.
	_pivot.position = SpringRig.pivot_position(_target.position, HEAD_HEIGHT)
	_pivot.rotation = Vector3(-_pitch, _yaw, 0.0)

	# SpringArm3D sweeps its shape backwards every physics frame and reports how
	# far it got. That is the whole collision query — no ray to write, and the
	# only exclusion to manage is the character, set once in _ready().
	#
	# Except on the very first physics frame, where it has not swept yet and
	# answers 0. That is "no answer", not "blocked at zero metres" — an arm
	# alone in an empty scene says it too — and believing it costs a second of
	# every run: the instant pull-in rate takes the camera straight to
	# MIN_LENGTH and then eases it back out. Nothing errors and nothing warns,
	# so it reads as a deliberate little zoom-out on spawn.
	#
	# Assume clear until the arm has actually answered. The opposite guess costs
	# more: starting against a wall would put the camera through it, and this
	# way the worst case is one frame too far out, which the instant pull-in
	# corrects on the very next one.
	var allowed := _arm.get_hit_length() if _swept else _arm.spring_length
	_swept = true
	_length = ArmSmoothing.recover_clamped(
		_length, allowed, PULL_IN_RATE, PUSH_OUT_RATE, delta, MIN_LENGTH, _arm.spring_length)
	_camera.position = Vector3(0.0, 0.0, _length)
	_camera.rotation = Vector3.ZERO

	var obstructed := ArmSmoothing.is_obstructed(_length, _arm.spring_length)
	_status.text = "arm %.2f m of %.1f   allowed %.2f   %s" % [
		_length, _arm.spring_length, allowed,
		"obstructed" if obstructed else "clear"]

func _move_target(delta: float) -> void:
	# Camera-relative and flattened — same rule as the orbit-camera demo, and in
	# a component here for the same reason: it is arithmetic, so it is testable.
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := SpringRig.move_direction(_pivot.global_transform.basis, input)
	if direction == Vector3.ZERO:
		return
	_target.position += direction * MOVE_SPEED * delta
