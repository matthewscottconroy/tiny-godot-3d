extends Node3D

# Demo driver. Builds a stack of RigidBody3D boxes at the positions DropStack
# works out, then offers the two ways of moving them: an impulse, which the
# physics engine integrates, and a transform write, which it does not.

const BOX_SIZE := 0.5
const ROWS := 4
const BLAST_STRENGTH := 9.0
const BLAST_RADIUS := 4.0
const BLAST_LIFT := 0.6

@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _boxes: Array[RigidBody3D] = []
var _last_action := "waiting"

func _ready() -> void:
	_hint.text = "Space blast (impulse)   T teleport (transform)   R reset"
	_build_stack()

func _build_stack() -> void:
	for box in _boxes:
		box.queue_free()
	_boxes.clear()

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * BOX_SIZE
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * BOX_SIZE

	for position in DropStack.pyramid(ROWS, BOX_SIZE * 1.05, BOX_SIZE):
		var body := RigidBody3D.new()
		body.position = position
		var view := MeshInstance3D.new()
		view.mesh = mesh
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(view)
		body.add_child(collider)
		add_child(body)
		_boxes.append(body)
	_last_action = "built %d boxes" % _boxes.size()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: _blast()
		KEY_T: _teleport()
		KEY_R: _build_stack()
		_: return

func _blast() -> void:
	# The engine's way in: an impulse is added to the body's momentum, so the
	# result is a velocity change the solver knows about and can integrate.
	var centre := Vector3(0.0, 0.0, 0.0)
	var moved := 0
	for box in _boxes:
		var impulse := DropStack.impulse_with_lift(
			centre, box.position, BLAST_STRENGTH, BLAST_RADIUS, BLAST_LIFT)
		if impulse != Vector3.ZERO:
			box.apply_central_impulse(impulse)
			moved += 1
	_last_action = "impulse to %d boxes" % moved

func _teleport() -> void:
	# The wrong way, shown deliberately: writing position moves the body without
	# giving it any velocity, so it drops from the new place as if it had been
	# placed there. Momentum is discarded, and nothing collided with on the way.
	for box in _boxes:
		box.position += Vector3.UP * 2.0
	_last_action = "teleported (no momentum)"

func _process(_delta: float) -> void:
	var moving := 0
	var highest := 0.0
	for box in _boxes:
		if box.linear_velocity.length() > 0.05:
			moving += 1
		highest = maxf(highest, box.position.y)
	_status.text = "%d boxes   %d moving   highest %.2f m   last: %s" % [
		_boxes.size(), moving, highest, _last_action]
