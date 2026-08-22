extends Node

# Drives the real FencePlan from scripts/fence_plan.gd, then the real @tool
# script from scripts/fence_builder.gd.
#
# mutate-driver: skip — the scene is instantiated to exercise fence_builder.gd, not main.gd
#
# A tool script runs inside the editor, where a mistake corrupts the scene
# somebody is editing and a test cannot easily reach. That is the argument for
# keeping the arithmetic in a plain object — and for testing what the tool does
# to the tree, which is the other half of what can go wrong.

var _pass := 0
var _fail := 0
var _checked := false

func _ready() -> void:
	test_a_fence_reaches_both_ends()
	test_the_spacing_is_fitted_to_the_length()
	test_a_tighter_spacing_gives_more_posts()
	test_degenerate_lengths_and_spacings()
	test_rail_transforms_span_their_posts()
	test_a_rail_between_two_points_in_the_same_place()
	test_a_vertical_rail()
	test_post_yaw()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[editor-tool-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_a_fence_reaches_both_ends() -> void:
	print("both ends")
	var posts := FencePlan.post_distances(10.0, 2.0)
	expect(posts.size() == 6, "ten metres at two-metre spacing is six posts")
	expect(is_zero_approx(posts[0]), "the first is at the start")
	# A fence that stops short of its corner is a fence with a hole in it.
	expect(is_equal_approx(posts[posts.size() - 1], 10.0), "and the last is exactly at the end")

func test_the_spacing_is_fitted_to_the_length() -> void:
	print("fitting")
	# 9.4 metres at a requested 2 metres: five spans of 1.88, not four of 2 and
	# a 1.4-metre gap with a post hanging past the end.
	var spacing := FencePlan.fitted_spacing(9.4, 2.0)
	expect(absf(spacing - 1.88) < 0.001, "the spacing is adjusted so the spans divide the length")
	var posts := FencePlan.post_distances(9.4, 2.0)
	expect(is_equal_approx(posts[posts.size() - 1], 9.4), "and the last post lands on the end")
	var even := true
	for i in range(1, posts.size()):
		if absf((posts[i] - posts[i - 1]) - spacing) > 0.001:
			even = false
	expect(even, "with every span the same length")

func test_a_tighter_spacing_gives_more_posts() -> void:
	print("density")
	expect(FencePlan.post_count(10.0, 1.0) > FencePlan.post_count(10.0, 2.5),
		"asking for closer posts gets more of them")
	expect(FencePlan.post_count(10.0, 100.0) == 2,
		"and a spacing longer than the fence still gets both ends")

func test_degenerate_lengths_and_spacings() -> void:
	print("degenerate input")
	expect(FencePlan.post_distances(0.0, 2.0).size() == 1,
		"a fence of no length is one post, not an empty list")
	expect(FencePlan.post_distances(10.0, 0.0).size() > 1,
		"a spacing of zero is floored rather than dividing by zero")
	expect(is_zero_approx(FencePlan.fitted_spacing(0.0, 2.0)),
		"and a zero-length fence has no spacing to report")

func test_rail_transforms_span_their_posts() -> void:
	print("rails")
	var from := Vector3(0, 1, 0)
	var to := Vector3(4, 1, 0)
	var transform := FencePlan.rail_transform(from, to)
	expect(transform.origin.is_equal_approx(Vector3(2, 1, 0)), "a rail sits at the midpoint")
	# Scaled on Z, so one unit-long mesh serves every rail whatever the curve
	# does between the posts.
	expect(absf(transform.basis.get_scale().z - 4.0) < 0.001,
		"and is scaled to the distance between the posts")
	expect(absf((-transform.basis.z.normalized()).dot(Vector3.LEFT) - 1.0) < 0.01,
		"pointing along the span")

func test_a_rail_between_two_points_in_the_same_place() -> void:
	print("zero-length rail")
	var transform := FencePlan.rail_transform(Vector3.ONE, Vector3.ONE)
	expect(transform.origin.is_equal_approx(Vector3.ONE),
		"two posts in the same place give a rail there rather than a NAN")
	expect(not is_nan(transform.basis.x.x), "with a usable basis")

func test_a_vertical_rail() -> void:
	print("vertical rail")
	# Straight up is parallel to the up vector used to build the basis, which is
	# where a naive cross product collapses to nothing.
	var transform := FencePlan.rail_transform(Vector3.ZERO, Vector3(0, 3, 0))
	expect(not is_nan(transform.basis.x.x), "a vertical rail still has a basis")
	expect(absf(transform.basis.get_scale().z - 3.0) < 0.001, "and the right length")

func test_post_yaw() -> void:
	print("facing")
	expect(is_zero_approx(FencePlan.post_yaw(Vector3.BACK)), "a post facing +Z has no yaw")
	expect(absf(FencePlan.post_yaw(Vector3.RIGHT) - PI * 0.5) < 0.001,
		"and one facing +X is turned a quarter")
	expect(is_zero_approx(FencePlan.post_yaw(Vector3.UP)),
		"a straight-up direction has no yaw to speak of, rather than a NAN")

# --- the real tool script --------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real tool")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var builder: Node3D = scene.get_node("FenceBuilder")
	var path: Path3D = scene.get_node("FenceBuilder/Path3D")

	expect(builder.generated_count() > 0,
		"the tool built a fence (%d nodes)" % builder.generated_count())
	# Nodes added without an owner are not written into the scene file. Without
	# that, every rebuild leaves the scene fatter than it was.
	var owned := 0
	for child in builder.get_children():
		if child != path and child.owner != null:
			owned += 1
	expect(owned == 0, "and none of the generated nodes would be saved into the scene")

	# The checkbox-as-button pattern: setting it triggers a rebuild and leaves
	# the property false, because it is an action rather than a state.
	builder.rebuild_now = true
	expect(builder.rebuild_now == false, "the rebuild checkbox resets itself")

	# Rails run between two posts at the same height. A sign flip at one end
	# gives a fence of diagonals, which is a plausible-looking fence.
	var rails := 0
	var level := 0
	for child in builder.get_children():
		if child.is_in_group(&"fence_rail"):
			rails += 1
			if absf((child as Node3D).basis.z.normalized().y) < 0.01:
				level += 1
	expect(rails > 0, "the fence has rails (%d)" % rails)
	expect(level == rails, "and every one of them is level")

	# Posts square up to the fence line, which means their yaw follows the
	# direction the curve is going — not the position it happens to be at.
	var curve: Curve3D = path.curve
	var first_post: Node3D = null
	for child in builder.get_children():
		if child.is_in_group(&"fence_post"):
			first_post = child as Node3D
			break
	expect(first_post != null, "there is a post to check")
	if first_post != null:
		var at := curve.sample_baked(0.0)
		var ahead := curve.sample_baked(0.1)
		expect(absf(first_post.rotation.y - FencePlan.post_yaw(ahead - at)) < 0.05,
			"and it faces along the curve")
		# A box mesh is centred on its origin, so a post standing *on* the curve
		# sits half its height above it. Placed at the curve itself, half the
		# fence is underground — which reads as the curve being wrong.
		expect(absf(first_post.position.y - (at.y + builder.post_height * 0.5)) < 0.01,
			"and stands on the curve rather than half-buried in it")

	# Rails are spread up the post: the lowest at 35% of its height and the
	# highest at 85%, whatever the rail count.
	var heights: Array[float] = []
	for child in builder.get_children():
		if child.is_in_group(&"fence_rail"):
			heights.append((child as Node3D).position.y)
	heights.sort()
	expect(heights.size() >= 2, "there are rails at more than one height")
	if heights.size() >= 2:
		expect(absf(heights[0] - builder.post_height * 0.35) < 0.05,
			"the lowest rail is a third of the way up the post")
		expect(absf(heights[heights.size() - 1] - builder.post_height * 0.85) < 0.05,
			"and the highest is near the top of it")

	# A builder with no Path3D at all: the case that only happens the moment
	# someone drops the node into a scene, which is also the moment a @tool
	# script gets to crash the editor rather than the game.
	var orphan: Node3D = builder.duplicate()
	orphan.get_node("Path3D").free()
	add_child(orphan)
	expect(orphan.generated_count() == 0, "a builder with no Path3D builds nothing")
	expect(not orphan._get_configuration_warnings().is_empty(),
		"and says why, where the editor shows it")
	orphan.rebuild_now = true
	expect(orphan.generated_count() == 0, "and rebuilding it is still nothing, not an error")
	orphan.queue_free()

	var before: int = builder.generated_count()
	builder.rebuild_now = true
	expect(builder.generated_count() == before,
		"rebuilding replaces the fence rather than adding a second one")

	builder.spacing = builder.spacing * 0.5
	expect(builder.generated_count() > before, "halving the spacing builds more of it")

	# A working setup must be *quiet*. A warning check that only ever fires is
	# as useless as one that never does.
	expect(builder._get_configuration_warnings().is_empty(),
		"a fence with a curve to follow reports no warnings")

	# The editor's own feedback channel: a warning attached to the node, which
	# survives a scene reload in a way a print() does not.
	path.curve = null
	expect(not builder._get_configuration_warnings().is_empty(),
		"and a curve it cannot use produces a configuration warning")

	scene.queue_free()
	_report()
