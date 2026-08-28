extends Node

# Drives the real AimConstraint from scripts/aim_constraint.gd, and then runs the
# real modifier on a real skeleton with a real animation playing — because the
# claim worth checking is about *ordering*, and ordering cannot be tested by
# calling a function.
#
# mutate-driver: skip — the scene is instantiated to run a real SkeletonModifier3D, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_aiming_at_what_you_already_face()
	test_aiming_sideways()
	test_aiming_exactly_backwards()
	test_aiming_along_the_axis_it_would_pick()
	test_aiming_at_nothing()
	test_the_turn_is_limited()
	test_a_turn_inside_the_limit_is_untouched()
	test_the_limited_turn_keeps_its_axis()
	test_knowing_when_to_give_up()
	test_blending_from_the_animated_pose()
	test_influence_is_clamped()
	test_fading_is_frame_rate_independent()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[skeleton-modifier] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_aiming_at_what_you_already_face() -> void:
	print("already facing it")
	var rotation := AimConstraint.aim(Vector3.FORWARD, Vector3.FORWARD)
	expect(rotation.get_angle() < 0.001, "aiming at what you already face turns nothing")

func test_aiming_sideways() -> void:
	print("sideways")
	var rotation := AimConstraint.aim(Vector3.FORWARD, Vector3.RIGHT)
	expect(absf(rotation.get_angle() - PI * 0.5) < 0.001, "a right angle is a quarter turn")
	expect((rotation * Vector3.FORWARD).is_equal_approx(Vector3.RIGHT),
		"and applying it points forward at the target")

func test_aiming_exactly_backwards() -> void:
	print("backwards")
	# The degenerate case: the cross product is zero, so an axis has to be
	# chosen rather than computed, and the naive version returns a NaN.
	var rotation := AimConstraint.aim(Vector3.FORWARD, Vector3.BACK)
	expect(not is_nan(rotation.x), "turning exactly backwards produces a real rotation")
	expect(absf(rotation.get_angle() - PI) < 0.01, "of half a turn")
	expect((rotation * Vector3.FORWARD).is_equal_approx(Vector3.BACK),
		"and it does face backwards afterwards")

func test_aiming_along_the_axis_it_would_pick() -> void:
	print("straight up and down")
	# The other degenerate case: turning from straight up to straight down. The
	# cross product with UP is zero as well, so the fallback axis needs a
	# fallback of its own.
	var rotation := AimConstraint.aim(Vector3.UP, Vector3.DOWN)
	expect(not is_nan(rotation.x), "turning from up to down produces a real rotation")
	expect(absf(rotation.get_angle() - PI) < 0.01, "of half a turn")
	expect((rotation * Vector3.UP).is_equal_approx(Vector3.DOWN),
		"and it does end up pointing down")

func test_aiming_at_nothing() -> void:
	print("nothing to aim at")
	# Each guard on its own, with the other input perfectly valid: a single
	# condition covering both is a condition that only needs one of them.
	var no_target := AimConstraint.aim(Vector3.FORWARD, Vector3.ZERO)
	expect(no_target.is_equal_approx(Quaternion.IDENTITY),
		"a target on top of the bone turns nothing rather than producing a NaN")
	var no_forward := AimConstraint.aim(Vector3.ZERO, Vector3.RIGHT)
	expect(no_forward.is_equal_approx(Quaternion.IDENTITY),
		"and neither does a bone with no forward direction")
	expect(AimConstraint.aim_within(Vector3.FORWARD, Vector3.ZERO, 1.0)
		.is_equal_approx(Quaternion.IDENTITY),
		"and the limited version says the same")

func test_the_turn_is_limited() -> void:
	print("the limit")
	# A head that can rotate 180 degrees to look behind is an owl.
	var limited := AimConstraint.aim_within(Vector3.FORWARD, Vector3.BACK, 0.8)
	expect(absf(limited.get_angle() - 0.8) < 0.001,
		"a turn past the limit stops at the limit (%.3f)" % limited.get_angle())

func test_a_turn_inside_the_limit_is_untouched() -> void:
	print("inside the limit")
	var small := AimConstraint.aim(Vector3.FORWARD, Vector3(0.3, 0, -1))
	var limited := AimConstraint.aim_within(Vector3.FORWARD, Vector3(0.3, 0, -1), 1.5)
	expect(absf(limited.get_angle() - small.get_angle()) < 0.001,
		"a turn inside the limit is left exactly as it was")

func test_the_limited_turn_keeps_its_axis() -> void:
	print("which way it turns")
	# Clamped as an angle, not by clamping the result: the head still turns
	# *toward* the target, just not all the way.
	var limited := AimConstraint.aim_within(Vector3.FORWARD, Vector3.RIGHT, 0.4)
	var pointed := limited * Vector3.FORWARD
	expect(pointed.x > 0.0, "the head turns toward the target, as far as it may")
	expect(pointed.z < 0.0, "without having got there")

func test_knowing_when_to_give_up() -> void:
	print("out of reach")
	# A head that gives up and faces front is better than one straining sideways
	# at its limit for ever.
	expect(AimConstraint.within_reach(Vector3.FORWARD, Vector3(0.2, 0, -1), 1.0),
		"something nearly ahead is within reach")
	expect(not AimConstraint.within_reach(Vector3.FORWARD, Vector3.BACK, 1.0),
		"and something directly behind is not")

func test_blending_from_the_animated_pose() -> void:
	print("blending")
	var animated := Quaternion(Vector3.UP, 0.5)
	var aimed := Quaternion(Vector3.UP, 1.5)
	# From the animated pose, not from rest. Fading in from rest makes the
	# character straighten up as the modifier arrives.
	expect(AimConstraint.blended(animated, aimed, 0.0).is_equal_approx(animated),
		"no influence leaves the animation exactly as it was")
	expect(AimConstraint.blended(animated, aimed, 1.0).is_equal_approx(aimed),
		"full influence is the aim")
	var half := AimConstraint.blended(animated, aimed, 0.5)
	expect(half.get_angle() > animated.get_angle() and half.get_angle() < aimed.get_angle(),
		"and half way is between the two (%.3f)" % half.get_angle())

func test_influence_is_clamped() -> void:
	print("influence limits")
	var animated := Quaternion(Vector3.UP, 0.5)
	var aimed := Quaternion(Vector3.UP, 1.5)
	expect(AimConstraint.blended(animated, aimed, 3.0).is_equal_approx(aimed),
		"an influence above one is full influence, not an extrapolation past the target")
	expect(AimConstraint.blended(animated, aimed, -1.0).is_equal_approx(animated),
		"and below zero is none")

func test_fading_is_frame_rate_independent() -> void:
	print("fading")
	var one_step := AimConstraint.fade(0.0, 1.0, 0.1)
	var ten_steps := 0.0
	for i in 10:
		ten_steps = AimConstraint.fade(ten_steps, 1.0, 0.01)
	expect(absf(one_step - ten_steps) < 0.01,
		"the same time in one step or ten arrives at the same place (%.3f, %.3f)"
			% [one_step, ten_steps])
	expect(AimConstraint.fade(0.5, 1.0, 0.0) == 0.5, "and no time at all changes nothing")

# --- the real modifier -----------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			print("the real modifier")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		6:
			_check_it_is_a_modifier()
		10:
			_check_it_beats_the_animation()
		14:
			_check_the_aim_is_exact()
		20:
			_check_the_modifier_guards()
		24:
			_check_influence_turns_it_off()
			_report()

func _skeleton() -> Skeleton3D:
	return _scene.get_node("Character/Skeleton")

func _head_direction() -> Vector3:
	var skeleton := _skeleton()
	var head := skeleton.find_bone("head")
	return (skeleton.get_bone_global_pose(head).basis * Vector3.FORWARD).normalized()

func _check_it_is_a_modifier() -> void:
	var modifier: SkeletonModifier3D = _scene.get_node("Character/Skeleton/HeadLook")
	expect(modifier is SkeletonModifier3D, "the head-look is a SkeletonModifier3D")
	# A modifier has to be a child of the skeleton it modifies, and Godot finds
	# the skeleton for it. One parented elsewhere silently does nothing.
	expect(modifier.get_skeleton() == _skeleton(),
		"and Godot gave it the skeleton it is parented to")
	expect(_scene.get_node("Character/Player").is_playing(),
		"with an animation playing, so there is a pose to run after")

## What the modifier actually promises, checked from inside its own pass.
##
## A pose written by a modifier is gone by the next frame: the skeleton resets
## the pose and reapplies the animation before every pass, so reading
## `get_bone_pose_rotation()` from a `_process()` shows the animation's pose and
## not the modifier's. That is exactly why this has to be a modifier and not a
## script — and it is why the modifier records what it did.
func _check_it_beats_the_animation() -> void:
	var modifier: SkeletonModifier3D = _scene.get_node("Character/Skeleton/HeadLook")
	var limit: float = modifier.get("limit")

	expect(modifier.get("calls") > 0,
		"Godot called the modifier (%d times so far)" % modifier.get("calls"))

	# It ran *after* the animation: the chest track is turning, and the head's
	# pose the modifier read is the animated one rather than the rest pose.
	var chest := _skeleton().get_bone_pose_rotation(_skeleton().find_bone("chest"))
	expect(chest.get_angle() > 0.001,
		"with the animation having written the chest first (%.3f rad)" % chest.get_angle())

	var turn: Quaternion = modifier.get("last_turn")
	expect(turn.get_angle() > 0.01, "and it turned the head (%.2f rad)" % turn.get_angle())
	expect(turn.get_angle() <= limit + 0.001,
		"by no more than its limit (%.2f of %.2f)" % [turn.get_angle(), limit])

	# Toward the target — worked out here from the target's own world position,
	# not read back off the modifier. Asking the code where it thought the target
	# was and then checking it turned that way proves nothing at all.
	var skeleton := _skeleton()
	var head := skeleton.find_bone("head")
	var parent := skeleton.get_bone_parent(head)
	var parent_global := skeleton.global_transform
	if parent != -1:
		parent_global = skeleton.global_transform * skeleton.get_bone_global_pose(parent)
	var target: Node3D = _scene.get_node("Target")
	var to_target := (parent_global.affine_inverse() * target.global_position
		- skeleton.get_bone_pose_position(head)).normalized()
	var animated: Quaternion = modifier.get("last_animated")
	var before := (animated * Vector3.FORWARD).normalized()
	var after := (turn * animated * Vector3.FORWARD).normalized()
	expect(after.dot(to_target) > before.dot(to_target),
		"and toward it rather than away (%.3f, was %.3f)"
			% [after.dot(to_target), before.dot(to_target)])

## With the target close and well inside the limit, the aim should be *exact* —
## which is the only assertion that catches aiming from the wrong origin, or in
## the wrong bone's space. "It turned roughly that way" survives both, because a
## target three metres off forgives a lot.
func _check_the_aim_is_exact() -> void:
	var modifier: SkeletonModifier3D = _scene.get_node("Character/Skeleton/HeadLook")
	var target: Node3D = _scene.get_node("Target")
	var skeleton := _skeleton()
	var head := skeleton.find_bone("head")

	# Stop the target wandering and put it just off the head's forward, near
	# enough that the offset between the head and its parent matters.
	_scene.set("_time", 0.0)
	Input.action_press(&"ui_select")
	target.global_position = (skeleton.global_transform
		* skeleton.get_bone_global_pose(head)).origin + Vector3(0.35, 0.0, -1.0)
	await get_tree().process_frame
	await get_tree().process_frame

	var turn: Quaternion = modifier.get("last_turn")
	var animated: Quaternion = modifier.get("last_animated")
	var limit: float = modifier.get("limit")
	expect(turn.get_angle() < limit - 0.05,
		"the target is inside the limit, so the aim is not clamped (%.2f of %.2f)"
			% [turn.get_angle(), limit])

	# Where the head ends up pointing, against where the target actually is —
	# both worked out here, in the parent bone's space, from the scene.
	var parent := skeleton.get_bone_parent(head)
	var parent_global := skeleton.global_transform
	if parent != -1:
		parent_global = skeleton.global_transform * skeleton.get_bone_global_pose(parent)
	var wanted := (parent_global.affine_inverse() * target.global_position
		- skeleton.get_bone_pose_position(head)).normalized()
	var pointed := (turn * animated * Vector3.FORWARD).normalized()
	var error := acos(clampf(pointed.dot(wanted), -1.0, 1.0))
	expect(error < 0.05,
		"and the head points at it to within a twentieth of a radian (%.3f)" % error)
	Input.action_release(&"ui_select")

## The modifier's own guards, driven through it rather than around it.
func _check_the_modifier_guards() -> void:
	var modifier: SkeletonModifier3D = _scene.get_node("Character/Skeleton/HeadLook")
	var before: int = modifier.get("calls")

	# The bone index is looked up once and cached. A cache that never fills is a
	# modifier that reads bone -1 every frame.
	expect(modifier.get("_bone") >= 0,
		"the modifier resolved its bone (index %d)" % modifier.get("_bone"))
	expect(modifier.get("_bone") == _skeleton().find_bone("head"),
		"and it is the head")

	# A bone name nothing in the rig has — a renamed bone, a rig swapped for
	# another. The modifier has to do nothing rather than read bone -1.
	modifier.set("bone_name", "no_such_bone")
	modifier.set("_bone", -1)
	await get_tree().process_frame
	await get_tree().process_frame
	expect(modifier.get("_bone") == -1, "a bone name nothing has leaves the modifier unresolved")
	modifier.set("bone_name", "head")
	modifier.set("_bone", -1)
	await get_tree().process_frame
	expect(modifier.get("_bone") >= 0, "and naming a real one resolves it again")

	# No target: the pass has to return before it aims at the origin.
	modifier.set("target", null)
	await get_tree().process_frame
	var turn_without: Quaternion = modifier.get("last_turn")
	modifier.set("target", _scene.get_node("Target"))
	await get_tree().process_frame
	expect(modifier.get("calls") > before, "the modifier kept being called throughout")
	expect(turn_without.is_equal_approx(modifier.get("last_turn")) == false
		or turn_without.is_equal_approx(Quaternion.IDENTITY),
		"and a pass with no target aimed at nothing rather than at the origin")

func _check_influence_turns_it_off() -> void:
	var modifier: SkeletonModifier3D = _scene.get_node("Character/Skeleton/HeadLook")
	# Influence at zero leaves the animation's pose untouched, which is what
	# makes a modifier fadeable rather than a switch. The turn is still computed;
	# it is the blend that drops it.
	modifier.influence = 0.0
	_scene.set("_wanted_influence", 0.0)
	var animated: Quaternion = modifier.get("last_animated")
	var turn: Quaternion = modifier.get("last_turn")
	expect(AimConstraint.blended(animated, turn * animated, 0.0).is_equal_approx(animated),
		"at no influence the modifier leaves the animation exactly as it was")
	expect(not AimConstraint.blended(animated, turn * animated, 1.0).is_equal_approx(animated),
		"and at full influence it does not")
