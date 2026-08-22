extends Node

# Drives the real SkyCycle from scripts/sky_cycle.gd.
#
# A day-night cycle is a pile of curves, and curves are exactly the thing that
# looks plausible while being wrong: a sun that sets an hour early, ambient that
# reaches zero, fog that thickens at noon. All of it is checkable as numbers.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_the_clock_wraps()
	test_the_sun_is_highest_at_noon()
	test_the_sun_is_below_the_horizon_at_night()
	test_daytime_is_between_sunrise_and_sunset()
	test_the_sun_rises_in_the_east()
	test_the_sun_direction_points_downward_by_day()
	test_the_sun_is_dark_at_night()
	test_the_sun_is_full_at_noon()
	test_dawn_and_dusk_are_symmetric()
	test_the_sun_reddens_near_the_horizon()
	test_ambient_never_reaches_zero()
	test_fog_burns_off_during_the_day()
	test_the_horizon_darkens_at_night()
	test_the_clock_reads_as_a_time()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[environment-fog] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_clock_wraps() -> void:
	print("the clock")
	expect(is_equal_approx(SkyCycle.normalise(25.0), 1.0), "25:00 is 1am")
	expect(is_equal_approx(SkyCycle.normalise(-1.0), 23.0), "and -1:00 is 11pm")
	expect(is_equal_approx(SkyCycle.normalise(13.5), 13.5), "an ordinary hour is left alone")
	# The cycle holds no state, so the sky at 3am tomorrow is the sky at 3am
	# today — which is what makes a saved game only need the clock.
	expect(is_equal_approx(SkyCycle.sun_energy(3.0), SkyCycle.sun_energy(27.0)),
		"and the sky repeats exactly, one day to the next")

func test_the_sun_is_highest_at_noon() -> void:
	print("sun height")
	expect(is_equal_approx(SkyCycle.sun_height(12.0), 1.0), "noon is the top of the arc")
	expect(SkyCycle.sun_height(9.0) < SkyCycle.sun_height(11.0), "the morning climbs")
	expect(SkyCycle.sun_height(15.0) > SkyCycle.sun_height(17.0), "and the afternoon falls")

func test_the_sun_is_below_the_horizon_at_night() -> void:
	print("night")
	expect(is_equal_approx(SkyCycle.sun_height(0.0), -1.0), "midnight is the bottom of the arc")
	expect(SkyCycle.sun_height(3.0) < 0.0, "3am is below the horizon")
	expect(is_zero_approx(SkyCycle.sun_height(6.0)), "and 6am is exactly on it")

func test_daytime_is_between_sunrise_and_sunset() -> void:
	print("daylight hours")
	expect(SkyCycle.is_daytime(12.0), "noon is daytime")
	expect(SkyCycle.is_daytime(6.0), "sunrise counts as day")
	expect(not SkyCycle.is_daytime(18.0), "sunset does not — the day has ended by then")
	expect(not SkyCycle.is_daytime(2.0), "and the small hours certainly do not")

func test_the_sun_rises_in_the_east() -> void:
	print("east and west")
	# The vector is where the light travels, so at dawn it points west (-X):
	# the sun is in the east, shining across.
	expect(SkyCycle.sun_direction(6.0).x < 0.0, "at dawn the light travels west")
	expect(SkyCycle.sun_direction(18.0).x > 0.0, "and at dusk it travels east")

func test_the_sun_direction_points_downward_by_day() -> void:
	print("direction")
	var noon := SkyCycle.sun_direction(12.0)
	expect(noon.y < -0.9, "at noon the light comes almost straight down")
	expect(is_equal_approx(noon.length(), 1.0), "and the direction is normalised")
	expect(SkyCycle.sun_direction(0.0).y > 0.9,
		"at midnight it points up, because the sun is under the world")

func test_the_sun_is_dark_at_night() -> void:
	print("night light")
	expect(is_zero_approx(SkyCycle.sun_energy(0.0)), "the sun gives nothing at midnight")
	expect(is_zero_approx(SkyCycle.sun_energy(3.0)), "nor at three in the morning")
	expect(is_zero_approx(SkyCycle.sun_energy(22.0)), "nor late in the evening")

func test_the_sun_is_full_at_noon() -> void:
	print("day light")
	expect(is_equal_approx(SkyCycle.sun_energy(12.0), 1.0), "full brightness at noon")
	expect(is_equal_approx(SkyCycle.sun_energy(10.0), 1.0), "and for the whole middle of the day")
	var dawn := SkyCycle.sun_energy(SkyCycle.SUNRISE)
	expect(dawn > 0.0 and dawn < 1.0, "sunrise is partway up, not a switch")

func test_dawn_and_dusk_are_symmetric() -> void:
	print("symmetry")
	# An hour after sunrise should be as bright as an hour before sunset. This
	# is the assertion that catches an off-by-one in one of the two ramps —
	# which otherwise shows only as "dusk feels wrong somehow".
	for offset in [0.0, 0.5, 1.0, 1.4]:
		var morning := SkyCycle.sun_energy(SkyCycle.SUNRISE + offset)
		var evening := SkyCycle.sun_energy(SkyCycle.SUNSET - offset)
		expect(is_equal_approx(morning, evening),
			"%.1f hours into the day matches %.1f hours before its end" % [offset, offset])

func test_the_sun_reddens_near_the_horizon() -> void:
	print("colour")
	var dawn := SkyCycle.sun_colour(6.0)
	var noon := SkyCycle.sun_colour(12.0)
	expect(dawn.r - dawn.b > 0.3, "at dawn the light is markedly warmer than it is blue")
	expect(noon.r - noon.b < 0.1, "at noon it is near white")
	expect(dawn.b < noon.b, "the blue is what drops as the sun gets low")

func test_ambient_never_reaches_zero() -> void:
	print("ambient")
	var darkest := 99.0
	for i in 240:
		darkest = minf(darkest, SkyCycle.ambient_energy(i * 0.1))
	# Zero ambient at midnight is not darkness, it is an unlit scene, and
	# players read that as the game having failed to load.
	expect(darkest > 0.0, "there is always some ambient light")
	expect(SkyCycle.ambient_energy(12.0) > SkyCycle.ambient_energy(0.0),
		"but far more of it by day")

func test_fog_burns_off_during_the_day() -> void:
	print("fog")
	expect(SkyCycle.fog_density(0.0) > SkyCycle.fog_density(12.0),
		"night is foggier than noon")
	var thickest := 0.0
	for i in 240:
		thickest = maxf(thickest, SkyCycle.fog_density(i * 0.1))
	expect(thickest < 0.1, "and the fog never gets thick enough to hide the level")

func test_the_horizon_darkens_at_night() -> void:
	print("horizon")
	var night := SkyCycle.horizon_colour(0.0)
	var day := SkyCycle.horizon_colour(12.0)
	expect(night.v < day.v, "the sky is darker at midnight than at noon")
	var sunset := SkyCycle.horizon_colour(17.5)
	expect(sunset.r > sunset.b, "and warm just before the sun goes down")
	# Only near the horizon. A glow that reaches the whole day tints noon
	# orange, which reads as permanent sunset rather than as daylight.
	expect(day.b > day.r, "while at noon the sky is blue rather than sun-coloured")

func test_the_clock_reads_as_a_time() -> void:
	print("readout")
	expect(SkyCycle.clock(6.5) == "06:30", "half past six reads as 06:30")
	expect(SkyCycle.clock(0.0) == "00:00", "midnight is zero, not 24")
	expect(SkyCycle.clock(25.25) == "01:15", "and a wrapped hour reads as the hour it is")
