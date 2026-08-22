extends Node

# Drives the real Tunnelling from scripts/tunnelling.gd, and then fires the real
# shots at the real wall — because the arithmetic predicting that a bullet goes
# through a wall is only worth anything if the bullet actually does.
#
# mutate-driver: skip — the scene is instantiated to fire real bodies at a real wall, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _checked := false

func _ready() -> void:
	test_distance_per_step()
	test_what_tunnels()
	test_the_speed_limit()
	test_the_rate_that_would_fix_it()
	test_steps_spent_inside()
	test_the_sweep_segment()
	test_degenerate_input()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[continuous-collision] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_distance_per_step() -> void:
	print("distance per step")
	# The number the whole subject reduces to. A rifle round at 60Hz moves
	# further in one step than most rooms are wide.
	expect(is_equal_approx(Tunnelling.travel_per_step(120.0, 60.0), 2.0),
		"120 m/s at 60Hz is two metres a step")
	expect(is_equal_approx(Tunnelling.travel_per_step(120.0, 240.0), 0.5),
		"and half a metre at 240Hz")

func test_what_tunnels() -> void:
	print("tunnelling")
	# The comparison is against the wall's *thickness*, not the distance to it.
	# A wall ten metres away is no harder to hit than one right here.
	expect(Tunnelling.tunnels(220.0, 60.0, 0.15),
		"a 220 m/s shot skips a 15cm wall at 60Hz")
	expect(not Tunnelling.tunnels(220.0, 60.0, 5.0),
		"but not a five-metre one")
	expect(not Tunnelling.tunnels(5.0, 60.0, 0.15),
		"and a slow shot does not skip anything")

func test_the_speed_limit() -> void:
	print("the safe speed")
	expect(is_equal_approx(Tunnelling.safe_speed(60.0, 0.15), 9.0),
		"a 15cm wall at 60Hz catches anything under 9 m/s")
	# Which is walking pace. Everything faster than a jog needs one of the fixes,
	# and that is the point of the number.
	expect(Tunnelling.safe_speed(60.0, 0.15) < 10.0,
		"— walking pace, which is why this is not an edge case")
	expect(not Tunnelling.tunnels(Tunnelling.safe_speed(60.0, 0.15) - 0.01, 60.0, 0.15),
		"and just under the limit does not tunnel")

func test_the_rate_that_would_fix_it() -> void:
	print("the brute-force fix")
	expect(is_equal_approx(Tunnelling.required_hz(220.0, 0.15), 1466.6667),
		"catching a 220 m/s shot with a 15cm wall needs 1467 steps a second")
	expect(Tunnelling.required_hz(1.0, 0.0) == INF,
		"and a wall with no thickness cannot be caught at any rate")

func test_steps_spent_inside() -> void:
	print("steps inside")
	expect(is_equal_approx(Tunnelling.steps_inside(9.0, 60.0, 0.15), 1.0),
		"at the limit the shot spends exactly one step inside the wall")
	expect(Tunnelling.steps_inside(220.0, 60.0, 0.15) < 0.05,
		"and at 220 m/s it spends a twentieth of one — there is nothing to detect")
	# Around 1 is the worst place to be: whether it is caught depends on where in
	# the step the shot happened to start, which is the bug that reproduces one
	# time in five and gets closed as unrepeatable.
	expect(Tunnelling.steps_inside(8.5, 60.0, 0.15) > 1.0
		and Tunnelling.steps_inside(9.5, 60.0, 0.15) < 1.0,
		"and either side of the limit is where it becomes intermittent")

func test_the_sweep_segment() -> void:
	print("the sweep")
	var from := Vector3(-1, 0, 0)
	var to := Vector3(2, 0, 0)
	expect(Tunnelling.sweep(from, to) == Vector3(3, 0, 0),
		"the cast covers the whole step, not the destination")
	expect(Tunnelling.sweep(to, to) == Vector3.ZERO,
		"and a body that did not move sweeps nothing")

func test_degenerate_input() -> void:
	print("degenerate input")
	expect(Tunnelling.travel_per_step(100.0, 0.0) > 0.0,
		"a physics rate of zero does not divide by zero")
	expect(not Tunnelling.tunnels(0.0, 60.0, 0.0),
		"and something that is not moving does not tunnel through a wall with no thickness")

# --- the real shots --------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real wall")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			# 220 m/s: fast enough that the prediction above says the discrete
			# lane cannot possibly be caught.
			_scene.call("_fire")
		7:
			# Four physics steps after firing. The discrete shot is already
			# fourteen metres past the wall and about to be culled — which is
			# itself the lesson: there is no frame in which it was inside.
			_check_shots()
			_report()

func _check_shots() -> void:
	var shots: Node3D = _scene.get_node("Shots")
	var by_lane := {}
	for shot in shots.get_children():
		by_lane[int((shot as Node3D).get_meta(&"lane", -1))] = shot as Node3D

	expect(by_lane.size() == 3, "three shots were fired, one per lane")
	if by_lane.size() < 3:
		return

	# The wall is at x = 0. Past it means through it.
	var discrete: Node3D = by_lane[0]
	var swept: Node3D = by_lane[1]
	var raycast: Node3D = by_lane[2]

	expect(discrete.position.x > 1.0,
		"the discrete shot is past the wall (x %.2f) — it tunnelled" % discrete.position.x)
	expect(swept.position.x < 0.5,
		"continuous_cd stopped its shot at the wall (x %.2f)" % swept.position.x)
	expect(raycast.call("stopped"), "and the raycast shot found the wall on its path")
	expect(absf(raycast.position.x) < 0.3,
		"stopping at the surface (x %.2f) rather than at the end of the step"
			% raycast.position.x)

	# Same speed, same wall, same frame count: the only difference between the
	# first two lanes is one boolean.
	expect(discrete.position.x - swept.position.x > 1.0,
		"one boolean is the whole difference between the two bodies")
