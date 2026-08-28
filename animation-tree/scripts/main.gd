extends Node3D

# Demo driver. Builds three clips, a blend space and an AnimationTree at
# runtime, then drives the blend from how fast the pawn is actually moving.

const WALK_SPEED := 2.0
const RUN_SPEED := 6.0
const BLEND_PARAM := "parameters/blend_position"

@onready var _player: AnimationPlayer = $AnimationPlayer
@onready var _tree: AnimationTree = $AnimationTree
@onready var _pawn: Node3D = $Pawn
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _driver := BlendDriver.new()
var _speed := 0.0
var _target_speed := 0.0

func _ready() -> void:
	_hint.text = "1/2 slower or faster   3 stop   4 sprint   the blend chases the speed"
	_build_clips()
	_build_tree()

## Three clips of the same limbs, at three amplitudes.
##
## Real clips come from an artist; these are built in code for the same reason
## the rest of the collection generates its assets. See animation-in-code.
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	library.add_animation("idle", _clip(0.05, 2.4))
	library.add_animation("walk", _clip(0.35, 1.2))
	library.add_animation("run", _clip(0.7, 0.6))
	_player.add_animation_library("", library)

func _clip(swing: float, period: float) -> Animation:
	var clip := Animation.new()
	clip.length = period
	clip.loop_mode = Animation.LOOP_LINEAR
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, "Pawn/Leg%s" % ("Left" if side < 0.0 else "Right"))
		for step in 5:
			var time := period * float(step) / 4.0
			var angle := sin(TAU * float(step) / 4.0) * swing * side
			clip.rotation_track_insert_key(track, time, Quaternion(Vector3.RIGHT, angle))
	var bob := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(bob, "Pawn/Body")
	for step in 5:
		clip.position_track_insert_key(bob, period * float(step) / 4.0,
			Vector3(0, 1.0 + absf(sin(PI * float(step) / 2.0)) * swing * 0.3, 0))
	return clip

## A blend space with the three clips at 0, 1 and 2.
##
## Built here rather than in the editor so the whole thing is one readable file —
## and because a tree assembled in code is a tree you can see the shape of.
func _build_tree() -> void:
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 2.0
	var points := {"idle": 0.0, "walk": 1.0, "run": 2.0}
	var named_points := _add_blend_point_takes_a_name(space)
	for clip_name in points:
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name
		var args: Array = [node, float(points[clip_name]), -1]
		if named_points:
			# Naming a blend point is a 4.7 addition. It is worth having — an
			# unnamed point is referenced by index, indices move when points are
			# added or removed, and a parameter path built from one goes quietly
			# stale — and 4.7 warns when the name is left out.
			args.append(clip_name)
		# `callv`, not a direct call: passing four arguments to a three-argument
		# method is a *parse* error, so a static call would stop this demo
		# loading at all on 4.5 and 4.6 rather than skipping the extra argument.
		# Setting the name afterwards does not work either — the warning is
		# emitted by `add_blend_point()` itself.
		space.callv(&"add_blend_point", args)
	_tree.tree_root = space
	_tree.anim_player = _tree.get_path_to(_player)
	# Nothing plays until the tree is active, and an inactive tree is the
	# commonest reason a correctly built one does nothing at all.
	_tree.active = true

## Does this engine's `add_blend_point()` take a name?
##
## Asked of the method list rather than of the version number: a feature check
## keeps working across the release where it was backported, and does not need
## updating when the next version arrives.
static func _add_blend_point_takes_a_name(space: AnimationNodeBlendSpace1D) -> bool:
	for method in space.get_method_list():
		if String(method["name"]) == "add_blend_point":
			return (method["args"] as Array).size() >= 4
	return false

func _process(delta: float) -> void:
	# The pawn accelerates toward the speed asked for, so the blend has
	# something real to chase rather than a step change.
	_speed = move_toward(_speed, _target_speed, 6.0 * delta)
	_pawn.position.z -= _speed * delta
	if _pawn.position.z < -12.0:
		_pawn.position.z = 12.0

	var blend := _driver.update(_speed, WALK_SPEED, RUN_SPEED, delta)
	_tree.set(BLEND_PARAM, blend)

	_status.text = "%.2f m/s   blend %.2f   %s   asked for %.1f" % [
		_speed, blend, BlendDriver.dominant_clip(blend), _target_speed]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _target_speed = maxf(_target_speed - 0.5, 0.0)
		KEY_2: _target_speed = minf(_target_speed + 0.5, RUN_SPEED)
		KEY_3: _target_speed = 0.0
		KEY_4: _target_speed = RUN_SPEED
		_: return
