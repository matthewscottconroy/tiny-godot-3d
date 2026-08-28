extends Node3D

# Demo driver. One body on one Generic6DOFJoint3D, reconfigured live from a
# DofSpec. Press through the presets and watch the same joint become a door, a
# drawer, a shoulder and a ball. The axis bookkeeping is in scripts/dof_spec.gd.

@onready var _rig: Node3D = $Rig
@onready var _anchor: StaticBody3D = $Anchor
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

const PRESETS := ["door", "drawer", "shoulder", "ball", "unconstrained", "weld"]

var _body: RigidBody3D = null
var _joint: Generic6DOFJoint3D = null
var _spec := DofSpec.door()
var _preset := 0

func _ready() -> void:
	_hint.text = "1-6 pick a joint   Space shove it   R rebuild"
	_build()

func _build() -> void:
	for child in _rig.get_children():
		child.queue_free()

	_body = RigidBody3D.new()
	_body.mass = 3.0
	_body.position = Vector3(0.8, 3.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.5, 0.5)
	shape.shape = box
	_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	_body.add_child(mesh)
	_rig.add_child(_body)

	_joint = Generic6DOFJoint3D.new()
	_joint.position = _anchor.position
	_rig.add_child(_joint)
	_joint.node_a = _joint.get_path_to(_anchor)
	_joint.node_b = _joint.get_path_to(_body)
	_apply(_spec)

## Writing a spec onto the joint: six axes, each either limited (with bounds) or
## free. There is no "locked" flag — locked is a limit of zero.
func _apply(spec: DofSpec) -> void:
	const LINEAR := [
		Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT,
		Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT]
	const ANGULAR := [
		Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT,
		Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT]
	for axis in 3:
		var bounds := spec.bounds("linear", axis as DofSpec.Axis)
		_set_flag(axis, Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT,
			spec.limit_enabled("linear", axis as DofSpec.Axis))
		_set_param(axis, LINEAR[0], bounds.x)
		_set_param(axis, LINEAR[1], bounds.y)

		var angular := spec.bounds("angular", axis as DofSpec.Axis)
		_set_flag(axis, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT,
			spec.limit_enabled("angular", axis as DofSpec.Axis))
		_set_param(axis, ANGULAR[0], angular.x)
		_set_param(axis, ANGULAR[1], angular.y)
	_show()

func _set_flag(axis: int, flag: int, value: bool) -> void:
	match axis:
		0: _joint.set_flag_x(flag, value)
		1: _joint.set_flag_y(flag, value)
		_: _joint.set_flag_z(flag, value)

func _set_param(axis: int, param: int, value: float) -> void:
	match axis:
		0: _joint.set_param_x(param, value)
		1: _joint.set_param_y(param, value)
		_: _joint.set_param_z(param, value)

func _spec_for(name: String) -> DofSpec:
	match name:
		"drawer": return DofSpec.drawer()
		"shoulder": return DofSpec.shoulder()
		"ball": return DofSpec.ball()
		"unconstrained": return DofSpec.unconstrained()
		"weld": return DofSpec.new()
		_: return DofSpec.door()

func _process(_delta: float) -> void:
	_show()

func _show() -> void:
	_readout.text = "%s — %d of six degrees of freedom%s\n%s\nlocked axes have their limit *enabled* with a range of zero" % [
		PRESETS[_preset], _spec.degrees_of_freedom(),
		"   (a weld: two bodies that could have been one)" if _spec.is_weld() else "",
		_spec.describe()]
	if _body != null:
		_status.text = "body at %.2f, %.2f, %.2f   moving at %.2f m/s" % [
			_body.position.x, _body.position.y, _body.position.z,
			_body.linear_velocity.length()]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + PRESETS.size():
		_preset = key.keycode - KEY_1
		_spec = _spec_for(PRESETS[_preset])
		_apply(_spec)
		return
	match key.keycode:
		KEY_SPACE:
			if _body != null:
				_body.apply_impulse(Vector3(0, 0, -6.0), Vector3(0.6, 0, 0))
		KEY_R:
			_build()
		_:
			return
