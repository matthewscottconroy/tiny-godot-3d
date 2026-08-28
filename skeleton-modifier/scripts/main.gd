extends Node3D

# Demo driver. A skeleton built in code, a looping idle written in code, and a
# head-look hung off the skeleton as a SkeletonModifier3D. The arithmetic is in
# scripts/aim_constraint.gd; the modifier itself is scripts/head_look.gd.
#
# size-exempt: three scripts, because the subject is the boundary between them —
# the maths, the modifier node Godot calls at the right moment, and a driver that
# has to build a skeleton *and* an animation before there is an ordering problem
# to demonstrate at all.

@onready var _skeleton: Skeleton3D = $Character/Skeleton
@onready var _modifier: SkeletonModifier3D = $Character/Skeleton/HeadLook
@onready var _player: AnimationPlayer = $Character/Player
@onready var _target: MeshInstance3D = $Target
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

const BONES := [
	["hips", -1, Vector3(0, 0.9, 0)],
	["chest", 0, Vector3(0, 0.4, 0)],
	["head", 1, Vector3(0, 0.35, 0)],
]

var _wanted_influence := 1.0
var _time := 0.0
var _bones: Array[MeshInstance3D] = []

func _ready() -> void:
	_hint.text = "L look on or off   1/2 how far the head can turn   Space stop the target   R reset"
	_build_skeleton()
	_build_idle()
	_player.play(&"idle")
	_modifier.set("target", _target)
	_modifier.influence = 1.0

func _build_skeleton() -> void:
	for entry in BONES:
		var index := _skeleton.add_bone(entry[0])
		_skeleton.set_bone_parent(index, entry[1])
		_skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, entry[2]))
		_skeleton.set_bone_pose_position(index, entry[2])
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.16 if entry[0] != "head" else 0.2
		capsule.height = 0.42
		mesh.mesh = capsule
		_skeleton.add_child(mesh)
		_bones.append(mesh)

## Something for the modifier to run *after*. Without an animation writing the
## pose there is nothing to fight over, and the whole point is the ordering.
func _build_idle() -> void:
	var animation := Animation.new()
	animation.length = 2.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, "Skeleton:chest")
	animation.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
	animation.rotation_track_insert_key(track, 1.0, Quaternion(Vector3.UP, 0.5))
	animation.rotation_track_insert_key(track, 2.0, Quaternion.IDENTITY)
	var library := AnimationLibrary.new()
	library.add_animation(&"idle", animation)
	_player.add_animation_library(&"", library)

func _process(delta: float) -> void:
	if not Input.is_action_pressed(&"ui_select"):
		_time += delta
		_target.position = Vector3(sin(_time * 0.8) * 3.0, 1.6 + sin(_time * 0.5) * 0.6,
			cos(_time * 0.8) * 3.0)
	# Faded rather than switched: a head that snaps to a target and snaps back
	# reads as a glitch, whatever the aim itself is doing.
	_modifier.influence = AimConstraint.fade(_modifier.influence, _wanted_influence, delta)
	# The bone meshes are not skinned to anything, so they are posed by hand. A
	# real character has a mesh with weights and needs none of this.
	for i in _bones.size():
		_bones[i].transform = _skeleton.get_bone_global_pose(i)
	_show()

func _show() -> void:
	# Read off the modifier's own last pass. A pose written by a modifier is gone
	# by the time anything else looks, so recomputing it here would report a
	# different number from the one the character is actually posed with.
	var limit: float = _modifier.get("limit")
	var to_target: Vector3 = _modifier.get("last_to_target")
	var forward: Vector3 = (_modifier.get("last_animated") as Quaternion) * Vector3.FORWARD
	var wanted := AimConstraint.aim(forward, to_target).get_angle()
	var reach := "within reach" if AimConstraint.within_reach(forward, to_target, limit) \
		else "out of reach — the head turns as far as it can and no further"
	_readout.text = "influence %.2f (heading for %.0f)   the head can turn %.2f rad (%.0f°)\nthe target is %.2f rad (%.0f°) off where the head points\n%s" % [
		_modifier.influence, _wanted_influence, limit, rad_to_deg(limit),
		wanted, rad_to_deg(wanted), reach]
	_status.text = "the modifier runs after the animation, every frame, because Godot calls it there"

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_L:
			_wanted_influence = 0.0 if _wanted_influence > 0.5 else 1.0
		KEY_1:
			_modifier.set("limit", maxf(_modifier.get("limit") - 0.1, 0.1))
		KEY_2:
			_modifier.set("limit", minf(_modifier.get("limit") + 0.1, PI))
		KEY_R:
			_wanted_influence = 1.0
			_modifier.set("limit", 1.1)
			_time = 0.0
		_:
			return
