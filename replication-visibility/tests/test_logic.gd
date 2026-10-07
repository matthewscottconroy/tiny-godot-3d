extends Node

# Drives the real Relevance from scripts/replication_visibility.gd, then checks
# the real scene actually wired a MultiplayerSynchronizer — because the whole
# claim of this demo is that the engine does the sending, and a demo that
# quietly did it some other way would look identical.
#
# mutate-driver: skip — the scene is instantiated to inspect a real synchronizer, not main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_range_is_measured_on_the_ground()
	test_leaving_is_further_than_entering()
	test_hysteresis_stops_the_edge_flapping()
	test_distant_things_are_sent_less_often()
	test_an_inverted_band_does_not_divide_by_zero()
	test_the_saving_is_against_the_quadratic()
	test_the_audience_excludes_the_owner()
	test_an_unknown_owner_has_no_audience()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[replication-visibility] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const HERE := Vector3.ZERO

func test_range_is_measured_on_the_ground() -> void:
	print("range")
	expect(Relevance.in_range(HERE, Vector3(3, 0, 4), 6.0), "five metres away is inside six")
	expect(not Relevance.in_range(HERE, Vector3(3, 0, 4), 4.0), "and outside four")
	# Flat, not spherical: a player on a walkway directly overhead is as relevant
	# as one standing beside you, and counting the height would drop them.
	expect(Relevance.in_range(HERE, Vector3(0, 40, 0), 1.0),
		"height does not push someone out of range")
	expect(Relevance.in_range(HERE, Vector3(6, 0, 0), 6.0), "exactly on the radius is inside")

	# A viewer away from the origin, on both axes. At (0, 0, 0) subtracting the
	# viewer and adding it are the same thing, so half of this arithmetic goes
	# unchecked — and a relevance bubble centred on the world origin rather than
	# on the player is a bug that only shows up once someone walks away from it.
	var viewer := Vector3(10.0, 0.0, -20.0)
	expect(Relevance.in_range(viewer, Vector3(13.0, 0.0, -24.0), 6.0),
		"five metres from a viewer that is not at the origin is in range")
	expect(not Relevance.in_range(viewer, Vector3(17.0, 0.0, -20.0), 6.0),
		"and seven metres along x from it is not")
	expect(not Relevance.in_range(viewer, Vector3(10.0, 0.0, -27.0), 6.0),
		"nor seven metres along z")

func test_leaving_is_further_than_entering() -> void:
	print("two radii")
	var far := Vector3(7, 0, 0)
	expect(not Relevance.stays_relevant(false, HERE, far, 6.0, 8.0),
		"at seven metres, someone not being sent to stays not sent")
	expect(Relevance.stays_relevant(true, HERE, far, 6.0, 8.0),
		"but someone already being sent to keeps being sent")

func test_hysteresis_stops_the_edge_flapping() -> void:
	print("the boundary")
	# Each flip is a full state resend, so a peer loitering on a single radius
	# costs more traffic than one standing in the middle of the bubble.
	var relevant := false
	var flips := 0
	for i in 60:
		# Hovering either side of the enter radius, as someone walking a line does.
		var x := 6.0 + sin(float(i) * 0.7) * 0.4
		var now := Relevance.stays_relevant(relevant, HERE, Vector3(x, 0, 0), 6.0, 8.0)
		if now != relevant:
			flips += 1
		relevant = now
	expect(flips <= 1, "sixty frames on the boundary cause at most one change (%d)" % flips)

	# And with one radius it would thrash, which is the point of having two.
	var single := false
	var single_flips := 0
	for i in 60:
		var x := 6.0 + sin(float(i) * 0.7) * 0.4
		var now := Relevance.stays_relevant(single, HERE, Vector3(x, 0, 0), 6.0, 6.0)
		if now != single:
			single_flips += 1
		single = now
	expect(single_flips > 5,
		"where a single radius flips repeatedly (%d), which is what to avoid" % single_flips)

func test_distant_things_are_sent_less_often() -> void:
	print("rate falloff")
	# Relevance is not really binary: someone across the map still has to exist
	# on a minimap, they just do not need twenty updates a second to do it.
	expect(is_equal_approx(Relevance.interval_for(0.0, 6.0, 24.0), 0.05),
		"inside the near band, the full rate")
	expect(is_equal_approx(Relevance.interval_for(99.0, 6.0, 24.0), 0.5),
		"past the far band, the slow rate, rather than slower still")
	var middle := Relevance.interval_for(15.0, 6.0, 24.0)
	expect(absf(middle - 0.275) < 0.001, "and halfway between, halfway (%.3f)" % middle)
	expect(Relevance.interval_for(10.0, 6.0, 24.0) < Relevance.interval_for(20.0, 6.0, 24.0),
		"nearer is always sent more often than further")

func test_an_inverted_band_does_not_divide_by_zero() -> void:
	print("degenerate bands")
	expect(is_equal_approx(Relevance.interval_for(5.0, 10.0, 10.0), 0.05),
		"a zero-width band falls back to the near rate rather than dividing by zero")
	expect(is_equal_approx(Relevance.interval_for(5.0, 10.0, 2.0), 0.05),
		"and so does one given the wrong way round")

func test_the_saving_is_against_the_quadratic() -> void:
	print("what it saves")
	# n*(n-1) is the number worth showing, because it is the one that grows
	# quadratically while the bandwidth bill grows with it.
	expect(is_equal_approx(Relevance.streams_saved(16, 240), 0.0),
		"sending everything to everyone saves nothing")
	expect(is_equal_approx(Relevance.streams_saved(16, 120), 0.5),
		"sending half of them saves half")
	expect(is_equal_approx(Relevance.streams_saved(16, 0), 1.0), "and sending none saves all of it")
	expect(is_equal_approx(Relevance.streams_saved(1, 0), 0.0),
		"one peer has nobody to tell, so there is nothing to save")
	expect(is_equal_approx(Relevance.streams_saved(0, 0), 0.0), "and neither has none")

func test_the_audience_excludes_the_owner() -> void:
	print("who hears about it")
	var positions := {
		1: Vector3.ZERO,
		2: Vector3(3, 0, 0),
		3: Vector3(30, 0, 0),
	}
	var heard := Relevance.audience(1, positions, 6.0)
	expect(heard.size() == 1 and heard[0] == 2,
		"the near peer hears about it and the far one does not (%s)" % str(heard))
	# A synchronizer does not send a player their own state back; doing so is how
	# an authority ends up fighting its own client over a position.
	expect(not heard.has(1), "and the owner is never in their own audience")

func test_an_unknown_owner_has_no_audience() -> void:
	print("a peer that has gone")
	# A peer can disconnect between the filter being asked and the positions
	# being collected, and the answer has to be "tell nobody" rather than a crash.
	expect(Relevance.audience(99, {1: Vector3.ZERO}, 6.0).is_empty(),
		"an owner with no position tells nobody")

# --- the real synchronizer --------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real synchronizer")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			var sync: MultiplayerSynchronizer = null
			for child in _scene.get_children():
				if child is MultiplayerSynchronizer:
					sync = child
			expect(sync != null, "the driver built a MultiplayerSynchronizer")
			if sync == null:
				_report()
				return

			# The claim the demo makes: the engine does the sending. A demo that
			# had quietly kept an @rpc would look identical on screen.
			var config := sync.replication_config
			expect(config != null, "with a replication config")
			expect(config.has_property(^"Pawn:position"),
				"naming the pawn's position as the thing to replicate")
			expect(config.property_get_replication_mode(^"Pawn:position")
					== SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
				"on change rather than always, so a standing player costs nothing")

			# Visibility off by default is what makes the filter meaningful: public
			# visibility sends to everyone and the filter is never consulted.
			expect(not sync.is_visibility_public(),
				"nobody is sent anything until the filter says so")
			expect(sync.replication_interval > 0.0,
				"and it sends at a bounded rate rather than every frame")
			_report()
