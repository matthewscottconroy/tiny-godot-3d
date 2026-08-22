extends Node3D

# Demo driver. Fires the same shot three ways at the same thin wall and counts
# which ones get through. The arithmetic that predicts the outcome is in
# scripts/tunnelling.gd; this only carries it out.

@onready var _shots: Node3D = $Shots
@onready var _behind: Area3D = $Behind
@onready var _hint: Label = $HUD/TitleLabel
@onready var _prediction: Label = $HUD/PredictionLabel
@onready var _score: Label = $HUD/ScoreLabel
@onready var _status: Label = $HUD/StatusLabel

const WALL_THICKNESS := 0.15
const LANES := ["discrete", "swept (continuous_cd)", "raycast"]
const LANE_Z := [-3.5, 0.0, 3.5]
const START_X := -9.0

var _speed := 220.0
var _fired := [0, 0, 0]
var _through := [0, 0, 0]
var _hz := 60.0

func _ready() -> void:
	_hint.text = "Space fire   1/2 speed   3 physics rate   R reset"
	_hz = float(Engine.physics_ticks_per_second)
	_behind.body_entered.connect(_on_body_got_through)
	_refresh()

func _refresh() -> void:
	var per_step := Tunnelling.travel_per_step(_speed, _hz)
	var steps := Tunnelling.steps_inside(_speed, _hz, WALL_THICKNESS)
	var verdict := "discrete collision will miss this"
	if not Tunnelling.tunnels(_speed, _hz, WALL_THICKNESS):
		verdict = "slow enough for discrete collision (under %.0f m/s)" \
			% Tunnelling.safe_speed(_hz, WALL_THICKNESS)
	_prediction.text = "%.0f m/s at %.0fHz moves %.2f m per step into a %.2f m wall — %.2f steps inside\n%s" \
		% [_speed, _hz, per_step, WALL_THICKNESS, steps, verdict]
	var lines: Array[String] = []
	for i in LANES.size():
		lines.append("%-22s fired %d   through the wall %d" % [LANES[i], _fired[i], _through[i]])
	_score.text = "\n".join(lines)

func _fire() -> void:
	for lane in LANES.size():
		var shot := _make_shot(lane)
		_shots.add_child(shot)
		shot.position = Vector3(START_X, 1.5, LANE_Z[lane])
		if shot is RigidBody3D:
			(shot as RigidBody3D).linear_velocity = Vector3.RIGHT * _speed
		_fired[lane] += 1
	_refresh()

func _make_shot(lane: int) -> Node3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	var view := MeshInstance3D.new()
	view.mesh = mesh

	if lane == 2:
		# Not a physics body at all: moved by hand, with a ray along the step it
		# is about to take. This is what most games ship for bullets.
		var swept: Node3D = preload("res://scripts/swept_shot.gd").new()
		swept.speed = _speed
		swept.add_child(view)
		swept.set_meta(&"lane", lane)
		return swept

	var body := RigidBody3D.new()
	body.gravity_scale = 0.0
	# Lane 1 asks the engine to sweep the shape along its motion instead of
	# teleporting it. Everything else about the two lanes is identical.
	body.continuous_cd = lane == 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	shape.shape = sphere
	body.add_child(shape)
	body.add_child(view)
	body.set_meta(&"lane", lane)
	return body

func _on_body_got_through(body: Node3D) -> void:
	_through[body.get_meta(&"lane", 0)] += 1
	_refresh()

func _process(_delta: float) -> void:
	for shot in _shots.get_children():
		var node := shot as Node3D
		if node.position.x > 14.0:
			node.queue_free()
	_status.text = "%d shots in flight" % _shots.get_child_count()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_fire()
		KEY_1:
			_speed = maxf(_speed - 20.0, 5.0)
			_refresh()
		KEY_2:
			_speed = minf(_speed + 20.0, 600.0)
			_refresh()
		KEY_3:
			# The blunt fix: step more often. It works, and every body in the
			# scene pays for it.
			_hz = 60.0 if _hz > 100.0 else 240.0
			Engine.physics_ticks_per_second = int(_hz)
			_refresh()
		KEY_R:
			_fired = [0, 0, 0]
			_through = [0, 0, 0]
			for shot in _shots.get_children():
				shot.queue_free()
			_refresh()
		_:
			return
