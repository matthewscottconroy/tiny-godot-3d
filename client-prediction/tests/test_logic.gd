extends Node

# Drives the real Prediction from scripts/prediction.gd, and then runs the real
# demo against its own fake server — because the claim worth checking is that a
# client which guessed wrong ends up exactly where the server says, and that is
# a claim about a whole loop rather than about one function.

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_the_step_both_ends_run()
	test_the_step_is_frame_rate_independent()
	test_diagonal_input_is_not_faster()
	test_predicting_records_the_input()
	test_sequence_numbers_count_up()
	test_acknowledging_drops_what_is_done()
	test_reconciling_when_the_server_agrees()
	test_reconciling_when_the_server_disagrees()
	test_replaying_beats_snapping()
	test_a_correction_too_small_to_bother_with()
	test_a_correction_too_big_to_smooth()
	test_easing_is_frame_rate_independent()
	test_resetting()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[client-prediction] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_step_both_ends_run() -> void:
	print("the shared step")
	# The single most important function here. If the server's version differs by
	# so much as an operator, the client is corrected constantly and the player
	# feels it as rubber-banding.
	var after := Prediction.step(Vector3.ZERO, Vector3.RIGHT, 0.5, 6.0)
	expect(is_equal_approx(after.x, 3.0), "half a second at six metres a second is three metres")
	expect(Prediction.step(Vector3.ZERO, Vector3.ZERO, 0.5).is_zero_approx(),
		"and no input moves nothing")

func test_the_step_is_frame_rate_independent() -> void:
	print("frame rate")
	var one_big := Prediction.step(Vector3.ZERO, Vector3.RIGHT, 0.2)
	var two_small := Prediction.step(
		Prediction.step(Vector3.ZERO, Vector3.RIGHT, 0.1), Vector3.RIGHT, 0.1)
	expect(one_big.is_equal_approx(two_small),
		"one long step and two short ones arrive at the same place")

func test_diagonal_input_is_not_faster() -> void:
	print("diagonals")
	# Unclamped input is the oldest bug in movement code: hold two directions and
	# you move 1.41 times as fast. Here it also desynchronises the two ends.
	var straight := Prediction.step(Vector3.ZERO, Vector3.RIGHT, 1.0).length()
	var diagonal := Prediction.step(Vector3.ZERO, Vector3(1, 0, 1), 1.0).length()
	expect(absf(diagonal - straight) < 0.001, "diagonal input is no faster than straight")

func test_predicting_records_the_input() -> void:
	print("recording")
	var prediction := Prediction.new()
	var position := prediction.predict(Vector3.ZERO, Vector3.RIGHT, 0.1)
	expect(is_equal_approx(position.x, 0.6), "predicting moves the character now, not later")
	# Every input is kept until the server acknowledges it: the correction
	# arrives stamped with the last one it saw, and the rest have to be replayed.
	expect(prediction.pending() == 1, "and keeps the input that did it")

func test_sequence_numbers_count_up() -> void:
	print("sequence numbers")
	var prediction := Prediction.new()
	prediction.predict(Vector3.ZERO, Vector3.RIGHT, 0.1)
	prediction.predict(Vector3.ZERO, Vector3.RIGHT, 0.1)
	expect(prediction.last_sequence() == 1, "the second input is number one")
	expect(prediction.pending() == 2, "and both are still waiting")

func test_acknowledging_drops_what_is_done() -> void:
	print("acknowledging")
	var prediction := Prediction.new()
	for i in 5:
		prediction.predict(Vector3.ZERO, Vector3.RIGHT, 0.1)
	prediction.forget_up_to(2)
	expect(prediction.pending() == 2, "acknowledging up to two leaves three and four")
	prediction.forget_up_to(99)
	expect(prediction.pending() == 0, "and acknowledging everything leaves nothing")
	prediction.forget_up_to(-1)
	expect(prediction.pending() == 0, "an acknowledgement for nothing drops nothing")

func test_reconciling_when_the_server_agrees() -> void:
	print("agreement")
	var prediction := Prediction.new()
	var position := Vector3.ZERO
	for i in 3:
		position = prediction.predict(position, Vector3.RIGHT, 0.1)
	# The server has seen the first input and agrees about where it ended up.
	var corrected := prediction.reconcile(Prediction.step(Vector3.ZERO, Vector3.RIGHT, 0.1), 0)
	expect(corrected.is_equal_approx(position),
		"when the server agrees, replaying puts the character exactly where it already was")
	expect(prediction.pending() == 2, "with the acknowledged input dropped")

func test_reconciling_when_the_server_disagrees() -> void:
	print("disagreement")
	var prediction := Prediction.new()
	var position := Vector3.ZERO
	for i in 3:
		position = prediction.predict(position, Vector3.RIGHT, 0.1)
	# The server says the first step ended somewhere else — a wall the client did
	# not know about.
	var corrected := prediction.reconcile(Vector3(0.2, 0, 0), 0)
	expect(not corrected.is_equal_approx(position), "the correction moves the character")
	# Two unacknowledged inputs replayed on top of the server's position.
	expect(is_equal_approx(corrected.x, 0.2 + 1.2),
		"landing where the remaining inputs would have taken it from there (%.2f)" % corrected.x)

func test_replaying_beats_snapping() -> void:
	print("replay, not snap")
	var prediction := Prediction.new()
	var position := Vector3.ZERO
	for i in 10:
		position = prediction.predict(position, Vector3.RIGHT, 0.1)
	var server := Vector3(0.5, 0, 0)
	var corrected := prediction.reconcile(server, 0, 6.0)
	# Snapping to the server position throws away every input the player has made
	# since. Replaying keeps them, which is the entire difference between a
	# correction the player notices and one they do not.
	expect(corrected.x > server.x + 5.0,
		"the replayed position is far ahead of the server's (%.2f against %.2f)"
			% [corrected.x, server.x])

func test_a_correction_too_small_to_bother_with() -> void:
	print("tolerance")
	# Floating point drifts between two machines running the same code.
	# Correcting a two-millimetre disagreement every frame is visible jitter with
	# no cause.
	expect(not Prediction.worth_correcting(Vector3.ZERO, Vector3(0.005, 0, 0)),
		"five millimetres is drift, not a correction")
	expect(Prediction.worth_correcting(Vector3.ZERO, Vector3(0.5, 0, 0)),
		"half a metre is a correction")

func test_a_correction_too_big_to_smooth() -> void:
	print("snapping")
	# A metre is a mistake to smooth away. Forty is a respawn, and smoothing it
	# is a character flying across the level for a second and a half.
	expect(not Prediction.should_snap(Vector3.ZERO, Vector3(1, 0, 0)), "a metre is smoothed")
	expect(Prediction.should_snap(Vector3.ZERO, Vector3(40, 0, 0)), "forty metres is a teleport")

func test_easing_is_frame_rate_independent() -> void:
	print("easing")
	var target := Vector3(10, 0, 0)
	var slow := Prediction.ease_toward(Vector3.ZERO, target, 0.1)
	var fast := Vector3.ZERO
	for i in 10:
		fast = Prediction.ease_toward(fast, target, 0.01)
	# A correction that takes twice as long on a slower machine is a correction
	# the player on that machine can see.
	expect(absf(slow.x - fast.x) < 0.05,
		"the same time in one step or ten arrives at the same place (%.3f, %.3f)"
			% [slow.x, fast.x])
	expect(Prediction.ease_toward(Vector3.ZERO, target, 0.0).is_zero_approx(),
		"and no time at all moves nothing")

func test_resetting() -> void:
	print("reset")
	var prediction := Prediction.new()
	for i in 4:
		prediction.predict(Vector3.ZERO, Vector3.RIGHT, 0.1)
	prediction.reset()
	expect(prediction.pending() == 0, "reset drops the pending inputs")
	expect(prediction.last_sequence() == -1, "and starts the numbering again")

# --- the real loop ---------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real client and server")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			# Straight at a wall the client's own simulation knows nothing about.
			Input.action_press(&"ui_right")
		120:
			# Long enough to walk past the wall, then stop and let the queue
			# drain: the client only agrees with the server once the last input
			# has made the round trip.
			Input.action_release(&"ui_right")
		100:
			_check_the_pipeline()
		160:
			_check_the_loop()
			_check_the_latency_keys()
			_report()

## Mid-flight: the queue is full and the client is ahead of the server by
## roughly a latency's worth of inputs.
func _check_the_pipeline() -> void:
	var prediction = _scene.get("_prediction")
	var latency: float = _scene.get("_latency")
	var in_flight: int = prediction.pending()
	# 120ms at 60Hz is about seven inputs the server has not answered yet. A
	# client showing zero here is one whose packets arrive instantly, which is
	# not a network and does not need any of this.
	expect(in_flight > 3,
		"there are %d inputs in flight at %.0f ms of latency" % [in_flight, latency * 1000.0])
	expect(_scene.get("_predicted").x > _scene.get("_authoritative").x,
		"and the client is ahead of the server, which is the whole point")

	var marker: MeshInstance3D = _scene.get_node("Server")
	expect(is_equal_approx(marker.position.z, (_scene.get("_authoritative") as Vector3).z + 2.5),
		"the server's marker is drawn alongside where the server says the character is")

func _check_the_latency_keys() -> void:
	var before: float = _scene.get("_latency")
	var press := InputEventKey.new()
	press.keycode = KEY_2
	press.pressed = true
	_scene.call("_unhandled_key_input", press)
	expect(_scene.get("_latency") > before, "pressing 2 puts the latency up")

	var down := InputEventKey.new()
	down.keycode = KEY_1
	down.pressed = true
	_scene.call("_unhandled_key_input", down)
	expect(is_equal_approx(_scene.get("_latency"), before), "and 1 puts it back down")

	var echo := InputEventKey.new()
	echo.keycode = KEY_2
	echo.pressed = true
	echo.echo = true
	_scene.call("_unhandled_key_input", echo)
	expect(is_equal_approx(_scene.get("_latency"), before), "a key repeat changes nothing")

	var release := InputEventKey.new()
	release.keycode = KEY_2
	release.pressed = false
	_scene.call("_unhandled_key_input", release)
	expect(is_equal_approx(_scene.get("_latency"), before), "and neither does letting go")

func _check_the_loop() -> void:
	var client: Vector3 = _scene.get("_predicted")
	var server: Vector3 = _scene.get("_authoritative")
	var corrections: int = _scene.get("_corrections")
	var worst: float = _scene.get("_worst")

	expect(client.x > -6.0, "the client moved as soon as the player pressed a key")
	# The server owns the wall, so this is the number that matters: whatever the
	# client believed on the way, it ends up where the server says.
	expect(server.x < 3.5, "the server stopped the character at its wall (x %.2f)" % server.x)
	expect(absf(client.x - server.x) < 0.2,
		"and the client agrees with it once the corrections have arrived (%.2f against %.2f)"
			% [client.x, server.x])

	expect(corrections > 0, "which took real corrections (%d)" % corrections)
	# About one frame of movement, and no more: a correction arrives every frame
	# here, so the error is caught before it can accumulate. A real server ticks
	# slower than the client, and this number grows with the gap between them.
	expect(worst > 0.05 and worst < 0.3,
		"against a real disagreement of roughly one frame's movement (%.2f m at its worst)"
			% worst)
	# Nothing should still be waiting once the player has stopped and the queue
	# has drained: a pending list that only grows is a leak with a latency.
	expect(_scene.get("_prediction").pending() < 20,
		"and the pending list drained rather than growing for ever (%d)"
			% _scene.get("_prediction").pending())
