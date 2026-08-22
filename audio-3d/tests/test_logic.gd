extends Node

# Drives the real Hearing model from scripts/hearing.gd.
#
# Nothing here listens to anything — a headless run has no audio device. What is
# checkable is the model the game shares with the mixer: how loud a sound is at a
# distance, whether a listener can hear it, and how far it carries. Those are the
# numbers the AI makes decisions with, and they are wrong silently.

var _pass := 0
var _fail := 0

const UNIT := 3.0
const MAX := 30.0

func _ready() -> void:
	test_close_up_is_full_volume()
	test_gain_falls_with_distance()
	test_the_max_distance_is_a_hard_cutoff()
	test_inverse_square_falls_faster_than_inverse()
	test_logarithmic_is_the_gentlest()
	test_disabled_does_not_fall_off_at_all()
	test_standing_on_the_source()
	test_decibels_follow_the_gain()
	test_audibility_has_a_threshold()
	test_better_ears_hear_further()
	test_range_matches_audibility()
	test_doppler_rises_when_approaching()
	test_doppler_is_clamped()
	test_closing_speed()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[audio-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_close_up_is_full_volume() -> void:
	print("up close")
	expect(is_equal_approx(Hearing.gain_at(0.0, UNIT, MAX), 1.0), "at zero distance, full volume")
	expect(is_equal_approx(Hearing.gain_at(UNIT, UNIT, MAX), 1.0),
		"and anywhere inside the unit sphere, which is what unit_size means")

func test_gain_falls_with_distance() -> void:
	print("falling off")
	var near := Hearing.gain_at(6.0, UNIT, MAX)
	var far := Hearing.gain_at(12.0, UNIT, MAX)
	expect(near > far, "further away is quieter")
	expect(is_equal_approx(near, 0.5), "twice the unit size is half the volume, on the inverse model")
	expect(is_equal_approx(far, 0.25), "and four times it is a quarter")

func test_the_max_distance_is_a_hard_cutoff() -> void:
	print("the cutoff")
	expect(is_zero_approx(Hearing.gain_at(MAX, UNIT, MAX)), "at max_distance the sound stops")
	expect(is_zero_approx(Hearing.gain_at(MAX + 50.0, UNIT, MAX)), "and stays stopped past it")
	expect(Hearing.gain_at(MAX - 0.1, UNIT, MAX) > 0.0, "while just inside it is still audible")
	expect(Hearing.gain_at(1000.0, UNIT, 0.0) > 0.0,
		"a max_distance of zero means no cutoff, as the node treats it")

func test_inverse_square_falls_faster_than_inverse() -> void:
	print("inverse square")
	var inverse := Hearing.gain_at(12.0, UNIT, MAX, Hearing.Model.INVERSE)
	var square := Hearing.gain_at(12.0, UNIT, MAX, Hearing.Model.INVERSE_SQUARE)
	expect(square < inverse, "the physically correct model is quieter at distance")
	expect(is_equal_approx(square, 0.0625), "four unit sizes out is a sixteenth")

func test_logarithmic_is_the_gentlest() -> void:
	print("logarithmic")
	var log_gain := Hearing.gain_at(20.0, UNIT, MAX, Hearing.Model.LOGARITHMIC)
	var inverse := Hearing.gain_at(20.0, UNIT, MAX, Hearing.Model.INVERSE)
	expect(log_gain > inverse, "logarithmic keeps distant sounds more present")
	expect(log_gain < 1.0, "while still falling off")

func test_disabled_does_not_fall_off_at_all() -> void:
	print("no attenuation")
	expect(is_equal_approx(Hearing.gain_at(25.0, UNIT, MAX, Hearing.Model.DISABLED), 1.0),
		"with attenuation off, distance does not matter")
	expect(is_zero_approx(Hearing.gain_at(MAX, UNIT, MAX, Hearing.Model.DISABLED)),
		"but max_distance still cuts it off")

func test_standing_on_the_source() -> void:
	print("degenerate input")
	# 1/distance with distance at zero is the obvious way to write this, and it
	# is infinite loudness the first time a player walks into an emitter.
	var on_top := Hearing.gain_at(0.0, 0.0, MAX, Hearing.Model.INVERSE_SQUARE)
	expect(on_top <= 1.0, "a zero unit_size at zero distance does not divide by zero")
	expect(on_top > 0.0, "and is still audible")

func test_decibels_follow_the_gain() -> void:
	print("decibels")
	expect(is_zero_approx(Hearing.db_at(1.0, UNIT, MAX)), "full volume is 0 dB")
	expect(absf(Hearing.db_at(6.0, UNIT, MAX) - (-6.0)) < 0.1, "half the gain is about -6 dB")
	expect(is_equal_approx(Hearing.db_at(MAX, UNIT, MAX), Hearing.SILENCE_DB),
		"and silence has a floor rather than being minus infinity")

func test_audibility_has_a_threshold() -> void:
	print("audibility")
	expect(Hearing.is_audible(4.0, UNIT, MAX), "a sound nearby is heard")
	expect(not Hearing.is_audible(MAX + 1.0, UNIT, MAX), "one past the cutoff is not")

func test_better_ears_hear_further() -> void:
	print("thresholds")
	var distance := 20.0
	expect(Hearing.is_audible(distance, UNIT, MAX, Hearing.Model.INVERSE, -30.0),
		"a listener paying attention hears it")
	expect(not Hearing.is_audible(distance, UNIT, MAX, Hearing.Model.INVERSE, -10.0),
		"a distracted one does not")

func test_range_matches_audibility() -> void:
	print("carrying distance")
	# A threshold that bites well inside the cutoff, so the answer is the
	# distance the sound fades at rather than the distance it is switched off at.
	var reach := Hearing.range_of(UNIT, MAX, Hearing.Model.INVERSE, -10.0)
	expect(reach > 0.0, "the sound carries some distance")
	expect(reach < MAX, "and stops being audible well before the hard cutoff")
	# The two functions have to agree, or the AI's "will they hear me" and the
	# AI's "did they hear me" answer differently.
	expect(Hearing.is_audible(reach - 0.5, UNIT, MAX, Hearing.Model.INVERSE, -10.0),
		"just inside the range it is audible")
	expect(not Hearing.is_audible(reach, UNIT, MAX, Hearing.Model.INVERSE, -10.0),
		"and at the range it is not")

func test_doppler_rises_when_approaching() -> void:
	print("doppler")
	expect(Hearing.doppler(20.0) > 1.0, "something coming towards you sounds higher")
	expect(Hearing.doppler(-20.0) < 1.0, "something going away sounds lower")
	expect(is_equal_approx(Hearing.doppler(0.0), 1.0), "and something stationary sounds the same")

func test_doppler_is_clamped() -> void:
	print("supersonic")
	# At the speed of sound the formula divides by zero, and past it the pitch
	# goes negative — which in a mixer is silence or a crash, depending.
	expect(Hearing.doppler(343.0) > 1.0 and Hearing.doppler(343.0) < 100.0,
		"a source at the speed of sound is clamped rather than infinite")
	expect(Hearing.doppler(2000.0) > 1.0, "and so is one well past it")
	expect(is_equal_approx(Hearing.doppler(10.0, 0.0), 1.0),
		"a speed of sound of zero is ignored rather than dividing by zero")

func test_closing_speed() -> void:
	print("closing speed")
	var source := Vector3(0, 0, 10)
	var listener := Vector3.ZERO
	var towards := Hearing.closing_speed(source, Vector3(0, 0, -5), listener, Vector3.ZERO)
	expect(is_equal_approx(towards, 5.0), "a source heading at the listener is closing")
	var away := Hearing.closing_speed(source, Vector3(0, 0, 5), listener, Vector3.ZERO)
	expect(is_equal_approx(away, -5.0), "one heading away is opening")
	var sideways := Hearing.closing_speed(source, Vector3(5, 0, 0), listener, Vector3.ZERO)
	expect(is_zero_approx(sideways), "and one passing sideways is neither")
	# Only the component along the line between them counts, from both ends.
	var both := Hearing.closing_speed(source, Vector3(0, 0, -5), listener, Vector3(0, 0, 5))
	expect(is_equal_approx(both, 10.0), "a listener moving towards the source adds to it")
	expect(is_zero_approx(Hearing.closing_speed(
		listener, Vector3(1, 0, 0), listener, Vector3.ZERO)),
		"two things in the same place have no direction to close along")
