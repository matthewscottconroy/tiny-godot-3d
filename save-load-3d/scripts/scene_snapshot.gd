class_name SceneSnapshot
extends RefCounted

## Saving where things are, and putting them back.
##
## The tempting version of this is `ResourceSaver.save(PackedScene)` — save the
## whole tree and load it back. It works exactly once, and then someone edits the
## level: the save file still contains the old geometry, the old scripts and the
## old node names, and it happily restores all of them over the new ones.
##
## So a save file holds **state, not scenes**: which objects existed and where
## they were, keyed by name, and nothing else. Restoring is a lookup against the
## scene that is actually loaded, and anything the file mentions that no longer
## exists is skipped rather than resurrected.
##
## The other half is the version number. It costs one line to write and is the
## only thing that lets a save file outlive the format it was written in — which
## it will, the first time anyone adds a field.

## Bump when the shape of a snapshot changes, and add a step to `migrated()`.
const VERSION := 2

## What a Vector3 looks like in JSON. Three floats in an array, not a dictionary
## of x/y/z: smaller, and it round-trips through JSON without ambiguity.
const KEY_VERSION := "version"
const KEY_NODES := "nodes"


## Capture the transforms of `nodes`, keyed by node name.
static func capture(nodes: Array[Node3D]) -> Dictionary:
	var entries := {}
	for node in nodes:
		if not is_instance_valid(node):
			continue
		entries[String(node.name)] = {
			"position": _from_vector(node.position),
			"rotation": _from_vector(node.rotation),
			"scale": _from_vector(node.scale),
		}
	return {KEY_VERSION: VERSION, KEY_NODES: entries}


## Put a snapshot back onto the scene. Returns how many nodes were restored.
##
## Anything in the file with no matching node is skipped, and any node the file
## does not mention is left where it is. Both cases are normal after a level
## edit, and neither is worth an error.
static func apply(snapshot: Dictionary, nodes: Array[Node3D]) -> int:
	var data := migrated(snapshot)
	var entries: Dictionary = data.get(KEY_NODES, {})
	var restored := 0
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var entry = entries.get(String(node.name))
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		node.position = _to_vector(entry.get("position"), node.position)
		node.rotation = _to_vector(entry.get("rotation"), node.rotation)
		node.scale = _to_vector(entry.get("scale"), node.scale)
		restored += 1
	return restored


## Bring an older snapshot up to the current version.
##
## Version 1 stored only a position, as a bare array. Rather than refuse to load
## it — which is what "unsupported save version" means to a player who has lost
## their progress — fill in the fields it never had.
static func migrated(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return snapshot
	var version := int(snapshot.get(KEY_VERSION, 1))
	if version >= VERSION:
		return snapshot

	var upgraded := {KEY_VERSION: VERSION, KEY_NODES: {}}
	var entries: Dictionary = snapshot.get(KEY_NODES, {})
	for name in entries:
		var entry = entries[name]
		if typeof(entry) == TYPE_ARRAY:
			# v1: the value was the position and nothing else.
			upgraded[KEY_NODES][name] = {
				"position": entry,
				"rotation": [0.0, 0.0, 0.0],
				"scale": [1.0, 1.0, 1.0],
			}
		elif typeof(entry) == TYPE_DICTIONARY:
			var copy: Dictionary = (entry as Dictionary).duplicate()
			copy["rotation"] = copy.get("rotation", [0.0, 0.0, 0.0])
			copy["scale"] = copy.get("scale", [1.0, 1.0, 1.0])
			upgraded[KEY_NODES][name] = copy
	return upgraded


## Write a snapshot to `user://`. Returns OK, or the error that stopped it.
static func save_to(path: String, snapshot: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	return OK


## Read a snapshot back. An unreadable or corrupt file reads as `{}`.
##
## Not an error: a missing save file is the normal state of a new game, and a
## corrupt one is something the game has to survive rather than crash on.
static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	# JSON.new().parse() rather than JSON.parse_string(): the instance form
	# returns an error code, while the static one pushes an engine error before
	# handing back null. A corrupt save file is an expected condition, and an
	# expected condition should not print like a bug.
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


## How many nodes a snapshot describes.
static func size_of(snapshot: Dictionary) -> int:
	var entries = snapshot.get(KEY_NODES, {})
	return (entries as Dictionary).size() if typeof(entries) == TYPE_DICTIONARY else 0


static func _from_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _to_vector(value, fallback: Vector3) -> Vector3:
	# JSON gives back floats, ints, nulls and anything else that was in the file.
	# A save file is data from outside the program, so nothing in it is trusted.
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		return fallback
	var out := Vector3.ZERO
	for i in 3:
		if typeof(value[i]) not in [TYPE_FLOAT, TYPE_INT]:
			return fallback
		out[i] = float(value[i])
	return out
