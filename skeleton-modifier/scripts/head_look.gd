extends SkeletonModifier3D

# A head-look, as a SkeletonModifier3D.
#
# The whole reason this is a modifier rather than a script that pokes the
# skeleton from _process(): Godot calls `_process_modification()` at the point in
# the skeleton's update where the animation has written its pose and nothing has
# drawn it yet. Anywhere else is a race with the AnimationMixer.

@export var bone_name := "head"
@export var target: Node3D = null
## How far the head can turn before it gives up, in radians.
@export var limit := 1.1

var _bone := -1

## What the last pass saw and did. A pose written by a modifier does not survive
## into a later frame's `get_bone_pose_rotation()` — the skeleton resets and
## reapplies the animation before each pass — so this is the only honest way to
## observe the modifier from outside it.
var calls := 0
var last_animated := Quaternion.IDENTITY
var last_turn := Quaternion.IDENTITY
var last_to_target := Vector3.ZERO

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or target == null:
		return
	if _bone == -1:
		_bone = skeleton.find_bone(bone_name)
		if _bone == -1:
			return

	# The pose the animation just wrote — not the rest pose, which is what makes
	# a character straighten up whenever the modifier is active.
	var animated := skeleton.get_bone_pose_rotation(_bone)
	calls += 1
	last_animated = animated

	# Everything in the parent bone's space, and nothing in any other. The target
	# is in the world, the pose is local to the parent, and mixing the two is why
	# a head-look works while the character faces one way and not another.
	var parent := skeleton.get_bone_parent(_bone)
	var parent_global := skeleton.global_transform
	if parent != -1:
		parent_global = skeleton.global_transform * skeleton.get_bone_global_pose(parent)
	var target_local := parent_global.affine_inverse() * target.global_position
	var to_target := target_local - skeleton.get_bone_pose_position(_bone)

	# The bone's forward, also in the parent's space.
	var forward := animated * Vector3.FORWARD
	var turn := AimConstraint.aim_within(forward, to_target, limit)
	last_turn = turn
	last_to_target = to_target
	skeleton.set_bone_pose_rotation(_bone,
		AimConstraint.blended(animated, turn * animated, influence))
