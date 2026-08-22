extends Node3D

# Demo driver. Watches every input event, asks Prompts which device it came
# from, and rebuilds the on-screen prompts only when the answer changes.

@onready var _player: MeshInstance3D = $Player
@onready var _hint: Label = $HUD/TitleLabel
@onready var _device_label: Label = $HUD/DeviceLabel
@onready var _prompts_label: Label = $HUD/PromptLabel
@onready var _status: Label = $HUD/StatusLabel

const ACTIONS: Array[StringName] = [&"jump", &"interact", &"back"]

var _prompts := Prompts.new()
var _rebuilds := 0
var _forced := -1

func _ready() -> void:
	_hint.text = "Move with the arrows or a stick   1-5 pretend to be another device   R reset"
	# One signal, so nothing has to poll for a device change or rebuild labels
	# every frame just in case.
	_prompts.device_changed.connect(_on_device_changed)
	_rebuild()

func _on_device_changed(_device: Prompts.Device) -> void:
	_forced = -1
	_rebuild()

func _rebuild() -> void:
	_rebuilds += 1
	var device: Prompts.Device = _prompts.device() if _forced < 0 \
		else _forced as Prompts.Device
	_device_label.text = "Playing on: %s%s" % [
		Prompts.device_name(device), "   (pretended)" if _forced >= 0 else ""]
	var lines: Array[String] = []
	for action in ACTIONS:
		lines.append("%-12s %s" % [action, Prompts.prompt_for(action, device)])
	lines.append("")
	lines.append("bottom face button: %s   right face button: %s%s" % [
		Prompts.face_label(JOY_BUTTON_A, device),
		Prompts.face_label(JOY_BUTTON_B, device),
		"   ← swapped, as Nintendo has them" if Prompts.swaps_face_buttons(device) else ""])
	_prompts_label.text = "\n".join(lines)
	_status.text = "prompts rebuilt %d times — only when the device changed" % _rebuilds

func _input(event: InputEvent) -> void:
	# Every event, including the ones that say nothing. Prompts decides which
	# ones count, so this stays one line.
	_prompts.note(event)

func _process(delta: float) -> void:
	var move := Input.get_axis(&"ui_left", &"ui_right")
	_player.position.x = clampf(_player.position.x + move * 4.0 * delta, -6.0, 6.0)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	# There is no way to test PlayStation prompts without a PlayStation pad, so
	# the demo can pretend. Every shipped game needs this switch somewhere.
	match key.keycode:
		KEY_1: _forced = Prompts.Device.KEYBOARD
		KEY_2: _forced = Prompts.Device.XBOX
		KEY_3: _forced = Prompts.Device.PLAYSTATION
		KEY_4: _forced = Prompts.Device.NINTENDO
		KEY_5: _forced = Prompts.Device.GENERIC_PAD
		KEY_R: _forced = -1
		_: return
	_rebuild()
