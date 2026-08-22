class_name StateBuffer
extends RefCounted

## Where a remote player *was*, so it can be drawn moving smoothly.
##
## A networked game sends position perhaps ten times a second. Applying each one
## as it lands gives ten updates per second of movement inside sixty frames of
## rendering, which looks exactly like a stutter — and no amount of tuning the
## send rate fixes it, because the problem is not the rate.
##
## The fix every networked game uses is to **render the past**. Keep the updates
## in a buffer, and draw remote players at a moment slightly behind now,
## interpolating between the two updates that straddle it. The cost is a fixed
## delay — a hundred milliseconds, say — and the benefit is that motion is
## continuous even though the data is not.
##
## Two things this has to get right, both invisible until they are wrong:
##
##   * **Out-of-order and duplicate packets.** UDP delivers neither in order nor
##     exactly once. A sample that arrives late must not rewind the buffer.
##   * **Running dry.** When the network hiccups there is nothing left to
##     interpolate toward. Holding the last known position is honest; guessing
##     forward is extrapolation, and it puts players through walls.

## How far behind now to render, in seconds. One or two send intervals is the
## usual choice: enough to always have a sample on both sides, no more.
var delay := 0.12

## Samples older than this are dropped, so the buffer cannot grow forever.
var history := 1.0

var _times: PackedFloat64Array = PackedFloat64Array()
var _states: PackedVector3Array = PackedVector3Array()


## Record where a peer was at `time`.
##
## Returns false for a sample that is not newer than what is already held —
## a duplicate or a straggler. Accepting one would rewind the buffer and make
## the remote player jump backwards.
func push(time: float, state: Vector3) -> bool:
	if not _times.is_empty() and time <= _times[_times.size() - 1]:
		return false
	_times.append(time)
	_states.append(state)
	_trim(time)
	return true


## Where the peer should be drawn at `now`, given the delay.
##
## Interpolates between the two samples straddling `now - delay`. Before the
## first sample, or after the last, it holds rather than guessing.
func sample(now: float) -> Vector3:
	if _times.is_empty():
		return Vector3.ZERO
	var target := now - delay
	if target <= _times[0]:
		return _states[0]                 # not enough history yet: hold the oldest
	var last := _times.size() - 1
	if target >= _times[last]:
		# Run dry. Holding the last known position is honest; extrapolating puts
		# players through walls, and then snaps them back when the next packet
		# arrives.
		return _states[last]
	for i in range(1, _times.size()):
		if _times[i] >= target:
			var span := _times[i] - _times[i - 1]
			var weight := 0.0 if span <= 0.0 else float((target - _times[i - 1]) / span)
			return _states[i - 1].lerp(_states[i], clampf(weight, 0.0, 1.0))
	return _states[last]


## True while there is a sample on each side of the render time — which is when
## the buffer is doing its job rather than holding a pose.
func is_interpolating(now: float) -> bool:
	if _times.size() < 2:
		return false
	var target := now - delay
	return target > _times[0] and target < _times[_times.size() - 1]


## The most recent position received, without any delay. What a hit test should
## use: the player being shot at is where they are now, not where they look.
func latest() -> Vector3:
	if _states.is_empty():
		return Vector3.ZERO
	return _states[_states.size() - 1]


func latest_time() -> float:
	if _times.is_empty():
		return -1.0
	return float(_times[_times.size() - 1])


func count() -> int:
	return _times.size()


func clear() -> void:
	_times = PackedFloat64Array()
	_states = PackedVector3Array()


## Drop everything older than `history` seconds before `now`, but never the
## sample the interpolation is currently reading from.
func _trim(now: float) -> void:
	var cutoff := now - maxf(history, delay * 2.0)
	var first_kept := 0
	while first_kept + 2 < _times.size() and _times[first_kept + 1] < cutoff:
		first_kept += 1
	if first_kept == 0:
		return
	_times = _times.slice(first_kept)
	_states = _states.slice(first_kept)
