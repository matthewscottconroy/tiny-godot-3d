extends Node3D

# Demo driver. Fires projectiles continuously, either from a pool or by
# instantiating them, so the difference in allocations is visible as a number.

const FIRE_INTERVAL := 0.06
const LIFETIME := 1.6
const SPEED := 12.0

@onready var _muzzle: Node3D = $Muzzle
@onready var _bullets: Node3D = $Bullets
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _projectile: PackedScene = preload("res://scenes/projectile.tscn")
var _pool: ScenePool
var _pooled := true
var _cooldown := 0.0
var _angle := 0.0
var _live: Array = []          ## [node, velocity, remaining]
var _instantiated := 0

func _ready() -> void:
	_hint.text = "Space pooling on/off   R reset the counters   watch the instances created"
	_pool = ScenePool.new(_projectile, _bullets, 24)
	# The step that makes recycling safe. Everything a projectile accumulates
	# while alive has to be undone before it is handed out again.
	_pool.reset = func(instance: Node3D) -> void:
		instance.global_position = Vector3.ZERO
		instance.scale = Vector3.ONE
		instance.rotation = Vector3.ZERO

func _process(delta: float) -> void:
	_angle += delta * 1.2
	_muzzle.rotation.y = _angle

	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire()

	var still_live := []
	for entry in _live:
		var node: Node3D = entry[0]
		var velocity: Vector3 = entry[1]
		var remaining: float = entry[2] - delta
		node.global_position += velocity * delta
		if remaining > 0.0:
			still_live.append([node, velocity, remaining])
		elif _pooled:
			_pool.release(node)
		else:
			node.queue_free()
	_live = still_live

	_status.text = "%s   %d in flight   pool %d free / %d total   %d instances created" % [
		"pooled" if _pooled else "instantiating every shot",
		_live.size(), _pool.available(), _pool.total(),
		_pool.created() + _instantiated]

func _fire() -> void:
	var direction := -_muzzle.global_transform.basis.z
	var node: Node3D
	if _pooled:
		node = _pool.acquire()
		if node == null:
			return                        # pool exhausted and capped: skip the shot
	else:
		# The version pooling replaces: a whole scene instance per shot, and a
		# free per expiry, sixty times a second.
		node = _projectile.instantiate() as Node3D
		_bullets.add_child(node)
		_instantiated += 1
	node.global_position = _muzzle.global_position + direction * 0.5
	_live.append([node, direction * SPEED, LIFETIME])

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_switch_mode()
		KEY_R:
			_switch_mode()
			_switch_mode()
			_instantiated = 0
		_: return

## Clear the sky before switching, so the two modes never share projectiles.
func _switch_mode() -> void:
	for entry in _live:
		var node: Node3D = entry[0]
		if _pooled:
			_pool.release(node)
		else:
			node.queue_free()
	_live.clear()
	_pooled = not _pooled
