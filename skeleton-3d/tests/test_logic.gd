extends Node

# Drives the real SkeletonRig from scripts/skeleton_rig.gd against real
# Skeleton3D nodes.
#
# mutate-driver: skip — the scene is instantiated to inspect a real Skeleton3D, not to test main.gd
#
# A Skeleton3D needs no rendering, so all of this runs headless — which is worth
# knowing, because "skeletons can only be checked by looking at them" is why so
# much rig code goes untested.

var _pass := 0
var _fail := 0
var _checked := false

const LENGTH := 0.5

func _ready() -> void:
	test_building_a_chain()
	test_bones_are_parented_in_order()
	test_rests_are_relative_to_the_parent()
	test_global_rests_accumulate()
	test_building_nothing()
	test_bending_toward_an_aligned_direction()
	test_bending_partway()
	test_bending_is_clamped()
	test_bending_to_the_exact_opposite()
	test_bending_with_nothing_to_bend_toward()
	test_curling_moves_the_tip_toward_the_target()
	test_relaxing_puts_it_back()
	test_the_tip_of_a_bone()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[skeleton-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	add_child(skeleton)
	return skeleton

func test_building_a_chain() -> void:
	print("building")
	var skeleton := _skeleton()
	var bones := SkeletonRig.build_chain(skeleton, 4, LENGTH)
	expect(bones.size() == 4, "four bones were asked for and four were made")
	expect(skeleton.get_bone_count() == 4, "and the skeleton agrees")
	expect(skeleton.get_bone_name(bones[0]) == "bone_0", "each one is named")

func test_bones_are_parented_in_order() -> void:
	print("parenting")
	var skeleton := _skeleton()
	var bones := SkeletonRig.build_chain(skeleton, 4, LENGTH)
	expect(skeleton.get_bone_parent(bones[0]) == -1, "the root bone has no parent")
	expect(skeleton.get_bone_parent(bones[1]) == bones[0], "and each other hangs off the one before")
	expect(skeleton.get_bone_parent(bones[3]) == bones[2], "all the way down the chain")

func test_rests_are_relative_to_the_parent() -> void:
	print("rests")
	var skeleton := _skeleton()
	var bones := SkeletonRig.build_chain(skeleton, 3, LENGTH)
	# Each bone is one length from its *parent*, not from the origin. Writing
	# absolute offsets here builds a chain that stretches as it goes.
	expect(skeleton.get_bone_rest(bones[0]).origin.is_equal_approx(Vector3.ZERO),
		"the root rests at the skeleton's origin")
	expect(is_equal_approx(skeleton.get_bone_rest(bones[1]).origin.y, LENGTH),
		"and every other bone one length from its parent")
	expect(is_equal_approx(skeleton.get_bone_rest(bones[2]).origin.y, LENGTH),
		"the same for every link, however far down it is")

func test_global_rests_accumulate() -> void:
	print("global rests")
	var skeleton := _skeleton()
	var bones := SkeletonRig.build_chain(skeleton, 4, LENGTH)
	var last := skeleton.get_bone_global_pose(bones[3]).origin
	expect(is_equal_approx(last.y, LENGTH * 3.0),
		"the fourth bone sits three lengths up, because the parents add up")

func test_building_nothing() -> void:
	print("degenerate builds")
	var skeleton := _skeleton()
	expect(SkeletonRig.build_chain(skeleton, 0, LENGTH).is_empty(),
		"a chain of no bones is empty rather than an error")
	expect(SkeletonRig.build_chain(null, 3, LENGTH).is_empty(),
		"and building on nothing gives nothing")
	var flat := _skeleton()
	var bones := SkeletonRig.build_chain(flat, 2, LENGTH, Vector3.ZERO)
	expect(bones.size() == 2, "an axis of zero is replaced rather than collapsing the chain")
	expect(flat.get_bone_rest(bones[1]).origin.length() > 0.0, "with the bones still apart")

func test_bending_toward_an_aligned_direction() -> void:
	print("no bend needed")
	expect(SkeletonRig.bend_toward(Vector3.UP, Vector3.UP, 1.0).is_equal_approx(Quaternion.IDENTITY),
		"a bone already pointing at the target does not rotate")

func test_bending_partway() -> void:
	print("partial bends")
	var full := SkeletonRig.bend_toward(Vector3.UP, Vector3.RIGHT, 1.0)
	var half := SkeletonRig.bend_toward(Vector3.UP, Vector3.RIGHT, 0.5)
	expect(absf(full.get_angle() - PI * 0.5) < 0.001, "a full-strength bend turns the whole way")
	expect(absf(half.get_angle() - PI * 0.25) < 0.001, "and half strength turns half of it")
	expect(SkeletonRig.bend_toward(Vector3.UP, Vector3.RIGHT, 0.0).is_equal_approx(
		Quaternion.IDENTITY), "no strength is no rotation")

func test_bending_is_clamped() -> void:
	print("limits")
	var limited := SkeletonRig.bend_toward(Vector3.UP, Vector3.DOWN, 1.0, 0.3)
	expect(absf(limited.get_angle() - 0.3) < 0.001, "a bend past the limit stops at the limit")

func test_bending_to_the_exact_opposite() -> void:
	print("opposite directions")
	# Every axis perpendicular to the bone is a valid answer here, and the cross
	# product that normally supplies one is zero. A NAN would put the bone
	# somewhere no rendering can show.
	var flipped := SkeletonRig.bend_toward(Vector3.UP, Vector3.DOWN, 1.0)
	expect(not is_nan(flipped.x), "turning exactly backwards produces a real rotation")
	expect(absf(flipped.get_angle() - PI) < 0.01, "of half a turn")

func test_bending_with_nothing_to_bend_toward() -> void:
	print("degenerate bends")
	expect(SkeletonRig.bend_toward(Vector3.ZERO, Vector3.UP, 1.0).is_equal_approx(
		Quaternion.IDENTITY), "a zero-length direction bends nothing")
	expect(SkeletonRig.bend_toward(Vector3.UP, Vector3.ZERO, 1.0).is_equal_approx(
		Quaternion.IDENTITY), "at either end")

func test_curling_moves_the_tip_toward_the_target() -> void:
	print("curling")
	var skeleton := _skeleton()
	var bones := SkeletonRig.build_chain(skeleton, 5, LENGTH)
	var target := Vector3(2.0, 1.0, 0.0)
	var before := SkeletonRig.tip_of(skeleton, bones[4], LENGTH).distance_to(target)
	SkeletonRig.curl(skeleton, bones, target, 0.9)
	var after := SkeletonRig.tip_of(skeleton, bones[4], LENGTH).distance_to(target)
	expect(after < before, "curling brings the tip closer to the target (%.2f -> %.2f)"
		% [before, after])
	# Poses are local to the parent, so a chain that curls has every bone
	# rotated a little rather than the root rotated a lot.
	var rotated := 0
	for bone in bones:
		if skeleton.get_bone_pose_rotation(bone).get_angle() > 0.01:
			rotated += 1
	expect(rotated >= 3, "with the bend spread along the chain rather than all at one joint")

	# A target off to one side at the base's own height, so "toward the target"
	# and "along the chain" point in obviously different directions. A curl that
	# adds the bone's position instead of subtracting it bends up rather than
	# across, and the tip never arrives.
	var sideways := _skeleton()
	var side_bones := SkeletonRig.build_chain(sideways, 5, LENGTH)
	var side_target := Vector3(LENGTH * 3.0, 0.0, 0.0)
	SkeletonRig.curl(sideways, side_bones, side_target, 1.0)
	var tip := SkeletonRig.tip_of(sideways, side_bones[4], LENGTH)
	expect(tip.x > LENGTH * 1.5, "a target to the side pulls the tip to that side (%.2f)" % tip.x)
	expect(tip.y < LENGTH * 3.0, "rather than leaving it standing upright")

func test_relaxing_puts_it_back() -> void:
	print("relaxing")
	var skeleton := _skeleton()
	var bones := SkeletonRig.build_chain(skeleton, 4, LENGTH)
	SkeletonRig.curl(skeleton, bones, Vector3(2, 1, 0), 1.0)
	SkeletonRig.relax(skeleton, bones)
	var straight := true
	for bone in bones:
		if skeleton.get_bone_pose_rotation(bone).get_angle() > 0.001:
			straight = false
	expect(straight, "relaxing returns every bone to its rest pose")
	# Rest is not pose: relaxing clears the pose and leaves the rest alone.
	expect(is_equal_approx(skeleton.get_bone_rest(bones[1]).origin.y, LENGTH),
		"and leaves the rests exactly where they were")

func test_the_tip_of_a_bone() -> void:
	print("tips")
	var skeleton := _skeleton()
	var bones := SkeletonRig.build_chain(skeleton, 2, LENGTH)
	expect(is_equal_approx(SkeletonRig.tip_of(skeleton, bones[1], LENGTH).y, LENGTH * 2.0),
		"the tip of the second bone is two lengths up")
	expect(SkeletonRig.tip_of(skeleton, 99, LENGTH) == Vector3.ZERO,
		"a bone that does not exist has no tip rather than an error")
	expect(SkeletonRig.tip_of(skeleton, -1, LENGTH) == Vector3.ZERO,
		"nor does a negative index")
	expect(SkeletonRig.tip_of(null, 0, LENGTH) == Vector3.ZERO,
		"and neither does a skeleton that is not there")

# --- the real rig ----------------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real rig")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var skeleton: Skeleton3D = scene.get_node("Rig/Skeleton3D")
	expect(skeleton.get_bone_count() == 7, "the driver built its skeleton at startup")

	var attachments := 0
	for child in skeleton.get_children():
		var attachment := child as BoneAttachment3D
		# A BoneAttachment3D is how anything unskinned rides a skeleton: it
		# copies its bone's pose every frame.
		if attachment != null and attachment.bone_idx >= 0:
			attachments += 1
	expect(attachments == 7, "with a BoneAttachment3D per bone to hang meshes off")

	scene.queue_free()
	_report()
