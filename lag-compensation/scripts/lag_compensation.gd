class_name Rewind
extends RefCounted

## The server's memory of where everything used to be, so it can judge a shot
## against the world the shooter actually saw.
##
## client-prediction is the other half: there the client moves before the server
## answers, so its own character feels immediate. This is the problem that makes
## for everyone else. By the time "I fired at that spot" arrives, the target has
## moved on, and judging the shot against where it is *now* means the shooter
## missed — which teaches players to lead by their own ping, an amount that is
## unlearnable and different on every connection.
##
## The cost is not hidden and should not be: the target can be shot after they
## reached cover, because on the shooter's screen they had not reached it yet.
## "I was already behind the wall" is this working as designed.

## How far back the history goes. Past this, samples are dropped.
##
## It bounds both memory and how much unfairness the server is willing to
## tolerate: rewinding two seconds to please one player punishes everyone else.
var history_seconds := 1.0

var _times: Array[float] = []
var _states: Array[Dictionary] = []


## Remember where everything was at this moment.
##
## Time must not go backwards — a server recording out of order has a history it
## cannot interpolate, and the bug shows up as shots that land somewhere between
## two unrelated moments.
func record(time: float, positions: Dictionary) -> void:
	if not _times.is_empty() and time <= _times[_times.size() - 1]:
		return
	_times.append(time)
	_states.append(positions.duplicate())
	_prune(time)


func _prune(now: float) -> void:
	var cutoff := now - history_seconds
	while _times.size() > 1 and _times[0] < cutoff:
		_times.remove_at(0)
		_states.remove_at(0)


## The moment a client was looking at, given how long the round trip takes.
##
## Two delays, and both are needed. Half the round trip is how long the shot took
## to arrive; the interpolation delay is the client's own, because it renders
## others slightly in the past to smooth their movement, so what it *drew* was
## older still. Forgetting the second is the subtle version of this bug — shots
## land a little behind a moving target and the hitboxes get blamed.
static func seen_at(now: float, round_trip: float, interpolation_delay: float = 0.1) -> float:
	return now - maxf(round_trip, 0.0) * 0.5 - maxf(interpolation_delay, 0.0)


## Where everything was at `time`, interpolated between the samples either side.
##
## Interpolated rather than nearest: at 20 updates a second the nearest sample
## can be 25ms out, which at running speed is most of a body width, and snapping
## to it gives back the error the rewind just removed. Outside the history it
## clamps rather than extrapolating — inventing a position nobody ever saw is
## the one thing this mechanism exists to avoid.
func state_at(time: float) -> Dictionary:
	if _times.is_empty():
		return {}
	if time <= _times[0]:
		return _states[0].duplicate()
	var last := _times.size() - 1
	if time >= _times[last]:
		return _states[last].duplicate()

	var i := 1
	while i < _times.size() and _times[i] < time:
		i += 1
	var span := _times[i] - _times[i - 1]
	var t := 0.0 if span <= 0.0 else (time - _times[i - 1]) / span

	var result := {}
	var before: Dictionary = _states[i - 1]
	var after: Dictionary = _states[i]
	for id in before:
		if after.has(id):
			var a: Vector3 = before[id]
			var b: Vector3 = after[id]
			result[id] = a.lerp(b, t)
		else:
			result[id] = before[id]
	return result


## True when `time` is old enough that the history no longer reaches it.
##
## The server has to answer something, and the honest answer is "judged against
## the oldest moment I still have" — a slightly unfair shot for a client on a
## dreadful connection, rather than a crash or a silent miss.
func beyond_history(time: float) -> bool:
	return not _times.is_empty() and time < _times[0]


## Oldest and newest moments still remembered.
func oldest() -> float:
	return _times[0] if not _times.is_empty() else 0.0


func newest() -> float:
	return _times[_times.size() - 1] if not _times.is_empty() else 0.0


func samples() -> int:
	return _times.size()


## Does a shot from `origin` along `direction` reach a target of this radius?
##
## The geometry is the ordinary point-to-ray distance; what matters is which
## position it is handed. Give it the live one and the shooter has to lead by
## their ping; give it the rewound one and they aim at what they see.
static func hits(origin: Vector3, direction: Vector3, target: Vector3,
		radius: float = 0.5) -> bool:
	var forward := direction.normalized()
	if forward.length() < 0.0001:
		return false
	var to_target := target - origin
	var along := to_target.dot(forward)
	if along < 0.0:
		return false              # behind the shooter
	return (to_target - forward * along).length() <= radius


func reset() -> void:
	_times.clear()
	_states.clear()
