extends Node3D

# Demo driver. A target slides back and forth; the shooter sees it late, as every
# real client does. Space fires at what the shooter can see, and the shot is
# judged against the live position or the rewound one, so the difference between
# them is a hit and a miss rather than an argument.
#
# The latency is simulated rather than networked: the arithmetic is the lesson,
# and a real socket only makes the numbers harder to read. See multiplayer-3d.

const TRACK := 4.0
const TARGET_SPEED := 0.9
const TARGET_RADIUS := 0.5
const SHOOTER := Vector3(0.0, 0.8, 7.0)

@onready var _live: MeshInstance3D = $Live
@onready var _seen: MeshInstance3D = $Seen
@onready var _rewound: MeshInstance3D = $Rewound
@onready var _beam: MeshInstance3D = $Beam
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _rewind := Rewind.new()
var _now := 0.0
var _ping := 0.2                  ## simulated round trip, in seconds
var _compensate := true
var _shots := 0
var _hits := 0
var _last := "nothing fired yet"

func _ready() -> void:
	_hint.text = "Space fire at what the shooter sees   1/2 ping   C compensation on or off   R reset"
	_rewind.history_seconds = 1.0

func _process(delta: float) -> void:
	_now += delta

	# The server's truth, as a real one records every tick. Only the target moves.
	var live := Vector3(sin(_now * TARGET_SPEED) * TRACK, 0.8, 0.0)
	_rewind.record(_now, {&"target": live})
	_live.position = live

	# What the shooter's screen is showing right now: the world as it was half a
	# round trip ago, and then another interpolation delay older again.
	var seen_time := Rewind.seen_at(_now, _ping)
	var seen: Vector3 = _rewind.state_at(seen_time).get(&"target", live)
	_seen.position = seen
	_rewound.visible = false

	_show(live, seen, seen_time)

func _show(live: Vector3, seen: Vector3, seen_time: float) -> void:
	var gap := live.distance_to(seen)
	_status.text = "ping %.0f ms   compensation %s   history %.2f s (%d samples)\nthe shooter is aiming at where the target was %.0f ms ago — %.2f m behind it\n%d/%d shots hit   %s" % [
		_ping * 1000.0, "on" if _compensate else "off",
		_rewind.newest() - _rewind.oldest(), _rewind.samples(),
		(_now - seen_time) * 1000.0, gap,
		_hits, _shots, _last]

func _fire() -> void:
	# The shooter aims at what their screen shows, which is the whole premise.
	var seen_time := Rewind.seen_at(_now, _ping)
	var seen: Vector3 = _rewind.state_at(seen_time).get(&"target", Vector3.ZERO)
	var direction := seen - SHOOTER

	# The two answers, and which the server uses is the demo. `seen` is already
	# the rewound world; uncompensated simply asks about the live position.
	var judged_against := seen if _compensate else _live.position
	var hit := Rewind.hits(SHOOTER, direction, judged_against, TARGET_RADIUS)

	_shots += 1
	if hit:
		_hits += 1

	# Left on screen so a miss is explicable: it marks the world that was judged.
	_rewound.position = judged_against
	_rewound.visible = true
	_draw_beam(direction)

	var stale := " (older than the history — judged against the oldest sample kept)" \
		if _rewind.beyond_history(seen_time) else ""
	_last = "%s: judged against %s%s" % [
		"HIT" if hit else "MISS",
		"where the shooter saw it" if _compensate else "where it is now",
		stale]

## A line from the shooter to what they aimed at, so the shot is visible.
func _draw_beam(direction: Vector3) -> void:
	var length := direction.length()
	if length < 0.01:
		return
	_beam.position = SHOOTER + direction * 0.5
	_beam.look_at(SHOOTER + direction, Vector3.UP)
	_beam.scale = Vector3(1.0, 1.0, length)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: _fire()
		KEY_1: _ping = maxf(_ping - 0.05, 0.0)
		KEY_2: _ping = minf(_ping + 0.05, 0.6)
		KEY_C: _compensate = not _compensate
		KEY_R:
			_ping = 0.2
			_compensate = true
			_shots = 0
			_hits = 0
			_last = "nothing fired yet"
			_beam.scale = Vector3.ONE
			_rewound.visible = false
		_: return
