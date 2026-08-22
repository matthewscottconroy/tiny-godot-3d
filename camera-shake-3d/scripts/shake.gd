class_name Shake
extends RefCounted

## Camera shake that another system can apply without owning the camera.
##
## In 2D, shake is usually written straight into the camera's offset, and that
## works because a 2D camera's transform belongs to the camera script. In 3D it
## almost never does: the transform belongs to an orbit rig, a spring arm, a
## cutscene track, a vehicle mount. Shake that writes the camera's transform
## fights every one of them, and the symptom is a camera that snaps back to a
## stale position the moment anything else moves it.
##
## So this produces an **offset** and nothing else. Whatever owns the transform
## adds it — ideally on a child node, so the two never touch the same property.
##
## The model is trauma rather than amplitude. Callers add trauma; the shake
## itself is `trauma²`, which makes small hits nearly invisible and big ones
## dramatic without anyone tuning two numbers. Trauma decays linearly, so a shake
## always ends, and repeated hits accumulate up to a ceiling rather than
## multiplying into nausea.

## How much trauma drains away per second.
var decay := 1.6

## Maximum displacement at full trauma, in metres.
var max_offset := 0.35

## Maximum rotation at full trauma, in radians.
var max_roll := 0.06

## How fast the noise moves. Higher is a sharper rattle, lower is a lurch.
var frequency := 22.0

var _trauma := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()


func _init(seed_value: int = 1) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	# Seeded, so a replay, a test, or two players in a networked game all shake
	# identically. `randf()` here would make the demo untestable and the game
	# irreproducible.
	_noise.seed = seed_value


## Add trauma. 0.2 is a footstep, 0.5 a hit, 1.0 an explosion in your face.
func add(amount: float) -> void:
	_trauma = clampf(_trauma + maxf(amount, 0.0), 0.0, 1.0)


## Advance the shake. Call once per frame.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	_trauma = maxf(_trauma - decay * delta, 0.0)


## The positional offset to add to whatever holds the camera.
func offset() -> Vector3:
	var amount := shake_amount()
	if amount <= 0.0:
		return Vector3.ZERO
	return Vector3(
		_sample(0) * max_offset,
		_sample(1) * max_offset,
		_sample(2) * max_offset * 0.5) * amount


## The rotational offset, in radians, as pitch/yaw/roll.
##
## Rotation sells a shake far better than translation does — and unlike
## translation it cannot push the camera through a wall.
func rotation_offset() -> Vector3:
	var amount := shake_amount()
	if amount <= 0.0:
		return Vector3.ZERO
	return Vector3(
		_sample(3) * max_roll,
		_sample(4) * max_roll,
		_sample(5) * max_roll) * amount


## Trauma squared: the curve that makes a small hit small and a big one big.
func shake_amount() -> float:
	return _trauma * _trauma


func trauma() -> float:
	return _trauma


func is_shaking() -> bool:
	return _trauma > 0.0


func reset() -> void:
	_trauma = 0.0
	_time = 0.0


## One noise channel, in -1..1. Separate rows of the noise field rather than
## separate generators, so the axes are uncorrelated but reproducible.
func _sample(channel: int) -> float:
	return _noise.get_noise_2d(_time * frequency, float(channel) * 100.0)
