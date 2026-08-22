extends Node

# Drives the real ShadowBudget from scripts/shadow_budget.gd.
#
# Shadows are the most expensive thing in a 3D scene and the hardest to reason
# about by looking: the picture is correct whether four lights cast or one does.
# What is checkable is the policy — who casts, how many, and whether the answer
# stays still when the camera barely moves.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_ranking_by_distance()
	test_ranking_is_stable_for_ties()
	test_ranking_an_empty_scene()
	test_the_budget_is_respected()
	test_the_nearest_lights_win()
	test_a_budget_of_zero_casts_nothing()
	test_distant_lights_never_cast()
	test_a_budget_larger_than_the_scene()
	test_sticky_slots_survive_a_small_move()
	test_a_clearly_nearer_light_takes_the_slot()
	test_sticky_slots_release_a_light_that_left_range()
	test_resetting_forgets_the_incumbents()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[lights-and-shadows] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _row(xs: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in xs:
		out.append(Vector3(float(x), 0.0, 0.0))
	return out

func _count(flags: Array[bool]) -> int:
	var n := 0
	for flag in flags:
		if flag:
			n += 1
	return n

# --- ranking ---------------------------------------------------------------

func test_ranking_by_distance() -> void:
	print("ranking")
	var lights := _row([10, 2, 6])
	var near_first: Array[int] = [1, 2, 0]
	var far_first: Array[int] = [0, 2, 1]
	expect(ShadowBudget.ranked(lights, Vector3.ZERO) == near_first,
		"nearest first, whatever order they were declared in")
	expect(ShadowBudget.ranked(lights, Vector3(20, 0, 0)) == far_first,
		"and the order follows the viewer")

func test_ranking_is_stable_for_ties() -> void:
	print("ties")
	# Two lamps either side of the camera at the same distance. Whichever wins,
	# it has to keep winning: an unstable sort here is a shadow that flickers
	# while the player stands still.
	var lights := _row([-4, 4, -4])
	var first := ShadowBudget.ranked(lights, Vector3.ZERO)
	var second := ShadowBudget.ranked(lights, Vector3.ZERO)
	expect(first == second, "the same scene ranks the same way twice")
	expect(first[0] == 0, "and ties fall back to declaration order")

func test_ranking_an_empty_scene() -> void:
	print("no lights")
	var none: Array[Vector3] = []
	expect(ShadowBudget.ranked(none, Vector3.ZERO).is_empty(),
		"a scene with no lights ranks to nothing rather than erroring")

# --- the stateless answer --------------------------------------------------

func test_the_budget_is_respected() -> void:
	print("budget")
	var budget := ShadowBudget.new()
	var flags := budget.casters(_row([1, 2, 3, 4, 5]), Vector3.ZERO, 2)
	expect(flags.size() == 5, "every light gets an answer")
	expect(_count(flags) == 2, "and exactly the budget cast")

func test_the_nearest_lights_win() -> void:
	print("who casts")
	var budget := ShadowBudget.new()
	var flags := budget.casters(_row([12, 3, 7, 1]), Vector3.ZERO, 2)
	expect(flags[3] and flags[1], "the two nearest cast")
	expect(not flags[0] and not flags[2], "the rest do not")

func test_a_budget_of_zero_casts_nothing() -> void:
	print("zero budget")
	var budget := ShadowBudget.new()
	expect(_count(budget.casters(_row([1, 2]), Vector3.ZERO, 0)) == 0,
		"a budget of zero turns every shadow off")
	expect(_count(budget.casters(_row([1, 2]), Vector3.ZERO, -3)) == 0,
		"and so does a negative one, rather than wrapping round")

func test_distant_lights_never_cast() -> void:
	print("range")
	var budget := ShadowBudget.new()
	budget.max_distance = 10.0
	var flags := budget.casters(_row([4, 40, 60]), Vector3.ZERO, 3)
	expect(flags[0], "a light in range casts")
	expect(not flags[1] and not flags[2],
		"lights past max_distance do not, even with the budget going spare")

func test_a_budget_larger_than_the_scene() -> void:
	print("spare budget")
	var budget := ShadowBudget.new()
	expect(_count(budget.casters(_row([1, 2]), Vector3.ZERO, 9)) == 2,
		"a budget bigger than the scene lights everything and stops")

# --- the sticky answer -----------------------------------------------------

func test_sticky_slots_survive_a_small_move() -> void:
	print("stickiness")
	var budget := ShadowBudget.new()
	budget.switch_margin = 1.5
	var lights := _row([-3, 3])
	# Light 0 takes the slot from a viewer slightly to its side.
	budget.update(lights, Vector3(-0.5, 0, 0), 1)
	var only_zero: Array[int] = [0]
	expect(budget.casting() == only_zero, "the nearer light takes the only slot")
	# The camera drifts past the midpoint. Light 1 is now nearer, but only just.
	var flags := budget.update(lights, Vector3(0.5, 0, 0), 1)
	expect(flags[0] and not flags[1],
		"a rival barely nearer does not take the slot, so nothing flickers")

func test_a_clearly_nearer_light_takes_the_slot() -> void:
	print("displacement")
	var budget := ShadowBudget.new()
	budget.switch_margin = 1.5
	var lights := _row([-3, 3])
	budget.update(lights, Vector3(-0.5, 0, 0), 1)
	var flags := budget.update(lights, Vector3(2.9, 0, 0), 1)
	expect(flags[1] and not flags[0],
		"a rival well past the margin does take it — stickiness is not stuck")

func test_sticky_slots_release_a_light_that_left_range() -> void:
	print("leaving range")
	var budget := ShadowBudget.new()
	budget.max_distance = 10.0
	var lights := _row([2, 8])
	budget.update(lights, Vector3.ZERO, 1)
	var only_zero: Array[int] = [0]
	expect(budget.casting() == only_zero, "the near light holds the slot")
	# The camera walks away until light 0 is out of range but light 1 is not.
	var flags := budget.update(lights, Vector3(16, 0, 0), 1)
	expect(not flags[0], "an incumbent that leaves range gives its slot up")
	expect(flags[1], "and the slot goes to something still worth shadowing")

	# The same thing with nothing else to take the slot, so the incumbent has to
	# be dropped on its own account rather than displaced by a rival.
	var lone := ShadowBudget.new()
	lone.max_distance = 10.0
	var single := _row([2])
	lone.update(single, Vector3.ZERO, 1)
	expect(lone.casting().size() == 1, "the only light holds the only slot")
	var alone := lone.update(single, Vector3(40, 0, 0), 1)
	expect(not alone[0], "and gives it up when it goes out of range, rival or no rival")
	expect(lone.casting().is_empty(), "leaving nothing casting at all")

func test_resetting_forgets_the_incumbents() -> void:
	print("reset")
	var budget := ShadowBudget.new()
	budget.update(_row([1, 2, 3]), Vector3.ZERO, 2)
	expect(budget.casting().size() == 2, "two lights are holding slots")
	budget.reset()
	expect(budget.casting().is_empty(), "reset drops them, so a new level starts clean")
