extends Node3D

# Demo driver. A motorised hinge door and a hanging chain, both held together by
# joints rather than by animation.

const CHAIN_LINKS := 6
const LINK_SPACING := 0.5

@onready var _hinge: HingeJoint3D = $Hinge
@onready var _door: RigidBody3D = $Door
@onready var _anchor: StaticBody3D = $ChainAnchor
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _control := HingeControl.new()
var _target := 0.0
var _links: Array[RigidBody3D] = []

func _ready() -> void:
	_hint.text = "1 close   2 open   3 halfway   Space shove the door   the chain is PinJoint3Ds"
	# The joint's limits and the controller's have to be the same numbers. Two
	# places that must agree is one place too many, so they are set from here.
	_hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	_hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, _control.min_angle)
	_hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, _control.max_angle)
	_hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	_hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 12.0)
	_build_chain()

## A chain of rigid bodies, each pinned to the one above it.
##
## PinJoint3D constrains a point, not an orientation — which is exactly what a
## chain link is, and why a chain built out of hinges swings like a ladder.
func _build_chain() -> void:
	var previous: PhysicsBody3D = _anchor
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	var shape := SphereShape3D.new()
	shape.radius = 0.16

	for i in CHAIN_LINKS:
		var link := RigidBody3D.new()
		link.position = _anchor.position + Vector3.DOWN * (LINK_SPACING * (i + 1))
		var view := MeshInstance3D.new()
		view.mesh = mesh
		var collider := CollisionShape3D.new()
		collider.shape = shape
		link.add_child(view)
		link.add_child(collider)
		add_child(link)

		var joint := PinJoint3D.new()
		# The joint sits at the point being held: halfway between the two bodies.
		joint.position = link.position + Vector3.UP * (LINK_SPACING * 0.5)
		add_child(joint)
		# node_a and node_b are NodePaths, and they must be set after both
		# bodies are in the tree — a joint that cannot resolve a path silently
		# constrains nothing.
		joint.node_a = joint.get_path_to(previous)
		joint.node_b = joint.get_path_to(link)

		_links.append(link)
		previous = link

func _physics_process(_delta: float) -> void:
	var angle := _door.rotation.y
	var velocity := _control.drive_toward(angle, _target)
	_hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, velocity)

	var swing := 0.0
	for link in _links:
		swing = maxf(swing, link.linear_velocity.length())

	_status.text = "door %.0f°  target %.0f°  motor %.2f  %s%s   chain swing %.2f m/s" % [
		rad_to_deg(angle), rad_to_deg(_target), velocity,
		"open" if _control.is_open(angle) else "shut",
		" (at a limit)" if _control.at_limit(angle) else "",
		swing]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _target = _control.min_angle
		KEY_2: _target = _control.max_angle
		KEY_3: _target = (_control.min_angle + _control.max_angle) * 0.5
		KEY_SPACE:
			# A shove, not a teleport: the solver integrates it, and the motor
			# then has to argue the door back to where it was told to be.
			_door.apply_impulse(Vector3(0, 0, -3.0), Vector3(0.9, 0, 0))
		_: return
