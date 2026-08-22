extends Node3D

# Demo driver. Walks a capsule into a row of steps of increasing height,
# sweeping a shape ahead of it to decide what each one is.

const SPEED := 2.2
const CAPSULE_HEIGHT := 1.8

@onready var _body: CharacterBody3D = $Player
@onready var _probe: ShapeCast3D = $Player/Probe
@onready var _top: RayCast3D = $Player/TopProbe
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _direction := 1.0
var _last := "walking"
var _climbed := 0
var _max_step := 0.45

func _ready() -> void:
	_hint.text = "1/2 lower or raise the step limit   Space turn round   the steps get taller"

func _physics_process(delta: float) -> void:
	var forward := Vector3(0, 0, -_direction)
	_probe.target_position = Vector3(0, 0, -_direction * 0.45)
	# The cast has to be re-run after moving it, in the same frame — otherwise
	# the answer is about where the probe was last frame.
	_probe.force_shapecast_update()

	var surface := StepProbe.Surface.GROUND
	var blocked := false
	if _probe.is_colliding():
		# The forward sweep says *that* there is an obstruction. It cannot say
		# how tall one is: the contact point can be anywhere on its face. The
		# height comes from a second cast, straight down from above it.
		_top.global_position = _body.global_position + forward * 0.7 \
			+ Vector3.UP * (_max_step + 0.3)
		_top.force_raycast_update()
		var feet := _body.global_position.y - CAPSULE_HEIGHT * 0.5
		if _top.is_colliding() and StepProbe.can_step_onto(
				_top.get_collision_normal(), _top.get_collision_point().y, feet, _max_step):
			# Lift and nudge forward together: a lift alone leaves the capsule
			# inside the step's face, and the next frame shoves it back off.
			surface = StepProbe.Surface.STEP
			_body.global_position = StepProbe.step_target(_body.global_position,
				_top.get_collision_point().y + CAPSULE_HEIGHT * 0.5, forward)
			_climbed += 1
			_last = "climbed a step"
		else:
			surface = StepProbe.Surface.WALL
			blocked = true
			_last = "blocked by a wall"

	if blocked:
		_direction = -_direction     # turn round rather than grind into it
		_body.velocity = Vector3.ZERO
	else:
		_body.velocity = forward * SPEED + Vector3.DOWN * 4.0
		_body.move_and_slide()

	_status.text = "%s   step limit %.2f m   %d climbed   %s" % [
		StepProbe.name_of(surface), _max_step, _climbed, _last]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _max_step = maxf(_max_step - 0.1, 0.0)
		KEY_2: _max_step = minf(_max_step + 0.1, 1.2)
		KEY_SPACE: _direction = -_direction
