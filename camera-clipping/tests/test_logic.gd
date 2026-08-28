extends Node

# Drives the real NearPlane from scripts/near_plane.gd, and then walks the real
# player into the real wall — because "the camera stops short of the wall" is a
# claim about a loop of raycasts and pushes, not about one function.

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_the_near_plane_has_a_size()
	test_a_wider_view_is_a_bigger_plane()
	test_aspect_widens_it_sideways_only()
	test_the_enclosing_radius()
	test_the_safe_distance()
	test_what_counts_as_too_close()
	test_pushing_a_camera_out()
	test_a_camera_already_clear()
	test_pushing_along_the_normal_not_the_view()
	test_the_price_of_a_smaller_near_plane()
	test_where_the_depth_buffer_goes()
	test_degenerate_planes()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[camera-clipping] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_near_plane_has_a_size() -> void:
	print("the plane")
	# A camera does not see from a point. It sees from a rectangle a short
	# distance in front of itself, and that rectangle is what gets stuck in walls.
	var h := NearPlane.half_height(75.0, 0.05)
	expect(h > 0.0, "the near plane is a rectangle, not a point (%.4f m tall each way)" % h)
	expect(is_equal_approx(h, 0.05 * tan(deg_to_rad(37.5))), "sized by the field of view")

func test_a_wider_view_is_a_bigger_plane() -> void:
	print("field of view")
	expect(NearPlane.half_height(100.0, 0.05) > NearPlane.half_height(60.0, 0.05),
		"a wider field of view makes the near plane bigger")
	# Which is why a first-person camera clips more than a cinematic one at the
	# same distance from the same wall.
	expect(NearPlane.safe_distance(100.0, 0.05, 1.78)
		> NearPlane.safe_distance(60.0, 0.05, 1.78),
		"and so it has to stay further from walls")

func test_aspect_widens_it_sideways_only() -> void:
	print("aspect")
	# Godot's fov is the *vertical* field of view, so a wider window makes the
	# plane wider without making it taller.
	var wide := NearPlane.half_width(75.0, 0.05, 2.0)
	var square := NearPlane.half_width(75.0, 0.05, 1.0)
	expect(wide > square, "a wider window makes a wider near plane")
	expect(is_equal_approx(NearPlane.half_height(75.0, 0.05), square),
		"but not a taller one, because fov is measured vertically")

func test_the_enclosing_radius() -> void:
	print("the radius")
	var near := 0.05
	var radius := NearPlane.radius(75.0, near, 1.78)
	# The number that matters: keep the camera this far from anything solid and
	# no corner of the plane can be inside it, whichever way it faces.
	expect(radius > near, "the corners reach further than the plane's distance (%.4f)" % radius)
	expect(radius > NearPlane.half_width(75.0, near, 1.78),
		"and further than its width, because a corner is a diagonal")

func test_the_safe_distance() -> void:
	print("safe distance")
	var safe := NearPlane.safe_distance(75.0, 0.05, 1.78, 0.05)
	expect(is_equal_approx(safe, NearPlane.radius(75.0, 0.05, 1.78) + 0.05),
		"the safe distance is the radius plus the margin")
	expect(NearPlane.safe_distance(75.0, 0.05, 1.78, 0.0)
		< NearPlane.safe_distance(75.0, 0.05, 1.78, 0.2),
		"and more margin means more clearance")

func test_what_counts_as_too_close() -> void:
	print("too close")
	var safe := NearPlane.safe_distance(75.0, 0.05, 1.78)
	expect(NearPlane.would_clip(safe - 0.01, 75.0, 0.05, 1.78), "just inside the line clips")
	expect(not NearPlane.would_clip(safe + 0.01, 75.0, 0.05, 1.78), "and just outside it does not")

func test_pushing_a_camera_out() -> void:
	print("pushing out")
	# A wall at x = 0 facing +X, camera 2cm in front of it.
	var moved := NearPlane.pushed_out(Vector3(0.02, 1, 0), Vector3.ZERO, Vector3.RIGHT,
		75.0, 0.05, 1.78)
	var safe := NearPlane.safe_distance(75.0, 0.05, 1.78)
	expect(moved.x > 0.02, "a camera too close to a wall is moved away from it")
	expect(absf(moved.x - safe) < 0.001, "to exactly the safe distance, not further (%.3f)" % moved.x)
	expect(is_equal_approx(moved.y, 1.0) and is_zero_approx(moved.z),
		"and not moved on any other axis")

func test_a_camera_already_clear() -> void:
	print("already clear")
	var far := Vector3(3.0, 1, 0)
	expect(NearPlane.pushed_out(far, Vector3.ZERO, Vector3.RIGHT, 75.0, 0.05, 1.78)
		.is_equal_approx(far),
		"a camera already clear of the wall is left exactly where it was")

func test_pushing_along_the_normal_not_the_view() -> void:
	print("which way to push")
	# Along the surface normal, whatever the camera is looking at. Backing off
	# along the view direction instead is what puts a first-person camera inside
	# the character's own head.
	var moved := NearPlane.pushed_out(Vector3(0, 1, 0.02), Vector3(0, 1, 0), Vector3.BACK,
		75.0, 0.05, 1.78)
	expect(moved.z > 0.02, "it moves along the wall's normal")
	expect(is_zero_approx(moved.x), "and nowhere else")

func test_the_price_of_a_smaller_near_plane() -> void:
	print("the price")
	# The trap. Depth precision scales with the far/near ratio, so halving the
	# near plane costs as much precision as doubling the view distance.
	expect(is_equal_approx(NearPlane.precision_cost(0.05, 0.025), 2.0),
		"halving the near plane costs twice the depth precision")
	expect(is_equal_approx(NearPlane.precision_cost(0.05, 0.005), 10.0),
		"and dividing it by ten costs ten times")
	expect(is_equal_approx(NearPlane.precision_cost(0.05, 0.05), 1.0),
		"while leaving it alone costs nothing")

func test_where_the_depth_buffer_goes() -> void:
	print("the depth buffer")
	# A perspective depth buffer is hyperbolic: most of its resolution is spent
	# on what is close, which is why distant geometry z-fights first.
	var share := NearPlane.near_precision_share(0.05, 1000.0)
	expect(share > 0.9, "the first metre uses most of the depth buffer (%.1f%%)" % (share * 100.0))
	expect(NearPlane.near_precision_share(0.5, 1000.0) < share,
		"and a further near plane spends less of it there")

func test_degenerate_planes() -> void:
	print("degenerate input")
	expect(NearPlane.near_precision_share(0.0, 100.0) == 1.0,
		"a near plane of zero does not divide by zero")
	expect(NearPlane.near_precision_share(10.0, 5.0) == 1.0,
		"and neither does a far plane in front of the near one")
	expect(NearPlane.precision_cost(0.05, 0.0) == INF,
		"a near plane of nothing costs infinite precision, which is the honest answer")
	expect(NearPlane.precision_cost(0.0, 0.05) == INF,
		"and so does coming *from* one, rather than reporting a free improvement")

# --- the real camera and the real wall -------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real wall")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			# Straight at the wall, and hold it there.
			Input.action_press(&"ui_left")
		110:
			# Long enough to actually reach the wall: 4.5 metres at 3 m/s is a
			# second and a half of physics, not the twenty frames it looks like.
			_check_the_guard_held()
		112:
			_check_without_the_guard()
			Input.action_release(&"ui_left")
			_check_the_readout()
			_check_the_readout_when_there_is_nothing_there()
			_check_the_controls()
			_report()

func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _check_the_readout() -> void:
	# One more step with the guard off, so the readout describes the state the
	# camera is actually in rather than the one before it was moved.
	_scene.call("_physics_process", 0.016)
	var readout: Label = _scene.get_node("HUD/ReadoutLabel")
	var status: Label = _scene.get_node("HUD/StatusLabel")
	# The guard is off at this point and the camera is up against the wall, so
	# the demo has to be saying so. A readout that never admits to clipping is a
	# readout that is not measuring anything.
	expect(readout.text.contains("CLIPPING"),
		"with the guard off against a wall, the readout says it is clipping")
	expect(readout.text.contains("guard off"), "and that the guard is off")
	expect(not readout.text.contains("nothing near"),
		"and does not claim there is nothing near")
	expect(status.text.contains("2x"),
		"the status line prices halving the near plane at twice the precision (%s)" % status.text)

## Guard off and nothing anywhere near: the readout must not cry wolf.
func _check_the_readout_when_there_is_nothing_there() -> void:
	var player: CharacterBody3D = _scene.get_node("Player")
	player.global_position = Vector3(8, 0.9, 0)
	_scene.set("_guard", false)
	_scene.call("_physics_process", 0.016)
	var readout: Label = _scene.get_node("HUD/ReadoutLabel")
	expect(readout.text.contains("nothing near"),
		"out in the open, the readout says there is nothing near")
	expect(not readout.text.contains("CLIPPING"),
		"and does not claim to be clipping just because the guard is off")

func _check_the_controls() -> void:
	var camera := _camera()
	_scene.call("_unhandled_key_input", _key(KEY_R))
	var near := camera.near
	var fov := camera.fov
	expect(_scene.get("_guard"), "R turns the guard back on")

	_scene.call("_unhandled_key_input", _key(KEY_2))
	expect(camera.near > near, "2 moves the near plane out")
	_scene.call("_unhandled_key_input", _key(KEY_1))
	expect(is_equal_approx(camera.near, near), "and 1 brings it back in")

	_scene.call("_unhandled_key_input", _key(KEY_4))
	expect(camera.fov > fov, "4 widens the field of view")
	_scene.call("_unhandled_key_input", _key(KEY_3))
	expect(is_equal_approx(camera.fov, fov), "and 3 narrows it again")

	_scene.call("_unhandled_key_input", _key(KEY_G))
	expect(not _scene.get("_guard"), "G turns the guard off")

	_scene.call("_unhandled_key_input", _key(KEY_G, true, true))
	expect(not _scene.get("_guard"), "a key repeat changes nothing")
	_scene.call("_unhandled_key_input", _key(KEY_G, false))
	expect(not _scene.get("_guard"), "and neither does letting go")

func _camera() -> Camera3D:
	return _scene.get_node("Player/Camera3D")

func _check_the_guard_held() -> void:
	var camera := _camera()
	var player: CharacterBody3D = _scene.get_node("Player")
	# The player's own body stops well short of the wall, so this is about the
	# camera inside it rather than about the character controller.
	expect(player.global_position.x < 0.0, "the player walked up to the wall (x %.2f)"
		% player.global_position.x)

	var space := _scene.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position + Vector3.LEFT * 3.0)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	expect(not hit.is_empty(), "with the wall in front of the camera")
	if hit.is_empty():
		return
	var distance: float = camera.global_position.distance_to(hit["position"])
	# The demo's own aspect ratio, not a guessed one: the near plane is wider on
	# a wide window, so the safe distance is a different number in a headless
	# viewport than on a 16:9 screen.
	var safe := NearPlane.safe_distance(camera.fov, camera.near, _scene.call("_aspect"))
	expect(distance >= safe - 0.02,
		"and the camera kept its near plane clear of it (%.3f m, needs %.3f m)"
			% [distance, safe])

func _check_without_the_guard() -> void:
	# Turn the guard off and the same frame puts the camera back where the body
	# is — which is inside the near plane's reach of the wall.
	var camera := _camera()
	var guarded := camera.global_position.x
	_scene.set("_guard", false)
	_scene.call("_physics_process", 0.016)
	expect(camera.global_position.x < guarded,
		"with the guard off the camera sits closer to the wall (%.3f, was %.3f)"
			% [camera.global_position.x, guarded])
