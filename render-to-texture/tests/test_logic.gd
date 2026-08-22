extends Node

# Drives the real FeedThrottle from scripts/feed_throttle.gd, then checks the
# real SubViewport is wired the way a feed has to be.
#
# mutate-driver: skip — the scene is instantiated to inspect a real SubViewport, not to test main.gd

var _pass := 0
var _fail := 0
var _checked := false

func _ready() -> void:
	test_a_hidden_feed_never_renders()
	test_rates_fall_with_distance()
	test_updates_come_at_the_rate()
	test_a_hidden_feed_is_not_merely_slow()
	test_zero_delta_never_triggers_an_update()
	test_resolution_falls_with_distance()
	test_resolution_has_a_floor()
	test_update_modes()
	test_the_cost_of_a_feed()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[render-to-texture] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _throttle() -> FeedThrottle:
	var throttle := FeedThrottle.new()
	throttle.near_distance = 8.0
	throttle.far_distance = 25.0
	throttle.near_hz = 60.0
	throttle.mid_hz = 15.0
	throttle.far_hz = 5.0
	return throttle

func test_a_hidden_feed_never_renders() -> void:
	print("out of sight")
	var throttle := _throttle()
	expect(is_zero_approx(throttle.rate_for(2.0, false)),
		"a screen nobody can see does not render at all")
	expect(throttle.rate_for(2.0, true) > 0.0, "while one in view does")

func test_rates_fall_with_distance() -> void:
	print("rates")
	var throttle := _throttle()
	expect(is_equal_approx(throttle.rate_for(4.0, true), 60.0), "close up, every frame")
	expect(is_equal_approx(throttle.rate_for(15.0, true), 15.0), "across the room, less often")
	expect(is_equal_approx(throttle.rate_for(40.0, true), 5.0), "and far away, rarely")
	expect(is_equal_approx(throttle.rate_for(8.0, true), 60.0),
		"with the boundary itself belonging to the nearer band")

func test_updates_come_at_the_rate() -> void:
	print("timing")
	var throttle := _throttle()
	var updates := 0
	# One second of 60fps frames at the 15 Hz band should be about 15 renders,
	# not 60 and not 1.
	for i in 60:
		if throttle.should_update(15.0, true, 1.0 / 60.0):
			updates += 1
	expect(updates >= 14 and updates <= 16, "a 15 Hz feed renders about 15 times a second (%d)"
		% updates)

func test_a_hidden_feed_is_not_merely_slow() -> void:
	print("hidden")
	var throttle := _throttle()
	var updates := 0
	for i in 600:
		if throttle.should_update(4.0, false, 1.0 / 60.0):
			updates += 1
	# Ten seconds of being invisible: not one render. This is the saving that
	# dwarfs the others, and a throttle that merely slows down misses it.
	expect(updates == 0, "ten seconds out of sight is zero renders")

func test_zero_delta_never_triggers_an_update() -> void:
	print("paused")
	var throttle := _throttle()
	var updates := 0
	for i in 100:
		if throttle.should_update(15.0, true, 0.0):
			updates += 1
	expect(updates == 0, "a paused game does not accumulate renders")

func test_resolution_falls_with_distance() -> void:
	print("resolution")
	var base := Vector2i(512, 288)
	expect(FeedThrottle.resolution_for(4.0, base) == base, "close up, the full resolution")
	var mid := FeedThrottle.resolution_for(15.0, base)
	expect(mid.x == 256, "across the room, half")
	var far := FeedThrottle.resolution_for(40.0, base)
	expect(far.x == 128, "and far away, a quarter")

func test_resolution_has_a_floor() -> void:
	print("the floor")
	# A viewport a handful of pixels across costs nothing to render and looks
	# like a fault rather than a distant screen.
	var tiny := FeedThrottle.resolution_for(100.0, Vector2i(64, 36))
	expect(tiny.x >= 32 and tiny.y >= 32, "a feed never shrinks below something legible")

func test_update_modes() -> void:
	print("update modes")
	expect(FeedThrottle.update_mode_for(false, true) == SubViewport.UPDATE_DISABLED,
		"an invisible feed is switched off entirely")
	expect(FeedThrottle.update_mode_for(true, true) == SubViewport.UPDATE_ALWAYS,
		"a continuous one redraws every frame")
	# UPDATE_ONCE renders one frame and disables itself, which is what makes a
	# throttled feed a throttle rather than a frozen image.
	expect(FeedThrottle.update_mode_for(true, false) == SubViewport.UPDATE_ONCE,
		"and a throttled one renders a single frame at a time")

func test_the_cost_of_a_feed() -> void:
	print("cost")
	var throttle := _throttle()
	expect(is_equal_approx(throttle.cost_of(4.0, true), 1.0), "a near feed costs a full render")
	expect(throttle.cost_of(15.0, true) < 0.3, "a mid one a fraction of it")
	expect(is_zero_approx(throttle.cost_of(4.0, false)), "and a hidden one nothing at all")

# --- the real viewport -----------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real feed")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var feed: SubViewport = scene.get_node("Feed")
	var screen: MeshInstance3D = scene.get_node("Screen")

	# The line the whole demo turns on: a SubViewport has its own empty World3D
	# until told otherwise, and a feed of an empty world is a black rectangle.
	expect(feed.world_3d == scene.get_viewport().world_3d,
		"the feed renders the same world as the main view")
	var camera := feed.get_node("FeedCamera") as Camera3D
	expect(camera != null and camera.current, "with a camera of its own, made current")
	expect(feed.size.x > 0 and feed.size.y > 0, "and a size to render into")

	var material := screen.material_override as StandardMaterial3D
	expect(material != null and material.albedo_texture is ViewportTexture,
		"the screen samples the viewport's texture")
	# A monitor emits light rather than reflecting it: a lit material makes the
	# feed dark wherever the room is.
	expect(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
		"and does it unshaded, the way a screen glows")

	scene.queue_free()
	_report()
