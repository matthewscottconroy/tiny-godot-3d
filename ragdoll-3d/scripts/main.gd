extends Node3D

# Demo driver. A skeleton built in code, physical bones hung off it, and the two
# transitions that matter. The bookkeeping is in scripts/ragdoll.gd.
#
# size-exempt: this demo has to build both skeletons — the animated one and the
# physical one hung off it — before there is anything to hand over between, and
# the ordering trap in _build_physical_bones() is one of the lessons. Shipping a
# .glb with a rig in it would be shorter and would teach nothing.

@onready var _character: Node3D = $Character
@onready var _skeleton: Skeleton3D = $Character/Skeleton
## Physical bones hang off a simulator, not off the skeleton itself.
var _simulator: PhysicalBoneSimulator3D = null
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

## Bone name, parent index, offset from the parent, and how long the limb is.
const SKELETON := [
	["hips", -1, Vector3(0, 1.1, 0), 0.3],
	["chest", 0, Vector3(0, 0.35, 0), 0.35],
	["head", 1, Vector3(0, 0.35, 0), 0.22],
	["arm_l", 1, Vector3(-0.3, 0.2, 0), 0.5],
	["arm_r", 1, Vector3(0.3, 0.2, 0), 0.5],
	["leg_l", 0, Vector3(-0.15, -0.4, 0), 0.55],
	["leg_r", 0, Vector3(0.15, -0.4, 0), 0.55],
]

var _ragdoll := Ragdoll.new()
var _bones: Array[PhysicalBone3D] = []
var _pose_time := 0.0
var _velocity := Vector3(0, 0, -3.0)

func _ready() -> void:
	_hint.text = "Space hit it   G get up   1/2 the shove   R reset"
	_build_skeleton()
	_build_physical_bones()

func _build_skeleton() -> void:
	for entry in SKELETON:
		var index := _skeleton.add_bone(entry[0])
		_skeleton.set_bone_parent(index, entry[1])
		_skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, entry[2]))
		_skeleton.set_bone_pose_position(index, entry[2])

## A capsule per bone, jointed to its parent. In a real project this is what the
## editor's "Create physical skeleton" button generates.
func _build_physical_bones() -> void:
	# Created *after* the bones exist. A PhysicalBoneSimulator3D caches the
	# skeleton's bone list when it enters the tree, so one that was already there
	# binds every physical bone against an empty list and errors once per bone —
	# the first thing that happens when this is built in code rather than with
	# the editor's button.
	_simulator = PhysicalBoneSimulator3D.new()
	_skeleton.add_child(_simulator)
	for i in SKELETON.size():
		var entry: Array = SKELETON[i]
		var bone := PhysicalBone3D.new()
		bone.name = "Physical_%s" % entry[0]
		bone.bone_name = entry[0]
		bone.mass = 2.0
		bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE if entry[1] >= 0 \
			else PhysicalBone3D.JOINT_TYPE_NONE

		var length := maxf(float(entry[3]), 0.25)
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.12
		capsule.height = length
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		bone.add_child(shape)

		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.12
		capsule_mesh.height = length
		var mesh := MeshInstance3D.new()
		mesh.mesh = capsule_mesh
		bone.add_child(mesh)
		_simulator.add_child(bone)
		_bones.append(bone)

func _physics_process(delta: float) -> void:
	if not _ragdoll.is_simulating():
		_animate(delta)
	elif _ragdoll.observe(_fastest_body(), delta):
		# The fastest body, not the average: an arm still flailing is not a
		# character ready to stand up.
		_status.text = "settled — press G to get up"
	_ragdoll.advance_recovery(delta)
	_show()

## A breathing idle, so there is a pose to hand over *from*.
func _animate(delta: float) -> void:
	_pose_time += delta
	var weight := _ragdoll.animation_weight()
	for i in SKELETON.size():
		var rest: Vector3 = SKELETON[i][2]
		var swing := sin(_pose_time * 2.0 + float(i)) * 0.06
		var posed := rest + Vector3(0, swing, 0)
		# Blended, not snapped: coming back from physics, the animation starts
		# from where the bodies left the pose.
		_skeleton.set_bone_pose_position(i, _skeleton.get_bone_pose_position(i).lerp(posed, weight))

func hit(impulse: Vector3) -> void:
	if _ragdoll.is_simulating():
		return
	# Start the bodies from the pose, not from the rest pose: a simulation that
	# begins from rest snaps the character into a T-shape for one frame, which is
	# the most recognisable ragdoll bug there is.
	_simulator.physical_bones_start_simulation()
	_ragdoll.go_limp()
	for bone in _bones:
		# And with the character's momentum in them, or a character shot while
		# sprinting drops straight down instead of falling forwards.
		bone.linear_velocity = Ragdoll.launch_velocity(_velocity, impulse, bone.mass)

func get_up() -> void:
	if not _ragdoll.is_simulating():
		return
	_simulator.physical_bones_stop_simulation()
	_ragdoll.recover()

func _fastest_body() -> float:
	var speeds: Array[float] = []
	for bone in _bones:
		speeds.append(bone.linear_velocity.length())
	return Ragdoll.fastest(speeds)

func _show() -> void:
	var top := _fastest_body()
	var names := ["animated", "simulating", "recovering"]
	_readout.text = "%s   animation is %.0f%% in charge\n%d physical bones, fastest moving at %.2f m/s\nsettles below %.2f m/s held for %.1f s" % [
		names[_ragdoll.state()], _ragdoll.animation_weight() * 100.0,
		_bones.size(), top, _ragdoll.settle_speed, _ragdoll.settle_time]
	if _ragdoll.state() != Ragdoll.State.SIMULATING:
		_status.text = "shove %.1f m/s   character momentum %.1f m/s" % [
			_velocity.length(), _velocity.length()]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			hit(Vector3(0, 2.0, -6.0))
		KEY_G:
			get_up()
		KEY_1:
			_velocity = _velocity.normalized() * maxf(_velocity.length() - 1.0, 0.0)
		KEY_2:
			_velocity = Vector3(0, 0, -1).normalized() * (_velocity.length() + 1.0)
		KEY_R:
			_simulator.physical_bones_stop_simulation()
			_ragdoll.reset()
			_character.position = Vector3.ZERO
		_:
			return
