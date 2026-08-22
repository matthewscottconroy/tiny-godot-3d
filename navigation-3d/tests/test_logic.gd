extends Node

# Drives the real RouteFollower from scripts/route_follower.gd, then lets the
# real scene bake and walk for a few frames.
#
# mutate-driver: skip — the scene is instantiated to bake a real navigation mesh, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _start := Vector3.ZERO

func _ready() -> void:
	test_the_first_waypoint_is_first()
	test_arrival_uses_the_ground_plane()
	test_arrival_radius_is_respected()
	test_advancing_walks_the_route()
	test_a_looping_route_wraps()
	test_a_one_shot_route_finishes()
	test_update_reports_the_change()
	test_an_empty_route_is_harmless()
	test_resetting()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[navigation-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _square() -> Array[Vector3]:
	var points: Array[Vector3] = [
		Vector3(5, 0, 5), Vector3(-5, 0, 5), Vector3(-5, 0, -5)]
	return points

func test_the_first_waypoint_is_first() -> void:
	print("starting out")
	var route := RouteFollower.new(_square())
	expect(route.current() == Vector3(5, 0, 5), "the route starts at its first waypoint")
	expect(route.index() == 0, "at index zero")
	expect(route.laps() == 0, "with no laps completed")

func test_arrival_uses_the_ground_plane() -> void:
	print("arrival height")
	var route := RouteFollower.new(_square())
	route.arrive_distance = 0.6
	# A body's origin sits at its own half-height, so a full 3D distance can
	# never fall below that — the agent stands on the marker and circles it.
	var standing_on_it := Vector3(5, 0.9, 5)
	expect(route.arrived(standing_on_it),
		"a body standing on the waypoint has arrived, whatever its height")
	expect(not route.arrived(Vector3(5, 0.9, 7)), "while one two metres away has not")

func test_arrival_radius_is_respected() -> void:
	print("arrival radius")
	var route := RouteFollower.new(_square())
	route.arrive_distance = 1.0
	expect(route.arrived(Vector3(5.9, 0, 5)), "just inside the radius counts")
	expect(not route.arrived(Vector3(6.5, 0, 5)), "just outside it does not")
	route.arrive_distance = 3.0
	expect(route.arrived(Vector3(6.5, 0, 5)), "and a larger radius takes it in")

func test_advancing_walks_the_route() -> void:
	print("advancing")
	var route := RouteFollower.new(_square())
	route.advance()
	expect(route.current() == Vector3(-5, 0, 5), "advancing moves to the next waypoint")
	route.advance()
	expect(route.current() == Vector3(-5, 0, -5), "and the one after that")

func test_a_looping_route_wraps() -> void:
	print("looping")
	var route := RouteFollower.new(_square())
	for i in 3:
		route.advance()
	expect(route.current() == Vector3(5, 0, 5), "past the end it starts again")
	expect(route.laps() == 1, "counting a lap as it goes")
	expect(not route.finished(), "and a looping route is never finished")

func test_a_one_shot_route_finishes() -> void:
	print("one-shot")
	var route := RouteFollower.new(_square())
	route.looping = false
	# Not finished before it has been walked — the state that separates "this
	# route ends" from "this route is over".
	expect(not route.finished(), "a fresh one-shot route has not finished")
	route.advance()
	expect(not route.finished(), "nor has one part of the way through")
	expect(route.current() == Vector3(-5, 0, 5), "and it still has somewhere to go")
	route.reset()
	for i in 3:
		route.advance()
	expect(route.finished(), "a non-looping route finishes at the end")
	expect(route.current() == Vector3.ZERO, "and asks for nowhere afterwards")
	expect(route.laps() == 0, "having completed no laps")
	route.advance()
	expect(route.finished(), "advancing past the end changes nothing")
	# index() is what a HUD prints, so it has to stay inside the route even when
	# the internal counter has run past the end.
	expect(route.index() == _square().size() - 1,
		"and the reported index stays on the last waypoint rather than past it")

func test_update_reports_the_change() -> void:
	print("update")
	var route := RouteFollower.new(_square())
	expect(not route.update(Vector3.ZERO), "far from the waypoint, nothing happens")
	expect(route.update(Vector3(5, 0, 5)), "standing on it advances, and says so")
	expect(route.current() == Vector3(-5, 0, 5), "leaving the next waypoint current")

func test_an_empty_route_is_harmless() -> void:
	print("no route")
	var route := RouteFollower.new()
	expect(route.current() == Vector3.ZERO, "an empty route asks for nowhere")
	expect(not route.arrived(Vector3.ZERO), "cannot be arrived at")
	expect(not route.update(Vector3.ZERO), "and updating it does nothing rather than erroring")

func test_resetting() -> void:
	print("reset")
	var route := RouteFollower.new(_square())
	for i in 5:
		route.advance()
	route.reset()
	expect(route.index() == 0 and route.laps() == 0, "reset puts the route back to the start")

# --- the real navigation mesh ----------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real region")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			var region: NavigationRegion3D = _scene.get_node("NavigationRegion3D")
			var mesh := region.navigation_mesh
			expect(mesh.get_polygon_count() > 0,
				"the region baked a navigation mesh at runtime (%d polygons)"
				% mesh.get_polygon_count())
			expect(mesh.get_vertices().size() > 0, "with vertices to go with it")
			_start = (_scene.get_node("Agent") as Node3D).global_position
		30:
			var agent: NavigationAgent3D = _scene.get_node("Agent/NavigationAgent3D")
			var body: Node3D = _scene.get_node("Agent")
			expect(agent.get_current_navigation_path().size() >= 2,
				"the agent has a path with corners in it")
			var moved := _start.distance_to(body.global_position)
			expect(moved > 0.5, "and has walked along it (%.2f m)" % moved)
			# The route runs anticlockwise from (8, 8) to (-8, 8): the agent
			# should be heading in -X, not wandering off across the map.
			expect(body.global_position.x < _start.x, "in the direction of the next waypoint")
			_report()
