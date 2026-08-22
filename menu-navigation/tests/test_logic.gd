extends Node

# Drives the real FocusRing from scripts/focus_ring.gd, and then works the real
# menu with nothing but directional input — which is the only way to find out
# whether a menu can be used without a mouse.

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

## A ragged two-column menu, as pixel rects. Not a neat grid, because a neat grid
## makes every layout question look easy.
var _menu: Array[Rect2] = [
	Rect2(0, 0, 200, 36),        # 0 Resume
	Rect2(0, 44, 200, 36),       # 1 Load
	Rect2(0, 88, 200, 36),       # 2 Save
	Rect2(0, 150, 200, 36),      # 3 Options
	Rect2(0, 194, 200, 36),      # 4 Quit
	Rect2(240, 20, 200, 36),     # 5 Audio
	Rect2(240, 64, 200, 36),     # 6 Video
	Rect2(240, 108, 200, 36),    # 7 Controls
	Rect2(240, 170, 200, 36),    # 8 Credits
]

func _ready() -> void:
	test_moving_down_a_column()
	test_moving_up_again()
	test_direction_beats_distance()
	test_crossing_to_the_other_column()
	test_wrapping_off_the_end()
	test_not_wrapping_when_told_not_to()
	test_the_first_focus()
	test_a_focus_index_that_is_not_there()
	test_first_focus_does_not_just_mean_index_zero()
	test_wrapping_away_from_the_origin()
	test_an_empty_menu()
	test_focus_after_the_control_disappears()
	test_the_lost_item_is_never_the_answer()
	test_a_menu_with_nothing_usable_left()
	test_directions_from_input()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[menu-navigation] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_moving_down_a_column() -> void:
	print("down")
	var ring := FocusRing.new()
	expect(ring.next_in_direction(_menu, 0, Vector2.DOWN) == 1, "Resume goes down to Load")
	expect(ring.next_in_direction(_menu, 1, Vector2.DOWN) == 2, "and Load to Save")
	# Across the gap in the column: a spacer is not a reason to stop.
	expect(ring.next_in_direction(_menu, 2, Vector2.DOWN) == 3, "and Save over the gap to Options")

func test_moving_up_again() -> void:
	print("up")
	var ring := FocusRing.new()
	expect(ring.next_in_direction(_menu, 3, Vector2.UP) == 2, "Options goes back up to Save")
	expect(ring.next_in_direction(_menu, 4, Vector2.UP) == 3, "and Quit to Options")

func test_direction_beats_distance() -> void:
	print("direction first")
	var ring := FocusRing.new()
	# Audio (5) is 240 pixels right and 20 down from Resume (0). Load (1) is 44
	# straight down. Pressing down must not pick the one that is merely near.
	expect(_menu[5].get_center().distance_to(_menu[0].get_center())
		> _menu[1].get_center().distance_to(_menu[0].get_center()),
		"Load is nearer to Resume than Audio is")
	expect(ring.next_in_direction(_menu, 0, Vector2.DOWN) == 1,
		"and pressing down picks it, because direction filters before distance chooses")
	expect(ring.next_in_direction(_menu, 0, Vector2.RIGHT) == 5,
		"while pressing right picks Audio")

func test_crossing_to_the_other_column() -> void:
	print("across")
	var ring := FocusRing.new()
	expect(ring.next_in_direction(_menu, 1, Vector2.RIGHT) == 6,
		"from Load, right lands on the item beside it rather than the top of the column")
	expect(ring.next_in_direction(_menu, 6, Vector2.LEFT) == 1, "and left comes back")

func test_wrapping_off_the_end() -> void:
	print("wrapping")
	var ring := FocusRing.new()
	# Off the bottom of the left column, back to its top. A menu that stops dead
	# at the last item is one where the player holds the stick and nothing moves.
	expect(ring.next_in_direction(_menu, 4, Vector2.DOWN) == 0,
		"past Quit, down wraps to the furthest thing back up")
	expect(ring.next_in_direction(_menu, 0, Vector2.UP) == 4, "and up from the top wraps to Quit")

func test_not_wrapping_when_told_not_to() -> void:
	print("no wrapping")
	var ring := FocusRing.new()
	ring.wrap = false
	expect(ring.next_in_direction(_menu, 4, Vector2.DOWN) == -1,
		"with wrapping off, the end of the column reports nothing rather than jumping")

func test_the_first_focus() -> void:
	print("opening the menu")
	# A gamepad has no pointer. A menu that opens with nothing focused does
	# nothing at all when the player pushes the stick, and looks frozen.
	expect(FocusRing.first(_menu) == 0, "opening the menu focuses the topmost item")
	expect(FocusRing.first(_menu, Vector2.RIGHT) == 0,
		"and coming in from the right starts at the leftmost")
	expect(FocusRing.first(_menu, Vector2.ZERO) >= 0,
		"a direction of nothing still focuses something")

func test_a_focus_index_that_is_not_there() -> void:
	print("out of range")
	var ring := FocusRing.new()
	# A menu rebuilt behind focus's back leaves an index pointing past the end.
	# Both ends of that have to be caught, not just the negative one.
	expect(ring.next_in_direction(_menu, 99, Vector2.DOWN) >= 0,
		"an index past the end falls back to a first focus rather than reading past the array")
	expect(ring.next_in_direction(_menu, -1, Vector2.DOWN) >= 0, "and so does a negative one")

func test_first_focus_does_not_just_mean_index_zero() -> void:
	print("first, properly")
	# Written bottom-first, so "the topmost item" and "the first in the array"
	# are different answers.
	var upside_down: Array[Rect2] = [
		Rect2(0, 200, 100, 30), Rect2(0, 100, 100, 30), Rect2(0, 0, 100, 30)]
	expect(FocusRing.first(upside_down) == 2,
		"the topmost item is focused, whatever order the array happens to be in")
	expect(FocusRing.first(upside_down, Vector2.UP) == 0,
		"and coming up from below, the bottom one")

func test_wrapping_away_from_the_origin() -> void:
	print("wrapping, off the origin")
	var ring := FocusRing.new()
	# A menu nowhere near the origin. Centres and offsets are different things,
	# and a layout centred on 0,0 cannot tell them apart.
	var far: Array[Rect2] = [
		Rect2(900, 500, 100, 30), Rect2(900, 560, 100, 30), Rect2(900, 620, 100, 30)]
	expect(ring.next_in_direction(far, 2, Vector2.DOWN) == 0,
		"off the bottom, focus wraps to the top of a menu that is far from the origin")
	expect(ring.next_in_direction(far, 0, Vector2.UP) == 2, "and off the top, to the bottom")

func test_an_empty_menu() -> void:
	print("empty menus")
	var ring := FocusRing.new()
	var empty: Array[Rect2] = []
	expect(FocusRing.first(empty) == -1, "an empty menu has nothing to focus")
	expect(ring.next_in_direction(empty, 0, Vector2.DOWN) == -1, "and nowhere to move")
	expect(ring.next_in_direction(_menu, 0, Vector2.ZERO) == -1,
		"and a direction of nothing is not a move")

func test_focus_after_the_control_disappears() -> void:
	print("losing focus")
	# Hide or disable the focused control and the menu goes dead, silently. This
	# is the case nobody tests, because with a mouse it never comes up.
	var usable: Array[bool] = [true, true, true, true, true, true, true, true, true]
	usable[2] = false
	expect(FocusRing.after_losing(_menu, 2, usable) == 3, "focus falls to the next usable item")
	usable[3] = false
	usable[4] = false
	usable[5] = false
	usable[6] = false
	usable[7] = false
	usable[8] = false
	expect(FocusRing.after_losing(_menu, 2, usable) == 1,
		"and when there is nothing below, back up to the one above")

func test_the_lost_item_is_never_the_answer() -> void:
	print("not back to itself")
	# A control can be un-focusable without the flags saying so — hidden, moved
	# off screen, covered by a dialogue. Focus must not land back on it whatever
	# the array claims.
	var three: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(0, 20, 10, 10), Rect2(0, 40, 10, 10)]
	var only_the_lost_one: Array[bool] = [false, false, true]
	expect(FocusRing.after_losing(three, 2, only_the_lost_one) == -1,
		"with nothing else usable, focus goes nowhere rather than back where it was")

func test_a_menu_with_nothing_usable_left() -> void:
	print("nothing left")
	var none: Array[bool] = [false, false, false]
	var three: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(0, 20, 10, 10), Rect2(0, 40, 10, 10)]
	expect(FocusRing.after_losing(three, 1, none) == -1,
		"a menu with nothing usable reports it rather than focusing something dead")

func test_directions_from_input() -> void:
	print("input to direction")
	expect(FocusRing.direction_of(false, false, false, true) == Vector2.DOWN, "down is down")
	expect(FocusRing.direction_of(true, false, false, false) == Vector2.LEFT, "left is left")
	# Both at once cancel, which is what a d-pad pressed diagonally into a corner
	# actually reports.
	expect(FocusRing.direction_of(true, true, false, false) == Vector2.ZERO,
		"left and right together are no direction at all")
	expect(FocusRing.direction_of(false, false, false, false) == Vector2.ZERO, "and nothing is nothing")

# --- the real menu ---------------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			print("the real menu")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			_check_the_menu_opened()
			_walk_the_menu()
		6:
			_check_the_highlight()
			_check_the_readout()
			_check_focusing_something_that_is_not_there()
			_check_disabling_the_focused_item()
			_check_the_keys_themselves()
			_check_a_menu_with_nothing_left()
			_check_disabling()
			_report()

func _check_the_menu_opened() -> void:
	expect(_scene.get("_focused") == 0, "the menu opened with its first item focused")
	expect(_scene.get_node("HUD/Menu").get_child_count() == _menu.size(),
		"with every item built")

func _walk_the_menu() -> void:
	# Through the demo's own movement, not by setting the variable.
	_scene.call("_move", Vector2.DOWN)
	expect(_scene.get("_focused") == 1, "pressing down moves focus down")
	_scene.call("_move", Vector2.RIGHT)
	expect(_scene.get("_focused") == 6, "and right crosses to the other column")

func _check_the_highlight() -> void:
	# Which item is focused has to be *visible*. A menu that tracks focus
	# perfectly and shows it nowhere is a menu the player cannot use, and this is
	# the one assertion that fails if the highlight ends up on everything except
	# the focused item.
	var menu: Control = _scene.get_node("HUD/Menu")
	var focused: int = _scene.get("_focused")
	# Against the named colour, not merely "different from the others": a menu
	# that highlights everything *except* the focused item also passes that.
	var focus_colour: Color = _scene.get("FOCUS_COLOUR")
	expect((menu.get_child(focused) as Button).get_theme_color(&"font_color") == focus_colour,
		"the focused item is drawn in the focus colour")
	var wrongly_lit := 0
	for i in menu.get_child_count():
		if i == focused:
			continue
		if (menu.get_child(i) as Button).get_theme_color(&"font_color") == focus_colour:
			wrongly_lit += 1
	expect(wrongly_lit == 0, "and nothing else is")

func _check_the_readout() -> void:
	var status: Label = _scene.get_node("HUD/StatusLabel")
	expect(status.text.contains(_scene.get_node("HUD/Menu").get_child(6).text),
		"the readout names the item that is focused, not the first one")

func _check_focusing_something_that_is_not_there() -> void:
	var before: int = _scene.get("_focused")
	_scene.call("_focus", 99)
	expect(_scene.get("_focused") == before,
		"focusing an index past the end of the menu does nothing at all")
	_scene.call("_focus", -3)
	expect(_scene.get("_focused") == before, "and neither does a negative one")

func _check_disabling_the_focused_item() -> void:
	# Focus is on 6, not on 0 — with focus at zero, "is anything focused" and
	# "is focus past the start" are the same question.
	var before: int = _scene.get("_focused")
	expect(before > 0, "focus is somewhere other than the first item (%d)" % before)
	_scene.call("_disable_focused")
	var usable: Array = _scene.get("_usable")
	expect(not usable[before], "disabling the focused item marks it unusable")
	expect(_scene.get("_focused") != before,
		"and focus moves off it rather than sitting on something that cannot be pressed")
	var status: Label = _scene.get_node("HUD/StatusLabel")
	expect(status.text.contains("disabled: 1 of 9"),
		"with the readout counting what is disabled rather than what is not (%s)" % status.text)

func _check_the_keys_themselves() -> void:
	# Through the actual handler, with actual events. A held key repeats, and a
	# menu that acts on every repeat disables four items while the player is
	# still deciding about the first.
	var usable: Array = _scene.get("_usable")
	for i in usable.size():
		usable[i] = true
	_scene.set("_usable", usable)
	_scene.call("_focus", 3)

	var echo := InputEventKey.new()
	echo.keycode = KEY_D
	echo.pressed = true
	echo.echo = true
	_scene.call("_unhandled_key_input", echo)
	expect((_scene.get("_usable") as Array)[3], "a key repeat does nothing")

	var release := InputEventKey.new()
	release.keycode = KEY_D
	release.pressed = false
	_scene.call("_unhandled_key_input", release)
	expect((_scene.get("_usable") as Array)[3], "and neither does letting go of it")

	var press := InputEventKey.new()
	press.keycode = KEY_D
	press.pressed = true
	_scene.call("_unhandled_key_input", press)
	expect(not (_scene.get("_usable") as Array)[3], "but the press itself disables the item")

func _check_a_menu_with_nothing_left() -> void:
	# Everything disabled. Skipping past unusable items wraps, so an unbounded
	# skip goes round for ever and the game hangs with nothing printed — which
	# is exactly what a menu does while a dialogue has everything greyed out.
	var usable: Array = _scene.get("_usable")
	for i in usable.size():
		usable[i] = false
	_scene.set("_usable", usable)
	var before: int = _scene.get("_focused")
	_scene.call("_move", Vector2.DOWN)
	expect(_scene.get("_focused") == before,
		"with nothing usable, moving returns and leaves focus where it was")

	# And the restore key puts it all back.
	var press := InputEventKey.new()
	press.keycode = KEY_R
	press.pressed = true
	_scene.call("_unhandled_key_input", press)
	expect(not (_scene.get("_usable") as Array).has(false),
		"pressing R makes every item usable again")

func _check_disabling() -> void:
	# Set up explicitly rather than inheriting whatever the last check left:
	# everything usable, focus on 5, and 6 disabled directly beneath it.
	var usable: Array = _scene.get("_usable")
	for i in usable.size():
		usable[i] = true
	usable[6] = false
	_scene.set("_usable", usable)
	_scene.call("_focus", 5)
	expect(_scene.get("_focused") == 5, "focus is on the item above the disabled one")

	_scene.call("_move", Vector2.DOWN)
	expect(_scene.get("_focused") == 7,
		"moving onto a disabled item carries on past it (landed on %d)" % _scene.get("_focused"))
