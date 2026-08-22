class_name ScenePool
extends RefCounted

## Reusing scene instances instead of creating and freeing them.
##
## In 2D the allocation people worry about is a node. In 3D it is a whole scene
## instance — nodes, meshes, collision shapes, materials — and `instantiate()`
## plus `queue_free()` sixty times a second produces exactly the periodic stutter
## that makes a game feel bad without ever showing up as a low average frame
## rate.
##
## A pool is a list of instances that are alive but not in use. That is the easy
## part. The part that goes wrong is **reset**: a recycled object arrives
## carrying whatever state it had when it was released — a velocity, a timer, a
## trail of particles, a half-finished tween — and the bug looks like a physics
## bug rather than a lifecycle one.
##
## So `acquire()` takes reset seriously enough to make it a required step, and
## the suite checks that it happens.
##
# size-exempt: a pool is acquire, release, grow, park, reset and prune. Dropping
# any one of them leaves a pool that works in a demo and breaks in a game — a
# parked instance still processing, a double release handing one object to two
# callers, an instance freed while checked out. The size is the subject.

## Emitted when the pool has to grow, which is the signal to raise `initial_size`.
signal grew(new_size: int)

var _scene: PackedScene
var _parent: Node
var _free: Array[Node3D] = []
var _in_use: Array[Node3D] = []
var _created := 0

## Reset an instance before it is handed out. Set this or every user of the pool
## has to remember; the whole point is that they do not.
var reset: Callable = Callable()

## Grow past the initial size on demand, rather than returning null.
var can_grow := true

## Never exceed this many instances, growth included. Zero means no ceiling.
var max_size := 0


func _init(scene: PackedScene, parent: Node, initial_size: int = 0) -> void:
	_scene = scene
	_parent = parent
	prewarm(initial_size)


## Create instances up front, so the first shot costs no more than the hundredth.
##
## Do this during a loading screen: the cost does not go away, it moves to a
## moment where nobody is looking at it.
func prewarm(count: int) -> int:
	var made := 0
	for i in maxi(count, 0):
		var instance := _instantiate()
		if instance == null:
			break
		_park(instance)
		_free.append(instance)
		made += 1
	return made


## Take an instance out of the pool, ready to use.
##
## Returns null when the pool is empty and cannot grow, which callers must
## handle: handing out a busy instance means two things sharing one object,
## which is far worse than a missing bullet.
func acquire() -> Node3D:
	var instance: Node3D
	if _free.is_empty():
		if not can_grow or (max_size > 0 and total() >= max_size):
			return null
		instance = _instantiate()
		if instance == null:
			return null
		grew.emit(total() + 1)
	else:
		instance = _free.pop_back()

	_in_use.append(instance)
	# Reset before waking it, never after: a physics frame can land between the
	# two, and a recycled body with last life's velocity moves in it.
	if reset.is_valid():
		reset.call(instance)
	_wake(instance)
	return instance


## Give an instance back. Returns true if it was ours and in use.
func release(instance: Node3D) -> bool:
	var index := _in_use.find(instance)
	if index == -1:
		return false                      # not ours, or released twice
	_in_use.remove_at(index)
	if not is_instance_valid(instance):
		return true                       # freed behind our back; nothing to park
	_park(instance)
	_free.append(instance)
	return true


## Give everything back at once — the end of a wave, or a level change.
func release_all() -> int:
	var count := _in_use.size()
	for instance in _in_use.duplicate():
		release(instance)
	return count


## Drop anything freed behind the pool's back, so the counts stay honest.
func prune() -> void:
	_in_use = _surviving(_in_use)
	_free = _surviving(_free)


static func _surviving(instances: Array[Node3D]) -> Array[Node3D]:
	var kept: Array[Node3D] = []
	for instance in instances:
		if is_instance_valid(instance):
			kept.append(instance)
	return kept


func available() -> int:
	return _free.size()


func in_use() -> int:
	return _in_use.size()


func total() -> int:
	return _free.size() + _in_use.size()


## How many instances this pool has ever created.
##
## The number worth watching: if it keeps climbing during play, the pool is not
## pooling — something is acquiring without releasing.
func created() -> int:
	return _created


func _instantiate() -> Node3D:
	if _scene == null or _parent == null:
		return null
	var instance := _scene.instantiate() as Node3D
	if instance == null:
		return null
	_parent.add_child(instance)
	_created += 1
	return instance


## Asleep: invisible, not processing, not colliding, out of the way.
##
## Leaving a parked instance processing is the commonest pooling bug there is —
## the pool works, the frame rate does not improve, and nobody can see why.
func _park(instance: Node3D) -> void:
	instance.visible = false
	instance.set_process(false)
	instance.set_physics_process(false)
	if instance is CollisionObject3D:
		# Deferred: a body cannot change its collision state during a physics
		# callback, which is exactly when things get released.
		(instance as CollisionObject3D).set_deferred(&"process_mode",
			Node.PROCESS_MODE_DISABLED)


func _wake(instance: Node3D) -> void:
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.visible = true
	instance.set_process(true)
	instance.set_physics_process(true)
