extends Node

# Drives the real OrbitRig from scripts/orbit_rig.gd.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_offset_starts_behind()
	test_distance_is_respected()
	test_yaw_orbits_horizontally()
	test_pitch_clamps_away_from_the_poles()
	test_camera_stays_upright()
	test_zoom_clamps()
	test_ground_basis_is_flat_and_orthogonal()
	test_movement_is_camera_relative()
	test_pull_in()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[orbit-camera] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _flat() -> OrbitRig:
	var r := OrbitRig.new()
	r.pitch = 0.0
	r.yaw = 0.0
	return r

func test_offset_starts_behind() -> void:
	print("default framing")
	var r := _flat()
	expect(r.offset().z > 0.0, "the camera sits behind the target")
	expect(is_zero_approx(r.offset().x), "and centred on it")

func test_distance_is_respected() -> void:
	print("distance")
	var r := OrbitRig.new()
	r.distance = 9.0
	expect(is_equal_approx(r.offset().length(), 9.0), "the offset length is the distance")
	r.pitch = 0.7
	expect(is_equal_approx(r.offset().length(), 9.0), "pitching does not change the distance")
	r.yaw = 2.1
	expect(is_equal_approx(r.offset().length(), 9.0), "nor does yawing")

func test_yaw_orbits_horizontally() -> void:
	print("yaw")
	var r := _flat()
	r.yaw = PI / 2.0
	var o := r.offset()
	expect(is_zero_approx(o.y), "a flat yaw keeps the camera level")
	expect(absf(o.x) > 1.0, "a quarter turn moves the camera to the side")

func test_pitch_clamps_away_from_the_poles() -> void:
	print("pitch limits")
	var r := OrbitRig.new()
	r.look(Vector2(0, 100000))
	expect(r.pitch <= r.max_pitch, "pitch is clamped looking down")
	# Straight up is where the look-at basis degenerates and the view snaps.
	expect(r.max_pitch < PI / 2.0, "the limit stops short of vertical")
	r.look(Vector2(0, -100000))
	expect(r.pitch >= r.min_pitch, "pitch is clamped looking up")
	expect(r.min_pitch > -PI / 2.0, "and stops short of vertical there too")

func test_camera_stays_upright() -> void:
	print("no roll")
	# Pitch-then-yaw keeps the horizon level at every combination; the reverse
	# order rolls it. Check the offset's horizontal component stays consistent.
	var r := OrbitRig.new()
	for yaw_step in 8:
		r.yaw = TAU * float(yaw_step) / 8.0
		r.pitch = 0.6
		var o := r.offset()
		var horizontal := Vector2(o.x, o.z).length()
		expect(horizontal > 0.1, "yaw %d keeps a horizontal component" % yaw_step)
		expect(o.y > 0.0, "yaw %d keeps the camera above the target" % yaw_step)

func test_zoom_clamps() -> void:
	print("zoom limits")
	var r := OrbitRig.new()
	r.zoom(-1000.0)
	expect(is_equal_approx(r.distance, r.min_distance), "cannot zoom inside the target")
	r.zoom(1000.0)
	expect(is_equal_approx(r.distance, r.max_distance), "cannot zoom out forever")

func test_ground_basis_is_flat_and_orthogonal() -> void:
	print("ground basis")
	var r := OrbitRig.new()
	r.pitch = -1.0          # looking well down
	r.yaw = 0.9
	var b := r.ground_basis()
	var forward: Vector3 = b["forward"]
	var right: Vector3 = b["right"]
	expect(is_zero_approx(forward.y), "forward is flattened onto the ground plane")
	expect(is_zero_approx(right.y), "so is right")
	expect(is_equal_approx(forward.length(), 1.0), "forward is normalised")
	expect(absf(forward.dot(right)) < 0.001, "forward and right are perpendicular")

func test_movement_is_camera_relative() -> void:
	print("camera-relative movement")
	var r := _flat()
	# Facing down -Z: pressing "forward" should move along -Z.
	var forward := r.movement_direction(Vector2(0, -1))
	expect(forward.z < -0.9, "forward moves away from the camera")
	r.yaw = PI / 2.0
	var turned := r.movement_direction(Vector2(0, -1))
	expect(absf(turned.x) > 0.9, "after a quarter turn, forward is along X instead")
	expect(is_zero_approx(r.movement_direction(Vector2.ZERO).length()),
		"no input produces no direction, not a NaN")

func test_pull_in() -> void:
	print("collision pull-in")
	var r := OrbitRig.new()
	r.distance = 8.0
	var clear := r.pulled_in(100.0)
	expect(is_equal_approx(clear.length(), 8.0), "nothing in the way leaves the distance alone")
	var blocked := r.pulled_in(3.0)
	expect(blocked.length() < 8.0, "an obstruction pulls the camera in")
	expect(blocked.length() >= r.min_distance, "but never closer than the minimum")
	expect(blocked.normalized().is_equal_approx(r.offset().normalized()),
		"the direction is unchanged — only the distance moves")
