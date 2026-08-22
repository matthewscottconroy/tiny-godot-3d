extends Node

# Drives the real LoadQueue from scripts/load_queue.gd against the real
# ResourceLoader and the demo's own scenes.
#
# Nothing here is mocked: threaded loading is an interaction with the engine,
# and a fake ResourceLoader would test the fake. The suite polls across frames
# exactly as a game does, and reports when the loads have actually arrived.

var _pass := 0
var _fail := 0
var _frame := 0
var _queue := LoadQueue.new()
var _events: Array[String] = []
var _progress_seen: Array[float] = []
var _stage := 0
var _settle := 0
var _second_batch_frame := 0
var _single_batch_announced := 0

const PROPS: Array[String] = [
	"res://scenes/prop_a.tscn",
	"res://scenes/prop_b.tscn",
	"res://scenes/prop_c.tscn",
]
const MISSING := "res://scenes/nothing_here_at_all.tscn"

func _ready() -> void:
	test_an_empty_queue_is_done()
	test_queueing_counts_once()
	test_progress_of_an_empty_queue()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[threaded-loading] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_an_empty_queue_is_done() -> void:
	print("nothing queued")
	var queue := LoadQueue.new()
	expect(queue.is_done(), "a queue with nothing in it is finished")
	expect(queue.pending() == 0, "with nothing pending")
	expect(queue.results().is_empty() and queue.failures().is_empty(), "and no results either way")

func test_queueing_counts_once() -> void:
	print("duplicates")
	var queue := LoadQueue.new()
	expect(queue.queue(PROPS[0]), "queueing a path starts it")
	# Counting the same request twice is how a progress bar reaches half and
	# stops: the second copy finishes instantly and the total never gets there.
	expect(not queue.queue(PROPS[0]), "queueing it again is refused")
	expect(not queue.queue(""), "and an empty path is refused too")
	expect(queue.pending() == 1, "leaving one request in flight")
	# And then collected. `ResourceLoader` has no cancel: a request that is never
	# picked up is still outstanding when the engine shuts down, and Godot aborts
	# the process on the way out with nothing printed. Leaving one in flight here
	# made this suite crash after reporting that it passed.
	#
	# The blocking `load_threaded_get()` rather than polling: this is cleanup, and
	# a poll loop inside `_ready()` is a race — it spins without yielding, so
	# whether the loader has finished depends on the machine.
	# A method, not a lambda: a lambda connected to a signal on a RefCounted keeps
	# itself alive with the object, and shows up as a leak at exit. This suite has
	# made that mistake before — see docs/MEMORY.md.
	queue.all_done.connect(_on_single_batch_done)
	ResourceLoader.load_threaded_get(PROPS[0])
	queue.poll()
	expect(queue.is_done(), "and collected before the test ends, because there is no cancel")
	# A batch of one announces itself like any other. Batches of one are what
	# every "load the next level" call actually is.
	queue.poll()
	expect(_single_batch_announced == 1, "and a single-request batch announces itself, once")


func test_progress_of_an_empty_queue() -> void:
	print("progress with nothing to do")
	var queue := LoadQueue.new()
	expect(is_equal_approx(queue.progress(), 1.0),
		"an empty queue reports complete rather than dividing by zero")

# --- the real loader -------------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _stage:
		0:
			if _frame < 2:
				return
			print("the real loader")
			# Plain methods rather than lambdas: a lambda connected to a signal
			# on a RefCounted keeps the lambda alive for as long as the object
			# is, and Godot reports the survivors at exit.
			_queue.loaded.connect(_on_loaded)
			_queue.failed.connect(_on_failed)
			_queue.all_done.connect(_on_all_done)
			for path in PROPS:
				_queue.queue(path)
			# A missing file is a status, not an exception: code that only
			# handles success waits forever for a load that never arrives.
			_queue.queue(MISSING)
			expect(_queue.pending() >= 3, "four requests are in flight")
			_stage = 1
		1:
			_queue.poll()
			_progress_seen.append(_queue.progress())
			if _queue.is_done():
				# Keep polling for a few more frames before checking. A queue
				# that announces itself every frame once finished is a queue
				# that fires the "loading complete" handler over and over.
				_settle = 6
				_stage = 4
			elif _frame > 600:
				expect(false, "the loads finished within the frame budget")
				_stage = 3
				_report()
		2:
			_check_results()
			_stage = 5
		5:
			_check_second_batch()
		4:
			_queue.poll()
			_settle -= 1
			if _settle <= 0:
				_stage = 2

func _on_loaded(path: String, _resource: Resource) -> void:
	_events.append("loaded:" + path.get_file())

func _on_failed(path: String) -> void:
	_events.append("failed:" + path.get_file())

func _on_single_batch_done() -> void:
	_single_batch_announced += 1

func _on_all_done() -> void:
	_events.append("all_done")

func _check_results() -> void:
	expect(_queue.results().size() == 3, "the three real scenes loaded")
	expect(_queue.failures().size() == 1, "and the missing one failed rather than hanging")
	expect(_queue.failures()[0] == MISSING, "naming the path that could not be found")
	expect(_queue.get_result(PROPS[0]) is PackedScene, "a loaded result is the resource itself")
	expect(_queue.get_result(MISSING) == null, "and a failed one is simply absent")

	expect(_events.has("all_done"), "the queue announced that it had finished")
	expect(_events[_events.size() - 1] == "all_done", "once everything else had happened")
	expect(_events.count("all_done") == 1, "and only once")

	# A progress bar that goes backwards reads as a hang, so the number is only
	# allowed to climb.
	var monotonic := true
	for i in range(1, _progress_seen.size()):
		if _progress_seen[i] < _progress_seen[i - 1] - 0.0001:
			monotonic = false
	expect(monotonic, "progress never went backwards while loading")
	expect(is_equal_approx(_queue.progress(), 1.0), "and finished at exactly 100%")

	var scene := _queue.get_result(PROPS[1]) as PackedScene
	var instance := scene.instantiate()
	expect(instance != null, "and what came back can actually be instantiated")
	instance.free()

	_queue.reset()
	expect(_queue.results().is_empty() and _queue.pending() == 0,
		"resetting clears the queue for a second run")

	# And the second run has to announce itself too — a reset that forgets to
	# clear the "already announced" flag leaves every later batch silent.
	#
	# Polled across frames like the first batch, not in a loop here. A loop that
	# polls without yielding is a race with the loader's own thread: it passed on
	# this machine and failed under the memory limit the tooling runs demos with,
	# which is the least useful kind of flake.
	_events.clear()
	_queue.queue(PROPS[0])
	_second_batch_frame = _frame

func _check_second_batch() -> void:
	_queue.poll()
	if not _queue.is_done() and _frame - _second_batch_frame < 300:
		return
	expect(_queue.is_done(), "a second batch loads after a reset")
	expect(_events.has("all_done"), "and announces that it finished, like the first one")
	_stage = 3
	_report()
