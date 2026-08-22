extends Node3D

# Demo driver. Builds a MeshLibrary in code, then paints the room GridPlan
# works out into a GridMap.

const CELL := 2.0
const WALL_HEIGHT := 2

# The room, drawn from above. '#' is wall, '.' is floor, 'o' is a pillar, and
# the gap in the bottom wall is a doorway — nothing more than a space.
const ROOM := [
	"#########",
	"#.......#",
	"#..o.o..#",
	"#.......#",
	"#..o.o..#",
	"#.......#",
	"#### ####",
]

@onready var _map: GridMap = $GridMap
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _floor_id := 0
var _wall_id := 0
var _pillar_id := 0
var _storeys := 2
var _show_pillars := true

func _ready() -> void:
	_hint.text = "1/2 wall height   P pillars on/off   the room is the text in main.gd"
	_map.cell_size = Vector3(CELL, CELL, CELL)
	_map.mesh_library = _build_library()
	_paint()

## A MeshLibrary made at runtime, so the demo needs no imported resource.
##
## In a real project this is usually built once in the editor from a scene of
## tile nodes; doing it in code here keeps the whole lesson in one file, and
## shows what that editor tool is actually producing.
func _build_library() -> MeshLibrary:
	var library := MeshLibrary.new()
	_floor_id = _add_item(library, "floor", _box(Vector3(CELL, 0.2, CELL)), Color(0.35, 0.4, 0.45))
	_wall_id = _add_item(library, "wall", _box(Vector3(CELL, CELL, CELL)), Color(0.6, 0.55, 0.5))
	_pillar_id = _add_item(library, "pillar", _cylinder(0.4, CELL), Color(0.8, 0.6, 0.3))
	return library

func _add_item(library: MeshLibrary, item_name: String, mesh: Mesh, colour: Color) -> int:
	var id := library.get_last_unused_item_id()
	library.create_item(id)
	library.set_item_name(id, item_name)
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.surface_set_material(0, material)
	library.set_item_mesh(id, mesh)
	# A tile's collision is part of the library, not of the GridMap: one shape
	# here gives every cell using this item a collider, for free.
	var shape := BoxShape3D.new()
	shape.size = mesh.get_aabb().size
	library.set_item_shapes(id, [shape, Transform3D()])
	return id

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh

func _paint() -> void:
	_map.clear()
	var legend := {"#": _wall_id, ".": _floor_id, "o": _pillar_id}
	if not _show_pillars:
		legend.erase("o")
	var lines := PackedStringArray(ROOM)
	var ground := GridPlan.centred(GridPlan.parse(lines, legend), GridPlan.size_of(lines))

	# Walls get stacked to the height asked for; the floor and the pillars stay
	# on the ground level, so the upper storeys are walls and nothing else.
	var plans: Array[Dictionary] = [ground]
	var walls_only := {}
	for cell in ground:
		if ground[cell] == _wall_id:
			walls_only[cell] = _wall_id
	for storey in range(1, _storeys):
		plans.append(GridPlan.raised(walls_only, storey))

	var plan := GridPlan.merged(plans)
	for cell in plan:
		_map.set_cell_item(cell, plan[cell])

	_status.text = "%d cells   %d wall, %d floor, %d pillar   walls %d high" % [
		plan.size(),
		GridPlan.cells_of(plan, _wall_id).size(),
		GridPlan.cells_of(plan, _floor_id).size(),
		GridPlan.cells_of(plan, _pillar_id).size(),
		_storeys]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _storeys = maxi(_storeys - 1, 1)
		KEY_2: _storeys = mini(_storeys + 1, 4)
		KEY_P: _show_pillars = not _show_pillars
		_: return
	_paint()
