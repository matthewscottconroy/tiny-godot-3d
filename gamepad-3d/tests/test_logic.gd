extends Node

# Drives the real StickInput from scripts/stick_input.gd.
#
# This is the demo whose subject is hardware nobody has in CI, so the tests
# matter more than usual: every assertion here is a stick position fed in by
# hand, and the whole point is the shapes a square deadzone gets wrong.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_a_resting_stick_is_zero()
	test_the_deadzone_is_round_not_square()
	test_leaving_the_deadzone_does_not_jump()
	test_full_deflection_is_one()
	test_the_magnitude_is_never_over_one()
	test_direction_survives_the_deadzone()
	test_a_degenerate_deadzone()
	test_the_curve_leaves_direction_alone()
	test_a_curve_of_one_changes_nothing()
	test_a_higher_exponent_softens_small_pushes()
	test_triggers_have_the_same_two_problems()
	test_the_world_direction_follows_the_camera()
	test_the_world_direction_keeps_the_magnitude()
	test_no_input_is_no_direction()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[gamepad-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

# --- the deadzone ----------------------------------------------------------

func test_a_resting_stick_is_zero() -> void:
	print("at rest")
	expect(StickInput.deadzone(Vector2.ZERO) == Vector2.ZERO, "a centred stick is zero")
	# What a real stick reports when nobody is touching it.
	expect(StickInput.deadzone(Vector2(0.05, -0.07)) == Vector2.ZERO,
		"and so is the drift a stick reports while resting")

func test_the_deadzone_is_round_not_square() -> void:
	print("round, not square")
	# The case a per-axis deadzone gets wrong. Both axes are under 0.18, so
	# `if abs(x) < 0.18: x = 0` on each would zero this — while the stick is
	# 24% deflected diagonally, and the player is definitely pushing it.
	var diagonal := Vector2(0.17, 0.17)
	expect(diagonal.length() > StickInput.DEFAULT_INNER, "the test case really is outside the zone")
	expect(StickInput.deadzone(diagonal) != Vector2.ZERO,
		"a diagonal push past the radius registers, though neither axis alone does")
	# And the reverse: a single axis just inside the radius must not register.
	expect(StickInput.deadzone(Vector2(0.17, 0.0)) == Vector2.ZERO,
		"while the same value on one axis alone does not")

func test_leaving_the_deadzone_does_not_jump() -> void:
	print("no jump")
	# Without rescaling, the first movement outside the deadzone is at 18% speed
	# — the character goes from standing still to a brisk walk with no way to
	# move slowly, which is most of what an analogue stick is for.
	var just_outside := StickInput.deadzone(Vector2(StickInput.DEFAULT_INNER + 0.01, 0.0))
	expect(just_outside.length() < 0.05, "just past the edge moves barely at all")
	expect(just_outside.length() > 0.0, "but it does move")
	var halfway := StickInput.deadzone(Vector2(
		(StickInput.DEFAULT_INNER + StickInput.DEFAULT_OUTER) * 0.5, 0.0))
	expect(absf(halfway.length() - 0.5) < 0.02, "halfway between the limits is half speed")

func test_full_deflection_is_one() -> void:
	print("full push")
	expect(is_equal_approx(StickInput.deadzone(Vector2(1.0, 0.0)).length(), 1.0),
		"a stick pushed to its stop is full speed")
	expect(is_equal_approx(StickInput.deadzone(Vector2(StickInput.DEFAULT_OUTER, 0.0)).length(), 1.0),
		"and so is one at the outer limit, which is short of the stop on purpose")

func test_the_magnitude_is_never_over_one() -> void:
	print("clamping")
	# Sticks over-report at the corners: a diagonal can measure past 1.0, and a
	# character that moves 1.4x faster diagonally is the oldest bug in games.
	var corner := StickInput.deadzone(Vector2(1.0, 1.0))
	expect(corner.length() <= 1.0001, "a corner push is not faster than a straight one")
	expect(corner.length() > 0.99, "while still being full speed")

func test_direction_survives_the_deadzone() -> void:
	print("direction")
	var raw := Vector2(0.6, -0.3)
	var out := StickInput.deadzone(raw)
	expect(out.normalized().is_equal_approx(raw.normalized()),
		"the deadzone changes how far, never which way")

func test_a_degenerate_deadzone() -> void:
	print("degenerate limits")
	expect(StickInput.deadzone(Vector2(0.5, 0.0), 0.9, 0.5) == Vector2.ZERO,
		"an inner limit past the outer one gives nothing rather than a negative speed")

# --- the response curve ----------------------------------------------------

func test_the_curve_leaves_direction_alone() -> void:
	print("curve direction")
	var value := Vector2(0.3, 0.4)
	expect(StickInput.curve(value, 2.0).normalized().is_equal_approx(value.normalized()),
		"the curve bends magnitude, not aim")

func test_a_curve_of_one_changes_nothing() -> void:
	print("no curve")
	var value := Vector2(0.5, 0.0)
	expect(StickInput.curve(value, 1.0).is_equal_approx(value),
		"an exponent of one is the identity")
	expect(StickInput.curve(Vector2.ZERO, 2.0) == Vector2.ZERO, "and zero stays zero")
	# A nonsense exponent leaves the input alone rather than swallowing it: a
	# misconfigured curve should feel wrong, not disable the controls.
	expect(StickInput.curve(value, 0.0).is_equal_approx(value),
		"an exponent of zero passes the stick through untouched")
	expect(StickInput.curve(value, -2.0).is_equal_approx(value),
		"and so does a negative one")

func test_a_higher_exponent_softens_small_pushes() -> void:
	print("fine control")
	var small := Vector2(0.3, 0.0)
	expect(StickInput.curve(small, 2.0).length() < small.length(),
		"a small push moves less with a curve applied")
	expect(is_equal_approx(StickInput.curve(Vector2(1.0, 0.0), 3.0).length(), 1.0),
		"while a full push is still full — the curve bends the middle, not the ends")

func test_triggers_have_the_same_two_problems() -> void:
	print("triggers")
	expect(is_zero_approx(StickInput.trigger(0.05)), "a resting trigger reads as nothing")
	expect(StickInput.trigger(0.11) < 0.05, "and one just off the stop barely fires")
	expect(is_equal_approx(StickInput.trigger(1.0), 1.0), "a trigger held down is full")
	expect(is_zero_approx(StickInput.trigger(0.5, 1.0)),
		"a deadzone of one leaves nothing rather than dividing by zero")
	expect(is_zero_approx(StickInput.trigger(1.5, 1.0)),
		"and a reading past that deadzone is nothing too, rather than infinity")

# --- into the world --------------------------------------------------------

func test_the_world_direction_follows_the_camera() -> void:
	print("camera relative")
	# Stick up, camera looking down -Z: the character walks away from the camera.
	var forward := StickInput.to_world(Vector2(0.0, -1.0), 0.0)
	expect(forward.z < -0.9, "pushing up walks away from the camera")
	expect(is_zero_approx(forward.y), "and stays on the ground")
	# Turn the camera a quarter turn and the same push goes the other way.
	var turned := StickInput.to_world(Vector2(0.0, -1.0), PI / 2.0)
	expect(turned.x < -0.9, "after a quarter turn, up walks along -X instead")
	var right := StickInput.to_world(Vector2(1.0, 0.0), 0.0)
	expect(right.x > 0.9, "and pushing right strafes right, not left")

func test_the_world_direction_keeps_the_magnitude() -> void:
	print("analogue speed")
	var half := StickInput.to_world(Vector2(0.0, -0.5), 0.0)
	expect(is_equal_approx(half.length(), 0.5),
		"a half-pushed stick is a half-speed walk, not a run")
	var full := StickInput.to_world(Vector2(0.0, -1.0), 0.0)
	expect(is_equal_approx(full.length(), 1.0), "and a full push is a full-speed one")

func test_no_input_is_no_direction() -> void:
	print("no input")
	expect(StickInput.to_world(Vector2.ZERO, 1.2) == Vector3.ZERO,
		"no input is a zero direction rather than a normalised NaN")
