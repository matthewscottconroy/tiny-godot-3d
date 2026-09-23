extends Node

# Drives the real Rewind from scripts/lag_compensation.gd, and then the real
# scene, to check the claim the whole demo rests on: a shot aimed at what the
# shooter could see hits when the server rewinds and misses when it does not.
#
# mutate-driver: skip — the scene is instantiated to drive the real driver's history, not its input

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_both_delays_are_subtracted()
	test_a_negative_round_trip_is_not_the_future()
	test_a_recorded_moment_comes_back_exactly()
	test_between_samples_it_interpolates()
	test_it_never_extrapolates()
	test_old_samples_are_dropped()
	test_time_may_not_run_backwards()
	test_a_shot_down_the_line_hits()
	test_a_shot_behind_you_never_hits()
	test_rewinding_is_the_difference_between_a_hit_and_a_miss()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[lag-compensation] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

## Where the fixture's target is at a given moment.
##
## Deliberately not a straight line. A target moving at constant speed makes
## interpolating between the right two samples, extrapolating past the end, and
## picking entirely the wrong pair all give the same answer — so every mutation
## of the search that finds those samples survives, and the suite proves nothing
## about it. Accelerating separates them.
func _pos(t: float) -> Vector3:
	return Vector3(t * t * 4.0, 0.0, 0.0)

func _filled(history: float = 1.0) -> Rewind:
	var r := Rewind.new()
	r.history_seconds = history
	# One sample every 50ms, as a server recording ticks would.
	for i in 21:
		var t := float(i) * 0.05
		r.record(t, {&"target": _pos(t)})
	return r

func test_both_delays_are_subtracted() -> void:
	print("the moment they saw")
	# Half the round trip is how long the shot took to arrive. The interpolation
	# delay is the client's own — it draws others slightly in the past so their
	# movement is smooth — so what it *drew* was already older than what it had.
	expect(is_equal_approx(Rewind.seen_at(1.0, 0.2, 0.1), 0.8),
		"half the round trip and the interpolation delay both come off")
	expect(is_equal_approx(Rewind.seen_at(1.0, 0.2, 0.0), 0.9),
		"with no interpolation delay, only half the round trip does")
	expect(is_equal_approx(Rewind.seen_at(1.0, 0.0, 0.0), 1.0),
		"and a perfect connection saw the present")
	# Forgetting the interpolation delay is the subtle version of this bug:
	# shots land a little behind a moving target and the hitboxes get blamed.
	expect(Rewind.seen_at(1.0, 0.2) < Rewind.seen_at(1.0, 0.2, 0.0),
		"the default delay is not zero, so it is not quietly skipped")

func test_a_negative_round_trip_is_not_the_future() -> void:
	print("nonsense latency")
	expect(is_equal_approx(Rewind.seen_at(1.0, -5.0, 0.0), 1.0),
		"a negative round trip does not rewind forwards")

func test_a_recorded_moment_comes_back_exactly() -> void:
	print("exact samples")
	var r := _filled()
	var at: Dictionary = r.state_at(0.50)
	expect(at.has(&"target"), "a recorded moment has the things that were in it")
	expect((at[&"target"] as Vector3).is_equal_approx(_pos(0.50)),
		"and gives back exactly where they were")

func test_between_samples_it_interpolates() -> void:
	print("between samples")
	# At 20 updates a second the nearest sample is up to 25ms out, which at
	# running speed is most of a body width. Snapping to it hands back the error
	# the rewind just removed.
	var r := _filled()
	var halfway := _pos(0.50).lerp(_pos(0.55), 0.5)
	var midway: Vector3 = r.state_at(0.525)[&"target"]
	expect(absf(midway.x - halfway.x) < 0.001,
		"halfway between two samples is halfway between two positions (%.3f)" % midway.x)
	var quarter_way := _pos(0.50).lerp(_pos(0.55), 0.25)
	var quarter: Vector3 = r.state_at(0.5125)[&"target"]
	expect(absf(quarter.x - quarter_way.x) < 0.001, "and a quarter of the way is a quarter")
	# Between the samples, not on the curve through them: the rewind interpolates
	# what it was told, and was never told about the acceleration in between.
	expect(midway.x > _pos(0.525).x,
		"the chord between two samples, rather than the path that produced them")

func test_it_never_extrapolates() -> void:
	print("outside the history")
	# Extrapolating invents a position nobody ever saw, which is the one thing
	# this mechanism exists to avoid.
	var r := _filled()
	var before: Vector3 = r.state_at(-10.0)[&"target"]
	var after: Vector3 = r.state_at(99.0)[&"target"]
	expect(before.is_equal_approx(_pos(r.oldest())),
		"a time before the history clamps to the oldest sample")
	expect(after.is_equal_approx(_pos(r.newest())),
		"and a time after it clamps to the newest")
	expect(r.beyond_history(-10.0), "and the caller can tell that it was out of range")
	expect(not r.beyond_history(r.newest()), "while a moment inside it is not")

func test_old_samples_are_dropped() -> void:
	print("bounded memory")
	# A server keeping every position of every player since the match started
	# runs out of memory long before anyone notices the shots are fair.
	var short := _filled(0.2)
	expect(short.samples() < 21, "a short history does not keep everything (%d)" % short.samples())
	expect(short.newest() - short.oldest() <= 0.2 + 0.0001,
		"it spans the window it was given, and no more")
	var long := _filled(10.0)
	expect(long.samples() == 21, "a history longer than the run keeps all of it")

func test_time_may_not_run_backwards() -> void:
	print("out of order")
	# A history recorded out of order cannot be interpolated, and the bug shows
	# up as shots landing between two unrelated moments.
	var r := Rewind.new()
	r.record(1.0, {&"target": Vector3(1, 0, 0)})
	r.record(0.5, {&"target": Vector3(99, 0, 0)})
	expect(r.samples() == 1, "a sample from the past is refused rather than inserted")
	expect((r.state_at(1.0)[&"target"] as Vector3).is_equal_approx(Vector3(1, 0, 0)),
		"and the history it would have corrupted is intact")

func test_a_shot_down_the_line_hits() -> void:
	print("the geometry")
	var origin := Vector3(0, 0, 5)
	expect(Rewind.hits(origin, Vector3(0, 0, -1), Vector3(0, 0, 0), 0.5),
		"a shot straight at something hits it")
	expect(not Rewind.hits(origin, Vector3(0, 0, -1), Vector3(2, 0, 0), 0.5),
		"and one two metres wide of a half-metre target does not")
	expect(Rewind.hits(origin, Vector3(0, 0, -1), Vector3(0.4, 0, 0), 0.5),
		"a clip inside the radius counts")
	expect(not Rewind.hits(origin, Vector3(0, 0, -1), Vector3(0.6, 0, 0), 0.5),
		"and just outside it does not")

func test_a_shot_behind_you_never_hits() -> void:
	print("behind the shooter")
	# Without the check, a ray is a line: something directly behind you is
	# exactly on it, and you shoot people by facing away from them.
	expect(not Rewind.hits(Vector3(0, 0, 5), Vector3(0, 0, -1), Vector3(0, 0, 9), 0.5),
		"a target behind the shooter is not on the shot")
	expect(not Rewind.hits(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, 1), 0.5),
		"and a shot with no direction hits nothing rather than everything")

func test_rewinding_is_the_difference_between_a_hit_and_a_miss() -> void:
	print("the whole point")
	# The claim the demo makes, as arithmetic. A target crossing in front of a
	# shooter on a 200ms connection: aim at what you can see, and the answer
	# depends entirely on which world the server asks about.
	var r := _filled()
	var now := r.newest()
	var shooter := Vector3(0.0, 0.0, 6.0)

	var seen_time := Rewind.seen_at(now, 0.2, 0.1)
	var seen: Vector3 = r.state_at(seen_time)[&"target"]
	var live: Vector3 = r.state_at(now)[&"target"]
	var aim := seen - shooter

	expect(seen.distance_to(live) > 0.5,
		"200ms of lag puts the target well past where it was seen (%.2f m)"
		% seen.distance_to(live))
	expect(Rewind.hits(shooter, aim, seen, 0.5),
		"rewound, the shot lands where the shooter aimed")
	expect(not Rewind.hits(shooter, aim, live, 0.5),
		"and judged against the live position, the same shot misses")

# --- the real server's history ----------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real history")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		8:
			var rewind: Rewind = _scene.get("_rewind")
			expect(rewind != null, "the driver keeps a history")
			expect(rewind.samples() > 1,
				"and has been recording every frame (%d samples)" % rewind.samples())

			# The shooter's marker has to actually lag the live one, or the demo
			# is showing a difference it does not have.
			var live: Node3D = _scene.get_node("Live")
			var seen: Node3D = _scene.get_node("Seen")
			expect(live.position.distance_to(seen.position) > 0.01,
				"the shown position trails the live one at the default ping")
			expect(rewind.newest() - rewind.oldest() <= rewind.history_seconds + 0.0001,
				"and the history stays inside its window while it runs")
			_report()
