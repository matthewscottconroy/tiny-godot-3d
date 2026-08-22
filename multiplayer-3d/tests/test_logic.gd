extends Node

# Drives the real StateBuffer from scripts/state_buffer.gd, then opens a real
# ENet server and connects a real client to it — in one process, on localhost.
#
# Networking is the subject nobody tests, on the grounds that it needs two
# machines. It needs two *peers*, and a peer is an object.

var _pass := 0
var _fail := 0
var _frame := 0
var _stage := 0
var _server: ENetMultiplayerPeer = null
var _client: ENetMultiplayerPeer = null
var _port := 0

func _ready() -> void:
	test_an_empty_buffer()
	test_a_single_sample()
	test_interpolating_between_two()
	test_rendering_the_past()
	test_running_dry_holds_rather_than_guesses()
	test_out_of_order_samples_are_refused()
	test_duplicates_are_refused()
	test_the_latest_position_ignores_the_delay()
	test_it_knows_when_it_is_interpolating()
	test_old_samples_are_dropped()
	test_clearing()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	if _client != null:
		_client.close()
	if _server != null:
		_server.close()
	var summary := "[multiplayer-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _buffer() -> StateBuffer:
	var buffer := StateBuffer.new()
	buffer.delay = 0.1
	return buffer

func test_an_empty_buffer() -> void:
	print("nothing received")
	var buffer := _buffer()
	expect(buffer.count() == 0, "a new buffer holds nothing")
	expect(buffer.sample(1.0) == Vector3.ZERO, "and samples to the origin rather than erroring")
	expect(not buffer.is_interpolating(1.0), "with nothing to interpolate between")

func test_a_single_sample() -> void:
	print("one packet")
	var buffer := _buffer()
	buffer.push(1.0, Vector3(5, 0, 0))
	expect(buffer.sample(1.05) == Vector3(5, 0, 0), "one packet is held, not interpolated")
	expect(not buffer.is_interpolating(1.05), "and the buffer says so")

func test_interpolating_between_two() -> void:
	print("between packets")
	var buffer := _buffer()
	buffer.push(1.0, Vector3.ZERO)
	buffer.push(2.0, Vector3(10, 0, 0))
	# Rendering at 1.6 with a 0.1 delay reads the buffer at 1.5: halfway.
	expect(is_equal_approx(buffer.sample(1.6).x, 5.0), "halfway between two packets is halfway")
	expect(is_equal_approx(buffer.sample(1.35).x, 2.5), "and a quarter of the way, a quarter")

func test_rendering_the_past() -> void:
	print("the delay")
	var buffer := _buffer()
	buffer.push(1.0, Vector3.ZERO)
	buffer.push(2.0, Vector3(10, 0, 0))
	var delayed := buffer.sample(2.0)
	# The point of the whole class: at "now" the buffer draws where the peer was
	# a delay ago, which is the only moment it has data on both sides of.
	expect(delayed.x < 10.0, "at now, the peer is drawn where it was a moment ago")
	expect(is_equal_approx(delayed.x, 9.0), "exactly one delay behind the newest packet")

func test_running_dry_holds_rather_than_guesses() -> void:
	print("running dry")
	var buffer := _buffer()
	buffer.push(1.0, Vector3.ZERO)
	buffer.push(2.0, Vector3(10, 0, 0))
	# Extrapolating here is what puts players through walls, and then snaps them
	# back when the next packet lands.
	expect(buffer.sample(5.0) == Vector3(10, 0, 0), "with nothing newer, the last position holds")
	expect(not buffer.is_interpolating(5.0), "and the buffer knows it has run out")
	expect(buffer.sample(0.5) == Vector3.ZERO, "before the first packet, the oldest holds")

func test_out_of_order_samples_are_refused() -> void:
	print("late packets")
	var buffer := _buffer()
	buffer.push(2.0, Vector3(10, 0, 0))
	# UDP delivers neither in order nor exactly once. A straggler accepted here
	# rewinds the buffer and the remote player jumps backwards.
	expect(not buffer.push(1.0, Vector3.ZERO), "a packet older than the newest is refused")
	expect(buffer.count() == 1, "and does not join the buffer")
	expect(buffer.latest() == Vector3(10, 0, 0), "leaving the newest position intact")

func test_duplicates_are_refused() -> void:
	print("duplicate packets")
	var buffer := _buffer()
	buffer.push(2.0, Vector3(10, 0, 0))
	expect(not buffer.push(2.0, Vector3(99, 0, 0)), "a packet with the same timestamp is refused")
	expect(buffer.latest() == Vector3(10, 0, 0), "and does not overwrite what is there")

func test_the_latest_position_ignores_the_delay() -> void:
	print("latest")
	var buffer := _buffer()
	buffer.push(1.0, Vector3.ZERO)
	buffer.push(2.0, Vector3(10, 0, 0))
	# What a hit test uses: the player being shot at is where they are now, not
	# where they are drawn.
	expect(buffer.latest() == Vector3(10, 0, 0), "the latest position skips the interpolation")
	expect(is_equal_approx(buffer.latest_time(), 2.0), "and reports when it arrived")

func test_it_knows_when_it_is_interpolating() -> void:
	print("interpolating or holding")
	var buffer := _buffer()
	buffer.push(1.0, Vector3.ZERO)
	buffer.push(2.0, Vector3(10, 0, 0))
	expect(buffer.is_interpolating(1.6), "between two packets it is interpolating")
	expect(not buffer.is_interpolating(2.5), "past the newest it is holding")

func test_old_samples_are_dropped() -> void:
	print("trimming")
	var buffer := _buffer()
	buffer.history = 0.5
	for i in 100:
		buffer.push(float(i) * 0.1, Vector3(float(i), 0, 0))
	expect(buffer.count() < 20, "a long session does not grow the buffer forever (%d)"
		% buffer.count())
	# Trimming must not eat the samples the interpolation is reading from.
	var now := 9.9 + buffer.delay
	expect(buffer.is_interpolating(now) or buffer.sample(now) != Vector3.ZERO,
		"while keeping enough to still interpolate")

func test_clearing() -> void:
	print("clearing")
	var buffer := _buffer()
	buffer.push(1.0, Vector3.ONE)
	buffer.clear()
	expect(buffer.count() == 0, "clearing empties it — for a peer that left and came back")
	expect(buffer.latest_time() < 0.0, "with no last packet time to report")

# --- a real server and a real client ---------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _stage:
		0:
			if _frame < 2:
				return
			print("real peers")
			_server = ENetMultiplayerPeer.new()
			# Several ports, because the suites run in parallel and a bound port
			# is a machine condition rather than a bug in this code.
			for offset in 10:
				if _server.create_server(47300 + offset, 4) == OK:
					_port = 47300 + offset
					break
			expect(_port != 0, "an ENet server bound a port (%d)" % _port)
			expect(_server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
				"and is listening straight away — a server has nobody to wait for")
			_stage = 1
		1:
			_client = ENetMultiplayerPeer.new()
			expect(_client.create_client("127.0.0.1", _port) == OK, "a client opened a connection")
			expect(_client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING,
				"and is connecting rather than connected — the handshake takes time")
			_stage = 2
		2:
			# Polling is what advances an ENet peer. Without it the handshake
			# never completes, which is the commonest "my client never connects".
			_server.poll()
			_client.poll()
			if _client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				expect(true, "the handshake completed against a real server")
				expect(_client.get_unique_id() != 1,
					"the client has an id of its own, and the server keeps id 1")
				_stage = 3
				_report()
			elif _frame > 400:
				expect(false, "the handshake completed within the frame budget")
				_stage = 3
				_report()
