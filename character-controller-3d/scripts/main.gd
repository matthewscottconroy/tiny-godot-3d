extends Node3D

@onready var _player: CharacterBody3D = $Player
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/HintLabel

func _ready() -> void:
	_hint.text = "Arrow keys move   Shift to run   Space to jump (with coyote time)"

func _process(_delta: float) -> void:
	var motor: CharacterMotor = _player.motor()
	_status.text = "speed %.2f    vertical %.2f    on floor %s    jump allowed %s" % [
		motor.horizontal_speed(), motor.velocity.y,
		"yes" if _player.is_on_floor() else "no",
		"yes" if motor.can_jump(_player.is_on_floor()) else "no"]
