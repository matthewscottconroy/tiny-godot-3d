extends Node3D

# Demo driver. Builds a walk clip whose root bone actually travels, plays it
# through an AnimationTree, and moves the character by whatever the clip did.
# The arithmetic is in scripts/root_step.gd.

@onready var _walker: CharacterBody3D = $Walker
@onready var _rig: Node3D = $Walker/Rig
@onready var _root: Node3D = $Walker/Rig/Root
@onready var _player: AnimationPlayer = $Walker/Rig/Player
@onready var _tree: AnimationTree = $Walker/Rig/Tree
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

## Metres the walk clip travels, over its own length.
const STRIDE := 1.2
const CLIP_LENGTH := 1.0

var _authority := 1.0
var _wanted_speed := 1.2
var _travelled := 0.0
var _turn := 0.0

func _ready() -> void:
	_hint.text = "A/D turn   1/2 wanted speed   B blend root motion against input   R reset"
	_build_walk()
	_tree.tree_root = _walk_state_machine()
	_tree.anim_player = _tree.get_path_to(_player)
	# The path to the node the motion is baked into. Without it the tree has no
	# idea which track is root motion, and every read comes back zero.
	_tree.root_motion_track = ^"Root"
	# Stepped with physics, because that is where the character is moved. A tree
	# processed on idle frames hands its motion to a body that moves on physics
	# ones, and the two disagree by however far apart they happen to be.
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_tree.active = true

## The clip: a root that travels forward while the body bobs. In a real project
## this comes out of the animation package, with the same track on the root bone.
func _build_walk() -> void:
	var animation := Animation.new()
	animation.length = CLIP_LENGTH
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, "Root")
	# Straight down -Z over the length of the clip: this *is* the stride.
	animation.position_track_insert_key(track, 0.0, Vector3.ZERO)
	animation.position_track_insert_key(track, CLIP_LENGTH, Vector3(0, 0, -STRIDE))
	var library := AnimationLibrary.new()
	library.add_animation(&"walk", animation)
	_player.add_animation_library(&"", library)

func _walk_state_machine() -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = &"walk"
	return node

func _physics_process(delta: float) -> void:
	_turn += Input.get_axis(&"ui_right", &"ui_left") * 2.0 * delta
	_walker.rotation.y = _turn

	# Consumed exactly once per frame. Read it twice and the second reader gets
	# nothing, because the tree hands over the accumulated motion and resets.
	var step := _tree.get_root_motion_position()
	var from_clip := RootStep.velocity_for(step, _walker.global_transform.basis, delta)
	var from_input := _walker.global_transform.basis * Vector3(0, 0, -_wanted_speed)

	var velocity := RootStep.blend(from_clip, from_input, _authority)
	_walker.velocity = Vector3(velocity.x, 0.0, velocity.z)
	var before := _walker.global_position
	_walker.move_and_slide()
	_travelled += before.distance_to(_walker.global_position)

	# The root node is reset every frame: its travel has been handed to the
	# character, so leaving it where the clip put it would move the walker twice.
	_root.position = Vector3.ZERO
	_show(step, delta)

func _show(step: Vector3, delta: float) -> void:
	var speed := RootStep.clip_speed(step, delta)
	_readout.text = "the clip is asking for %.2f m/s   you asked for %.2f m/s\nplay it at %.2fx and the feet match\nauthority %.0f%% — %s" % [
		speed, _wanted_speed, RootStep.playback_scale(speed, _wanted_speed),
		_authority * 100.0,
		"all motion comes from the animation" if _authority >= 0.999
		else ("all motion comes from the code" if _authority <= 0.001
		else "steering a clip that mostly owns the movement")]
	_status.text = "travelled %.1f m   clip %s   step this frame %.4f m" % [
		_travelled, "moving" if RootStep.is_moving(step) else "still", step.length()]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_wanted_speed = maxf(_wanted_speed - 0.2, 0.2)
		KEY_2:
			_wanted_speed = minf(_wanted_speed + 0.2, 4.0)
		KEY_B:
			_authority = 0.0 if _authority >= 0.999 else 1.0
		KEY_R:
			_walker.global_position = Vector3(0, 0.9, 0)
			_turn = 0.0
			_travelled = 0.0
		_:
			return
