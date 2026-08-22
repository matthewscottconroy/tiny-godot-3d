class_name LoadQueue
extends RefCounted

## Loading several resources on a background thread, and knowing how far along
## it is.
##
## `load()` blocks. For a texture that is a frame nobody notices; for a level's
## worth of scenes it is a freeze, and a freeze during play is the difference
## between a loading screen and a bug report. `ResourceLoader`'s threaded API
## fixes that and hands you three chores in exchange:
##
##   * **Polling.** Nothing tells you when a load finishes. You ask, every frame,
##     and the answer is one of four statuses — one of which means "you never
##     requested this", which is what you get for a typo in a path.
##   * **Aggregate progress.** Each request reports its own 0..1. A progress bar
##     wants one number for the lot, and it must never go backwards, because a
##     bar that jumps back reads as a hang.
##   * **Failure.** A missing file is not an exception here; it is a status. Code
##     that only handles success spins forever waiting for a load that will never
##     arrive.

## Emitted as each resource arrives.
signal loaded(path: String, resource: Resource)

## Emitted for a path that could not be loaded at all.
signal failed(path: String)

## Emitted once every request has either arrived or failed.
signal all_done()

var _pending: Array[String] = []
var _results := {}
var _failures: Array[String] = []
var _progress := {}
var _requested := 0
## The request count `all_done` was last emitted for, so a finished batch
## announces itself exactly once and a batch that grew announces itself again.
var _announced_at := -1


## Add a path to the queue and start loading it.
##
## Returns false for a duplicate or an empty path: requesting the same resource
## twice is not an error, but it should not be counted twice either, or the
## progress bar reaches 50% and stops.
func queue(path: String) -> bool:
	if path.is_empty() or _pending.has(path) or _results.has(path) or _failures.has(path):
		return false
	var error := ResourceLoader.load_threaded_request(path)
	_pending.append(path)
	_progress[path] = 0.0
	_requested += 1
	if error != OK:
		# A bad path fails at the request, before any thread starts. It is
		# recorded like any other failure rather than thrown away, so the caller
		# sees one consistent story.
		_finish_failure(path)
	return true


## Check on everything still loading. Call once per frame.
func poll() -> void:
	for path in _pending.duplicate():
		var reported: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, reported)
		if not reported.is_empty():
			_progress[path] = float(reported[0])
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_progress[path] = 1.0
				var resource := ResourceLoader.load_threaded_get(path)
				_pending.erase(path)
				_results[path] = resource
				loaded.emit(path, resource)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_finish_failure(path)
			_:
				pass                      # still in progress
	if _pending.is_empty() and _requested > 0 and _announced_at != _requested:
		_announced_at = _requested
		all_done.emit()


## Overall progress, 0..1 across everything ever queued.
##
## Never goes backwards while a batch is in flight, because queueing more work
## mid-batch is what makes a progress bar jump back — and a bar that jumps back
## reads as a hang.
func progress() -> float:
	if _requested == 0:
		return 1.0
	var total := 0.0
	for path in _progress:
		total += float(_progress[path])
	return clampf(total / float(_requested), 0.0, 1.0)


func is_done() -> bool:
	return _pending.is_empty()


func pending() -> int:
	return _pending.size()


func results() -> Dictionary:
	return _results.duplicate()


func get_result(path: String) -> Resource:
	return _results.get(path)


func failures() -> Array[String]:
	return _failures.duplicate()


## Forget everything, for a second run. Does not cancel work already in flight —
## `ResourceLoader` has no cancel, and pretending otherwise would be a lie.
func reset() -> void:
	_pending.clear()
	_results.clear()
	_failures.clear()
	_progress.clear()
	_requested = 0
	_announced_at = -1


func _finish_failure(path: String) -> void:
	_pending.erase(path)
	_progress[path] = 1.0
	if not _failures.has(path):
		_failures.append(path)
	failed.emit(path)
