extends Node

# Drives the real ScenePool from scripts/scene_pool.gd against the real
# projectile scene.
#
# Pooling bugs are lifecycle bugs, and lifecycle bugs look like something else:
# a projectile that arrives carrying last life's velocity reads as a physics
# bug, and an instance handed out twice reads as two objects that teleport onto
# each other. All of it is checkable by counting.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_prewarming()
	test_a_pool_with_nothing_to_make()
	test_acquiring_takes_from_the_pool()
	test_acquired_instances_are_distinct()
	test_releasing_returns_it()
	test_recycling_reuses_the_same_instance()
	test_the_pool_grows_when_it_has_to()
	test_a_capped_pool_refuses_rather_than_sharing()
	test_a_pool_that_cannot_grow()
	test_releasing_something_twice()
	test_releasing_a_stranger()
	test_release_all()
	test_the_reset_callback_runs()
	test_reset_runs_before_the_instance_wakes()
	test_parked_instances_are_asleep()
	test_freed_instances_are_pruned()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[object-pool-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const PROJECTILE := preload("res://scenes/projectile.tscn")

func _pool(size: int = 0) -> ScenePool:
	var holder := Node3D.new()
	add_child(holder)
	return ScenePool.new(PROJECTILE, holder, size)

func test_prewarming() -> void:
	print("prewarming")
	var pool := _pool(5)
	# The cost of pooling does not disappear, it moves — ideally to a loading
	# screen, where nobody is watching the frame time.
	expect(pool.available() == 5, "the pool starts with what it was asked for")
	expect(pool.total() == 5 and pool.in_use() == 0, "and none of it is in use")
	expect(pool.created() == 5, "having created exactly that many instances")

func test_a_pool_with_nothing_to_make() -> void:
	print("no scene")
	var holder := Node3D.new()
	add_child(holder)
	# Both halves matter: a pool with no scene, and one with nowhere to put what
	# it makes. Either way the answer is null rather than an error deep inside.
	var no_scene := ScenePool.new(null, holder, 3)
	expect(no_scene.total() == 0, "a pool with no scene prewarms nothing")
	expect(no_scene.acquire() == null, "and hands out nothing")
	var no_parent := ScenePool.new(PROJECTILE, null, 3)
	expect(no_parent.acquire() == null, "a pool with nowhere to put instances hands out nothing too")

func test_acquiring_takes_from_the_pool() -> void:
	print("acquiring")
	var pool := _pool(3)
	var instance := pool.acquire()
	expect(instance != null, "acquiring gives you an instance")
	expect(pool.available() == 2 and pool.in_use() == 1, "taken from the free list")
	expect(pool.created() == 3, "without creating anything new")

func test_acquired_instances_are_distinct() -> void:
	print("no sharing")
	var pool := _pool(3)
	var a := pool.acquire()
	var b := pool.acquire()
	# Handing the same instance to two callers is far worse than running out:
	# two things share one object and each teleports it onto the other.
	expect(a != b, "two acquisitions are two different instances")
	expect(pool.in_use() == 2, "and both are marked as in use")

func test_releasing_returns_it() -> void:
	print("releasing")
	var pool := _pool(2)
	var instance := pool.acquire()
	expect(pool.release(instance), "releasing reports that it took it back")
	expect(pool.available() == 2 and pool.in_use() == 0, "and the instance is free again")

func test_recycling_reuses_the_same_instance() -> void:
	print("recycling")
	var pool := _pool(1)
	var first := pool.acquire()
	pool.release(first)
	var second := pool.acquire()
	expect(first == second, "the same instance comes back round")
	expect(pool.created() == 1, "and nothing new was created — which is the entire point")

func test_the_pool_grows_when_it_has_to() -> void:
	print("growing")
	var pool := _pool(1)
	var grown := [0]
	pool.grew.connect(func(size: int) -> void: grown[0] = size)
	pool.acquire()
	var extra := pool.acquire()
	expect(extra != null, "an empty pool that can grow still hands one out")
	expect(pool.total() == 2 and pool.created() == 2, "by making another")
	expect(grown[0] == 2, "and says so, which is the signal to raise the initial size")

func test_a_capped_pool_refuses_rather_than_sharing() -> void:
	print("the ceiling")
	var pool := _pool(1)
	pool.max_size = 1
	pool.acquire()
	expect(pool.acquire() == null, "a pool at its ceiling returns null")
	expect(pool.total() == 1, "rather than exceeding it")

	# And a ceiling that has not been reached is not a ceiling: a pool of one
	# with room for four still grows.
	var roomy := _pool(1)
	roomy.max_size = 4
	roomy.acquire()
	expect(roomy.acquire() != null, "a pool below its ceiling still grows")
	expect(roomy.total() == 2, "one instance at a time")

func test_a_pool_that_cannot_grow() -> void:
	print("fixed size")
	var pool := _pool(1)
	pool.can_grow = false
	pool.acquire()
	expect(pool.acquire() == null, "a fixed pool returns null when empty")
	expect(pool.created() == 1, "and creates nothing")

func test_releasing_something_twice() -> void:
	print("double release")
	var pool := _pool(2)
	var instance := pool.acquire()
	pool.release(instance)
	# The bug this prevents: the same instance twice in the free list, handed to
	# two callers at once next time it is busy.
	expect(not pool.release(instance), "releasing twice is refused")
	expect(pool.available() == 2, "and does not put it in the pool twice")

func test_releasing_a_stranger() -> void:
	print("strangers")
	var pool := _pool(1)
	var outsider := Node3D.new()
	add_child(outsider)
	expect(not pool.release(outsider), "a node the pool never handed out is refused")
	expect(pool.available() == 1, "and does not join the pool")

func test_release_all() -> void:
	print("releasing everything")
	var pool := _pool(4)
	pool.acquire()
	pool.acquire()
	pool.acquire()
	expect(pool.release_all() == 3, "release_all reports how many it took back")
	expect(pool.in_use() == 0 and pool.available() == 4, "and the pool is whole again")

func test_the_reset_callback_runs() -> void:
	print("resetting")
	var pool := _pool(1)
	var resets := [0]
	pool.reset = func(instance: Node3D) -> void:
		resets[0] += 1
		instance.position = Vector3.ZERO
	var instance := pool.acquire()
	instance.position = Vector3(9, 9, 9)
	pool.release(instance)
	var recycled := pool.acquire()
	expect(resets[0] == 2, "reset runs on every acquisition")
	# Without this, a recycled projectile arrives where the last one died,
	# which reads as a spawn bug rather than a pooling one.
	expect(recycled.position == Vector3.ZERO, "and the instance arrives in a known state")

func test_reset_runs_before_the_instance_wakes() -> void:
	print("order")
	var pool := _pool(1)
	var seen_visible := [true]
	pool.reset = func(instance: Node3D) -> void:
		seen_visible[0] = instance.visible
	pool.acquire()
	# A physics frame can land between waking and resetting. A body woken first
	# gets one frame with last life's state, and moves in it.
	expect(not seen_visible[0], "reset happens while the instance is still parked")

func test_parked_instances_are_asleep() -> void:
	print("parked")
	var pool := _pool(1)
	var instance := pool.acquire()
	expect(instance.visible, "an acquired instance is visible")
	expect(instance.is_processing(), "and is processing")
	expect(instance.is_physics_processing(), "and physics-processing")
	pool.release(instance)
	expect(not instance.visible, "a released one is not visible")
	expect(not instance.is_processing(), "not processing")
	# The half everyone forgets. A parked instance still running its physics is
	# the pooling bug where the pool works and the frame rate does not improve.
	expect(not instance.is_physics_processing(), "and not physics-processing either")

func test_freed_instances_are_pruned() -> void:
	print("freed instances")
	var pool := _pool(2)
	var instance := pool.acquire()
	instance.free()
	pool.prune()
	expect(pool.in_use() == 0, "an instance freed while checked out stops counting as in use")
	expect(pool.total() == 1, "and the pool's total falls to match reality")
