extends Node

# Drives the real Shake from scripts/shake.gd.
#
# Shake is the archetypal "looks fine, is wrong" system: any random offset looks
# like shake. What is checkable is the shape — that it always ends, that it never
# exceeds its limits, that a big hit is bigger than a small one, and that two
# runs of the same game shake identically.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_nothing_shakes_at_rest()
	test_adding_trauma_starts_it()
	test_trauma_is_clamped()
	test_trauma_decays_to_nothing()
	test_the_response_is_squared()
	test_offsets_stay_within_their_limits()
	test_rotation_shakes_too()
	test_the_offset_actually_moves()
	test_it_is_deterministic()
	test_different_seeds_differ()
	test_no_time_no_change()
	test_negative_trauma_is_ignored()
	test_resetting()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[camera-shake-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const STEP := 1.0 / 60.0

func test_nothing_shakes_at_rest() -> void:
	print("at rest")
	var shake := Shake.new(1)
	expect(shake.offset() == Vector3.ZERO, "an untouched camera does not move")
	expect(shake.rotation_offset() == Vector3.ZERO, "or rotate")
	expect(not shake.is_shaking(), "and knows it is still")

func test_adding_trauma_starts_it() -> void:
	print("starting")
	var shake := Shake.new(1)
	shake.add(0.5)
	shake.advance(STEP)
	expect(shake.is_shaking(), "trauma starts the shake")
	expect(shake.offset() != Vector3.ZERO, "and the camera moves")

func test_trauma_is_clamped() -> void:
	print("the ceiling")
	var shake := Shake.new(1)
	for i in 20:
		shake.add(0.5)
	# Repeated hits accumulate to a ceiling rather than multiplying. Without
	# this, a firefight makes the camera unwatchable.
	expect(is_equal_approx(shake.trauma(), 1.0), "trauma stops at one however much arrives")

func test_trauma_decays_to_nothing() -> void:
	print("decay")
	var shake := Shake.new(1)
	shake.add(1.0)
	for i in 120:
		shake.advance(STEP)
	# A shake that does not end is a shake someone has to remember to stop.
	expect(is_zero_approx(shake.trauma()), "two seconds later there is no trauma left")
	expect(shake.offset() == Vector3.ZERO, "and no offset at all — exactly zero, not nearly")
	var slow := Shake.new(1)
	slow.decay = 0.4
	slow.add(1.0)
	for i in 60:
		slow.advance(STEP)
	expect(slow.trauma() > 0.0, "a slower decay is still going after the same time")

func test_the_response_is_squared() -> void:
	print("the curve")
	var small := Shake.new(1)
	small.add(0.5)
	var large := Shake.new(1)
	large.add(1.0)
	# trauma², so twice the trauma is four times the shake: small hits stay
	# subtle and big ones land, from one number.
	expect(is_equal_approx(small.shake_amount(), 0.25), "half trauma is a quarter of the shake")
	expect(is_equal_approx(large.shake_amount(), 1.0), "full trauma is all of it")

func test_offsets_stay_within_their_limits() -> void:
	print("limits")
	var shake := Shake.new(3)
	shake.decay = 0.0                      # hold it at full trauma
	shake.add(1.0)
	var worst := 0.0
	var worst_roll := 0.0
	for i in 600:
		shake.advance(STEP)
		var offset := shake.offset()
		worst = maxf(worst, maxf(absf(offset.x), absf(offset.y)))
		worst_roll = maxf(worst_roll, absf(shake.rotation_offset().z))
	expect(worst <= shake.max_offset + 0.0001, "the camera never moves further than max_offset")
	expect(worst_roll <= shake.max_roll + 0.0001, "nor rolls further than max_roll")
	expect(worst > shake.max_offset * 0.3, "while using a decent part of the range")

func test_rotation_shakes_too() -> void:
	print("rotation")
	var shake := Shake.new(2)
	shake.add(1.0)
	shake.advance(STEP)
	# Rotation sells a shake better than translation, and cannot push the
	# camera through a wall.
	expect(shake.rotation_offset() != Vector3.ZERO, "there is a rotational component")
	expect(shake.rotation_offset().length() < 1.0, "and it is small — this is a shake, not a spin")

func test_the_offset_actually_moves() -> void:
	print("movement")
	var shake := Shake.new(5)
	shake.decay = 0.0
	shake.add(1.0)
	shake.advance(0.1)
	var first := shake.offset()
	shake.advance(0.1)
	var second := shake.offset()
	expect(not first.is_equal_approx(second), "the offset changes from frame to frame")

func test_it_is_deterministic() -> void:
	print("determinism")
	var a := Shake.new(11)
	var b := Shake.new(11)
	a.add(1.0)
	b.add(1.0)
	for i in 10:
		a.advance(STEP)
		b.advance(STEP)
	# A replay, a test and two players in a networked game all have to shake the
	# same way. randf() here would make every one of those impossible.
	expect(a.offset().is_equal_approx(b.offset()), "the same seed shakes the same way")

func test_different_seeds_differ() -> void:
	print("seeds")
	var a := Shake.new(11)
	var b := Shake.new(12)
	a.add(1.0)
	b.add(1.0)
	a.advance(0.2)
	b.advance(0.2)
	expect(not a.offset().is_equal_approx(b.offset()), "a different seed shakes differently")

func test_no_time_no_change() -> void:
	print("zero delta")
	var shake := Shake.new(1)
	shake.add(0.8)
	shake.advance(0.0)
	expect(is_equal_approx(shake.trauma(), 0.8), "no time passing decays nothing")
	var before := shake.offset()
	shake.advance(0.0)
	expect(shake.offset().is_equal_approx(before), "and moves nothing")

func test_negative_trauma_is_ignored() -> void:
	print("negative input")
	var shake := Shake.new(1)
	shake.add(0.5)
	shake.add(-2.0)
	expect(is_equal_approx(shake.trauma(), 0.5),
		"a negative hit is ignored rather than cancelling the shake")

func test_resetting() -> void:
	print("reset")
	var shake := Shake.new(1)
	shake.add(1.0)
	shake.advance(0.3)
	shake.reset()
	expect(is_zero_approx(shake.trauma()), "reset clears the trauma")
	expect(shake.offset() == Vector3.ZERO, "and the offset with it — for a cutscene or a respawn")
