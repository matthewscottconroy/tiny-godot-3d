extends Node

# Drives the real GridPlan from scripts/grid_plan.gd, then checks that the real
# scene's GridMap ended up holding what the plan asked for.
#
# mutate-driver: skip — the scene is instantiated to read a real GridMap, not to test main.gd

var _pass := 0
var _fail := 0
var _checked := false

const WALL := 1
const FLOOR := 2
const PILLAR := 3

func _ready() -> void:
	test_parsing_a_drawing()
	test_unknown_characters_are_empty()
	test_ragged_rows_are_fine()
	test_rows_run_along_z_and_columns_along_x()
	test_the_level_can_be_raised()
	test_sizing_uses_the_widest_row()
	test_centring_an_odd_room()
	test_centring_an_even_room()
	test_finding_the_cells_of_one_item()
	test_raising_a_plan()
	test_merging_plans()
	test_an_empty_drawing()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[grid-map] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const LEGEND := {"#": WALL, ".": FLOOR, "o": PILLAR}

func _drawing() -> PackedStringArray:
	return PackedStringArray([
		"###",
		"#o#",
		"# #",
	])

func test_parsing_a_drawing() -> void:
	print("parsing")
	var cells := GridPlan.parse(_drawing(), LEGEND)
	# Eight characters, one of which is a space: three walls on the top row,
	# two either side of the pillar, one pillar, two on the bottom row.
	expect(cells.size() == 8, "every drawn character becomes a cell")
	expect(cells[Vector3i(1, 0, 1)] == PILLAR, "and carries the item its symbol means")
	expect(cells[Vector3i(0, 0, 0)] == WALL, "the corner is a wall")

func test_unknown_characters_are_empty() -> void:
	print("unknown symbols")
	var cells := GridPlan.parse(_drawing(), LEGEND)
	expect(not cells.has(Vector3i(1, 0, 2)),
		"a space leaves the cell out entirely — that gap is the doorway")
	var partial := GridPlan.parse(PackedStringArray(["#?#"]), LEGEND)
	expect(partial.size() == 2, "an unlisted symbol is skipped rather than guessed at")

func test_ragged_rows_are_fine() -> void:
	print("ragged rows")
	var cells := GridPlan.parse(PackedStringArray(["####", "#", "##"]), LEGEND)
	expect(cells.size() == 7, "rows of different lengths parse to what is actually drawn")

func test_rows_run_along_z_and_columns_along_x() -> void:
	print("axes")
	# Getting this the wrong way round builds the room transposed, which looks
	# fine for a square room and is deeply confusing for any other shape.
	var cells := GridPlan.parse(PackedStringArray(["..", "o."]), LEGEND)
	expect(cells[Vector3i(0, 0, 1)] == PILLAR,
		"the second row is z = 1, not x = 1")

func test_the_level_can_be_raised() -> void:
	print("levels")
	var cells := GridPlan.parse(PackedStringArray(["o"]), LEGEND, 3)
	expect(cells.has(Vector3i(0, 3, 0)), "parsing at a level puts the cells on it")

func test_sizing_uses_the_widest_row() -> void:
	print("size")
	expect(GridPlan.size_of(PackedStringArray(["###", "#", "#####"])) == Vector2i(5, 3),
		"the width is the longest row, not the first")
	expect(GridPlan.size_of(PackedStringArray([])) == Vector2i(0, 0),
		"and nothing drawn is a size of zero")

func test_centring_an_odd_room() -> void:
	print("centring, odd")
	var lines := PackedStringArray(["###", "#o#", "###"])
	var cells := GridPlan.centred(GridPlan.parse(lines, LEGEND), GridPlan.size_of(lines))
	expect(cells[Vector3i(0, 0, 0)] == PILLAR, "an odd room has a middle cell, and it is the origin")
	expect(cells.has(Vector3i(-1, 0, -1)) and cells.has(Vector3i(1, 0, 1)),
		"with corners the same distance either side")

func test_centring_an_even_room() -> void:
	print("centring, even")
	var lines := PackedStringArray(["##", "##"])
	var cells := GridPlan.centred(GridPlan.parse(lines, LEGEND), GridPlan.size_of(lines))
	# There is no middle cell in an even room, so it lands half a cell off. That
	# is the honest answer for a grid, and the reason to know it is that the
	# alternative — rounding — silently shifts the whole level.
	expect(cells.has(Vector3i(-1, 0, -1)) and cells.has(Vector3i(0, 0, 0)),
		"an even room straddles the origin rather than being rounded onto it")
	expect(cells.size() == 4, "and keeps all its cells while doing so")

func test_finding_the_cells_of_one_item() -> void:
	print("filtering")
	var cells := GridPlan.parse(_drawing(), LEGEND)
	expect(GridPlan.cells_of(cells, PILLAR).size() == 1, "one pillar was drawn")
	expect(GridPlan.cells_of(cells, WALL).size() == 7, "and seven walls")
	expect(GridPlan.cells_of(cells, 99).is_empty(), "an item nothing uses finds nothing")

func test_raising_a_plan() -> void:
	print("stacking")
	var ground := GridPlan.parse(PackedStringArray(["##"]), LEGEND)
	var upper := GridPlan.raised(ground, 2)
	expect(upper.size() == ground.size(), "raising keeps every cell")
	expect(upper.has(Vector3i(0, 2, 0)), "two levels up")
	expect(not upper.has(Vector3i(0, 0, 0)), "and none left behind on the ground")

func test_merging_plans() -> void:
	print("merging")
	var a := GridPlan.parse(PackedStringArray(["##"]), LEGEND)
	var b := GridPlan.parse(PackedStringArray(["o"]), LEGEND)
	var merged := GridPlan.merged([a, b])
	expect(merged.size() == 2, "overlapping cells do not double up")
	expect(merged[Vector3i(0, 0, 0)] == PILLAR, "and the later plan wins where they overlap")

func test_an_empty_drawing() -> void:
	print("nothing drawn")
	expect(GridPlan.parse(PackedStringArray([]), LEGEND).is_empty(),
		"an empty drawing is an empty plan, not an error")
	expect(GridPlan.centred({}, Vector2i.ZERO).is_empty(), "and centring nothing stays nothing")

# --- the real GridMap ------------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real map")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var map: GridMap = scene.get_node("GridMap")

	expect(map.mesh_library != null, "the driver built a MeshLibrary at runtime")
	expect(map.mesh_library.get_item_list().size() == 3,
		"with one item per symbol in the legend")
	var used := map.get_used_cells()
	expect(used.size() > 40, "and painted the room into the map (%d cells)" % used.size())
	# A cell the drawing leaves blank has to be empty in the map too: that gap
	# is the doorway, and GridMap reports an empty cell as -1.
	expect(map.get_cell_item(Vector3i(999, 0, 999)) == GridPlan.EMPTY,
		"a cell nothing was painted into reads as empty")

	scene.queue_free()
	_report()
