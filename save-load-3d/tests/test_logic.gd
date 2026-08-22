extends Node

# Drives the real SceneSnapshot from scripts/scene_snapshot.gd, including a real
# write to and read from user://.
#
# Save code is the easiest thing in a game to write and the worst thing to get
# wrong, because the failure arrives later, on someone else's machine, holding
# the only copy of their progress. Everything here is about what happens when the
# file is not what the code expects: an older version, a missing node, a
# truncated write, a hand-edited number.

var _pass := 0
var _fail := 0

const TEST_PATH := "user://test-snapshot.json"

func _ready() -> void:
	test_capturing_transforms()
	test_a_round_trip_restores_everything()
	test_nodes_the_file_does_not_mention_are_left_alone()
	test_entries_with_no_node_are_skipped()
	test_writing_and_reading_a_real_file()
	test_a_missing_file_is_not_an_error()
	test_corrupt_json_is_survivable()
	test_a_file_that_is_not_a_snapshot()
	test_migrating_a_version_1_file()
	test_migration_leaves_current_files_alone()
	test_rubbish_values_fall_back_rather_than_crash()
	test_freed_nodes_are_skipped()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var summary := "[save-load-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

## A fresh pair of crates under a parent of their own.
##
## The parent matters: node names are unique per parent, so adding a second
## "One" beside the first would have Godot silently rename it to "One2" — and
## every assertion about a file keyed by name would then be testing the wrong
## thing.
func _crates() -> Array[Node3D]:
	var holder := Node3D.new()
	add_child(holder)
	var out: Array[Node3D] = []
	for entry in [["One", Vector3(1, 2, 3)], ["Two", Vector3(-4, 0.5, 6)]]:
		var node := Node3D.new()
		node.name = entry[0]
		node.position = entry[1]
		holder.add_child(node)
		out.append(node)
	return out

func test_capturing_transforms() -> void:
	print("capturing")
	var snapshot := SceneSnapshot.capture(_crates())
	expect(SceneSnapshot.size_of(snapshot) == 2, "every node given is captured")
	expect(int(snapshot["version"]) == SceneSnapshot.VERSION, "and stamped with the format version")
	var entry: Dictionary = snapshot["nodes"]["One"]
	expect(entry["position"] == [1.0, 2.0, 3.0], "position is stored as three plain numbers")
	expect(entry.has("rotation") and entry.has("scale"), "with rotation and scale beside it")

func test_a_round_trip_restores_everything() -> void:
	print("round trip")
	var crates := _crates()
	crates[0].rotation = Vector3(0.0, 1.25, 0.0)
	crates[0].scale = Vector3.ONE * 1.5
	var snapshot := SceneSnapshot.capture(crates)

	crates[0].position = Vector3.ZERO
	crates[0].rotation = Vector3.ZERO
	crates[0].scale = Vector3.ONE
	expect(SceneSnapshot.apply(snapshot, crates) == 2, "both nodes are restored")
	expect(crates[0].position.is_equal_approx(Vector3(1, 2, 3)), "the position comes back")
	expect(is_equal_approx(crates[0].rotation.y, 1.25), "so does the rotation")
	expect(crates[0].scale.is_equal_approx(Vector3.ONE * 1.5), "and the scale")

func test_nodes_the_file_does_not_mention_are_left_alone() -> void:
	print("partial saves")
	var crates := _crates()
	var partial: Array[Node3D] = [crates[0]]
	var snapshot := SceneSnapshot.capture(partial)
	crates[1].position = Vector3(9, 9, 9)
	expect(SceneSnapshot.apply(snapshot, crates) == 1, "only the saved node is restored")
	expect(crates[1].position.is_equal_approx(Vector3(9, 9, 9)),
		"a node the file never mentioned is left where it is")

func test_entries_with_no_node_are_skipped() -> void:
	print("deleted nodes")
	# The level was edited between saving and loading. The old file still names
	# a crate that no longer exists — which must be a shrug, not an error.
	var snapshot := {
		"version": SceneSnapshot.VERSION,
		"nodes": {
			"One": {"position": [5, 5, 5], "rotation": [0, 0, 0], "scale": [1, 1, 1]},
			"Ghost": {"position": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1]},
		},
	}
	var crates := _crates()
	expect(SceneSnapshot.apply(snapshot, crates) == 1, "the node that exists is restored")
	expect(crates[0].position.is_equal_approx(Vector3(5, 5, 5)), "with the values from the file")

func test_writing_and_reading_a_real_file() -> void:
	print("the real file")
	var crates := _crates()
	var snapshot := SceneSnapshot.capture(crates)
	expect(SceneSnapshot.save_to(TEST_PATH, snapshot) == OK, "the file writes")
	expect(FileAccess.file_exists(TEST_PATH), "and is there afterwards")

	var loaded := SceneSnapshot.load_from(TEST_PATH)
	expect(SceneSnapshot.size_of(loaded) == 2, "reading it back gives the same entry count")
	crates[0].position = Vector3.ZERO
	SceneSnapshot.apply(loaded, crates)
	# JSON round-trips doubles, so this is exact rather than approximate — but
	# the assertion is on the value, not on the text.
	expect(crates[0].position.is_equal_approx(Vector3(1, 2, 3)),
		"and the transforms survive JSON intact")

func test_a_missing_file_is_not_an_error() -> void:
	print("no save file")
	expect(SceneSnapshot.load_from("user://definitely-not-here.json").is_empty(),
		"a missing file reads as an empty snapshot — the normal state of a new game")

func test_corrupt_json_is_survivable() -> void:
	print("corrupt file")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 2, \"nodes\": {ruined")
	file.close()
	expect(SceneSnapshot.load_from(TEST_PATH).is_empty(),
		"a truncated write reads as empty rather than crashing the game")

func test_a_file_that_is_not_a_snapshot() -> void:
	print("wrong file")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	expect(SceneSnapshot.load_from(TEST_PATH).is_empty(),
		"valid JSON that is not a snapshot is refused too")

func test_migrating_a_version_1_file() -> void:
	print("migration")
	# Version 1 stored a bare position array per node and nothing else.
	var old := {"version": 1, "nodes": {"One": [7, 8, 9]}}
	var crates := _crates()
	expect(SceneSnapshot.apply(old, crates) == 1, "an old file still loads")
	expect(crates[0].position.is_equal_approx(Vector3(7, 8, 9)), "with the position it stored")
	expect(crates[0].scale.is_equal_approx(Vector3.ONE),
		"and sensible defaults for the fields it never had")
	var upgraded := SceneSnapshot.migrated(old)
	expect(int(upgraded["version"]) == SceneSnapshot.VERSION, "migration stamps the new version")

	# The other shape an old file comes in: a dictionary that simply predates a
	# field. It has to keep what it has and gain what it lacks.
	var partial := {"version": 1, "nodes": {"One": {"position": [1, 2, 3]}}}
	var filled := SceneSnapshot.migrated(partial)
	var entry: Dictionary = filled["nodes"]["One"]
	expect(entry["position"] == [1, 2, 3], "an entry keeps the fields it had")
	expect(entry.has("rotation") and entry.has("scale"), "and gains the ones it did not")
	expect(SceneSnapshot.size_of(filled) == 1, "without losing the entry itself")

func test_migration_leaves_current_files_alone() -> void:
	print("current files")
	var snapshot := SceneSnapshot.capture(_crates())
	expect(SceneSnapshot.migrated(snapshot) == snapshot,
		"a current file passes through migration untouched")
	expect(SceneSnapshot.migrated({}).is_empty(), "and an empty one stays empty")

func test_rubbish_values_fall_back_rather_than_crash() -> void:
	print("hand-edited files")
	# A save file is data from outside the program. Someone will edit it.
	var snapshot := {
		"version": SceneSnapshot.VERSION,
		"nodes": {"One": {"position": "over there", "rotation": [0, 0], "scale": null}},
	}
	var crates := _crates()
	var before := crates[0].position
	SceneSnapshot.apply(snapshot, crates)
	expect(crates[0].position.is_equal_approx(before), "a nonsense position is ignored")
	expect(crates[0].scale.is_equal_approx(Vector3.ONE), "a null scale leaves the node's own")

func test_freed_nodes_are_skipped() -> void:
	print("freed nodes")
	var crates := _crates()
	crates[1].free()
	var snapshot := SceneSnapshot.capture(crates)
	expect(SceneSnapshot.size_of(snapshot) == 1, "capturing skips a node that has been freed")
	expect(SceneSnapshot.apply(snapshot, crates) == 1, "and so does restoring")
