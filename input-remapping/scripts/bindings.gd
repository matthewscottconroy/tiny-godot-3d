class_name Bindings
extends RefCounted

## The bindings a player has chosen, separately from the `InputMap` they end up
## in.
##
# size-exempt: rebinding is defaults, conflicts, applying and persistence, and a
# version missing any one of them teaches a settings screen that loses the
# player's bindings or lets them bind two actions to one key. The parts are
# small; there are simply four of them.
##
## Godot's `InputMap` is a global singleton with no memory: it is the *current*
## state of the bindings and nothing else. It cannot tell you what the defaults
## were, it will happily let two actions share a key without mentioning it, and
## it does not persist. A rebinding screen needs all three.
##
## So this holds the bindings — defaults and current — and pushes them into the
## `InputMap` when asked. Everything a settings screen needs to ask is then a
## question about an object rather than about global state:
##
##   * What is this action bound to now?
##   * Is this key already taken, and by what?
##   * What was it before the player changed it?
##   * How do I write that to disk and read it back?

## Emitted whenever an action's bindings change.
signal changed(action: StringName)

var _defaults := {}
var _current := {}


## `defaults` maps an action name to an array of `InputEvent`s.
func _init(defaults: Dictionary = {}) -> void:
	for action in defaults:
		var events: Array[InputEvent] = []
		for event in defaults[action]:
			events.append(event)
		_defaults[StringName(action)] = events
		_current[StringName(action)] = events.duplicate()


func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for action in _current:
		out.append(action)
	out.sort()
	return out


func events_for(action: StringName) -> Array[InputEvent]:
	var events = _current.get(action, [])
	return (events as Array).duplicate()


## Which actions are already using this event?
##
## `is_match()` rather than `==`: two `InputEventKey`s for the same key are
## different objects, and comparing them by identity finds no conflicts at all —
## which is exactly the bug where a player binds jump to the key that already
## opens the map.
func conflicts(event: InputEvent, ignoring: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	if event == null:
		return out
	for action in _current:
		if action == ignoring:
			continue
		for existing in _current[action]:
			if (existing as InputEvent).is_match(event):
				out.append(action)
				break
	out.sort()
	return out


## Bind `event` to `action`, replacing whatever it had.
##
## Refuses when the event is already taken, unless `steal` is true — in which
## case it is removed from whoever had it, which is what a settings screen does
## after asking "that is already used for Jump; swap them?".
func rebind(action: StringName, event: InputEvent, steal: bool = false) -> bool:
	if not _claim(action, event, steal):
		return false
	var events: Array[InputEvent] = [event]
	_current[action] = events
	changed.emit(action)
	return true


## Add an event to an action rather than replacing what is there — a second
## binding, for a controller alongside a key.
func add_binding(action: StringName, event: InputEvent, steal: bool = false) -> bool:
	if not _claim(action, event, steal):
		return false
	if not conflicts(event, &"").is_empty():
		return false                      # already on this action; nothing to do
	(_current[action] as Array).append(event)
	changed.emit(action)
	return true


## Make `event` available to `action`, taking it from whoever holds it if asked.
## False when the binding cannot proceed at all.
func _claim(action: StringName, event: InputEvent, steal: bool) -> bool:
	if event == null or not _current.has(action):
		return false
	var taken := conflicts(event, action)
	if taken.is_empty():
		return true
	if not steal:
		return false
	for other in taken:
		_remove(other, event)
	return true


func reset(action: StringName) -> bool:
	if not _defaults.has(action):
		return false
	_current[action] = (_defaults[action] as Array).duplicate()
	changed.emit(action)
	return true


func reset_all() -> void:
	for action in _defaults:
		reset(action)


## True when this action still has the binding it shipped with.
func is_default(action: StringName) -> bool:
	var now := events_for(action)
	var was: Array = _defaults.get(action, [])
	if now.size() != was.size():
		return false
	for i in now.size():
		if not now[i].is_match(was[i]):
			return false
	return true


## Push the current bindings into Godot's global `InputMap`.
##
## Existing events for these actions are cleared first: adding without clearing
## leaves the old key working too, so the player rebinds jump and finds that both
## keys now jump.
func apply_to_input_map() -> void:
	for action in _current:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for event in _current[action]:
			InputMap.action_add_event(action, event)


## The bindings as plain data, for `JSON.stringify`.
func to_dictionary() -> Dictionary:
	var out := {}
	for action in _current:
		var events := []
		for event in _current[action]:
			var data := serialise(event)
			if not data.is_empty():
				events.append(data)
		out[String(action)] = events
	return out


## Read bindings back. Unknown actions and unreadable events are skipped rather
## than refused: a save file written by an older build should still restore the
## bindings it does understand.
func load_from(data: Dictionary) -> int:
	var restored := 0
	for name in data:
		var action := StringName(name)
		if not _current.has(action):
			continue
		var events: Array[InputEvent] = []
		for entry in data[name]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var event := deserialise(entry)
			if event != null:
				events.append(event)
		if events.is_empty():
			continue
		_current[action] = events
		changed.emit(action)
		restored += 1
	return restored


## One event as plain data. Keys and joypad buttons only — enough for a
## rebinding screen, and everything else returns nothing rather than a
## half-written entry.
static func serialise(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key != null:
		return {"type": "key", "keycode": int(key.physical_keycode if key.physical_keycode != 0
			else key.keycode)}
	var button := event as InputEventJoypadButton
	if button != null:
		return {"type": "button", "index": int(button.button_index)}
	return {}


static func deserialise(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var key := InputEventKey.new()
			# Physical keycodes, so a rebind survives the player switching
			# keyboard layout — "the key where W is" rather than "the letter W".
			key.physical_keycode = int(data.get("keycode", 0))
			return key if key.physical_keycode != 0 else null
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("index", -1))
			return button if button.button_index >= 0 else null
	return null


## Something a settings screen can print.
static func describe(event: InputEvent) -> String:
	if event == null:
		return "unbound"
	var key := event as InputEventKey
	if key != null:
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return OS.get_keycode_string(code)
	var button := event as InputEventJoypadButton
	if button != null:
		return "Button %d" % button.button_index
	return event.as_text()


func _remove(action: StringName, event: InputEvent) -> void:
	var kept: Array[InputEvent] = []
	for existing in _current[action]:
		if not (existing as InputEvent).is_match(event):
			kept.append(existing)
	_current[action] = kept
	changed.emit(action)
