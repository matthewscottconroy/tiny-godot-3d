class_name Prompts
extends RefCounted

## Which device the player is using, and what to call its buttons.
##
## Getting this wrong is one of the most common small failures in games: the
## prompt says "Press A" while the player is on a keyboard, or says "Press E"
## after they picked up a controller ten minutes ago.
##
## Three things make it harder than it looks:
##
##   * **What matters is the last input, not what is plugged in.** Almost
##     everyone has a controller connected. Choosing prompts by
##     `Input.get_connected_joypads()` shows gamepad glyphs to someone typing.
##   * **A stick at rest is not at rest.** Analogue sticks drift, and a drifting
##     stick that counts as input flips the prompts back and forth on its own.
##   * **Face buttons are positional, and the names are not.** Godot's
##     `JOY_BUTTON_A` is *the bottom button*. That is A on Xbox, ✕ on
##     PlayStation, and **B** on Nintendo, whose A and B are swapped compared to
##     everyone else. Labelling by button index without a family gives Nintendo
##     players confidently wrong prompts.

signal device_changed(device: Device)

enum Device { KEYBOARD, XBOX, PLAYSTATION, NINTENDO, GENERIC_PAD }

## Below this, stick movement is drift rather than intent.
var deadzone := 0.5

var _device := Device.KEYBOARD


func device() -> Device:
	return _device


## Note an input event, and switch prompts if it came from somewhere new.
##
## Returns true if the device changed, so a caller can rebuild its labels only
## when it has to.
func note(event: InputEvent) -> bool:
	var seen: Variant = device_for(event, deadzone)
	if seen == null or seen == _device:
		return false
	_device = seen as Device
	device_changed.emit(_device)
	return true


## Which device an event came from, or `null` for events that say nothing.
##
## A stick inside the deadzone says nothing: it is the controller sitting on a
## table, and treating it as input is what makes prompts flicker.
static func device_for(event: InputEvent, deadzone: float = 0.5) -> Variant:
	if event is InputEventKey or event is InputEventMouseButton:
		return Device.KEYBOARD
	if event is InputEventMouseMotion:
		# Deliberately not a device change. A mouse nudged by a passing cat is
		# not the player putting the controller down.
		return null
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < deadzone:
			return null
		return family_of(Input.get_joy_name(motion.device))
	if event is InputEventJoypadButton:
		return family_of(Input.get_joy_name((event as InputEventJoypadButton).device))
	return null


## The button-naming family a controller belongs to, from its reported name.
##
## Names are inconsistent enough that this is matching on substrings, which is
## unlovely and is what everyone ends up doing.
static func family_of(joy_name: String) -> Device:
	var lower := joy_name.to_lower()
	for hint in ["nintendo", "switch", "joy-con", "joycon", "wii"]:
		if lower.contains(hint):
			return Device.NINTENDO
	for hint in ["sony", "playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense"]:
		if lower.contains(hint):
			return Device.PLAYSTATION
	for hint in ["xbox", "xinput", "microsoft"]:
		if lower.contains(hint):
			return Device.XBOX
	return Device.GENERIC_PAD


## What to call a face button on this device.
##
## `button` is a Godot `JoyButton`, which is positional: `JOY_BUTTON_A` is the
## bottom one wherever it is and whatever it is called.
static func face_label(button: int, device: Device) -> String:
	# `JOY_BUTTON_A` is zero, so the clamped button index *is* the position:
	# bottom, right, left, top, in that order.
	var index := clampi(button, JOY_BUTTON_A, JOY_BUTTON_Y)
	match device:
		Device.PLAYSTATION:
			return ["✕", "○", "□", "△"][index]
		Device.NINTENDO:
			# Bottom is B and right is A: the swap that catches everyone.
			return ["B", "A", "Y", "X"][index]
		Device.KEYBOARD:
			return ["Space", "Esc", "Q", "E"][index]
		_:
			return ["A", "B", "X", "Y"][index]


## Is this device one whose face buttons are laid out Nintendo's way?
static func swaps_face_buttons(device: Device) -> bool:
	return device == Device.NINTENDO


## The prompt to show for an action, given what is being played on.
##
## Keyboard prompts come from the action's own bindings, so remapping a key
## changes the prompt with no extra work. Pad prompts come from the family.
static func prompt_for(action: StringName, device: Device) -> String:
	if not InputMap.has_action(action):
		return "—"
	for event in InputMap.action_get_events(action):
		if device == Device.KEYBOARD:
			if event is InputEventKey:
				return OS.get_keycode_string((event as InputEventKey).physical_keycode) \
					if (event as InputEventKey).keycode == KEY_NONE \
					else OS.get_keycode_string((event as InputEventKey).keycode)
		elif event is InputEventJoypadButton:
			return face_label((event as InputEventJoypadButton).button_index, device)
	return "—"


static func device_name(device: Device) -> String:
	return ["Keyboard & mouse", "Xbox", "PlayStation", "Nintendo", "Gamepad"][device]
