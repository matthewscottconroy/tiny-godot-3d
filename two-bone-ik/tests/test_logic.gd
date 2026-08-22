extends Node

# Drives the real LimbSolver from scripts/limb_solver.gd.
#
# IK is geometry, so it is testable to the millimetre — and it needs to be,
# because every one of its failure modes renders as something plausible. A knee
# that bends the wrong way looks like a bad animation. A NAN from an unguarded
# acos() makes the limb vanish, which looks like a missing mesh.

var _pass := 0
var _fail := 0

const UPPER := 1.2
const LOWER := 0.8
const POLE := Vector3(0, 0, -5)

func _ready() -> void:
	test_the_bones_keep_their_lengths()
	test_a_limb_whose_root_is_not_the_origin()
	test_a_folded_limb_bends_at_the_joint()
	test_a_straight_limb_is_straight()
	test_reaching_exactly_as_far_as_it_can()
	test_out_of_reach_straightens_rather_than_failing()
	test_too_close_folds_rather_than_failing()
	test_nothing_ever_returns_nan()
	test_the_pole_decides_which_way_it_bends()
	test_a_useless_pole_still_gives_an_answer()
	test_a_target_on_the_root()
	test_reach_and_fold()
	test_aim_points_a_bone()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[two-bone-ik] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_bones_keep_their_lengths() -> void:
	print("bone lengths")
	# The invariant everything else rests on: a solved limb is still made of two
	# bones of the lengths it started with. A solver that stretches them to reach
	# looks fine in a screenshot and wrong in motion.
	var solution := LimbSolver.solve(Vector3.ZERO, Vector3(0, -1.5, 0.4), UPPER, LOWER, POLE)
	expect(absf(solution.joint.length() - UPPER) < 0.001, "the upper bone is its own length")
	expect(absf(solution.joint.distance_to(solution.foot) - LOWER) < 0.001,
		"and so is the lower one")

func test_a_limb_whose_root_is_not_the_origin() -> void:
	print("away from the origin")
	# Every other test solves from Vector3.ZERO, where adding the root and
	# subtracting it are the same thing. A hip is almost never at the origin.
	var root := Vector3(3.0, 5.0, -2.0)
	var target := root + Vector3(0, -1.6, 0)
	var solution := LimbSolver.solve(root, target, UPPER, LOWER, root + Vector3(0, 0, -5))
	expect(solution.foot.is_equal_approx(target), "the foot lands on the target, not near it")
	expect(absf(root.distance_to(solution.joint) - UPPER) < 0.001,
		"and the upper bone still measures from the root it was given")
	expect(solution.reachable, "with the target still in reach")
	# The pole is a point in the world too, so it is only meaningful relative to
	# the root — a pole in front of a hip five metres up is not in front of the
	# origin.
	var front := LimbSolver.solve(root, target, UPPER, LOWER, root + Vector3(0, 0, -5))
	var behind := LimbSolver.solve(root, target, UPPER, LOWER, root + Vector3(0, 0, 5))
	expect(front.joint.z < root.z, "a pole in front of the root bends the knee in front of it")
	expect(behind.joint.z > root.z, "and one behind, behind")
	# Directly in front, not merely somewhere with a forward component: a pole
	# measured from the origin rather than from the root drags the knee
	# sideways by however far the root happens to be from the world centre.
	expect(absf(front.joint.x - root.x) < 0.01, "and straight in front, not off to one side")
	expect(absf(front.joint.y - behind.joint.y) < 0.01,
		"with the two solutions mirrored rather than tilted")

func test_a_folded_limb_bends_at_the_joint() -> void:
	print("bending")
	var near := LimbSolver.solve(Vector3.ZERO, Vector3(0, -0.6, 0), UPPER, LOWER, POLE)
	var far := LimbSolver.solve(Vector3.ZERO, Vector3(0, -1.9, 0), UPPER, LOWER, POLE)
	expect(near.bend < far.bend, "a closer target folds the joint further")
	expect(near.bend > 0.0, "without folding it past itself")
	# One exact angle, worked out by hand: with bones of 1.2 and 0.8 and a foot
	# 1.6 away, cos(bend) = (1.44 + 0.64 - 2.56) / (2 x 1.2 x 0.8) = -0.25.
	var known := LimbSolver.solve(Vector3.ZERO, Vector3(0, -1.6, 0), UPPER, LOWER, POLE)
	expect(absf(known.bend - acos(-0.25)) < 0.001, "and the angle is the one the triangle has")

func test_a_straight_limb_is_straight() -> void:
	print("straight")
	var solution := LimbSolver.solve(Vector3.ZERO, Vector3(0, -(UPPER + LOWER), 0),
		UPPER, LOWER, POLE)
	expect(absf(solution.bend - PI) < 0.01, "at full stretch the joint angle is 180 degrees")
	expect(solution.joint.distance_to(Vector3(0, -UPPER, 0)) < 0.01,
		"and the knee sits on the line between hip and foot")

func test_reaching_exactly_as_far_as_it_can() -> void:
	print("full reach")
	var solution := LimbSolver.solve(Vector3.ZERO, Vector3(UPPER + LOWER, 0, 0),
		UPPER, LOWER, POLE)
	expect(solution.reachable, "a target at exactly full reach is reachable")
	expect(solution.foot.distance_to(Vector3(UPPER + LOWER, 0, 0)) < 0.001,
		"and the foot lands on it")

func test_out_of_reach_straightens_rather_than_failing() -> void:
	print("out of reach")
	var target := Vector3(0, -8.0, 0)
	var solution := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, POLE)
	expect(not solution.reachable, "a target beyond the limb is reported as out of reach")
	expect(absf(solution.bend - PI) < 0.01, "the limb straightens instead")
	expect(absf(solution.foot.length() - (UPPER + LOWER)) < 0.001,
		"stopping at its own full reach rather than stretching to the target")
	expect(solution.foot.normalized().is_equal_approx(target.normalized()),
		"while still pointing at it")

func test_too_close_folds_rather_than_failing() -> void:
	print("too close")
	# Inside the fold distance the triangle is impossible in the other
	# direction — and it is a real case, not a curiosity: a foot planted right
	# under the hip while the character crouches.
	var solution := LimbSolver.solve(Vector3.ZERO, Vector3(0, -0.05, 0), UPPER, LOWER, POLE)
	expect(not solution.reachable, "a target inside the fold is out of range too")
	expect(absf(solution.foot.length() - absf(UPPER - LOWER)) < 0.001,
		"and the limb folds as far as it goes, no further")

func test_nothing_ever_returns_nan() -> void:
	print("no NANs")
	# An unguarded acos() outside -1..1 returns NAN, which propagates into a
	# transform and takes the limb off screen — with no error anywhere.
	var cases := [
		Vector3(0, -50, 0), Vector3.ZERO, Vector3(0.0001, 0, 0),
		Vector3(100, 100, 100), Vector3(0, 0.02, 0),
	]
	var clean := true
	for target in cases:
		var solution := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, POLE)
		if is_nan(solution.joint.x) or is_nan(solution.joint.y) or is_nan(solution.joint.z) \
				or is_nan(solution.bend):
			clean = false
	expect(clean, "no target produces a NAN, however unreasonable")

func test_the_pole_decides_which_way_it_bends() -> void:
	print("the pole")
	var target := Vector3(0, -1.6, 0)
	var forward := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, Vector3(0, 0, -5))
	var backward := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, Vector3(0, 0, 5))
	# Two mirrored solutions exist and the maths prefers neither. This is the
	# parameter people leave out, and then their character's knees bend
	# backwards when it turns round.
	expect(forward.joint.z < 0.0, "a pole in front bends the knee forwards")
	expect(backward.joint.z > 0.0, "a pole behind bends it backwards")
	expect(absf(forward.joint.z + backward.joint.z) < 0.001,
		"and the two are mirror images of each other")
	var sideways := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, Vector3(5, 0, 0))
	expect(sideways.joint.x > 0.0, "a pole to the side bends it sideways — it is a direction")

func test_a_useless_pole_still_gives_an_answer() -> void:
	print("degenerate pole")
	# A pole on the limb's own line indicates nothing at all. Any perpendicular
	# is as good as any other; what matters is that it is finite and stable.
	var target := Vector3(0, -1.6, 0)
	var first := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, Vector3(0, -5, 0))
	var second := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, Vector3(0, -5, 0))
	expect(not is_nan(first.joint.x), "a pole along the limb still produces a joint")
	expect(first.joint.is_equal_approx(second.joint),
		"and the same one twice, rather than a knee that jitters")
	# Any perpendicular will do, but it has to be *a* perpendicular: a fallback
	# that collapses to zero leaves the knee on the straight line between hip
	# and foot, which is a limb that has stopped bending at all.
	var along := (first.foot - Vector3.ZERO).normalized()
	var off_line := first.joint - along * first.joint.dot(along)
	expect(off_line.length() > 0.1, "with the knee genuinely off the hip-to-foot line")

func test_a_target_on_the_root() -> void:
	print("target on the hip")
	var solution := LimbSolver.solve(Vector3.ZERO, Vector3.ZERO, UPPER, LOWER, POLE)
	expect(not is_nan(solution.joint.y), "a target on the root does not divide by zero")
	expect(absf(solution.joint.length() - UPPER) < 0.001, "and the upper bone keeps its length")

func test_reach_and_fold() -> void:
	print("range")
	expect(is_equal_approx(LimbSolver.reach_of(1.2, 0.8), 2.0), "reach is the two lengths added")
	expect(is_equal_approx(LimbSolver.fold_of(1.2, 0.8), 0.4), "and the fold is their difference")
	expect(is_equal_approx(LimbSolver.fold_of(0.8, 1.2), 0.4), "whichever way round they are")

func test_aim_points_a_bone() -> void:
	print("aiming")
	var basis := LimbSolver.aim(Vector3.ZERO, Vector3(0, 0, -3))
	expect((-basis.z).is_equal_approx(Vector3(0, 0, -1)),
		"a bone aimed forward points its -Z that way")
	expect(is_equal_approx(basis.determinant(), 1.0), "and the basis is not mirrored")
	# The up vector is what stops the bone rolling arbitrarily about its own
	# axis, so a horizontal aim must come back upright rather than merely
	# perpendicular.
	expect(basis.y.dot(Vector3.UP) > 0.99, "with its up axis still pointing up")
	var sideways := LimbSolver.aim(Vector3.ZERO, Vector3(3, 0, 0))
	expect(sideways.y.dot(Vector3.UP) > 0.99, "whichever way it is aimed")
	# A direction the identity basis does not already satisfy — otherwise an
	# aim() that quietly returned Basis() would pass every assertion here.
	expect((-sideways.z).is_equal_approx(Vector3.RIGHT), "and it really is aimed there")
	# Aiming between two points that are both away from the origin — which is
	# every bone in a rig that is not standing at the world centre.
	var offset := LimbSolver.aim(Vector3(4, 2, 1), Vector3(4, 2, -2))
	expect((-offset.z).is_equal_approx(Vector3(0, 0, -1)),
		"a bone aimed from somewhere else still points along the direction between them")
	var straight_up := LimbSolver.aim(Vector3.ZERO, Vector3(0, 3, 0))
	expect(not is_nan(straight_up.z.x), "aiming straight up, along the up vector, still works")
	expect(is_equal_approx(straight_up.determinant(), 1.0), "and still gives a valid basis")
	# The same degenerate case with a different up vector, which is where a
	# fixed fallback axis would itself be parallel.
	var sideways_up := LimbSolver.aim(Vector3.ZERO, Vector3(3, 0, 0), Vector3.RIGHT)
	expect(not is_nan(sideways_up.x.x), "and so does aiming along a non-default up vector")
	expect(is_equal_approx(sideways_up.determinant(), 1.0), "with a valid basis again")
