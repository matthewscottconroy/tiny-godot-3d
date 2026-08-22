class_name Transitions
extends RefCounted

## One tween at a time, per node and property.
##
## `Tween` and `AnimationPlayer` overlap enough to argue about and are not
## interchangeable:
##
##   * **`AnimationPlayer` is for motion you authored.** It is a timeline. It can
##     be seeked, looped, blended and previewed, and it plays the same way every
##     time. A door swinging, a walk cycle, a UI flourish that never varies.
##   * **`Tween` is for motion you decided at runtime.** From wherever the thing
##     is now, to wherever it needs to be, over a length of time that may depend
##     on how far that is. It is code, not data, and it does not survive the node
##     it was created for.
##
## The bug that brings people here is neither of those. It is that `Tween`s are
## fire-and-forget: press the key twice and two tweens are now writing the same
## property every frame, and the property ends up wherever the last one to run
## happened to want it. Nothing errors. The motion just goes strange, usually
## only when someone presses the button quickly.
##
## The fix is to remember what is running.

## Keyed by node and property. The dictionary holds a reference, and a `Tween` is
## reference-counted, so anything in here is a live object — the only question is
## whether it is still a *valid* tween, which is what `is_valid()` answers.
var _running := {}


## Start a tween on a property, replacing whatever was already animating it.
##
## The replacement is the whole point: without it, the second press does not
## interrupt the first, it *joins* it.
func start(node: Node, property: NodePath, to: Variant, duration: float,
		trans: Tween.TransitionType = Tween.TRANS_CUBIC,
		ease_type: Tween.EaseType = Tween.EASE_OUT) -> Tween:
	stop(node, property)
	var tween := node.create_tween()
	tween.set_trans(trans).set_ease(ease_type)
	tween.tween_property(node, property, to, maxf(duration, 0.0001))
	var key := _key(node, property)
	_running[key] = tween
	# Forget it the moment it finishes. Without this the dictionary slowly
	# becomes a list of every transition the game has ever played, and
	# `is_running()` starts answering questions about tweens that are gone.
	tween.finished.connect(_forget.bind(key, tween))
	return tween


## Stop whatever is animating this property, if anything is.
func stop(node: Node, property: NodePath) -> bool:
	var key := _key(node, property)
	if not _running.has(key):
		return false
	var tween: Tween = _running[key]
	if tween.is_valid():
		tween.kill()
	_running.erase(key)
	return true


func is_running(node: Node, property: NodePath) -> bool:
	var key := _key(node, property)
	if not _running.has(key):
		return false
	var tween: Tween = _running[key]
	return tween.is_valid() and tween.is_running()


## How many transitions are being tracked.
func count() -> int:
	return _running.size()


## Drop a key, but only if it still holds the tween that finished.
##
## The guard matters: by the time a tween finishes, `start()` may already have
## replaced it, and erasing blindly would forget the *new* one.
func _forget(key: String, tween: Tween) -> void:
	if _running.get(key) == tween:
		_running.erase(key)


func stop_all() -> void:
	for key in _running.keys():
		var tween: Tween = _running[key]
		if tween.is_valid():
			tween.kill()
	_running.clear()


## How long a transition should take to cover this distance.
##
## A fixed duration makes small moves feel sluggish and big ones feel teleported.
## Deriving it from the distance is one line and is most of what separates
## transitions that feel right from ones that do not.
static func duration_for(distance: float, speed: float,
		shortest: float = 0.08, longest: float = 1.0) -> float:
	if speed <= 0.0:
		return longest
	return clampf(absf(distance) / speed, shortest, longest)


static func _key(node: Node, property: NodePath) -> String:
	return "%d:%s" % [node.get_instance_id(), property]
