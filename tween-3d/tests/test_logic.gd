extends Node

# Drives the real Transitions from scripts/transitions.gd against real Tweens on
# a real node — a fake tween would prove nothing about the thing this is for,
# which is what happens when two of them want the same property.

var _pass := 0
var _fail := 0
var _frame := 0
var _stage := 0
var _subject: Node3D = null
var _transitions := Transitions.new()
var _loose_a: Tween = null
var _loose_b: Tween = null
var _elapsed := 0.0

func _ready() -> void:
	test_duration_scales_with_distance()
	test_duration_is_clamped()
	test_duration_with_no_speed()
	_subject = Node3D.new()
	add_child(_subject)

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[tween-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_duration_scales_with_distance() -> void:
	print("duration")
	# A fixed duration makes small moves feel sluggish and big ones feel
	# teleported. Deriving it from the distance is one line.
	var near := Transitions.duration_for(1.0, 4.0)
	var far := Transitions.duration_for(3.0, 4.0)
	expect(far > near, "a longer move takes longer")
	expect(is_equal_approx(near, 0.25), "at four metres a second, one metre is a quarter second")
	expect(is_equal_approx(Transitions.duration_for(-3.0, 4.0), far),
		"and the direction does not change how long it takes")

func test_duration_is_clamped() -> void:
	print("duration limits")
	expect(is_equal_approx(Transitions.duration_for(0.001, 4.0), 0.08),
		"a tiny move still takes long enough to be seen as a move")
	expect(is_equal_approx(Transitions.duration_for(500.0, 4.0), 1.0),
		"and a huge one does not take eight minutes")

func test_duration_with_no_speed() -> void:
	print("degenerate speed")
	expect(is_equal_approx(Transitions.duration_for(5.0, 0.0), 1.0),
		"a speed of zero gives the longest duration rather than an infinite one")

# --- real tweens -----------------------------------------------------------

func _process(delta: float) -> void:
	_frame += 1
	_elapsed += delta
	match _stage:
		0:
			if _frame < 2:
				return
			print("real tweens")
			_start_one()
			_stage = 1
		1:
			_check_running()
			_replace_it()
			_stage = 2
		2:
			_check_replacement()
			_stage = 3
		3:
			# Tween durations are wall-clock seconds, so this waits on elapsed
			# time rather than on a frame count — headless frames are far
			# quicker than a sixtieth of a second each.
			if _elapsed < 1.2:
				return
			_check_it_finished()
			_start_the_fight()
			_stage = 4
		4:
			if _elapsed < 2.0:
				return
			_check_the_fight()
			_report()
			_stage = 5

func _start_one() -> void:
	_transitions.start(_subject, ^"position:y", 5.0, 1.0)

func _check_running() -> void:
	expect(_transitions.is_running(_subject, ^"position:y"), "a started transition is running")
	expect(_transitions.count() == 1, "and is the only one")

	# A tween killed behind the guard's back is still a key in the dictionary and
	# is emphatically not running. Both halves of that check have to hold, or
	# `is_running()` starts answering about tweens that are gone.
	var other := Node3D.new()
	add_child(other)
	var doomed := _transitions.start(other, ^"position:x", 5.0, 1.0)
	doomed.kill()
	expect(not _transitions.is_running(other, ^"position:x"),
		"a killed tween is not running, however valid the handle looks")

	# And a paused one is the other way round: perfectly valid, and not running.
	# Either half alone would call that a live transition and refuse to start a
	# new one over it.
	var paused := _transitions.start(other, ^"position:z", 5.0, 1.0)
	paused.pause()
	expect(paused.is_valid(), "a paused tween is still valid")
	expect(not _transitions.is_running(other, ^"position:z"), "and still not running")
	# And it has to be cleared by hand: a paused tween never finishes, so the
	# signal that normally drops the key never fires.
	expect(_transitions.stop(other, ^"position:z"), "so it has to be stopped rather than waited for")
	expect(_transitions.stop(other, ^"position:x"),
		"and stopping it reports that there was something to stop")
	expect(not _transitions.stop(other, ^"position:x"),
		"the second time, that there was not")
	other.queue_free()

func _replace_it() -> void:
	# The whole point: a second start on the same property replaces the first
	# rather than joining it.
	_transitions.start(_subject, ^"position:y", -5.0, 1.0)

func _check_replacement() -> void:
	expect(_transitions.count() == 1, "starting the same property again leaves one tween, not two")
	expect(_transitions.is_running(_subject, ^"position:y"), "and it is the new one, still running")
	expect(_subject.position.y < 5.0, "heading for the new target rather than the old one")

func _check_it_finished() -> void:
	expect(is_equal_approx(_subject.position.y, -5.0),
		"the replacement arrived where it was sent (%.2f)" % _subject.position.y)
	expect(not _transitions.is_running(_subject, ^"position:y"), "and is no longer running")
	# A finished Tween becomes invalid; holding the key would slowly turn the
	# dictionary into a list of every transition the game has ever played.
	expect(_transitions.count() == 0, "and has been dropped rather than remembered forever")
	expect(not _transitions.stop(_subject, ^"position:y"),
		"stopping something that is not running reports that there was nothing to stop")

func _start_the_fight() -> void:
	# Two tweens, same property, no guard — the bug the guard exists for.
	_subject.position.y = 0.0
	_loose_a = _subject.create_tween()
	_loose_a.tween_property(_subject, ^"position:y", 10.0, 0.3)
	_loose_b = _subject.create_tween()
	_loose_b.tween_property(_subject, ^"position:y", -10.0, 0.3)

func _check_the_fight() -> void:
	# Both ran to completion, both wrote the property every frame, and the value
	# is whichever one happened to run last. Nothing errored.
	expect(not _loose_a.is_running() and not _loose_b.is_running(),
		"both unguarded tweens ran to the end")
	expect(is_equal_approx(_subject.position.y, -10.0),
		"and the property ended up at the last one's target (%.2f), not the first's"
			% _subject.position.y)

	# Through the guard, the same two calls leave one winner by design.
	_subject.position.y = 0.0
	_transitions.start(_subject, ^"position:y", 10.0, 0.3)
	_transitions.start(_subject, ^"position:y", -10.0, 0.3)
	expect(_transitions.count() == 1, "the guarded version of the same two calls leaves one tween")
	_transitions.stop_all()
	expect(_transitions.count() == 0, "and stop_all clears the lot")
