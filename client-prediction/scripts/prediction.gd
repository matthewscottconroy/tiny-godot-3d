class_name Prediction
extends RefCounted

## Moving now, and being corrected later without it showing.
##
## [multiplayer-3d](../multiplayer-3d) covers the other end: taking snapshots
## that arrive ten times a second and interpolating them into smooth motion.
## That works for everyone *else's* character. It cannot work for your own,
## because it means your input takes a round trip before anything happens, and
## 80ms of that is the difference between a game and a demo.
##
## So the client moves immediately and assumes it was right. The server, which
## decides, sends back where it thinks the character actually is. Almost always
## those agree and nothing happens. When they do not — a wall the client did not
## know about, a shove from another player — the client has to end up where the
## server says, without teleporting.
##
## The whole technique is three rules:
##
##   * **Keep every input until the server acknowledges it.** The correction
##     arrives stamped with the last input the server had seen, and everything
##     after that has to be replayed on top.
##   * **Replay, do not blend.** Snapping to the server state throws away every
##     input the player has made since; replaying them puts the character where
##     those inputs would have taken it from the corrected start.
##   * **Simulate identically on both ends.** The same function, the same fixed
##     step. A client that predicts with a slightly different number is a client
##     that is corrected constantly, and the player feels it as rubber-banding.

## One recorded input, with the sequence number that identifies it.
class Command:
	var sequence := 0
	var move := Vector3.ZERO
	var delta := 0.0

	func _init(seq: int, direction: Vector3, step: float) -> void:
		sequence = seq
		move = direction
		delta = step


var _pending: Array[Command] = []
var _next_sequence := 0

## Corrections smaller than this are ignored rather than applied.
##
## Floating point drifts between two machines running the same code. Correcting
## a two-millimetre disagreement every frame is a visible jitter with no cause.
var tolerance := 0.02

## Bigger than this is not a correction, it is a teleport — a spawn, a respawn,
## a portal — and blending it looks like the character flying across the level.
var snap_beyond := 4.0


## The step both ends run. The single most important function in the file: if the
## server's version differs by so much as an operator, prediction is noise.
static func step(position: Vector3, move: Vector3, delta: float,
		speed: float = 6.0) -> Vector3:
	var direction := move.limit_length(1.0)
	return position + direction * speed * delta


## Record an input and return the position it predicts.
func predict(position: Vector3, move: Vector3, delta: float, speed: float = 6.0) -> Vector3:
	var command := Command.new(_next_sequence, move, delta)
	_next_sequence += 1
	_pending.append(command)
	return step(position, command.move, command.delta, speed)


## Everything the server has now acknowledged is dropped; the rest is replayed.
##
## Returns where the character should be: the server's position with every input
## the server had not seen yet applied on top of it.
func reconcile(authoritative: Vector3, acknowledged: int, speed: float = 6.0) -> Vector3:
	forget_up_to(acknowledged)
	var position := authoritative
	for command in _pending:
		position = step(position, command.move, command.delta, speed)
	return position


## Drop the inputs the server has already accounted for.
func forget_up_to(acknowledged: int) -> void:
	var kept: Array[Command] = []
	for command in _pending:
		if command.sequence > acknowledged:
			kept.append(command)
	_pending = kept


## How many inputs are still unacknowledged — the client's view of the latency.
func pending() -> int:
	return _pending.size()


func last_sequence() -> int:
	return _next_sequence - 1


## Is this correction worth applying at all?
static func worth_correcting(predicted: Vector3, corrected: Vector3,
		tolerance: float = 0.02) -> bool:
	return predicted.distance_to(corrected) > tolerance


## Should the character jump to the corrected position rather than move to it?
##
## A metre is a mistake to be smoothed away. Forty metres is a respawn, and
## smoothing it is a character flying across the level for a second and a half.
static func should_snap(predicted: Vector3, corrected: Vector3,
		snap_beyond: float = 4.0) -> bool:
	return predicted.distance_to(corrected) > snap_beyond


## Where to draw the character this frame, easing an accepted correction in.
##
## Frame-rate independent, because a correction that takes twice as long on a
## slower machine is a correction the player on that machine can see.
static func ease_toward(shown: Vector3, corrected: Vector3, delta: float,
		rate: float = 12.0) -> Vector3:
	return shown.lerp(corrected, 1.0 - exp(-maxf(rate, 0.0) * delta))


func reset() -> void:
	_pending.clear()
	_next_sequence = 0
