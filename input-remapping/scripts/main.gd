extends Node3D

# Demo driver. Moves a cube with four rebindable actions, and offers a rebinding
# screen for them.

const SAVE_PATH := "user://bindings.json"
const SPEED := 4.0
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_forward", &"move_back"]

@onready var _pawn: Node3D = $Pawn
@onready var _list: Label = $HUD/BindingList
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _bindings: Bindings
var _listening := -1
var _message := "ready"

func _ready() -> void:
	_hint.text = "1-4 rebind an action   R reset   S save   L load   (defaults are WASD)"
	_bindings = Bindings.new(_defaults())
	_bindings.apply_to_input_map()
	_refresh()

## The bindings the game ships with. Physical keycodes, so the defaults land on
## the same *keys* whatever layout the player's keyboard is in.
func _defaults() -> Dictionary:
	return {
		&"move_left": [_key(KEY_A)],
		&"move_right": [_key(KEY_D)],
		&"move_forward": [_key(KEY_W)],
		&"move_back": [_key(KEY_S)],
	}

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

func _process(delta: float) -> void:
	if _listening < 0:
		var direction := Vector3(
			Input.get_axis(&"move_left", &"move_right"),
			0.0,
			Input.get_axis(&"move_forward", &"move_back"))
		if direction.length() > 0.01:
			_pawn.position += direction.normalized() * SPEED * delta
	_status.text = "%s   |   %s" % [
		("press a key for %s…" % ACTIONS[_listening]) if _listening >= 0 else _message,
		"file present" if FileAccess.file_exists(SAVE_PATH) else "no saved bindings"]

func _refresh() -> void:
	var lines := PackedStringArray()
	for action in ACTIONS:
		var events := _bindings.events_for(action)
		var text := Bindings.describe(events[0]) if not events.is_empty() else "unbound"
		lines.append("%-14s %s%s" % [action, text,
			"" if _bindings.is_default(action) else "   (changed)"])
	_list.text = "\n".join(lines)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if _listening >= 0:
		# Anything the player presses becomes the binding — including Escape, if
		# that is what they want. A rebinding screen that reserves keys for
		# itself is a rebinding screen that cannot bind them.
		var action := ACTIONS[_listening]
		var taken := _bindings.conflicts(key, action)
		if _bindings.rebind(action, key, true):
			_bindings.apply_to_input_map()
			_message = "%s bound to %s%s" % [action, Bindings.describe(key),
				"" if taken.is_empty() else "  (taken from %s)" % ", ".join(taken)]
		_listening = -1
		_refresh()
		get_viewport().set_input_as_handled()
		return

	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_listening = key.keycode - KEY_1
		KEY_R:
			_bindings.reset_all()
			_bindings.apply_to_input_map()
			_message = "back to the defaults"
			_refresh()
		KEY_S:
			var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(_bindings.to_dictionary(), "\t"))
				file.close()
				_message = "saved"
		KEY_L:
			_message = "no saved bindings to load"
			if FileAccess.file_exists(SAVE_PATH):
				var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
				var json := JSON.new()
				if file != null and json.parse(file.get_as_text()) == OK \
						and typeof(json.data) == TYPE_DICTIONARY:
					_message = "restored %d action(s)" % _bindings.load_from(json.data)
					_bindings.apply_to_input_map()
					_refresh()
				if file != null:
					file.close()
		_: return
