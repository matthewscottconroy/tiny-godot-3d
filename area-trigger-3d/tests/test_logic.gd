extends Node

# Drives the real Occupancy from scripts/occupancy.gd, then drops a real body
# into the real Area3D to check that the layers are wired the way the demo says.
#
# mutate-driver: skip — the scene is instantiated to exercise a real Area3D, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_an_empty_zone()
	test_the_first_body_occupies_it()
	test_the_second_body_is_not_a_second_event()
	test_leaving_one_by_one()
	test_the_same_body_twice()
	test_leaving_without_entering()
	test_dwell_time()
	test_dwell_is_per_body()
	test_freed_bodies_are_pruned()
	test_clearing()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[area-trigger-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

## A counter for each of the three signals, so transitions can be asserted on.
class Watcher extends RefCounted:
	var occupied := 0
	var vacated := 0
	var counts: Array[int] = []

	func watch(zone: Occupancy) -> void:
		zone.occupied.connect(func() -> void: occupied += 1)
		zone.vacated.connect(func() -> void: vacated += 1)
		zone.count_changed.connect(func(n: int) -> void: counts.append(n))

func _body(body_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = body_name
	add_child(node)
	return node

func test_an_empty_zone() -> void:
	print("empty")
	var zone := Occupancy.new()
	expect(zone.count() == 0, "nothing is inside to begin with")
	expect(not zone.is_occupied(), "so it is not occupied")
	expect(is_zero_approx(zone.longest_dwell()), "and nobody has been waiting")

func test_the_first_body_occupies_it() -> void:
	print("first in")
	var zone := Occupancy.new()
	var watcher := Watcher.new()
	watcher.watch(zone)
	var crate := _body("Crate")
	expect(zone.enter(crate), "entering reports that something changed")
	expect(zone.count() == 1 and zone.contains(crate), "the body is inside")
	expect(watcher.occupied == 1, "and the zone announces that it is now occupied")
	expect(watcher.vacated == 0, "without announcing anything else")

func test_the_second_body_is_not_a_second_event() -> void:
	print("second in")
	var zone := Occupancy.new()
	var watcher := Watcher.new()
	watcher.watch(zone)
	zone.enter(_body("A"))
	zone.enter(_body("B"))
	expect(zone.count() == 2, "both bodies are inside")
	# The whole reason this class exists: a door wired to body_entered opens
	# twice and, worse, closes on the first body_exited while someone is still
	# standing in it.
	expect(watcher.occupied == 1, "but the zone only became occupied once")
	var wanted: Array[int] = [1, 2]
	expect(watcher.counts == wanted, "while the count reports every change")

func test_leaving_one_by_one() -> void:
	print("leaving")
	var zone := Occupancy.new()
	var watcher := Watcher.new()
	watcher.watch(zone)
	var a := _body("A2")
	var b := _body("B2")
	zone.enter(a)
	zone.enter(b)
	expect(zone.exit(a), "one body leaving is a change")
	expect(watcher.vacated == 0, "but the zone is not vacated while the other is still there")
	expect(zone.exit(b), "the last body leaving is a change too")
	expect(watcher.vacated == 1, "and that one does vacate it")
	expect(zone.count() == 0 and not zone.is_occupied(), "leaving it empty")

func test_the_same_body_twice() -> void:
	print("double entry")
	var zone := Occupancy.new()
	var watcher := Watcher.new()
	watcher.watch(zone)
	var crate := _body("A3")
	zone.enter(crate)
	# Godot reports the same body twice when it straddles two shapes of the same
	# area. A count that goes to two for one crate never comes back to zero.
	expect(not zone.enter(crate), "entering twice is not a second entry")
	expect(zone.count() == 1, "and does not double the count")
	expect(watcher.occupied == 1, "nor announce a second occupation")

func test_leaving_without_entering() -> void:
	print("spurious exit")
	var zone := Occupancy.new()
	var watcher := Watcher.new()
	watcher.watch(zone)
	expect(not zone.exit(_body("Stranger")), "a body that was never inside cannot leave")
	expect(watcher.vacated == 0, "and an empty zone is not vacated again")
	expect(not zone.exit(null), "nor does a null body do anything")

func test_dwell_time() -> void:
	print("dwell")
	var zone := Occupancy.new()
	var crate := _body("A4")
	zone.enter(crate)
	for i in 60:
		zone.advance(1.0 / 60.0)
	expect(absf(zone.dwell(crate) - 1.0) < 0.001, "a second of frames is a second of dwell")
	expect(absf(zone.longest_dwell() - 1.0) < 0.001, "and it is the longest anyone has waited")
	zone.exit(crate)
	expect(is_zero_approx(zone.dwell(crate)), "leaving forgets the timer")
	zone.enter(crate)
	expect(is_zero_approx(zone.dwell(crate)), "and re-entering starts it again from zero")

func test_dwell_is_per_body() -> void:
	print("per body")
	var zone := Occupancy.new()
	var early := _body("A5")
	var late := _body("B5")
	zone.enter(early)
	zone.advance(2.0)
	zone.enter(late)
	zone.advance(0.5)
	expect(absf(zone.dwell(early) - 2.5) < 0.001, "the first body has been there longest")
	expect(absf(zone.dwell(late) - 0.5) < 0.001, "the second only since it arrived")
	# "Stand here for three seconds" asks whether someone waited, not whether the
	# zone was busy for three seconds with people coming and going.
	expect(absf(zone.longest_dwell() - 2.5) < 0.001, "and the longest wait is the first one's")

func test_freed_bodies_are_pruned() -> void:
	print("freed bodies")
	var zone := Occupancy.new()
	var watcher := Watcher.new()
	watcher.watch(zone)
	var doomed := _body("A6")
	zone.enter(doomed)
	doomed.free()
	# A body destroyed inside an area never emits body_exited, so the plate
	# stays pressed by a crate that no longer exists.
	zone.prune()
	expect(zone.count() == 0, "a freed body stops occupying the zone")
	expect(watcher.vacated == 1, "and its removal vacates it properly")

func test_clearing() -> void:
	print("clearing")
	var zone := Occupancy.new()
	var watcher := Watcher.new()
	watcher.watch(zone)
	zone.enter(_body("A7"))
	zone.enter(_body("B7"))
	zone.clear()
	expect(zone.count() == 0, "clearing empties the zone")
	expect(watcher.vacated == 1, "and vacates it once")
	zone.clear()
	expect(watcher.vacated == 1, "clearing an empty zone changes nothing")

# --- the real area ---------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real area")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		3:
			# Drop both bodies onto the plate. One is on the layer the area
			# watches; the other is not.
			(_scene.get_node("Crate") as Node3D).global_position = Vector3(0, 1.0, 0)
			(_scene.get_node("Debris") as Node3D).global_position = Vector3(0.6, 1.0, 0.4)
		12:
			var plate: Area3D = _scene.get_node("Plate")
			var crate: Node3D = _scene.get_node("Crate")
			var debris: Node3D = _scene.get_node("Debris")
			var overlapping := plate.get_overlapping_bodies()
			expect(overlapping.has(crate), "the area sees the body on the layer it masks")
			# The lesson layers exist for: the area is not blind to the debris
			# because of where it is, but because of what it is.
			expect(not overlapping.has(debris),
				"and not the one on a layer outside its mask, though it is in the same place")
			expect(plate.collision_layer == 0,
				"the area itself is on no layer — it detects, it is not detected")
			var door: Node3D = _scene.get_node("Door")
			expect(door.position.y > 1.5, "and the door the plate drives has started opening")
			_report()
