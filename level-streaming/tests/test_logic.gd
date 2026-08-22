extends Node

# Drives the real ChunkGrid from scripts/chunk_grid.gd.
#
# Streaming bugs are the ones that reproduce a hundred metres from where they
# happen: a chunk indexed wrongly leaves a hole in the world on the other side of
# the origin, and a load radius equal to the keep radius costs a loading system's
# worth of work with nothing to show for it.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_which_chunk_a_position_is_in()
	test_negative_coordinates()
	test_chunk_origins_and_centres()
	test_a_disc_is_not_a_square()
	test_a_radius_of_zero()
	test_what_to_load_from_nothing()
	test_nothing_to_do_when_it_is_all_loaded()
	test_walking_forward_loads_ahead_and_frees_behind()
	test_the_keep_radius_stops_the_thrashing()
	test_nearest_chunks_are_loaded_first()
	test_distance_in_chunks()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[level-streaming] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _grid() -> ChunkGrid:
	var grid := ChunkGrid.new()
	grid.chunk_size = 10.0
	grid.load_radius = 1
	grid.keep_radius = 2
	return grid

func test_which_chunk_a_position_is_in() -> void:
	print("chunk indices")
	expect(ChunkGrid.chunk_of(Vector3(5, 0, 5), 10.0) == Vector2i(0, 0),
		"a position inside the first chunk is chunk zero")
	expect(ChunkGrid.chunk_of(Vector3(15, 0, 25), 10.0) == Vector2i(1, 2),
		"and further out is further along")
	expect(ChunkGrid.chunk_of(Vector3(10, 0, 0), 10.0) == Vector2i(1, 0),
		"with a boundary belonging to the chunk it starts")

func test_negative_coordinates() -> void:
	print("the other side of the origin")
	# int() truncates toward zero, so -0.5 and 0.5 would both be chunk 0 and the
	# world would be mirrored about the origin. floori() is the whole fix.
	expect(ChunkGrid.chunk_of(Vector3(-5, 0, -5), 10.0) == Vector2i(-1, -1),
		"a position just west of the origin is in chunk -1, not chunk 0")
	expect(ChunkGrid.chunk_of(Vector3(-15, 0, 5), 10.0) == Vector2i(-2, 0),
		"and further out again")
	expect(ChunkGrid.chunk_of(Vector3(-0.001, 0, 0.001), 10.0) == Vector2i(-1, 0),
		"with the origin itself splitting two chunks rather than joining them")

func test_chunk_origins_and_centres() -> void:
	print("where a chunk is")
	expect(ChunkGrid.origin_of(Vector2i(2, -1), 10.0).is_equal_approx(Vector3(20, 0, -10)),
		"a chunk's origin is its corner")
	expect(ChunkGrid.centre_of(Vector2i(0, 0), 10.0).is_equal_approx(Vector3(5, 0, 5)),
		"and its centre is half a chunk in from that")
	var chunk := Vector2i(3, -4)
	expect(ChunkGrid.chunk_of(ChunkGrid.centre_of(chunk, 10.0), 10.0) == chunk,
		"so the centre of a chunk is in that chunk — which is not automatic")

func test_a_disc_is_not_a_square() -> void:
	print("disc versus square")
	var grid := _grid()
	var disc := grid.chunks_within(Vector2i.ZERO, 2)
	grid.square = true
	var square := grid.chunks_within(Vector2i.ZERO, 2)
	# A square loads the corners, which are 1.4 times further away than the
	# edges: about 40% more chunks for no more view distance.
	expect(square.size() == 25, "a square of radius two is five by five")
	expect(disc.size() < square.size(), "and a disc is fewer (%d against %d)"
		% [disc.size(), square.size()])
	expect(not disc.has(Vector2i(2, 2)), "because it leaves out the corners")
	expect(disc.has(Vector2i(2, 0)), "while keeping the edges")

func test_a_radius_of_zero() -> void:
	print("no radius")
	var grid := _grid()
	var only := grid.chunks_within(Vector2i(3, 3), 0)
	expect(only.size() == 1 and only[0] == Vector2i(3, 3),
		"a radius of zero is the chunk you are standing in, and nothing else")

func test_what_to_load_from_nothing() -> void:
	print("starting up")
	var grid := _grid()
	var empty: Array[Vector2i] = []
	var plan := grid.plan(Vector3(5, 0, 5), empty)
	expect((plan["load"] as Array).size() == grid.wanted(Vector3(5, 0, 5)).size(),
		"with nothing loaded, everything wanted is loaded")
	expect((plan["free"] as Array).is_empty(), "and nothing is freed")

func test_nothing_to_do_when_it_is_all_loaded() -> void:
	print("steady state")
	var grid := _grid()
	var loaded := grid.wanted(Vector3(5, 0, 5))
	var plan := grid.plan(Vector3(5, 0, 5), loaded)
	expect((plan["load"] as Array).is_empty(), "standing still loads nothing new")
	expect((plan["free"] as Array).is_empty(), "and frees nothing")

func test_walking_forward_loads_ahead_and_frees_behind() -> void:
	print("walking")
	var grid := _grid()
	var loaded := grid.wanted(Vector3(5, 0, 5))
	# Three chunks east: everything behind is now outside even the keep radius.
	var plan := grid.plan(Vector3(35, 0, 5), loaded)
	expect(not (plan["load"] as Array).is_empty(), "moving on loads what is ahead")
	expect(not (plan["free"] as Array).is_empty(), "and frees what is well behind")
	for chunk in plan["free"]:
		expect_quiet((chunk as Vector2i).x < 2, "%s was freed but is not behind" % chunk)
	expect(_quiet == 0, "with only the chunks behind being freed")

func test_the_keep_radius_stops_the_thrashing() -> void:
	print("no thrashing")
	var grid := _grid()
	# A player standing on a boundary, stepping back and forth across it. With
	# one radius for both jobs, each step loads and frees the same chunks — a
	# loading system's worth of work with nothing to show for it.
	var loaded := grid.wanted(Vector3(9.9, 0, 5))
	var freed := 0
	for i in 20:
		var position := Vector3(9.9 if i % 2 == 0 else 10.1, 0, 5)
		var plan := grid.plan(position, loaded)
		freed += (plan["free"] as Array).size()
		for chunk in plan["load"]:
			if not loaded.has(chunk):
				loaded.append(chunk)
		for chunk in plan["free"]:
			loaded.erase(chunk)
	expect(freed == 0, "stepping over a boundary twenty times frees nothing (%d)" % freed)

	var tight := _grid()
	tight.keep_radius = tight.load_radius
	var tight_loaded := tight.wanted(Vector3(9.9, 0, 5))
	var tight_freed := 0
	for i in 6:
		var position := Vector3(9.9 if i % 2 == 0 else 10.1, 0, 5)
		var plan := tight.plan(position, tight_loaded)
		tight_freed += (plan["free"] as Array).size()
		for chunk in plan["load"]:
			if not tight_loaded.has(chunk):
				tight_loaded.append(chunk)
		for chunk in plan["free"]:
			tight_loaded.erase(chunk)
	expect(tight_freed > 0, "while one radius for both jobs thrashes immediately (%d)"
		% tight_freed)

func test_nearest_chunks_are_loaded_first() -> void:
	print("priority")
	var grid := _grid()
	grid.load_radius = 3
	var empty: Array[Vector2i] = []
	# Deliberately away from the origin: at chunk (0, 0) every distance is
	# symmetric and an ordering bug hides.
	var where := Vector3(40, 0, 40)
	var to_load: Array = grid.plan(where, empty)["load"]
	var centre := ChunkGrid.chunk_of(where, grid.chunk_size)
	expect(to_load[0] == centre, "the chunk the player is standing in comes first")
	var ordered := true
	for i in range(1, to_load.size()):
		if ChunkGrid.distance_in_chunks(to_load[i], centre) \
				< ChunkGrid.distance_in_chunks(to_load[i - 1], centre) - 0.001:
			ordered = false
	# The chunk the player is about to walk into matters more than the one four
	# chunks away; loading in index order pops in the wrong places.
	expect(ordered, "chunks are loaded nearest first")

func test_distance_in_chunks() -> void:
	print("distance")
	expect(is_equal_approx(ChunkGrid.distance_in_chunks(Vector2i(3, 0), Vector2i(0, 0)), 3.0),
		"three chunks along is a distance of three")
	expect(is_zero_approx(ChunkGrid.distance_in_chunks(Vector2i(2, 2), Vector2i(2, 2))),
		"and a chunk is no distance from itself")

var _quiet := 0

func expect_quiet(condition: bool, label: String) -> void:
	if not condition:
		_quiet += 1
		print("  (", label, " — failed)")
