extends Node

# Drives the real Bindings from scripts/bindings.gd, including against Godot's
# real InputMap.
#
# Rebinding is where a game touches global state, and global state is where
# tests have to be careful: the actions used here are prefixed so they cannot
# collide with anything real, and they are removed again at the end.

var _pass := 0
var _fail := 0

const LEFT := &"test_move_left"
const RIGHT := &"test_move_right"
const JUMP := &"test_jump"

func _ready() -> void:
	test_defaults_are_the_starting_point()
	test_rebinding_replaces()
	test_a_conflict_is_refused()
	test_a_conflict_can_be_stolen()
	test_conflicts_compare_by_key_not_by_object()
	test_adding_a_second_binding()
	test_resetting_one_action()
	test_resetting_everything()
	test_unknown_actions_are_ignored()
	test_serialising_a_round_trip()
	test_loading_skips_what_it_cannot_read()
	test_pad_buttons_round_trip()
	test_a_second_binding_is_not_the_default()
	test_describing_events()
	test_applying_to_the_real_input_map()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	# Leave the InputMap as it was found: it is global, and a test that adds
	# actions to it and walks away has broken the next suite in the process.
	for action in [LEFT, RIGHT, JUMP]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	var summary := "[input-remapping] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

func _bindings() -> Bindings:
	return Bindings.new({
		LEFT: [_key(KEY_A)],
		RIGHT: [_key(KEY_D)],
		JUMP: [_key(KEY_SPACE)],
	})

func test_defaults_are_the_starting_point() -> void:
	print("defaults")
	var bindings := _bindings()
	expect(bindings.actions().size() == 3, "every action is known")
	expect(Bindings.describe(bindings.events_for(LEFT)[0]) == "A", "with the binding it shipped with")
	expect(bindings.is_default(LEFT), "and it counts as unchanged")

func test_rebinding_replaces() -> void:
	print("rebinding")
	var bindings := _bindings()
	expect(bindings.rebind(LEFT, _key(KEY_J)), "rebinding succeeds")
	expect(Bindings.describe(bindings.events_for(LEFT)[0]) == "J", "the new key is bound")
	expect(bindings.events_for(LEFT).size() == 1, "replacing rather than adding")
	expect(not bindings.is_default(LEFT), "and the action reads as changed")

func test_a_conflict_is_refused() -> void:
	print("conflicts")
	var bindings := _bindings()
	# The bug this prevents: binding jump to the key that already opens the map,
	# and finding out in the middle of a level.
	expect(not bindings.rebind(LEFT, _key(KEY_SPACE)), "a key another action owns is refused")
	expect(Bindings.describe(bindings.events_for(LEFT)[0]) == "A", "leaving the old binding alone")
	var taken := bindings.conflicts(_key(KEY_SPACE))
	expect(taken.size() == 1 and taken[0] == JUMP, "and the conflict names who has it")

func test_a_conflict_can_be_stolen() -> void:
	print("stealing")
	var bindings := _bindings()
	expect(bindings.rebind(LEFT, _key(KEY_SPACE), true), "stealing succeeds when asked for")
	expect(Bindings.describe(bindings.events_for(LEFT)[0]) == "Space", "the key moves")
	expect(bindings.events_for(JUMP).is_empty(),
		"and the action that had it is left unbound rather than sharing")

func test_conflicts_compare_by_key_not_by_object() -> void:
	print("comparing events")
	var bindings := _bindings()
	# Two InputEventKeys for the same key are different objects. Comparing them
	# with == finds no conflicts at all, which is a rebinding screen that
	# silently allows duplicates.
	expect(not bindings.conflicts(_key(KEY_A)).is_empty(),
		"a freshly made event still matches the one already bound")
	expect(bindings.conflicts(_key(KEY_Z)).is_empty(), "while an unused key conflicts with nothing")
	expect(bindings.conflicts(null).is_empty(), "and a null event is not a conflict")

func test_adding_a_second_binding() -> void:
	print("second binding")
	var bindings := _bindings()
	expect(bindings.add_binding(JUMP, _key(KEY_ENTER)), "an action can hold more than one event")
	expect(bindings.events_for(JUMP).size() == 2, "both are kept")
	expect(not bindings.add_binding(JUMP, _key(KEY_SPACE)),
		"adding a key the action already has changes nothing")

func test_resetting_one_action() -> void:
	print("reset")
	var bindings := _bindings()
	bindings.rebind(LEFT, _key(KEY_J))
	expect(bindings.reset(LEFT), "resetting reports success")
	expect(Bindings.describe(bindings.events_for(LEFT)[0]) == "A", "the default comes back")
	expect(bindings.is_default(LEFT), "and the action is unchanged again")

func test_resetting_everything() -> void:
	print("reset all")
	var bindings := _bindings()
	bindings.rebind(LEFT, _key(KEY_J))
	bindings.rebind(JUMP, _key(KEY_K))
	bindings.reset_all()
	expect(bindings.is_default(LEFT) and bindings.is_default(JUMP), "every action goes back")

func test_unknown_actions_are_ignored() -> void:
	print("unknown actions")
	var bindings := _bindings()
	expect(not bindings.rebind(&"not_an_action", _key(KEY_J)),
		"rebinding something that does not exist fails rather than inventing it")
	expect(not bindings.reset(&"not_an_action"), "and so does resetting it")
	expect(bindings.events_for(&"not_an_action").is_empty(), "which has no bindings to report")

func test_serialising_a_round_trip() -> void:
	print("saving")
	var bindings := _bindings()
	bindings.rebind(LEFT, _key(KEY_J))
	var data := bindings.to_dictionary()
	# Through JSON, not just through a Dictionary: the file is the point, and
	# JSON turns every number into a float on the way back.
	var text := JSON.stringify(data)
	var parsed = JSON.parse_string(text)
	expect(typeof(parsed) == TYPE_DICTIONARY, "the bindings survive being written as JSON")

	var restored := _bindings()
	expect(restored.load_from(parsed) == 3, "and all three actions come back")
	expect(Bindings.describe(restored.events_for(LEFT)[0]) == "J", "with the key that was saved")
	expect(Bindings.describe(restored.events_for(RIGHT)[0]) == "D", "and the ones that were not")

func test_loading_skips_what_it_cannot_read() -> void:
	print("old and broken files")
	var bindings := _bindings()
	var data := {
		String(LEFT): [{"type": "key", "keycode": KEY_J}],
		"an_action_that_no_longer_exists": [{"type": "key", "keycode": KEY_K}],
		String(JUMP): [{"type": "nonsense"}, "not even a dictionary"],
	}
	expect(bindings.load_from(data) == 1, "only the action that still exists is restored")
	expect(Bindings.describe(bindings.events_for(LEFT)[0]) == "J", "with its saved key")
	expect(Bindings.describe(bindings.events_for(JUMP)[0]) == "Space",
		"and an entry with nothing readable in it leaves the default alone")

func test_pad_buttons_round_trip() -> void:
	print("pad buttons")
	var button := InputEventJoypadButton.new()
	button.button_index = 3
	var data := Bindings.serialise(button)
	expect(data.get("type", "") == "button", "a pad button serialises as a button")
	var back := Bindings.deserialise(data) as InputEventJoypadButton
	expect(back != null and back.button_index == 3, "and comes back as the same button")
	# Button 0 is a real button — the face button on most pads — so a check that
	# rejects it loses the most commonly bound input there is.
	var zero := InputEventJoypadButton.new()
	zero.button_index = 0
	var zero_back := Bindings.deserialise(Bindings.serialise(zero)) as InputEventJoypadButton
	expect(zero_back != null and zero_back.button_index == 0, "including button zero")
	expect(Bindings.deserialise({"type": "button", "index": -1}) == null,
		"while a negative index is refused")

func test_a_second_binding_is_not_the_default() -> void:
	print("changed bindings")
	var bindings := _bindings()
	expect(bindings.is_default(JUMP), "an untouched action is at its default")
	bindings.add_binding(JUMP, _key(KEY_ENTER))
	# Same first event, one more of them. Comparing only the events they share
	# would call this unchanged.
	expect(not bindings.is_default(JUMP), "adding a second binding is a change")

func test_describing_events() -> void:
	print("labels")
	expect(Bindings.describe(_key(KEY_SPACE)) == "Space", "a key is named")
	var button := InputEventJoypadButton.new()
	button.button_index = 3
	expect(Bindings.describe(button) == "Button 3", "so is a pad button")
	expect(Bindings.describe(null) == "unbound", "and nothing at all reads as unbound")

func test_applying_to_the_real_input_map() -> void:
	print("the real InputMap")
	var bindings := _bindings()
	bindings.apply_to_input_map()
	expect(InputMap.has_action(LEFT), "applying creates the actions")
	expect(InputMap.action_has_event(LEFT, _key(KEY_A)), "with their bindings")

	bindings.rebind(LEFT, _key(KEY_J))
	bindings.apply_to_input_map()
	expect(InputMap.action_has_event(LEFT, _key(KEY_J)), "rebinding reaches the InputMap")
	# Adding without clearing first leaves the old key working too, so the
	# player rebinds and finds that both keys now do the thing.
	expect(not InputMap.action_has_event(LEFT, _key(KEY_A)),
		"and the key that was replaced stops working")
