extends Node

# Drives the real ClipBuilder from scripts/clip_builder.gd.
#
# An Animation is a data structure, so all of it is checkable: how many tracks,
# what type, where the keys are, and — the useful one — what value the clip
# actually produces at a given time. That last check is what separates "the keys
# are there" from "the animation does what it looks like it does".

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_an_empty_clip()
	test_a_clip_cannot_have_zero_length()
	test_position_tracks_hold_their_keys()
	test_sampling_a_position_track_between_keys()
	test_rotation_tracks_are_quaternions()
	test_a_swing_returns_to_where_it_started()
	test_a_swing_reaches_its_angle()
	test_phase_shifts_the_swing()
	test_a_walk_cycle_has_one_track_per_leg()
	test_diagonal_legs_move_together()
	test_a_walk_cycle_with_the_wrong_number_of_legs()
	test_installing_into_a_player()
	test_reinstalling_replaces_rather_than_duplicates()
	test_phase_at()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[animation-in-code] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _legs() -> Array[NodePath]:
	var paths: Array[NodePath] = [^"FrontLeft", ^"FrontRight", ^"BackLeft", ^"BackRight"]
	return paths

func test_an_empty_clip() -> void:
	print("an empty clip")
	var clip := ClipBuilder.new_clip(2.0)
	expect(is_equal_approx(clip.length, 2.0), "the clip is as long as asked")
	expect(clip.loop_mode == Animation.LOOP_LINEAR, "and loops by default")
	expect(clip.get_track_count() == 0, "with no tracks yet")
	expect(ClipBuilder.new_clip(1.0, false).loop_mode == Animation.LOOP_NONE,
		"a one-shot clip does not loop")

func test_a_clip_cannot_have_zero_length() -> void:
	print("degenerate length")
	# Zero length is not an animation, it is a division by zero waiting for
	# whoever samples it.
	expect(ClipBuilder.new_clip(0.0).length > 0.0, "a zero-length clip is floored")
	expect(ClipBuilder.new_clip(-5.0).length > 0.0, "and so is a negative one")

func test_position_tracks_hold_their_keys() -> void:
	print("position tracks")
	var clip := ClipBuilder.new_clip(1.0)
	var track := ClipBuilder.add_position_track(clip, ^"Body", [
		[0.0, Vector3(0, 1, 0)],
		[0.5, Vector3(0, 2, 0)],
		[1.0, Vector3(0, 1, 0)],
	])
	expect(track == 0, "the first track is index zero")
	expect(clip.track_get_type(track) == Animation.TYPE_POSITION_3D, "it is a position track")
	expect(clip.track_get_path(track) == NodePath("Body"), "pointing at the node it was given")
	expect(clip.track_get_key_count(track) == 3, "with all three keys in it")

func test_sampling_a_position_track_between_keys() -> void:
	print("sampling")
	var clip := ClipBuilder.new_clip(1.0)
	var track := ClipBuilder.add_position_track(clip, ^"Body", [
		[0.0, Vector3(0, 0, 0)],
		[1.0, Vector3(0, 4, 0)],
	])
	# The check that matters: not "are the keys there" but "does the clip
	# produce the value it looks like it should" halfway between them.
	var middle: Vector3 = clip.position_track_interpolate(track, 0.5)
	expect(is_equal_approx(middle.y, 2.0), "halfway between two keys is halfway between their values")
	var start: Vector3 = clip.position_track_interpolate(track, 0.0)
	expect(is_zero_approx(start.y), "and the first key is exact")

func test_rotation_tracks_are_quaternions() -> void:
	print("rotation tracks")
	var clip := ClipBuilder.new_clip(1.0)
	var track := ClipBuilder.add_rotation_track(clip, ^"Leg", [
		[0.0, Quaternion(Vector3.RIGHT, 0.0)],
		[1.0, Quaternion(Vector3.RIGHT, 1.0)],
	])
	expect(clip.track_get_type(track) == Animation.TYPE_ROTATION_3D,
		"a rotation track holds quaternions, not Euler angles")
	var half: Quaternion = clip.rotation_track_interpolate(track, 0.5)
	expect(absf(half.get_angle() - 0.5) < 0.01, "and interpolates along the shortest arc")

func test_a_swing_returns_to_where_it_started() -> void:
	print("closing the loop")
	var clip := ClipBuilder.new_clip(1.0)
	var track := ClipBuilder.add_swing_track(clip, ^"Leg", Vector3.RIGHT, 30.0)
	var start: Quaternion = clip.rotation_track_interpolate(track, 0.0)
	var finish: Quaternion = clip.rotation_track_interpolate(track, clip.length)
	# Without a closing key the wrap from the end back to the start is a jump —
	# a limb that snaps once per cycle, which reads as a dropped frame.
	expect(start.is_equal_approx(finish), "the end of the cycle matches its beginning")

func test_a_swing_reaches_its_angle() -> void:
	print("swing size")
	var clip := ClipBuilder.new_clip(1.0)
	var track := ClipBuilder.add_swing_track(clip, ^"Leg", Vector3.RIGHT, 30.0)
	var forward: Quaternion = clip.rotation_track_interpolate(track, 0.25)
	expect(absf(forward.get_angle() - deg_to_rad(30.0)) < 0.01,
		"a quarter of the way in, the limb is fully forward")
	var neutral: Quaternion = clip.rotation_track_interpolate(track, 0.5)
	expect(neutral.get_angle() < 0.01, "and halfway through it is back at neutral")

func test_phase_shifts_the_swing() -> void:
	print("phase")
	var clip := ClipBuilder.new_clip(1.0)
	var early := ClipBuilder.add_swing_track(clip, ^"LegA", Vector3.RIGHT, 30.0, 0.0)
	var late := ClipBuilder.add_swing_track(clip, ^"LegB", Vector3.RIGHT, 30.0, 0.5)
	var a: Quaternion = clip.rotation_track_interpolate(early, 0.25)
	var b: Quaternion = clip.rotation_track_interpolate(late, 0.25)
	expect(not a.is_equal_approx(b), "two legs half a cycle apart are not in the same place")
	var b_later: Quaternion = clip.rotation_track_interpolate(late, 0.75)
	expect(a.is_equal_approx(b_later),
		"the later leg reaches the same pose half a cycle afterwards")

	# Half a cycle is symmetric — it looks the same shifted forwards or
	# backwards — so it cannot tell a phase from its negative. A quarter can.
	var quarter := ClipBuilder.add_swing_track(clip, ^"LegC", Vector3.RIGHT, 30.0, 0.25)
	# The whole quaternion, not just its angle: get_angle() has no sign, so a
	# phase applied backwards puts the limb at -30° and still measures 30°.
	var expected := Quaternion(Vector3.RIGHT, deg_to_rad(30.0))
	var forward: Quaternion = clip.rotation_track_interpolate(quarter, 0.5)
	expect(forward.is_equal_approx(expected),
		"a quarter-cycle phase delays the forward reach to halfway through")
	var neutral: Quaternion = clip.rotation_track_interpolate(quarter, 0.25)
	expect(neutral.get_angle() < 0.01,
		"with the neutral pose arriving a quarter of a cycle earlier")

func test_a_walk_cycle_has_one_track_per_leg() -> void:
	print("the walk")
	var clip := ClipBuilder.walk_cycle(_legs(), 30.0, 1.2)
	expect(clip.get_track_count() == 4, "four legs, four tracks")
	expect(is_equal_approx(clip.length, 1.2), "the cycle is as long as asked")
	expect(clip.loop_mode == Animation.LOOP_LINEAR, "and loops, because a walk repeats")

func test_diagonal_legs_move_together() -> void:
	print("gait")
	var clip := ClipBuilder.walk_cycle(_legs(), 30.0, 1.0)
	var front_left: Quaternion = clip.rotation_track_interpolate(0, 0.25)
	var front_right: Quaternion = clip.rotation_track_interpolate(1, 0.25)
	var back_left: Quaternion = clip.rotation_track_interpolate(2, 0.25)
	var back_right: Quaternion = clip.rotation_track_interpolate(3, 0.25)
	# A trot: front-left with back-right, front-right with back-left. All four
	# in step is a hop, and it is the same keys with the phases wrong.
	expect(front_left.is_equal_approx(back_right), "front-left and back-right move together")
	expect(front_right.is_equal_approx(back_left), "as do front-right and back-left")
	expect(not front_left.is_equal_approx(front_right), "while the pairs are out of step")

func test_a_walk_cycle_with_the_wrong_number_of_legs() -> void:
	print("not four legs")
	var three: Array[NodePath] = [^"A", ^"B", ^"C"]
	var clip := ClipBuilder.walk_cycle(three, 30.0, 1.0)
	expect(clip.get_track_count() == 0,
		"a creature that is not four-legged gets an empty clip rather than a broken one")

func test_installing_into_a_player() -> void:
	print("installing")
	var player := AnimationPlayer.new()
	add_child(player)
	ClipBuilder.install(player, ClipBuilder.walk_cycle(_legs(), 30.0, 1.0), "walk")
	expect(player.has_animation("walk"), "the player can find the clip by name")
	expect(player.get_animation("walk").get_track_count() == 4, "and it is the clip that was built")
	player.free()

func test_reinstalling_replaces_rather_than_duplicates() -> void:
	print("rebuilding")
	var player := AnimationPlayer.new()
	add_child(player)
	ClipBuilder.install(player, ClipBuilder.walk_cycle(_legs(), 20.0, 1.0), "walk")
	ClipBuilder.install(player, ClipBuilder.walk_cycle(_legs(), 60.0, 2.0), "walk")
	expect(player.get_animation_list().size() == 1, "installing twice leaves one clip")
	expect(is_equal_approx(player.get_animation("walk").length, 2.0), "and it is the newer one")
	player.free()

func test_phase_at() -> void:
	print("staying in step")
	expect(is_equal_approx(ClipBuilder.phase_at(0.5, 1.0, 0.0), 0.5), "halfway through is 0.5")
	expect(is_equal_approx(ClipBuilder.phase_at(1.25, 1.0, 0.0), 0.25), "and the cycle wraps")
	expect(is_equal_approx(ClipBuilder.phase_at(0.0, 1.0, 0.5), 0.5), "a phase offset shifts it")
	# Again asymmetric, so shifting the wrong way is distinguishable.
	expect(is_equal_approx(ClipBuilder.phase_at(0.0, 1.0, 0.25), 0.25),
		"a quarter-cycle offset moves it a quarter forward, not back")
	expect(is_equal_approx(ClipBuilder.phase_at(0.5, 2.0, 0.25), 0.5),
		"and the offset is added after the period is divided out")
	expect(is_zero_approx(ClipBuilder.phase_at(1.0, 0.0, 0.0)),
		"a period of zero is nothing rather than a division by zero")
