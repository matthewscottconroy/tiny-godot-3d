extends Node

# Drives the real RootStep from scripts/root_step.gd, and then walks the real
# character with a real AnimationTree — because "the animation moves the
# character" is a claim about the engine, not about arithmetic.
#
# mutate-driver: skip — the scene is instantiated to read a real AnimationTree's root motion, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _start := Vector3.ZERO

func _ready() -> void:
	test_the_step_is_local()
	test_the_step_follows_the_facing()
	test_velocity_divides_rather_than_multiplies()
	test_a_zero_delta()
	test_the_speed_the_clip_asks_for()
	test_an_idle_clip_is_not_moving()
	test_matching_the_stride_to_a_speed()
	test_the_playback_scale_is_clamped()
	test_blending_with_input()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[root-motion] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_step_is_local() -> void:
	print("local space")
	var step := Vector3(0, 0, -0.02)
	expect(RootStep.world_step(step, Basis.IDENTITY).is_equal_approx(step),
		"facing forward, the step is unchanged")

func test_the_step_follows_the_facing() -> void:
	print("facing")
	var step := Vector3(0, 0, -0.02)
	var turned := Basis(Vector3.UP, PI * 0.5)
	var world := RootStep.world_step(step, turned)
	# Turn the character and the same clip pushes a different way. A clip applied
	# in world space walks north for ever, whatever the character is doing.
	expect(absf(world.x + 0.02) < 0.0001, "turned a quarter turn, the same clip walks along -X")
	expect(absf(world.z) < 0.0001, "and no longer along Z at all")

func test_velocity_divides_rather_than_multiplies() -> void:
	print("velocity")
	var step := Vector3(0, 0, -0.02)
	# The value is already the distance for this frame. Multiplying by delta a
	# second time gives motion that is right at 60fps and eight times slower at 8.
	var velocity := RootStep.velocity_for(step, Basis.IDENTITY, 1.0 / 60.0)
	expect(is_equal_approx(velocity.z, -1.2), "0.02 m in a 60th of a second is 1.2 m/s")
	var slower := RootStep.velocity_for(step * 2.0, Basis.IDENTITY, 1.0 / 30.0)
	expect(is_equal_approx(slower.z, -1.2),
		"and the same speed at half the frame rate, because the step is twice as long")

func test_a_zero_delta() -> void:
	print("degenerate delta")
	expect(RootStep.velocity_for(Vector3.ONE, Basis.IDENTITY, 0.0) == Vector3.ZERO,
		"a zero delta gives no velocity rather than an infinite one")
	expect(is_zero_approx(RootStep.clip_speed(Vector3.ONE, 0.0)),
		"and no speed either")

func test_the_speed_the_clip_asks_for() -> void:
	print("clip speed")
	expect(is_equal_approx(RootStep.clip_speed(Vector3(0, 0, -0.02), 1.0 / 60.0), 1.2),
		"a 2cm step at 60fps is a 1.2 m/s walk")

func test_an_idle_clip_is_not_moving() -> void:
	print("idle")
	# An idle clip's root does not sit perfectly still — it breathes — so this is
	# a threshold rather than a comparison with zero.
	expect(not RootStep.is_moving(Vector3(0, 0.0001, 0)), "a breathing idle is not walking")
	expect(RootStep.is_moving(Vector3(0, 0, -0.01)), "and a step is")

func test_matching_the_stride_to_a_speed() -> void:
	print("matching the stride")
	# The honest way to go faster: play the walk quicker, so the feet still land
	# where the movement says they do.
	expect(is_equal_approx(RootStep.playback_scale(1.2, 2.4), 2.0),
		"wanting twice the clip's speed means playing it twice as fast")
	expect(is_equal_approx(RootStep.playback_scale(1.2, 1.2), 1.0),
		"and wanting exactly its speed means leaving it alone")

func test_the_playback_scale_is_clamped() -> void:
	print("scale limits")
	expect(is_equal_approx(RootStep.playback_scale(1.2, 100.0), 2.0),
		"a walk played eighty times over is a blur, so the scale has a ceiling")
	expect(is_equal_approx(RootStep.playback_scale(1.2, 0.0), 0.5), "and a floor")
	expect(is_equal_approx(RootStep.playback_scale(0.0, 2.0), 1.0),
		"and a clip that does not move cannot be scaled to a speed at all")

func test_blending_with_input() -> void:
	print("authority")
	var clip := Vector3(0, 0, -1.0)
	var input := Vector3(1.0, 0, 0)
	expect(RootStep.blend(clip, input, 1.0).is_equal_approx(clip),
		"full authority is pure root motion")
	expect(RootStep.blend(clip, input, 0.0).is_equal_approx(input),
		"none of it is an ordinary character controller")
	var half := RootStep.blend(clip, input, 0.5)
	expect(half.x > 0.0 and half.z < 0.0,
		"and half of it is a locked animation the player can still steer")
	expect(RootStep.blend(clip, input, 5.0).is_equal_approx(clip),
		"authority outside 0..1 is clamped rather than extrapolated")

# --- the real animation tree -----------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real walker")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			_start = (_scene.get_node("Walker") as CharacterBody3D).global_position
		40:
			_check_the_walker()
			_report()

func _check_the_walker() -> void:
	var walker: CharacterBody3D = _scene.get_node("Walker")
	var tree: AnimationTree = _scene.get_node("Walker/Rig/Tree")
	var root: Node3D = _scene.get_node("Walker/Rig/Root")
	var moved := _start.distance_to(walker.global_position)

	expect(tree.root_motion_track != NodePath(),
		"the tree has been told which track carries the motion")
	expect(moved > 0.2, "the character travelled because the animation did (%.2f m)" % moved)
	# Forward is -Z, and the clip walks forward.
	expect(walker.global_position.z < _start.z - 0.2,
		"in the direction the clip walks, not some other one")

	# The root is put back every frame: its travel has already been handed to the
	# character, and leaving it where the clip put it moves the walker twice.
	expect(root.position.length() < 0.001,
		"and the rig's root is back at the origin rather than metres ahead of it")

	# The other claim worth checking: reading the motion consumes it.
	var first := tree.get_root_motion_position()
	var second := tree.get_root_motion_position()
	expect(second.length() <= first.length(),
		"reading the motion twice in one frame does not give it to you twice")
