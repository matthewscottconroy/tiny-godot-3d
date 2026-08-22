extends Node

# Drives the real Prompts from scripts/prompts.gd with real InputEvent objects.
# No controller is required: the events a pad produces can be constructed, which
# is the only way any of this gets tested on a build machine.

var _pass := 0
var _fail := 0
var _changes := 0

func _ready() -> void:
	test_the_starting_device()
	test_a_key_is_the_keyboard()
	test_a_pad_button_is_the_pad()
	test_a_drifting_stick_says_nothing()
	test_a_pushed_stick_says_plenty()
	test_mouse_motion_says_nothing()
	test_the_change_is_announced_once()
	test_naming_the_families()
	test_face_buttons_by_family()
	test_the_nintendo_swap()
	test_prompts_come_from_the_bindings()
	test_an_action_that_does_not_exist()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[device-glyphs] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func _pad_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event

func _stick(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event

func test_the_starting_device() -> void:
	print("the start")
	var prompts := Prompts.new()
	# Not "whatever is plugged in": almost everyone has a controller connected,
	# and showing them gamepad glyphs while they type is the bug this avoids.
	expect(prompts.device() == Prompts.Device.KEYBOARD,
		"prompts start on keyboard, whatever is connected")

func test_a_key_is_the_keyboard() -> void:
	print("keys")
	var prompts := Prompts.new()
	prompts.note(_pad_button())
	expect(prompts.device() != Prompts.Device.KEYBOARD, "a pad button switched away from the keyboard")
	expect(prompts.note(_key_event(KEY_E)), "and a keypress switches straight back")
	expect(prompts.device() == Prompts.Device.KEYBOARD, "to the keyboard")

func test_a_pad_button_is_the_pad() -> void:
	print("pad buttons")
	var prompts := Prompts.new()
	expect(prompts.note(_pad_button()), "a pad button is a device change")
	expect(prompts.device() != Prompts.Device.KEYBOARD, "away from the keyboard")

func test_a_drifting_stick_says_nothing() -> void:
	print("stick drift")
	var prompts := Prompts.new()
	# A controller sitting on a table still reports its sticks. Treating that as
	# input flips the prompts back and forth on their own.
	expect(not prompts.note(_stick(0.2)), "a stick inside the deadzone is not a device change")
	expect(prompts.device() == Prompts.Device.KEYBOARD, "so the prompts stay where they were")
	expect(Prompts.device_for(_stick(0.2)) == null, "the event simply says nothing")

func test_a_pushed_stick_says_plenty() -> void:
	print("stick input")
	var prompts := Prompts.new()
	expect(prompts.note(_stick(0.9)), "a stick pushed past the deadzone is a device change")
	expect(Prompts.device_for(_stick(-0.9)) != null, "in either direction")
	expect(Prompts.device_for(_stick(0.9), 0.95) == null,
		"and the deadzone is a parameter, because sticks differ")

func test_mouse_motion_says_nothing() -> void:
	print("mouse motion")
	var prompts := Prompts.new()
	prompts.note(_pad_button())
	var before := prompts.device()
	# A mouse nudged by a passing cat is not the player putting the pad down.
	expect(not prompts.note(InputEventMouseMotion.new()), "mouse motion alone is not a device change")
	expect(prompts.device() == before, "so a controller player keeps their prompts")
	var click := InputEventMouseButton.new()
	click.pressed = true
	expect(prompts.note(click), "but a click is")

func test_the_change_is_announced_once() -> void:
	print("the signal")
	var prompts := Prompts.new()
	_changes = 0
	prompts.device_changed.connect(_on_device_changed)
	prompts.note(_pad_button())
	prompts.note(_pad_button())
	prompts.note(_pad_button())
	# Rebuilding every label on every event is how a prompt system becomes a
	# frame-rate problem. One signal, on the transition only.
	expect(_changes == 1, "three pad events in a row are one device change")
	prompts.note(_key_event(KEY_E))
	expect(_changes == 2, "and switching back is the second")

func _on_device_changed(_device: Prompts.Device) -> void:
	_changes += 1

func test_naming_the_families() -> void:
	print("families")
	expect(Prompts.family_of("Xbox Series Controller") == Prompts.Device.XBOX, "an Xbox pad")
	expect(Prompts.family_of("Sony DualSense") == Prompts.Device.PLAYSTATION, "a PlayStation pad")
	expect(Prompts.family_of("Nintendo Switch Pro Controller") == Prompts.Device.NINTENDO,
		"a Nintendo pad")
	expect(Prompts.family_of("Some Arcade Stick") == Prompts.Device.GENERIC_PAD,
		"and anything unrecognised gets neutral prompts rather than a guess")
	expect(Prompts.family_of("SONY PLAYSTATION(R) 5") == Prompts.Device.PLAYSTATION,
		"matching is case-insensitive, because the names are not consistent")

func test_face_buttons_by_family() -> void:
	print("face buttons")
	# JOY_BUTTON_A is positional: it is the bottom button, whatever it says on it.
	expect(Prompts.face_label(JOY_BUTTON_A, Prompts.Device.XBOX) == "A", "bottom button on Xbox is A")
	expect(Prompts.face_label(JOY_BUTTON_A, Prompts.Device.PLAYSTATION) == "✕",
		"on PlayStation it is cross")
	expect(Prompts.face_label(JOY_BUTTON_Y, Prompts.Device.PLAYSTATION) == "△",
		"and the top one is triangle")
	expect(Prompts.face_label(JOY_BUTTON_A, Prompts.Device.GENERIC_PAD) == "A",
		"an unknown pad borrows the most common names")

func test_the_nintendo_swap() -> void:
	print("the swap")
	# The one that catches everybody: Nintendo's A and B are the other way round
	# compared to everyone else, so the *bottom* button is B.
	expect(Prompts.face_label(JOY_BUTTON_A, Prompts.Device.NINTENDO) == "B",
		"the bottom button on a Nintendo pad is B, not A")
	expect(Prompts.face_label(JOY_BUTTON_B, Prompts.Device.NINTENDO) == "A",
		"and the right-hand one is A")
	expect(Prompts.swaps_face_buttons(Prompts.Device.NINTENDO), "which is worth asking about directly")
	expect(not Prompts.swaps_face_buttons(Prompts.Device.XBOX), "and nobody else does it")

func test_prompts_come_from_the_bindings() -> void:
	print("prompts from bindings")
	# Keyboard prompts read the action's own events, so a remapped key changes
	# the prompt with no extra work — see input-remapping for the other half.
	expect(Prompts.prompt_for(&"jump", Prompts.Device.KEYBOARD) == "Space",
		"jump is bound to Space, and that is what the prompt says")
	expect(Prompts.prompt_for(&"interact", Prompts.Device.KEYBOARD) == "E",
		"and interact to E")
	expect(Prompts.prompt_for(&"jump", Prompts.Device.XBOX) == "A",
		"on an Xbox pad the same action is A")
	expect(Prompts.prompt_for(&"jump", Prompts.Device.NINTENDO) == "B",
		"and on a Nintendo pad it is B — the same physical button, a different name")
	expect(Prompts.prompt_for(&"back", Prompts.Device.PLAYSTATION) == "○",
		"and back, on the right-hand button, is circle on PlayStation")

func test_an_action_that_does_not_exist() -> void:
	print("missing actions")
	expect(Prompts.prompt_for(&"no_such_action", Prompts.Device.XBOX) == "—",
		"an action nobody defined shows a dash rather than crashing the menu")
