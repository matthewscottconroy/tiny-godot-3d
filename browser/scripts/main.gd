extends Control

## A browser for the collection: search it, filter it by tag, and launch a demo
## in its own Godot process.
##
## Launching rather than embedding is deliberate. Every demo is a whole project
## with its own project.godot, rendering settings, autoloads and input map — loading one into this
## process would mean merging all of that, and the first things to break would be
## the input maps, which demos rebind on purpose, and the environment — two 3D
## scenes in one tree means two suns and two skies. A separate process is
## what "each folder is standalone" means in practice.

const Catalogue := preload("res://scripts/catalogue.gd")

## Where the demos are, relative to this project.
const COLLECTION := "res://.."

var _entries: Array = []
var _shown: Array = []
var _tag := ""

@onready var _search: LineEdit = $Layout/Top/Search
@onready var _tag_bar: HBoxContainer = $Layout/Tags
@onready var _list: ItemList = $Layout/Body/List
@onready var _title: Label = $Layout/Body/Detail/Title
@onready var _category: Label = $Layout/Body/Detail/Category
@onready var _description: Label = $Layout/Body/Detail/Description
@onready var _tags_label: Label = $Layout/Body/Detail/Tags
@onready var _launch: Button = $Layout/Body/Detail/Launch
@onready var _status: Label = $Layout/Status


func _ready() -> void:
	_entries = Catalogue.load_from(ProjectSettings.globalize_path(COLLECTION))
	if _entries.is_empty():
		_status.text = "No demos found. Run this from inside the collection."
		return

	_build_tag_bar()
	_search.text_changed.connect(func(_t: String) -> void: _refresh())
	_list.item_selected.connect(_on_selected)
	_launch.pressed.connect(_launch_selected)
	_refresh()
	_status.text = "%d demos. Enter launches the selected one." % _entries.size()


func _build_tag_bar() -> void:
	_add_tag_button("all", "")
	for tag in Catalogue.tags_in(_entries):
		_add_tag_button(tag, tag)


func _add_tag_button(label: String, tag: String) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.button_pressed = (tag == _tag)
	button.pressed.connect(func() -> void:
		_tag = tag
		for child in _tag_bar.get_children():
			(child as Button).button_pressed = (child == button)
		_refresh())
	_tag_bar.add_child(button)


func _refresh() -> void:
	_shown = Catalogue.filter(_entries, _search.text, _tag)
	_list.clear()
	for entry in _shown:
		_list.add_item(entry.name)
	if _shown.is_empty():
		_show_nothing()
	else:
		_list.select(0)
		_on_selected(0)


func _on_selected(index: int) -> void:
	if index < 0 or index >= _shown.size():
		return
	var entry = _shown[index]
	_title.text = entry.name
	_category.text = entry.category
	_description.text = entry.description
	_tags_label.text = ", ".join(entry.tags) if entry.tags.size() > 0 else "no tags"
	_launch.disabled = false


func _show_nothing() -> void:
	_title.text = "Nothing matches"
	_category.text = ""
	_description.text = "Try a shorter search, or the 'all' tag."
	_tags_label.text = ""
	_launch.disabled = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_launch_selected()
	elif key.keycode == KEY_ESCAPE:
		_search.text = ""
		_refresh()


func _launch_selected() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		return
	var entry = _shown[selected[0]]
	var demo_path := ProjectSettings.globalize_path(COLLECTION).path_join(entry.name)
	var executable := OS.get_executable_path()
	# --path, not a scene: the demo brings its own project settings, autoloads
	# and input map, and only a fresh process gets all three.
	var pid := OS.create_process(executable, ["--path", demo_path])
	if pid <= 0:
		_status.text = "Could not launch %s — is this running from an exported build?" % entry.name
	else:
		_status.text = "Launched %s (pid %d)." % [entry.name, pid]
