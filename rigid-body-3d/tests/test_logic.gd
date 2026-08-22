extends Node

# Drives the real DropStack from scripts/drop_stack.gd.
#
# The physics is the engine's and is not re-tested here. What is tested is the
# arithmetic the demo owns: where the stack starts, and how much of a blast each
# body receives — the numbers that stay plausible-looking while being wrong.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_pyramid_shape()
	test_pyramid_is_centred()
	test_pyramid_rows_climb()
	test_degenerate_pyramids()
	test_blast_is_strongest_at_the_centre()
	test_blast_stops_at_the_radius()
	test_falloff_is_linear()
	test_blast_pushes_away_from_the_centre()
	test_a_body_on_the_blast_goes_up()
	test_lift_adds_height_without_changing_reach()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[rigid-body-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_pyramid_shape() -> void:
	print("the stack")
	var stack := DropStack.pyramid(4, 1.0, 0.5)
	expect(stack.size() == 10, "4 rows is 4 + 3 + 2 + 1 = 10 boxes")
	expect(DropStack.pyramid(1, 1.0, 0.0).size() == 1, "one row is one box")

func test_pyramid_is_centred() -> void:
	print("centring")
	var stack := DropStack.pyramid(3, 2.0, 0.0)
	# Bottom row of three at spacing 2 runs -2, 0, +2.
	expect(is_equal_approx(stack[0].x, -2.0), "the bottom row starts one span left of centre")
	expect(is_equal_approx(stack[1].x, 0.0), "with the middle box on the axis")
	expect(is_equal_approx(stack[2].x, 2.0), "and the last one span right")
	# The row above has two boxes, so it straddles the axis instead.
	expect(is_equal_approx(stack[3].x, -1.0) and is_equal_approx(stack[4].x, 1.0),
		"a row of two straddles the axis rather than starting on it")
	var sum := 0.0
	for position in stack:
		sum += position.x
	expect(is_zero_approx(sum), "so the whole stack balances on x = 0")

func test_pyramid_rows_climb() -> void:
	print("rows")
	var stack := DropStack.pyramid(3, 2.0, 0.5)
	expect(is_equal_approx(stack[0].y, 0.5), "the base row sits at base_y")
	expect(is_equal_approx(stack[3].y, 2.5), "the next row one spacing above it")
	expect(is_equal_approx(stack[5].y, 4.5), "and the top row two")
	var flat := true
	for position in stack:
		if not is_zero_approx(position.z):
			flat = false
	expect(flat, "the stack is one slab deep, so nothing is hidden behind anything")

func test_degenerate_pyramids() -> void:
	print("degenerate input")
	expect(DropStack.pyramid(0, 1.0, 0.0).is_empty(), "zero rows is no boxes, not an error")
	expect(DropStack.pyramid(-3, 1.0, 0.0).is_empty(), "and neither is a negative count")

func test_blast_is_strongest_at_the_centre() -> void:
	print("blast strength")
	var centre := Vector3(1.0, 0.0, -2.0)
	var close := DropStack.impulse_at(centre, centre + Vector3(0.01, 0, 0), 10.0, 5.0)
	var far := DropStack.impulse_at(centre, centre + Vector3(4.0, 0, 0), 10.0, 5.0)
	expect(close.length() > far.length(), "a body nearer the blast is hit harder")
	expect(close.length() > 9.9, "one at the centre takes nearly the full strength")

func test_blast_stops_at_the_radius() -> void:
	print("reach")
	var origin := Vector3.ZERO
	expect(DropStack.impulse_at(origin, Vector3(5.0, 0, 0), 10.0, 5.0) == Vector3.ZERO,
		"a body exactly at the radius is not touched")
	expect(DropStack.impulse_at(origin, Vector3(50.0, 0, 0), 10.0, 5.0) == Vector3.ZERO,
		"nor is one well outside it")
	expect(DropStack.impulse_at(origin, Vector3(1.0, 0, 0), 10.0, 0.0) == Vector3.ZERO,
		"and a blast with no radius does nothing rather than dividing by zero")

func test_falloff_is_linear() -> void:
	print("falloff")
	var origin := Vector3.ZERO
	var half := DropStack.impulse_at(origin, Vector3(0, 0, 2.0), 8.0, 4.0)
	var quarter := DropStack.impulse_at(origin, Vector3(0, 0, 3.0), 8.0, 4.0)
	expect(is_equal_approx(half.length(), 4.0), "halfway out is half strength")
	expect(is_equal_approx(quarter.length(), 2.0), "three quarters out is a quarter")

func test_blast_pushes_away_from_the_centre() -> void:
	print("direction")
	var centre := Vector3(0, 1.0, 0)
	var right := DropStack.impulse_at(centre, centre + Vector3(2.0, 0, 0), 10.0, 5.0)
	var left := DropStack.impulse_at(centre, centre + Vector3(-2.0, 0, 0), 10.0, 5.0)
	expect(right.x > 0.0, "a body to the right is pushed right")
	expect(left.x < 0.0, "and one to the left, left")
	expect(is_equal_approx(right.length(), left.length()),
		"mirrored positions take mirrored impulses")

func test_a_body_on_the_blast_goes_up() -> void:
	print("zero distance")
	var centre := Vector3(3.0, 2.0, 1.0)
	var impulse := DropStack.impulse_at(centre, centre, 6.0, 4.0)
	expect(is_equal_approx(impulse.y, 6.0), "a body exactly on the blast is thrown straight up")
	expect(not is_nan(impulse.x), "rather than normalising a zero vector into NaN")

func test_lift_adds_height_without_changing_reach() -> void:
	print("lift")
	var origin := Vector3.ZERO
	var at := Vector3(2.0, 0, 0)
	var flat := DropStack.impulse_at(origin, at, 10.0, 5.0)
	var lifted := DropStack.impulse_with_lift(origin, at, 10.0, 5.0, 0.5)
	expect(is_equal_approx(lifted.x, flat.x), "lift leaves the sideways push alone")
	expect(is_equal_approx(lifted.y, flat.length() * 0.5), "and adds half its size upward")
	expect(DropStack.impulse_with_lift(origin, Vector3(9, 0, 0), 10.0, 5.0, 0.5) == Vector3.ZERO,
		"a body out of range is still untouched, lift or no lift")
