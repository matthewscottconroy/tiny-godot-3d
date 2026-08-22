extends Node

# Drives the real FirstPersonRig from scripts/first_person_rig.gd.
#
# Everything here is a number a player would feel and a screenshot would not
# show: which way the mouse turns you, where the pitch limit is, whether walking
# while looking down walks you into the floor, and how far the head travels per
# step.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_mouse_right_turns_right()
	test_mouse_up_looks_up()
	test_pitch_is_clamped_short_of_vertical()
	test_yaw_is_not_clamped()
	test_sensitivity_scales_the_look()
	test_forward_follows_yaw()
	test_forward_ignores_pitch()
	test_strafing_is_perpendicular()
	test_no_input_is_no_direction()
	test_diagonals_do_not_go_faster()
	test_the_head_starts_at_rest()
	test_the_head_bobs_as_you_walk()
	test_the_bob_repeats_every_stride()
	test_the_bob_stays_within_its_amplitude()
	test_standing_still_does_not_bob()
	test_a_zero_stride_does_not_divide_by_zero()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[first-person-controller] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

# --- looking ---------------------------------------------------------------

func test_mouse_right_turns_right() -> void:
	print("turning")
	var rig := FirstPersonRig.new()
	rig.look(Vector2(100.0, 0.0))
	# Yaw decreases as you turn right, because Godot's Y rotation is
	# counter-clockwise seen from above.
	expect(rig.yaw < 0.0, "moving the mouse right turns right")
	var after := rig.yaw
	rig.look(Vector2(-100.0, 0.0))
	expect(rig.yaw > after, "and moving it left turns back")
	expect(is_zero_approx(rig.yaw), "exactly back, for an equal and opposite movement")

func test_mouse_up_looks_up() -> void:
	print("looking up")
	var rig := FirstPersonRig.new()
	# Screen Y grows downward, so "up" is a negative delta. Getting this the
	# wrong way round is inverted look — fine as an option, a bug as a default.
	rig.look(Vector2(0.0, -100.0))
	expect(rig.pitch > 0.0, "moving the mouse up raises the view")
	rig.look(Vector2(0.0, 200.0))
	expect(rig.pitch < 0.0, "and pushing it down lowers it past level")

func test_pitch_is_clamped_short_of_vertical() -> void:
	print("pitch limits")
	var rig := FirstPersonRig.new()
	rig.look(Vector2(0.0, -100000.0))
	expect(is_equal_approx(rig.pitch, rig.max_pitch), "looking up stops at max_pitch")
	expect(rig.max_pitch < PI / 2.0, "which is short of straight up, where the basis degenerates")
	rig.look(Vector2(0.0, 100000.0))
	expect(is_equal_approx(rig.pitch, rig.min_pitch), "and looking down stops at min_pitch")
	expect(rig.min_pitch > -PI / 2.0, "short of straight down for the same reason")

func test_yaw_is_not_clamped() -> void:
	print("spinning")
	var rig := FirstPersonRig.new()
	for i in 100:
		rig.look(Vector2(500.0, 0.0))
	expect(absf(rig.yaw) > TAU, "you can keep turning past a full circle")

func test_sensitivity_scales_the_look() -> void:
	print("sensitivity")
	var slow := FirstPersonRig.new()
	var fast := FirstPersonRig.new()
	fast.sensitivity = slow.sensitivity * 3.0
	slow.look(Vector2(0.0, -100.0))
	fast.look(Vector2(0.0, -100.0))
	expect(is_equal_approx(fast.pitch, slow.pitch * 3.0),
		"three times the sensitivity is three times the movement")

# --- walking ---------------------------------------------------------------

func test_forward_follows_yaw() -> void:
	print("facing")
	var rig := FirstPersonRig.new()
	expect(rig.forward().is_equal_approx(Vector3(0, 0, -1)),
		"at rest, forward is -Z, which is where a Godot camera looks")
	rig.yaw = PI / 2.0
	expect(rig.forward().is_equal_approx(Vector3(-1, 0, 0)),
		"a quarter turn left faces -X")
	expect(is_equal_approx(rig.forward().length(), 1.0), "forward is always a unit vector")

func test_forward_ignores_pitch() -> void:
	print("pitch and movement")
	var rig := FirstPersonRig.new()
	rig.pitch = -1.2                       # looking at the floor
	expect(is_zero_approx(rig.forward().y), "looking down does not tilt the walking direction")
	var direction := rig.movement_direction(Vector2(0.0, -1.0))
	expect(is_zero_approx(direction.y), "so walking forward stays on the ground plane")

func test_strafing_is_perpendicular() -> void:
	print("strafing")
	var rig := FirstPersonRig.new()
	rig.yaw = 0.9
	expect(absf(rig.forward().dot(rig.right())) < 0.0001, "right is perpendicular to forward")
	expect(is_zero_approx(rig.right().y), "and flat, so strafing never climbs")
	var strafe := rig.movement_direction(Vector2(1.0, 0.0))
	expect(strafe.is_equal_approx(rig.right()), "a pure right input strafes exactly right")

func test_no_input_is_no_direction() -> void:
	print("no input")
	var rig := FirstPersonRig.new()
	expect(rig.movement_direction(Vector2.ZERO) == Vector3.ZERO,
		"no input is a zero direction, not a normalised NaN")

func test_diagonals_do_not_go_faster() -> void:
	print("diagonals")
	var rig := FirstPersonRig.new()
	var diagonal := rig.movement_direction(Vector2(1.0, -1.0))
	expect(is_equal_approx(diagonal.length(), 1.0),
		"forward and right together is still one unit, not 1.41")

# --- head bob --------------------------------------------------------------

func test_the_head_starts_at_rest() -> void:
	print("at rest")
	var rig := FirstPersonRig.new()
	expect(rig.head_offset() == Vector3.ZERO,
		"before walking, the head is exactly where the scene puts it")
	expect(is_zero_approx(rig.travelled()), "and nothing has been walked")

func test_the_head_bobs_as_you_walk() -> void:
	print("bobbing")
	var rig := FirstPersonRig.new()
	rig.advance(rig.stride * 0.125)        # a quarter of the way to the first peak
	expect(is_equal_approx(rig.head_offset().y, rig.bob_height),
		"an eighth of a stride in, the head is at the top of its rise")
	expect(rig.head_offset().x > 0.0, "and has swayed to one side")
	rig.advance(rig.stride * 0.5)
	expect(rig.head_offset().x < 0.0, "half a stride later it has swayed to the other")

func test_the_bob_repeats_every_stride() -> void:
	print("stride")
	var rig := FirstPersonRig.new()
	rig.advance(rig.stride * 3.0)
	expect(rig.head_offset().is_equal_approx(Vector3.ZERO),
		"a whole number of strides puts the head back at centre")
	# Twice per stride vertically, once horizontally: the head rises on each
	# footfall but only leans onto alternate feet.
	rig.reset()
	rig.advance(rig.stride * 0.5)
	expect(is_zero_approx(rig.head_offset().y), "the vertical bob has completed a full cycle")
	expect(absf(rig.head_offset().x) < 0.0001, "and the sway is at its own half-way point")

func test_the_bob_stays_within_its_amplitude() -> void:
	print("amplitude")
	var rig := FirstPersonRig.new()
	var worst_y := 0.0
	var worst_x := 0.0
	for i in 400:
		rig.advance(0.02)
		worst_y = maxf(worst_y, absf(rig.head_offset().y))
		worst_x = maxf(worst_x, absf(rig.head_offset().x))
	expect(worst_y <= rig.bob_height + 0.0001, "the rise never exceeds bob_height")
	expect(worst_x <= rig.bob_sway + 0.0001, "nor the sway bob_sway")
	expect(worst_y > rig.bob_height * 0.99, "while actually reaching it")

func test_standing_still_does_not_bob() -> void:
	print("standing still")
	var rig := FirstPersonRig.new()
	rig.advance(rig.stride * 0.125)
	var moving := rig.head_offset()
	rig.advance(0.0)
	expect(rig.head_offset().is_equal_approx(moving), "no distance covered is no change")
	# Falling should not bob either, which is why the driver passes horizontal
	# distance rather than the whole velocity.
	rig.advance(-5.0)
	expect(rig.head_offset().is_equal_approx(moving), "and neither does a negative distance")

func test_a_zero_stride_does_not_divide_by_zero() -> void:
	print("degenerate stride")
	var rig := FirstPersonRig.new()
	rig.stride = 0.0
	rig.advance(2.0)
	expect(rig.head_offset() == Vector3.ZERO, "a stride of zero turns the bob off")
