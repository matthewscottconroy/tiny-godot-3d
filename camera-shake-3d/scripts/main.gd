extends Node3D

# Demo driver. An orbiting rig owns the camera's transform; the shake only ever
# touches a child node, so the two never fight.

@onready var _pivot: Node3D = $Pivot
@onready var _mount: Node3D = $Pivot/Mount
@onready var _shaker: Node3D = $Pivot/Mount/Shaker
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _shake := Shake.new(7)
var _angle := 0.0
var _orbiting := true
var _rumble := false

func _ready() -> void:
	_hint.text = "1 footstep   2 hit   3 explosion   R continuous rumble   Space pause the orbit"

func _process(delta: float) -> void:
	if _orbiting:
		_angle += delta * 0.4
	# The rig writes the mount's transform every frame, exactly as an orbit
	# camera or a spring arm would.
	_pivot.rotation.y = _angle
	_mount.position = Vector3(0.0, 2.4, 8.0)
	_mount.look_at(_pivot.global_position + Vector3.UP * 1.2, Vector3.UP)

	if _rumble:
		# Topping up rather than setting: trauma accumulates to its ceiling, so
		# a continuous source never stacks into nausea.
		_shake.add(delta * 1.2)

	_shake.advance(delta)
	# The only thing the shake touches. Nothing else writes the Shaker's
	# transform, so there is nothing for it to fight with.
	_shaker.position = _shake.offset()
	_shaker.rotation = _shake.rotation_offset()

	_status.text = "trauma %.2f   shake %.2f   offset %.3f m   roll %.1f°   %s" % [
		_shake.trauma(), _shake.shake_amount(), _shake.offset().length(),
		rad_to_deg(_shake.rotation_offset().z),
		"rumbling" if _rumble else ("shaking" if _shake.is_shaking() else "still")]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _shake.add(0.2)
		KEY_2: _shake.add(0.5)
		KEY_3: _shake.add(1.0)
		KEY_R: _rumble = not _rumble
		KEY_SPACE: _orbiting = not _orbiting
		_: return
