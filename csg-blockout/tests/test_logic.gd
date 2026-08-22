extends Node

# Drives the real RoomPlan from scripts/room_plan.gd, then checks the CSG tree
# and the bake.
#
# mutate-driver: skip — the scene is instantiated to bake a real CSG tree, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_rooms_side_by_side_share_a_wall()
	test_rooms_that_only_touch_at_a_corner_do_not()
	test_rooms_that_do_not_touch_at_all()
	test_a_shared_wall_shorter_than_a_door()
	test_where_the_door_goes()
	test_which_way_the_door_faces()
	test_no_door_where_there_is_no_wall()
	test_the_door_cut_is_thicker_than_the_wall()
	test_the_hollow_is_smaller_than_the_shell()
	test_finding_every_doorway()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[csg-blockout] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const LEFT := Rect2(0, 0, 6, 6)
const RIGHT := Rect2(6, 0, 6, 6)        ## shares the wall at x = 6
const BELOW := Rect2(0, 6, 6, 6)        ## shares the wall at y = 6
const CORNER := Rect2(6, 6, 6, 6)       ## touches LEFT at one point only
const AWAY := Rect2(20, 20, 4, 4)       ## touches nothing

func test_rooms_side_by_side_share_a_wall() -> void:
	print("neighbours")
	expect(RoomPlan.shares_wall(LEFT, RIGHT), "rooms side by side share a wall")
	expect(RoomPlan.shares_wall(LEFT, BELOW), "and so do rooms one above the other")
	expect(RoomPlan.shares_wall(RIGHT, LEFT), "whichever way round they are asked")

func test_rooms_that_only_touch_at_a_corner_do_not() -> void:
	print("corners")
	# There is no wall at a corner, only an edge. A door there is a hole through
	# the diagonal into nothing.
	expect(not RoomPlan.shares_wall(LEFT, CORNER), "rooms meeting at a corner share no wall")

func test_rooms_that_do_not_touch_at_all() -> void:
	print("strangers")
	expect(not RoomPlan.shares_wall(LEFT, AWAY), "rooms across the level share nothing")

func test_a_shared_wall_shorter_than_a_door() -> void:
	print("short walls")
	var sliver := Rect2(6, 5.8, 4, 4)
	# They do share a wall — 0.2 metres of one. A door needs more than that, and
	# cutting one anyway leaves a gap in the corner of two rooms.
	expect(not RoomPlan.shares_wall(LEFT, sliver, 1.0),
		"a wall shorter than the minimum is not a place for a door")
	expect(RoomPlan.shares_wall(LEFT, sliver, 0.1), "unless the minimum is small enough")

func test_where_the_door_goes() -> void:
	print("door position")
	var vertical = RoomPlan.door_between(LEFT, RIGHT)
	expect(vertical != null, "there is a door between neighbours")
	expect(is_equal_approx((vertical as Vector2).x, 6.0), "on the wall they share")
	expect(is_equal_approx((vertical as Vector2).y, 3.0), "halfway along it")
	var horizontal = RoomPlan.door_between(LEFT, BELOW)
	expect(is_equal_approx((horizontal as Vector2).y, 6.0), "and the same for a horizontal wall")
	expect(is_equal_approx((horizontal as Vector2).x, 3.0), "halfway along that one too")

func test_which_way_the_door_faces() -> void:
	print("door orientation")
	# Wrong exactly half the time if you guess: a door box turned the wrong way
	# cuts along the wall instead of through it.
	expect(RoomPlan.door_is_horizontal(LEFT, BELOW),
		"rooms stacked vertically share a wall that runs along X")
	expect(not RoomPlan.door_is_horizontal(LEFT, RIGHT),
		"and rooms side by side share one that runs along Z")

func test_no_door_where_there_is_no_wall() -> void:
	print("no door")
	expect(RoomPlan.door_between(LEFT, CORNER) == null, "no door between rooms meeting at a corner")
	expect(RoomPlan.door_between(LEFT, AWAY) == null, "and none between rooms that never meet")

func test_the_door_cut_is_thicker_than_the_wall() -> void:
	print("cutting through")
	var plan := RoomPlan.new()
	plan.wall = 0.4
	var box := plan.door_box(true)
	# A cut exactly as deep as the wall leaves coplanar faces, and coplanar
	# faces in CSG are z-fighting or nothing at all depending on the day.
	expect(box.z > plan.wall, "the door cut is deeper than the wall it cuts")
	expect(is_equal_approx(box.x, plan.door_width), "as wide as a door")
	expect(is_equal_approx(box.y, plan.door_height), "and as tall as one")
	var turned := plan.door_box(false)
	expect(is_equal_approx(turned.z, plan.door_width),
		"and turning it swaps the width and the depth")

func test_the_hollow_is_smaller_than_the_shell() -> void:
	print("hollowing")
	var plan := RoomPlan.new()
	var shell := plan.shell_box(LEFT, 3.0)
	var hollow := plan.hollow_box(LEFT, 3.0)
	expect(hollow.x < shell.x and hollow.z < shell.z, "the hollow is inside the shell")
	expect(absf((shell.x - hollow.x) - plan.wall * 2.0) < 0.001,
		"by exactly one wall thickness on each side")
	var tiny := plan.hollow_box(Rect2(0, 0, 0.1, 0.1), 3.0)
	expect(tiny.x > 0.0, "and a room smaller than its own walls still has a positive size")

func test_finding_every_doorway() -> void:
	print("the whole plan")
	var rooms: Array[Rect2] = [LEFT, RIGHT, BELOW, CORNER]
	var doors := RoomPlan.doorways(rooms)
	# LEFT-RIGHT, LEFT-BELOW, RIGHT-CORNER, BELOW-CORNER — but not LEFT-CORNER,
	# which meet at a point.
	expect(doors.size() == 4, "four doorways between four rooms in a square (%d)" % doors.size())
	for pair in doors:
		expect_quiet(pair.x < pair.y, "%s is not in order" % pair)
	expect(_quiet == 0, "each pair listed once, in order")

# --- the real CSG tree -----------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real level")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			var combiner: CSGCombiner3D = _scene.get_node("Level")
			var unions := 0
			var subtractions := 0
			for child in combiner.get_children():
				var box := child as CSGBox3D
				if box == null:
					continue
				if box.operation == CSGShape3D.OPERATION_SUBTRACTION:
					subtractions += 1
				else:
					unions += 1
			expect(unions >= 4, "the driver added a solid per room (%d)" % unions)
			# One hollow per room plus one per doorway, and the order matters: a
			# subtraction before the thing it cuts removes nothing.
			expect(subtractions > unions,
				"and subtracted more than it added — hollows and doorways")
			expect(combiner.use_collision,
				"the live tree carries collision, so it is walkable while greyboxing")
		8:
			# CSG is evaluated deferred, so a bake in the same frame as the tree
			# was built comes back empty. Waiting a few frames is the difference
			# between a mesh and a puzzled afternoon.
			var combiner: CSGCombiner3D = _scene.get_node("Level")
			var mesh := combiner.bake_static_mesh()
			expect(mesh != null, "the CSG tree bakes to a mesh once it has been evaluated")
			if mesh != null:
				expect(mesh.get_faces().size() > 0,
					"with triangles in it (%d)" % (mesh.get_faces().size() / 3))
			_scene.queue_free()
			_report()

var _quiet := 0

func expect_quiet(condition: bool, label: String) -> void:
	if not condition:
		_quiet += 1
		print("  (", label, " — failed)")
