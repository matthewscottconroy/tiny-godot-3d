extends Node3D

# Demo driver. Walks a character into crates and shoves them, with a key to turn
# the shoving off so the default behaviour is visible next to it.

const SPEED := 4.0
const GRAVITY := 18.0
const MASS := 80.0
const STRENGTH := 1.0

@onready var _body: CharacterBody3D = $Player
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _pushing := true
var _last_push := 0.0

func _ready() -> void:
	_hint.text = "Arrows walk   P pushing on/off   R put the crates back"

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_body.velocity.x = input.x * SPEED
	_body.velocity.z = input.y * SPEED
	if _body.is_on_floor():
		_body.velocity.y = 0.0
	else:
		_body.velocity.y -= GRAVITY * delta
	# The velocity we *wanted*, kept before move_and_slide() overwrites it with
	# the velocity we got. Blocked head-on by a crate, that becomes zero — and a
	# push computed from it is no push at all, which is a bug that presents as
	# "the crates only move when I hit them at an angle".
	var intended := _body.velocity
	_body.move_and_slide()

	_last_push = maxf(_last_push - delta, 0.0)
	if _pushing:
		_push_what_we_hit(intended)

	_status.text = "%s   %d contact(s)   %s" % [
		"pushing" if _pushing else "not pushing — move_and_slide only",
		_body.get_slide_collision_count(),
		"shoving" if _last_push > 0.0 else "walking"]

## Every collision move_and_slide() resolved this frame.
##
## The loop that turns a kinematic body into something the world notices.
func _push_what_we_hit(intended: Vector3) -> void:
	for i in _body.get_slide_collision_count():
		var collision := _body.get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body == null:
			continue                      # a wall or the floor: nothing to push
		var impulse := PushForce.flat_impulse_for(
			collision.get_normal(), intended, MASS, body.mass, body.linear_velocity, STRENGTH)
		if impulse == Vector3.ZERO:
			continue
		# At the contact point rather than the centre, so the crate turns as it
		# slides — most of what makes a shove look physical.
		body.apply_impulse(impulse,
			PushForce.offset_of(collision.get_position(), body.global_position, 0.4))
		_last_push = 0.2

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P: _pushing = not _pushing
		KEY_R: _reset_crates()
		_: return

func _reset_crates() -> void:
	var spots := [Vector3(-2, 0.5, -3), Vector3(0, 0.5, -4), Vector3(2, 0.5, -3)]
	var i := 0
	for child in $Crates.get_children():
		var crate := child as RigidBody3D
		crate.linear_velocity = Vector3.ZERO
		crate.angular_velocity = Vector3.ZERO
		crate.global_position = spots[i % spots.size()]
		crate.global_rotation = Vector3.ZERO
		i += 1
