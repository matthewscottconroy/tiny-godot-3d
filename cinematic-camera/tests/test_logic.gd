extends Node

# Drives the real CameraTrack from scripts/camera_track.gd, then checks the
# demo's own path and cameras.
#
# mutate-driver: skip — the scene is instantiated to read a real Curve3D and PathFollow3D, not to test main.gd

var _pass := 0
var _fail := 0
var _checked := false

func _ready() -> void:
	test_progress_starts_at_the_beginning()
	test_progress_advances_with_time()
	test_a_looping_track_wraps()
	test_a_one_shot_track_stops_at_the_end()
	test_a_zero_duration_track()
	test_blending_takes_the_time_it_is_given()
	test_blending_back()
	test_an_instant_blend()
	test_easing_is_gentle_at_both_ends()
	test_blending_transforms()
	test_blending_rotation_takes_the_short_way()
	test_looking_ahead()
	test_resetting()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[cinematic-camera] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_progress_starts_at_the_beginning() -> void:
	print("the start")
	var track := CameraTrack.new()
	expect(is_zero_approx(track.progress()), "a fresh track is at the start")
	expect(is_zero_approx(track.blend()), "showing the gameplay camera")
	expect(not track.is_cinematic(), "and not in a cutscene")
	# Defaults are what most callers get, so they are worth pinning: a track
	# that stops at the end by default leaves a cutscene camera frozen on its
	# last frame instead of circling.
	expect(track.looping, "a track loops unless told otherwise")
	expect(track.duration > 0.0, "and has a duration, so advancing it does something")

func test_progress_advances_with_time() -> void:
	print("moving")
	var track := CameraTrack.new()
	track.duration = 4.0
	track.advance(1.0)
	expect(is_equal_approx(track.progress(), 0.25), "a quarter of the duration is a quarter along")
	track.advance(1.0)
	expect(is_equal_approx(track.progress(), 0.5), "and half is half")

func test_a_looping_track_wraps() -> void:
	print("looping")
	var track := CameraTrack.new()
	track.duration = 2.0
	track.looping = true
	track.advance(2.5)
	expect(is_equal_approx(track.progress(), 0.25), "past the end it starts again")
	expect(track.progress() < 1.0, "staying inside 0..1, which is what progress_ratio wants")

func test_a_one_shot_track_stops_at_the_end() -> void:
	print("one shot")
	var track := CameraTrack.new()
	track.duration = 2.0
	track.looping = false
	track.advance(5.0)
	expect(is_equal_approx(track.progress(), 1.0), "a one-shot track stops at the end")
	track.advance(5.0)
	expect(is_equal_approx(track.progress(), 1.0), "and stays there rather than wrapping")

func test_a_zero_duration_track() -> void:
	print("degenerate duration")
	var track := CameraTrack.new()
	track.duration = 0.0
	track.advance(1.0)
	expect(is_zero_approx(track.progress()), "a track with no duration does not divide by zero")

func test_blending_takes_the_time_it_is_given() -> void:
	print("blending in")
	var track := CameraTrack.new()
	track.blend_duration = 1.0
	track.set_cinematic(true)
	track.advance_blend(0.5)
	expect(absf(track.blend() - 0.5) < 0.001, "half the blend time is half the weight")
	expect(track.is_blending(), "and the blend is in flight")
	track.advance_blend(0.5)
	expect(is_equal_approx(track.blend(), 1.0), "the full time arrives at the cutscene camera")
	expect(not track.is_blending(), "and the blend is over")

func test_blending_back() -> void:
	print("blending out")
	var track := CameraTrack.new()
	track.blend_duration = 1.0
	track.set_cinematic(true)
	track.advance_blend(2.0)
	track.set_cinematic(false)
	track.advance_blend(0.5)
	expect(absf(track.blend() - 0.5) < 0.001, "coming back takes the same time")
	track.advance_blend(2.0)
	expect(is_zero_approx(track.blend()), "and ends exactly at the gameplay camera")

func test_an_instant_blend() -> void:
	print("no blend")
	var track := CameraTrack.new()
	track.blend_duration = 0.0
	track.set_cinematic(true)
	track.advance_blend(0.016)
	expect(is_equal_approx(track.blend(), 1.0), "a zero blend duration is a cut, immediately")

func test_easing_is_gentle_at_both_ends() -> void:
	print("easing")
	expect(is_zero_approx(CameraTrack.eased(0.0)), "eased(0) is 0")
	expect(is_equal_approx(CameraTrack.eased(1.0), 1.0), "eased(1) is 1")
	expect(is_equal_approx(CameraTrack.eased(0.5), 0.5), "and the middle is unchanged")
	# The point of easing: the first tenth of the blend covers much less than a
	# tenth of the distance, so the camera leaves gently instead of lurching.
	expect(CameraTrack.eased(0.1) < 0.1, "the start is slower than linear")
	expect(CameraTrack.eased(0.9) > 0.9, "and so is the end")
	expect(is_zero_approx(CameraTrack.eased(-5.0)), "out-of-range input is clamped")
	expect(is_equal_approx(CameraTrack.eased(5.0), 1.0), "at both ends")

func test_blending_transforms() -> void:
	print("blending transforms")
	var from := Transform3D(Basis(), Vector3(0, 0, 0))
	var to := Transform3D(Basis(), Vector3(10, 0, 0))
	expect(CameraTrack.blended(from, to, 0.0).origin.is_equal_approx(from.origin),
		"at weight zero the blend is exactly the first camera")
	expect(CameraTrack.blended(from, to, 1.0).origin.is_equal_approx(to.origin),
		"and at one, exactly the second — no drift at the ends")
	var middle := CameraTrack.blended(from, to, 0.5)
	expect(is_equal_approx(middle.origin.x, 5.0), "halfway is halfway")

func test_blending_rotation_takes_the_short_way() -> void:
	print("rotation")
	# 170 degrees apart. Lerping Euler angles separately would unwind the long
	# way round here, which looks like the camera being thrown across the level.
	var from := Transform3D(Basis(Vector3.UP, 0.0), Vector3.ZERO)
	var to := Transform3D(Basis(Vector3.UP, deg_to_rad(170.0)), Vector3.ZERO)
	var middle := CameraTrack.blended(from, to, 0.5)
	var angle := middle.basis.get_rotation_quaternion().get_angle()
	expect(absf(rad_to_deg(angle) - 85.0) < 1.0,
		"halfway between two orientations is halfway round the short arc")

func test_looking_ahead() -> void:
	print("looking ahead")
	expect(is_equal_approx(CameraTrack.look_ahead(0.5, 0.1, true), 0.6),
		"looking ahead moves along the track")
	expect(is_equal_approx(CameraTrack.look_ahead(0.95, 0.1, true), 0.05),
		"and wraps on a looping track rather than running off the end")
	expect(is_equal_approx(CameraTrack.look_ahead(0.95, 0.1, false), 1.0),
		"while a one-shot track clamps at its end")

func test_resetting() -> void:
	print("reset")
	var track := CameraTrack.new()
	track.set_cinematic(true)
	track.advance(1.0)
	track.advance_blend(1.0)
	track.reset()
	expect(is_zero_approx(track.progress()) and is_zero_approx(track.blend()),
		"reset puts both the track and the blend back")
	expect(not track.is_cinematic(), "and hands control back to the gameplay camera")

# --- the real path ---------------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real path")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var path: Path3D = scene.get_node("Path3D")
	var follow: PathFollow3D = scene.get_node("Path3D/PathFollow3D")

	expect(path.curve != null and path.curve.point_count >= 4,
		"the driver built a curve with points in it")
	expect(path.curve.get_baked_length() > 10.0,
		"and it is a real length of track (%.1f m)" % path.curve.get_baked_length())
	# progress_ratio is 0..1 along the baked curve, which is why the track keeps
	# its progress in the same range rather than in metres.
	follow.progress_ratio = 0.0
	var start := follow.global_position
	follow.progress_ratio = 0.5
	var middle := follow.global_position
	expect(start.distance_to(middle) > 1.0, "moving the ratio moves the follower along it")

	scene.queue_free()
	_report()
