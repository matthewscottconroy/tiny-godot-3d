extends Node

# Drives the real AccessibilityOptions from scripts/accessibility_options.gd.
#
# Accessibility settings are the ones nobody tests, because "does the game feel
# better" is not assertable. What is assertable is everything underneath: that
# reduced motion actually reaches zero, that the palette survives greyscale,
# that a settings file written by an older build still loads.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_the_defaults()
	test_motion_is_a_scale_not_a_switch()
	test_motion_is_clamped()
	test_text_scale_is_clamped()
	test_roles_have_distinct_colours()
	test_every_palette_survives_greyscale()
	test_high_contrast_uses_lightness_alone()
	test_the_luminance_weighting()
	test_subtitle_sizes()
	test_changes_are_announced()
	test_saving_and_restoring()
	test_a_settings_file_from_another_build()
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
	var summary := "[accessibility-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_defaults() -> void:
	print("defaults")
	var options := AccessibilityOptions.new()
	# Defaults matter more here than anywhere else: they are what everyone who
	# never opens the menu gets.
	expect(is_equal_approx(options.motion, 1.0), "motion is on by default")
	expect(options.subtitles, "and so are subtitles, because off by default is a choice too")
	expect(options.colours == AccessibilityOptions.Colours.NORMAL, "with the default palette")

func test_motion_is_a_scale_not_a_switch() -> void:
	print("motion")
	var options := AccessibilityOptions.new()
	options.motion = 0.5
	# Some players want less rather than none, and a scale covers both without a
	# second option.
	expect(is_equal_approx(options.motion_scale(), 0.5), "half motion is half the shake")
	expect(not options.motion_disabled(), "which is not the same as off")
	options.motion = 0.0
	expect(is_zero_approx(options.motion_scale()), "zero motion is no shake at all")
	expect(options.motion_disabled(), "and reads as disabled for the things that cannot be scaled")

func test_motion_is_clamped() -> void:
	print("motion limits")
	var options := AccessibilityOptions.new()
	options.motion = 5.0
	expect(is_equal_approx(options.motion, 1.0), "motion cannot exceed what was authored")
	options.motion = -2.0
	expect(is_zero_approx(options.motion), "nor go below nothing")

func test_text_scale_is_clamped() -> void:
	print("text limits")
	var options := AccessibilityOptions.new()
	options.text_scale = 99.0
	expect(options.text_scale <= 3.0, "text has a ceiling, so a subtitle still fits the screen")
	options.text_scale = 0.1
	expect(options.text_scale >= 0.75, "and a floor, because smaller is not an accessibility option")

func test_roles_have_distinct_colours() -> void:
	print("roles")
	var options := AccessibilityOptions.new()
	var friend := options.colour_for(AccessibilityOptions.Role.FRIEND)
	var enemy := options.colour_for(AccessibilityOptions.Role.ENEMY)
	expect(friend != enemy, "friend and enemy are different colours")
	# Asking by role rather than by colour is what lets the palette change
	# without touching the systems that draw things.
	options.colours = AccessibilityOptions.Colours.DEUTERANOPIA
	expect(options.colour_for(AccessibilityOptions.Role.FRIEND) != friend,
		"and changing the palette changes what a role looks like")

func test_every_palette_survives_greyscale() -> void:
	print("greyscale")
	var options := AccessibilityOptions.new()
	for palette in [AccessibilityOptions.Colours.NORMAL,
			AccessibilityOptions.Colours.DEUTERANOPIA,
			AccessibilityOptions.Colours.TRITANOPIA,
			AccessibilityOptions.Colours.HIGH_CONTRAST]:
		options.colours = palette
		var worst := 1.0
		for a in 4:
			for b in range(a + 1, 4):
				worst = minf(worst, AccessibilityOptions.lightness_gap(
					options.colour_for(a as AccessibilityOptions.Role),
					options.colour_for(b as AccessibilityOptions.Role)))
		# The honest test: two cues that differ only in hue are two cues a
		# player who cannot see that hue cannot tell apart — and neither can
		# anyone reading a greyscale screenshot in a bug report.
		# 0.12 is a real criterion rather than one the palettes scrape past: it
		# is roughly the point at which two greys read as different greys.
		expect(worst > 0.12, "palette %d keeps its roles apart without colour (%.3f)"
			% [palette, worst])

func test_high_contrast_uses_lightness_alone() -> void:
	print("high contrast")
	var options := AccessibilityOptions.new()
	options.colours = AccessibilityOptions.Colours.HIGH_CONTRAST
	var grey := true
	for role in 4:
		var colour := options.colour_for(role as AccessibilityOptions.Role)
		if absf(colour.r - colour.g) > 0.01 or absf(colour.g - colour.b) > 0.01:
			grey = false
	expect(grey, "the high-contrast palette has no hue in it at all")

func test_the_luminance_weighting() -> void:
	print("luminance")
	# Green looks far brighter than blue at the same value. A naive average
	# would call these two equally light and pass a palette nobody can read.
	var green := AccessibilityOptions.luminance(Color(0, 1, 0))
	var blue := AccessibilityOptions.luminance(Color(0, 0, 1))
	expect(green > blue * 5.0, "green is weighted far above blue, as the eye sees it")
	expect(is_equal_approx(AccessibilityOptions.luminance(Color.WHITE), 1.0), "white is fully light")
	expect(is_zero_approx(AccessibilityOptions.luminance(Color.BLACK)), "and black is not light at all")
	expect(is_zero_approx(AccessibilityOptions.lightness_gap(Color.WHITE, Color.WHITE)),
		"a colour is no distance from itself")
	expect(is_equal_approx(AccessibilityOptions.lightness_gap(Color.WHITE, Color.BLACK), 1.0),
		"and black and white are the whole range apart")

func test_subtitle_sizes() -> void:
	print("subtitles")
	var options := AccessibilityOptions.new()
	expect(options.subtitle_size(20) == 20, "at the default scale, the base size")
	options.text_scale = 2.0
	expect(options.subtitle_size(20) == 40, "and twice the scale is twice the size")

func test_changes_are_announced() -> void:
	print("the signal")
	var options := AccessibilityOptions.new()
	var changes := [0]
	options.changed.connect(func() -> void: changes[0] += 1)
	options.motion = 0.5
	options.subtitles = false
	options.colours = AccessibilityOptions.Colours.TRITANOPIA
	# One signal, so a system reacts to a change rather than polling for one.
	expect(changes[0] == 3, "every change is announced once")

func test_saving_and_restoring() -> void:
	print("persistence")
	var options := AccessibilityOptions.new()
	options.motion = 0.25
	options.subtitles = false
	options.text_scale = 1.5
	options.colours = AccessibilityOptions.Colours.DEUTERANOPIA
	var saved := options.to_dictionary()

	var restored := AccessibilityOptions.new()
	restored.load_from(saved)
	expect(is_equal_approx(restored.motion, 0.25), "motion comes back")
	expect(not restored.subtitles, "so does the subtitle setting")
	expect(is_equal_approx(restored.text_scale, 1.5), "and the text scale")
	expect(restored.colours == AccessibilityOptions.Colours.DEUTERANOPIA, "and the palette")

func test_a_settings_file_from_another_build() -> void:
	print("old files")
	var options := AccessibilityOptions.new()
	# A player who loses their accessibility options to a patch has lost more
	# than a preference, so an unfamiliar file restores what it can.
	options.load_from({"motion": 0.5, "an_option_from_the_future": true})
	expect(is_equal_approx(options.motion, 0.5), "what is recognised is restored")
	expect(options.subtitles, "what is missing keeps its default")
	options.load_from({"colours": 99})
	expect(options.colours == AccessibilityOptions.Colours.NORMAL,
		"and a palette that does not exist is ignored rather than crashing the menu")

func test_resetting() -> void:
	print("reset")
	var options := AccessibilityOptions.new()
	options.motion = 0.0
	options.text_scale = 2.0
	options.subtitles = false
	options.colours = AccessibilityOptions.Colours.HIGH_CONTRAST
	options.reset()
	expect(is_equal_approx(options.motion, 1.0) and is_equal_approx(options.text_scale, 1.0),
		"reset puts motion and text size back to their defaults")
	expect(options.subtitles and options.colours == AccessibilityOptions.Colours.NORMAL,
		"and the subtitle and palette settings too")
