extends Node3D

# Demo driver. Scatters some boxes, saves where they are, and puts them back.

const SAVE_PATH := "user://scene-snapshot.json"

@onready var _crates: Node3D = $Crates
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _rng := RandomNumberGenerator.new()
var _message := "nothing saved yet"

func _ready() -> void:
	_hint.text = "R scatter   S save   L load   D delete the save file"
	_rng.seed = 4
	_report()

func _movable() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in _crates.get_children():
		out.append(child as Node3D)
	return out

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R: _scatter()
		KEY_S: _save()
		KEY_L: _load()
		KEY_D: _delete()
		_: return
	_report()

func _scatter() -> void:
	for node in _movable():
		node.position = Vector3(
			_rng.randf_range(-6.0, 6.0), _rng.randf_range(0.5, 3.0), _rng.randf_range(-6.0, 6.0))
		node.rotation = Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)
		node.scale = Vector3.ONE * _rng.randf_range(0.6, 1.4)
	_message = "scattered"

func _save() -> void:
	var error := SceneSnapshot.save_to(SAVE_PATH, SceneSnapshot.capture(_movable()))
	_message = ("saved %d crates" % _movable().size()) if error == OK \
		else "could not save (error %d)" % error

func _load() -> void:
	var snapshot := SceneSnapshot.load_from(SAVE_PATH)
	if snapshot.is_empty():
		_message = "no save file to load"
		return
	# A file written by an older build is migrated on the way in, so an old save
	# loads rather than being refused.
	var restored := SceneSnapshot.apply(snapshot, _movable())
	_message = "restored %d of %d entries (file version %d)" % [
		restored, SceneSnapshot.size_of(snapshot), int(snapshot.get("version", 1))]

func _delete() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		_message = "save file deleted"
	else:
		_message = "there was no save file"

func _report() -> void:
	_status.text = "%s   |   %s   |   %s" % [
		_message,
		"file present" if FileAccess.file_exists(SAVE_PATH) else "no file",
		ProjectSettings.globalize_path(SAVE_PATH)]
