extends Node3D

# Demo driver. Builds a skeleton at startup, hangs a mesh off every bone with a
# BoneAttachment3D, and curls the whole thing toward a moving target.

const BONES := 7
const BONE_LENGTH := 0.55

@onready var _skeleton: Skeleton3D = $Rig/Skeleton3D
@onready var _target: Node3D = $Target
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _bones := PackedInt32Array()
var _strength := 0.9
var _falloff := 1.0
var _time := 0.0
var _following := true

func _ready() -> void:
	_hint.text = "1/2 strength   3/4 falloff (tip or root)   Space stop following   R relax"
	_bones = SkeletonRig.build_chain(_skeleton, BONES, BONE_LENGTH)
	_attach_meshes()

## A mesh per bone, via BoneAttachment3D.
##
## The attachment follows its bone's pose every frame, which is how anything
## that is not skinned — a weapon, a hat, a segment of shell — rides a skeleton.
func _attach_meshes() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.16
	mesh.height = BONE_LENGTH
	for i in _bones.size():
		var attachment := BoneAttachment3D.new()
		attachment.bone_idx = _bones[i]
		_skeleton.add_child(attachment)

		var segment := MeshInstance3D.new()
		segment.mesh = mesh
		# Half a bone along, so the capsule spans from this joint to the next.
		segment.position = Vector3.UP * BONE_LENGTH * 0.5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(0.55 - float(i) * 0.03, 0.5, 0.9)
		segment.material_override = material
		attachment.add_child(segment)

func _process(delta: float) -> void:
	if _following:
		_time += delta
	_target.position = Vector3(sin(_time * 0.7) * 3.0, 2.0 + cos(_time * 0.5) * 1.2,
		cos(_time * 0.9) * 1.5)

	# The target has to arrive in the skeleton's space, not the world's.
	var local_target := _skeleton.global_transform.affine_inverse() * _target.global_position
	SkeletonRig.curl(_skeleton, _bones, local_target, _strength, _falloff)

	var tip := SkeletonRig.tip_of(_skeleton, _bones[_bones.size() - 1], BONE_LENGTH)
	var reach := _skeleton.to_global(tip).distance_to(_target.global_position)
	_status.text = "%d bones   strength %.2f   falloff %.2f   tip is %.2f m from the target" % [
		_skeleton.get_bone_count(), _strength, _falloff, reach]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _strength = maxf(_strength - 0.1, 0.0)
		KEY_2: _strength = minf(_strength + 0.1, 1.0)
		KEY_3: _falloff = maxf(_falloff - 0.25, 0.25)
		KEY_4: _falloff = minf(_falloff + 0.25, 3.0)
		KEY_SPACE: _following = not _following
		KEY_R: SkeletonRig.relax(_skeleton, _bones)
		_: return
