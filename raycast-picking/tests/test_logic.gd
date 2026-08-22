extends Node

# Drives the real ScenePicker from scripts/picker.gd, and then the real scene.
#
# The last test is the odd one: it instantiates scenes/main.tscn and fires an
# actual ray at the actual boxes. That has to happen in _physics_process —
# `direct_space_state` is only valid there — so the suite reports after the
# first physics frame rather than at the end of _ready.
#
# mutate-driver: skip — the scene is instantiated to fire a real ray, not to test main.gd

var _pass := 0
var _fail := 0
var _scene_checked := false

func _ready() -> void:
	test_a_ray_straight_down_meets_the_floor()
	test_an_angled_ray_lands_further_out()
	test_a_ray_pointing_away_never_lands()
	test_a_parallel_ray_never_lands()
	test_the_plane_height_is_respected()
	test_selecting_one_thing()
	test_selecting_replaces_rather_than_adds()
	test_toggling_adds_and_removes()
	test_clearing()
	test_the_signal_reports_the_new_count()
	test_freed_nodes_are_pruned()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[raycast-picking] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

# --- the ground plane ------------------------------------------------------

func test_a_ray_straight_down_meets_the_floor() -> void:
	print("straight down")
	var hit = ScenePicker.ground_point(Vector3(2.0, 5.0, -1.0), Vector3.DOWN, 0.0)
	expect(hit != null, "a downward ray meets the ground")
	expect((hit as Vector3).is_equal_approx(Vector3(2.0, 0.0, -1.0)),
		"directly below where it started")

func test_an_angled_ray_lands_further_out() -> void:
	print("at an angle")
	# Down and forward at 45 degrees from 3m up: it travels 3m along Z as it
	# falls 3m, so it lands at z = -3.
	var direction := Vector3(0.0, -1.0, -1.0).normalized()
	var hit = ScenePicker.ground_point(Vector3(0.0, 3.0, 0.0), direction, 0.0)
	expect(hit != null, "an angled ray still meets the ground")
	expect(is_equal_approx((hit as Vector3).z, -3.0), "as far out as it fell, at 45 degrees")
	expect(is_zero_approx((hit as Vector3).y), "and lands on the plane, not near it")

func test_a_ray_pointing_away_never_lands() -> void:
	print("pointing away")
	# The maths has a solution here — the plane is behind the camera — and
	# taking it puts whatever you are placing somewhere the player cannot see.
	expect(ScenePicker.ground_point(Vector3(0.0, 5.0, 0.0), Vector3.UP, 0.0) == null,
		"aiming at the sky is a miss, not a point behind the ray")

func test_a_parallel_ray_never_lands() -> void:
	print("parallel")
	expect(ScenePicker.ground_point(Vector3(0.0, 5.0, 0.0), Vector3.FORWARD, 0.0) == null,
		"a ray parallel to the plane misses rather than dividing by zero")

func test_the_plane_height_is_respected() -> void:
	print("plane height")
	var hit = ScenePicker.ground_point(Vector3(0.0, 10.0, 0.0), Vector3.DOWN, 4.0)
	expect(is_equal_approx((hit as Vector3).y, 4.0), "a raised plane is met at its own height")
	expect(ScenePicker.ground_point(Vector3(0.0, 2.0, 0.0), Vector3.DOWN, 4.0) == null,
		"and a ray starting below it never reaches it")

# --- the selection ---------------------------------------------------------

func _node(name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	add_child(node)
	return node

func test_selecting_one_thing() -> void:
	print("selecting")
	var picker := ScenePicker.new()
	var a := _node("A")
	expect(picker.count() == 0, "nothing is selected to begin with")
	picker.select(a)
	expect(picker.count() == 1, "selecting one thing selects one thing")
	expect(picker.is_selected(a), "and it is the thing that was selected")

func test_selecting_replaces_rather_than_adds() -> void:
	print("replacing")
	var picker := ScenePicker.new()
	var a := _node("A2")
	var b := _node("B2")
	picker.select(a)
	picker.select(b)
	expect(picker.count() == 1, "a plain click selects only what was clicked")
	expect(picker.is_selected(b) and not picker.is_selected(a), "replacing the previous one")

func test_toggling_adds_and_removes() -> void:
	print("shift-clicking")
	var picker := ScenePicker.new()
	var a := _node("A3")
	var b := _node("B3")
	picker.select(a)
	picker.toggle(b)
	expect(picker.count() == 2, "shift-click adds to the selection")
	picker.toggle(b)
	expect(picker.count() == 1, "and shift-clicking it again takes it out")
	expect(picker.is_selected(a), "leaving the rest alone")
	picker.toggle(a)
	expect(picker.count() == 0, "toggling the last one empties the selection")

func test_clearing() -> void:
	print("clearing")
	var picker := ScenePicker.new()
	picker.select(_node("A4"))
	picker.toggle(_node("B4"))
	picker.clear()
	expect(picker.count() == 0, "clearing empties it")
	expect(picker.selected().is_empty(), "and the list agrees")

func test_the_signal_reports_the_new_count() -> void:
	print("the signal")
	var picker := ScenePicker.new()
	var counts: Array[int] = []
	picker.selection_changed.connect(func(n: int) -> void: counts.append(n))
	var a := _node("A5")
	picker.select(a)
	picker.toggle(_node("B5"))
	picker.clear()
	var wanted: Array[int] = [1, 2, 0]
	expect(counts == wanted, "every change reports the new count, in order")
	counts.clear()
	picker.clear()
	expect(counts.is_empty(), "and clearing an empty selection is not a change")
	picker.select(a)
	counts.clear()
	picker.select(a)
	expect(counts.is_empty(), "nor is selecting what is already selected")

func test_freed_nodes_are_pruned() -> void:
	print("pruning")
	var picker := ScenePicker.new()
	var a := _node("A6")
	var b := _node("B6")
	picker.select(a)
	picker.toggle(b)
	b.free()
	picker.prune()
	expect(picker.count() == 1, "a freed node drops out of the selection")
	expect(picker.is_selected(a), "and the survivor stays in it")

# --- the real scene --------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _scene_checked:
		return
	_scene_checked = true
	print("the real scene")

	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var space := scene.get_world_3d().direct_space_state

	# Straight down through BoxA, which the scene puts at x = -2.5.
	var from := Vector3(-2.5, 10.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0)
	var hit := space.intersect_ray(query)
	expect(not hit.is_empty(), "a ray fired at a box hits something")
	var collider := hit.get("collider") as Node3D
	expect(collider != null and collider.name == "BoxA", "and it is the box it was aimed at")
	expect(collider.is_in_group("pickable"), "which is in the pickable group the driver filters on")
	expect(is_equal_approx((hit["position"] as Vector3).y, 1.0),
		"hitting its top face at y = 1.0, half a metre above its centre")

	# Between the boxes: the only thing under that column is the floor, which is
	# not pickable — the case the ground-plane fallback exists for.
	var gap := Vector3(6.0, 10.0, 0.0)
	var floor_hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(gap, gap + Vector3.DOWN * 20.0))
	var floor_body := floor_hit.get("collider") as Node3D
	expect(floor_body != null and not floor_body.is_in_group("pickable"),
		"a ray between the boxes hits the floor, which is not pickable")

	scene.queue_free()
	_report()
