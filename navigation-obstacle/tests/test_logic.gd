extends Node

# Drives the real Carving from scripts/carving.gd, and then shuts a real door
# across a real navigation mesh — because the interesting claims here are about
# what the engine does, and none of them can be checked by reading the code.
#
# mutate-driver: skip — the scene is instantiated to carve a real navigation mesh, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _straight := 0.0

func _ready() -> void:
	test_the_footprint_covers_the_door()
	test_the_margin_is_the_agent()
	test_the_area_of_a_footprint()
	test_winding_does_not_change_the_area()
	test_the_signed_area_of_a_known_square()
	test_containment_off_the_origin()
	test_containment_against_a_slanted_edge()
	test_a_degenerate_box()
	test_points_outside()
	test_the_avoidance_radius()
	test_carve_or_avoid()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[navigation-obstacle] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_footprint_covers_the_door() -> void:
	print("coverage")
	var box := Carving.box_footprint(Vector3(4, 2, 1))
	expect(Carving.contains(box, Vector3.ZERO), "the middle of the door is inside the footprint")
	expect(Carving.contains(box, Vector3(1.9, 0, 0)), "and so is a point near its end")
	# The outline is flat, however tall the door is.
	expect(Carving.contains(box, Vector3(0, 50, 0)), "height is not part of it")

func test_the_margin_is_the_agent() -> void:
	print("the agent's shoulders")
	var tight := Carving.box_footprint(Vector3(4, 2, 1))
	var padded := Carving.box_footprint(Vector3(4, 2, 1), 0.5)
	var beside := Vector3(0, 0, 0.9)
	# A hole exactly the size of the door leaves a strip along its edge that is
	# walkable on the mesh and too narrow to walk down.
	expect(not Carving.contains(tight, beside), "a point just past the door is outside a tight footprint")
	expect(Carving.contains(padded, beside), "and inside one padded by the agent radius")
	expect(Carving.area(padded) > Carving.area(tight), "which is the larger of the two")

func test_the_area_of_a_footprint() -> void:
	print("area")
	expect(is_equal_approx(Carving.area(Carving.box_footprint(Vector3(4, 2, 2))), 8.0),
		"a 4 by 2 door has an 8 m² footprint")
	expect(is_equal_approx(Carving.area(Carving.box_footprint(Vector3(4, 2, 2), 0.5)), 15.0),
		"and 15 m² once the agent radius is added all round")

func test_winding_does_not_change_the_area() -> void:
	print("winding")
	var forwards := Carving.box_footprint(Vector3(3, 1, 2))
	var backwards := PackedVector3Array()
	for i in range(forwards.size() - 1, -1, -1):
		backwards.append(forwards[i])
	# Godot normalises the winding of a carving outline. Worth stating as a fact
	# rather than leaving as a thing to worry about — the signs differ and the
	# footprint does not.
	expect(Carving.signed_area(forwards) * Carving.signed_area(backwards) < 0.0,
		"reversing the outline flips the sign of its signed area")
	expect(is_equal_approx(Carving.area(forwards), Carving.area(backwards)),
		"but not the area, which is what gets carved either way")

func test_the_signed_area_of_a_known_square() -> void:
	print("signed area")
	# Counter-clockwise seen from above, so the doubled signed area is +8 for a
	# 2 by 2 square. Stating the number is what makes this a measurement rather
	# than a shrug.
	var square := PackedVector3Array([
		Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)])
	expect(is_equal_approx(Carving.signed_area(square), 8.0),
		"a 2 by 2 counter-clockwise square has a doubled signed area of +8")
	expect(is_equal_approx(Carving.area(square), 4.0), "which is four square metres")

func test_containment_off_the_origin() -> void:
	print("off-centre footprints")
	# A footprint centred on the origin hides a whole family of arithmetic
	# mistakes, because everything is symmetric. This one is not.
	var wedge := PackedVector3Array([
		Vector3(2, 0, 1), Vector3(6, 0, 1), Vector3(6, 0, 3), Vector3(2, 0, 3)])
	expect(Carving.contains(wedge, Vector3(3, 0, 2)), "a point inside an off-centre footprint")
	expect(not Carving.contains(wedge, Vector3(1, 0, 2)), "one short of its near edge is outside")
	expect(not Carving.contains(wedge, Vector3(7, 0, 2)), "and one past its far edge is too")
	expect(Carving.contains(wedge, Vector3(5.9, 0, 2.9)), "a point just inside the far corner")
	expect(not Carving.contains(wedge, Vector3(6.1, 0, 2.9)), "and just outside it")

func test_containment_against_a_slanted_edge() -> void:
	print("slanted edges")
	# Every box is axis-aligned, and an axis-aligned polygon never exercises the
	# interpolation inside a crossing test — both sides of the edge have the same
	# x. A triangle does.
	var triangle := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 4)])
	expect(Carving.contains(triangle, Vector3(0.5, 0, 0.5)), "well inside the right angle")
	expect(Carving.contains(triangle, Vector3(1.4, 0, 1.4)),
		"just inside the hypotenuse, where the arithmetic has to be right")
	expect(not Carving.contains(triangle, Vector3(2.2, 0, 2.2)),
		"and just outside it, which the same arithmetic decides")
	expect(not Carving.contains(triangle, Vector3(3.5, 0, 3.5)), "well outside the hypotenuse")
	expect(not Carving.contains(triangle, Vector3(-0.5, 0, 2.0)), "and behind the vertical edge")

func test_a_degenerate_box() -> void:
	print("degenerate boxes")
	var flat := Carving.box_footprint(Vector3(0, 2, 0))
	expect(flat.size() == 4, "a box with no width still produces a polygon")
	expect(Carving.area(flat) > 0.0, "with a real area, rather than nothing to carve")
	expect(not Carving.contains(PackedVector3Array([Vector3.ZERO, Vector3.ONE]), Vector3.ZERO),
		"and two points are not a polygon anything can be inside")

func test_points_outside() -> void:
	print("outside")
	var box := Carving.box_footprint(Vector3(2, 2, 2))
	expect(not Carving.contains(box, Vector3(5, 0, 0)), "a point beyond the door is outside")
	expect(not Carving.contains(box, Vector3(0, 0, -5)), "and so is one on the other axis")

func test_the_avoidance_radius() -> void:
	print("avoidance")
	var radius := Carving.avoidance_radius(Vector3(2, 2, 2))
	# The half-diagonal, not the half-width: a circle covering only the flat
	# sides of a box leaves its corners sticking out.
	expect(is_equal_approx(radius, sqrt(2.0)), "the circle reaches the corners (%.3f)" % radius)
	expect(radius > 1.0, "which is further than the sides")
	expect(is_equal_approx(Carving.avoidance_radius(Vector3(2, 2, 2), 0.5), sqrt(2.0) + 0.5),
		"and the agent radius is added on top")

func test_carve_or_avoid() -> void:
	print("which mechanism")
	# Carving means re-baking, and re-baking is not free. Anything that moves has
	# to be avoided instead; there is no third option.
	expect(Carving.should_carve(0.0), "something standing still can be carved into the mesh")
	expect(not Carving.should_carve(2.0), "and something moving has to be avoided")
	expect(Carving.should_carve(-0.01), "a twitch either way is still standing still")

# --- the real navigation mesh ----------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real door")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		8:
			# Not frame 2: a navigation map takes a few frames to come up, and a
			# path asked for before then comes back empty rather than wrong.
			_open_the_door()
		12:
			_scene.call("_repath")
		14:
			_straight = _scene.call("path_length")
			_check_the_open_door()
		16:
			_shut_the_door()
		20:
			_check_carving_needs_a_bake()
		22:
			_scene.call("_rebake")
		26:
			_scene.call("_repath")
		28:
			_check_the_carve()
			_report()

func _open_the_door() -> void:
	_scene.set("_shut", false)
	_scene.call("_apply_door")
	_scene.call("_rebake")

func _shut_the_door() -> void:
	_scene.set("_shut", true)
	_scene.call("_apply_door")
	# Deliberately no re-bake here. This is the state everyone hits first.

func _check_the_open_door() -> void:
	expect(_straight > 13.0 and _straight < 15.0,
		"with the door open the path is the straight 14 m (%.1f m)" % _straight)
	expect(_scene.call("path_swing") < 0.5, "straight down the middle")

func _check_carving_needs_a_bake() -> void:
	var obstacle: NavigationObstacle3D = _scene.get_node("Region/Door/Obstacle")
	expect(obstacle.vertices.size() == 4, "the shut door has handed the obstacle a footprint")
	expect(obstacle.carve_navigation_mesh, "and asked it to carve")
	# The whole point of the demo: none of that has done anything yet.
	expect(is_equal_approx(_scene.call("path_length"), _straight),
		"and the path is unchanged, because carving is a bake-time property")
	expect(_scene.get("_stale"), "the demo says so rather than pretending otherwise")

func _check_the_carve() -> void:
	var carved: float = _scene.call("path_length")
	expect(carved > _straight + 0.5,
		"after a re-bake the path is longer (%.1f m against %.1f m)" % [carved, _straight])
	expect(_scene.call("path_swing") > 1.0,
		"swinging %.1f m off the straight line to get round the door"
			% _scene.call("path_swing"))
	expect(not _scene.get("_stale"), "and the mesh is no longer stale")
