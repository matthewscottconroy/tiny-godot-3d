extends Node3D

# Demo driver. A menu laid out in two ragged columns, navigable with nothing but
# a d-pad. Focus neighbours are worked out from the layout by FocusRing rather
# than wired up by hand.

@onready var _menu: Control = $HUD/Menu
@onready var _prop: MeshInstance3D = $Prop
@onready var _hint: Label = $HUD/TitleLabel
@onready var _status: Label = $HUD/StatusLabel

const ITEMS := [
	["Resume", Vector2(0, 0)], ["Load", Vector2(0, 44)], ["Save", Vector2(0, 88)],
	["Options", Vector2(0, 150)], ["Quit", Vector2(0, 194)],
	["Audio", Vector2(240, 20)], ["Video", Vector2(240, 64)],
	["Controls", Vector2(240, 108)], ["Credits", Vector2(240, 170)],
]

## Named, because "the focused one is a different colour from the others" is true
## of a menu that highlights everything *except* the focused item.
const FOCUS_COLOUR := Color(1, 0.85, 0.35)
const REST_COLOUR := Color(0.85, 0.85, 0.85)

var _ring := FocusRing.new()
var _buttons: Array[Button] = []
var _usable: Array[bool] = []
var _focused := -1

func _ready() -> void:
	_hint.text = "Arrows or d-pad to move   Enter to press   D disable the focused item   R restore"
	_build()
	# Something has to be focused when the menu opens: a gamepad has no pointer,
	# and a menu with nothing focused looks frozen.
	_focus(FocusRing.first(_rects()))

func _build() -> void:
	for item in ITEMS:
		var button := Button.new()
		button.text = item[0]
		button.position = item[1]
		button.size = Vector2(200, 36)
		# The mouse is deliberately not part of this. Focus follows the
		# directional input, and nothing else moves it.
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu.add_child(button)
		_buttons.append(button)
		_usable.append(true)

func _rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for button in _buttons:
		out.append(Rect2(button.position, button.size))
	return out

## Move focus, if there is anything usable at that index. The one place that
## decides: a caller that has to check first is a caller that will forget to.
func _focus(index: int) -> void:
	if index < 0 or index >= _buttons.size() or not _usable[index]:
		return
	_focused = index
	for i in _buttons.size():
		var button := _buttons[i]
		button.modulate = Color(1, 1, 1) if _usable[i] else Color(0.45, 0.45, 0.45)
		button.add_theme_color_override("font_color",
			FOCUS_COLOUR if i == _focused else REST_COLOUR)
	_show()

func _show() -> void:
	var name := _buttons[_focused].text if _focused in range(_buttons.size()) else "nothing"
	_status.text = "focused: %s   disabled: %d of %d   (no mouse involved at any point)" % [
		name, _usable.count(false), _usable.size()]

func _move(direction: Vector2) -> void:
	var next := _ring.next_in_direction(_rects(), _focused, direction)
	# Skipping the disabled ones on the way past, rather than stopping on
	# something that cannot be pressed — bounded by the size of the menu,
	# because wrapping is on and a menu with everything disabled would otherwise
	# go round for ever with no error to say so.
	for _step in _buttons.size():
		if next < 0 or _usable[next]:
			break
		next = _ring.next_in_direction(_rects(), next, direction)
	_focus(next)

## Disable whatever is focused: the case that quietly kills a menu, because
## focus was on it and now there is nowhere for focus to be.
func _disable_focused() -> void:
	if _focused < 0:
		return
	_usable[_focused] = false
	_focus(FocusRing.after_losing(_rects(), _focused, _usable))

func _process(delta: float) -> void:
	_prop.rotate_y(delta * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_up"):
		_move(Vector2.UP)
	elif event.is_action_pressed(&"ui_down"):
		_move(Vector2.DOWN)
	elif event.is_action_pressed(&"ui_left"):
		_move(Vector2.LEFT)
	elif event.is_action_pressed(&"ui_right"):
		_move(Vector2.RIGHT)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_D:
			_disable_focused()
		KEY_R:
			for i in _usable.size():
				_usable[i] = true
			_focus(maxi(_focused, 0))
		_:
			return
