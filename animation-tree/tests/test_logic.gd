extends Node

# Drives the real BlendDriver from scripts/blend_driver.gd, then checks the tree
# the driver builds.
#
# mutate-driver: skip — the scene is instantiated to inspect a real AnimationTree, not to test main.gd
#
# A blend that twitches, snaps or maps the wrong speeds is not a picture anyone
# can look at and judge. It is three numbers, and all three can be stated.

var _pass := 0
var _fail := 0
var _checked := false

const WALK := 2.0
const RUN := 6.0

func _ready() -> void:
	test_standing_still_is_idle()
	test_the_idle_deadzone()
	test_walking_speed_is_the_walk_point()
	test_running_speed_is_the_run_point()
	test_between_the_points()
	test_the_blend_never_leaves_the_space()
	test_degenerate_speeds()
	test_the_blend_chases_rather_than_snaps()
	test_smoothing_is_frame_rate_independent()
	test_snapping()
	test_the_dominant_clip()
	test_the_time_scale()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[animation-tree] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_standing_still_is_idle() -> void:
	print("standing")
	expect(is_zero_approx(BlendDriver.position_for(0.0, WALK, RUN)), "no speed is the idle point")

func test_the_idle_deadzone() -> void:
	print("the deadzone")
	# A character standing still is never exactly still: a stick drifts, a body
	# settles, a slope nudges. Without a deadzone the idle clip flickers into
	# the walk clip several times a second.
	expect(is_zero_approx(BlendDriver.position_for(0.05, WALK, RUN)),
		"a twitch below the threshold is still idle")
	expect(BlendDriver.position_for(0.4, WALK, RUN) > 0.0, "while real movement is not")
	# And the first moving frame starts from the threshold, not from zero speed,
	# so it does not begin a quarter of the way into a walk.
	expect(BlendDriver.position_for(0.2, WALK, RUN) < 0.1,
		"movement just past the threshold is barely a walk")

func test_walking_speed_is_the_walk_point() -> void:
	print("walking")
	expect(is_equal_approx(BlendDriver.position_for(WALK, WALK, RUN), 1.0),
		"walking speed lands exactly on the walk clip")

func test_running_speed_is_the_run_point() -> void:
	print("running")
	expect(is_equal_approx(BlendDriver.position_for(RUN, WALK, RUN), 2.0),
		"running speed lands exactly on the run clip")

func test_between_the_points() -> void:
	print("in between")
	var half := BlendDriver.position_for((WALK + RUN) * 0.5, WALK, RUN)
	expect(absf(half - 1.5) < 0.001, "halfway between walk and run is halfway between the clips")
	var jog := BlendDriver.position_for(WALK * 0.5, WALK, RUN)
	expect(jog > 0.0 and jog < 1.0, "and half walking speed is between idle and walk")

func test_the_blend_never_leaves_the_space() -> void:
	print("the range")
	# The blend space runs 0..2. A position outside it is clamped by the tree,
	# but a caller that produces one has already lost track of what the numbers
	# mean.
	expect(is_equal_approx(BlendDriver.position_for(100.0, WALK, RUN), 2.0),
		"a speed past running is still the run clip")
	expect(BlendDriver.position_for(-5.0, WALK, RUN) == 0.0,
		"and a negative speed is idle rather than off the end")

func test_degenerate_speeds() -> void:
	print("degenerate speeds")
	expect(not is_nan(BlendDriver.position_for(1.0, 0.0, 0.0)),
		"walk and run speeds of zero do not divide by zero")
	expect(BlendDriver.position_for(3.0, 4.0, 2.0) >= 0.0,
		"and a run speed below the walk speed still produces a position")
	# Someone types the two numbers in the wrong order eventually. The guard
	# keeps run strictly above walk, so a fast character still reads as running
	# rather than folding back into the walk it has already passed.
	expect(is_equal_approx(BlendDriver.position_for(10.0, 4.0, 2.0), 2.0),
		"a speed well above both blends to a full run, not back to a walk")

func test_the_blend_chases_rather_than_snaps() -> void:
	print("chasing")
	var driver := BlendDriver.new()
	# Speed can change instantly; a gait cannot, or the legs change between one
	# frame and the next.
	var first := driver.update(RUN, WALK, RUN, 1.0 / 60.0)
	expect(first > 0.0, "the blend starts moving toward the new speed")
	expect(first < 2.0, "without arriving in a single frame")
	for i in 120:
		driver.update(RUN, WALK, RUN, 1.0 / 60.0)
	expect(absf(driver.blend() - 2.0) < 0.01, "and gets there given a couple of seconds")

func test_smoothing_is_frame_rate_independent() -> void:
	print("frame rate")
	var one := BlendDriver.new()
	var two := BlendDriver.new()
	var whole := one.update(RUN, WALK, RUN, 0.1)
	two.update(RUN, WALK, RUN, 0.05)
	var halves := two.update(RUN, WALK, RUN, 0.05)
	expect(absf(whole - halves) < 0.001, "two half-steps land where one whole step does")
	var instant := BlendDriver.new()
	instant.smoothing = 0.0
	expect(is_equal_approx(instant.update(RUN, WALK, RUN, 0.016), 2.0),
		"and a smoothing of zero arrives at once rather than never")

func test_snapping() -> void:
	print("snapping")
	var driver := BlendDriver.new()
	expect(is_equal_approx(driver.snap(RUN, WALK, RUN), 2.0), "snapping goes straight there")
	driver.reset()
	expect(is_zero_approx(driver.blend()), "and reset puts it back to idle")

func test_the_dominant_clip() -> void:
	print("which clip")
	expect(BlendDriver.dominant_clip(0.2) == "idle", "near zero, idle is doing the work")
	expect(BlendDriver.dominant_clip(1.0) == "walk", "at one, the walk")
	expect(BlendDriver.dominant_clip(1.9) == "run", "and near two, the run")

func test_the_time_scale() -> void:
	print("foot sliding")
	# If the walk clip was authored at 2 m/s and the character moves at 3, the
	# feet slide. Scaling playback to the ratio is what most "foot sliding"
	# fixes actually are.
	expect(is_equal_approx(BlendDriver.time_scale_for(3.0, 2.0), 1.5),
		"moving half as fast again plays the clip half as fast again")
	expect(is_equal_approx(BlendDriver.time_scale_for(2.0, 2.0), 1.0),
		"and matching the clip's own speed plays it as authored")
	expect(BlendDriver.time_scale_for(100.0, 2.0) <= 1.8,
		"with a ceiling, so a sprint does not become a blur")
	expect(is_equal_approx(BlendDriver.time_scale_for(1.0, 0.0), 1.0),
		"a clip with no authored speed is played as-is rather than dividing by zero")

# --- the real tree ---------------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real tree")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var tree: AnimationTree = scene.get_node("AnimationTree")
	var player: AnimationPlayer = scene.get_node("AnimationPlayer")

	expect(player.get_animation_list().size() == 3, "the driver built three clips")
	var space := tree.tree_root as AnimationNodeBlendSpace1D
	expect(space != null, "and a blend space to mix them")
	expect(space.get_blend_point_count() == 3, "with a point per clip")
	expect(is_equal_approx(space.get_blend_point_position(2), 2.0),
		"the last of them at the far end of the space")
	# An inactive tree is the commonest reason a correctly built one does
	# nothing at all.
	expect(tree.active, "the tree is active")
	expect(not tree.anim_player.is_empty(), "and knows which player holds its clips")

	tree.set("parameters/blend_position", 1.5)
	expect(is_equal_approx(float(tree.get("parameters/blend_position")), 1.5),
		"the blend position is a parameter, set by path")

	scene.queue_free()
	_report()
