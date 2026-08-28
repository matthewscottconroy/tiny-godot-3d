extends Node

# Drives the real DofSpec from scripts/dof_spec.gd, and then builds the real
# joint and checks what actually reached it — because the whole subject is a set
# of flags and parameters that are easy to write and hard to read back.
#
# mutate-driver: skip — the scene is instantiated to configure a real Generic6DOFJoint3D, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_the_default_is_a_weld()
	test_a_door()
	test_a_drawer()
	test_a_ball_joint()
	test_a_shoulder()
	test_the_node_you_dropped_in_unchanged()
	test_locked_axes_have_their_limit_on()
	test_free_axes_have_it_off()
	test_the_bounds_written_for_each_kind()
	test_describing_it()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[six-dof-joint] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_the_default_is_a_weld() -> void:
	print("nothing configured")
	var spec := DofSpec.new()
	# Everything locked. Two bodies that could have been one — useless as a
	# joint, and the right starting point for building one deliberately.
	expect(spec.degrees_of_freedom() == 0, "a spec with nothing unlocked has no freedom at all")
	expect(spec.is_weld(), "which is a weld")

func test_a_door() -> void:
	print("a door")
	var door := DofSpec.door()
	expect(door.degrees_of_freedom() == 1, "a door has exactly one degree of freedom")
	expect(door.angular[DofSpec.Axis.Y] == DofSpec.Freedom.LIMITED,
		"the upright axis, limited")
	expect(door.linear[DofSpec.Axis.X] == DofSpec.Freedom.LOCKED,
		"and it does not slide anywhere")
	var swing := door.bounds("angular", DofSpec.Axis.Y)
	expect(swing.y > swing.x, "with a range it can swing through")
	expect(swing.x < 0.0 and swing.y > 0.0, "opening either way from shut")

func test_a_drawer() -> void:
	print("a drawer")
	var drawer := DofSpec.drawer(0.8)
	expect(drawer.degrees_of_freedom() == 1, "a drawer also has one")
	expect(drawer.linear[DofSpec.Axis.Z] == DofSpec.Freedom.LIMITED, "but it is a linear one")
	expect(drawer.angular[DofSpec.Axis.Y] == DofSpec.Freedom.LOCKED, "and it does not turn")
	var travel := drawer.bounds("linear", DofSpec.Axis.Z)
	expect(is_zero_approx(travel.x) and is_equal_approx(travel.y, 0.8),
		"opening one way only, as far as it was told")

func test_a_ball_joint() -> void:
	print("a ball joint")
	var ball := DofSpec.ball()
	expect(ball.degrees_of_freedom() == 3, "a ball joint turns three ways")
	expect(not ball.limit_enabled("angular", DofSpec.Axis.X), "with no angular limits at all")
	expect(ball.limit_enabled("linear", DofSpec.Axis.X),
		"and every linear axis pinned, or it is not a joint, it is a suggestion")

func test_a_shoulder() -> void:
	print("a shoulder")
	var shoulder := DofSpec.shoulder()
	expect(shoulder.degrees_of_freedom() == 3, "a shoulder also turns three ways")
	# The difference between a shoulder and a ball joint is entirely the limits:
	# an arm that can rotate freely about its own length is a broken arm.
	expect(shoulder.limit_enabled("angular", DofSpec.Axis.Z),
		"but the twist is limited rather than free")
	var twist := shoulder.bounds("angular", DofSpec.Axis.Z)
	var reach := shoulder.bounds("angular", DofSpec.Axis.X)
	expect(twist.y < reach.y, "and it twists less than it reaches")

func test_the_node_you_dropped_in_unchanged() -> void:
	print("straight out of the box")
	var loose := DofSpec.unconstrained()
	# What a Generic6DOFJoint3D is before anyone configures it: a ball joint that
	# also slides. It is almost never what anybody wanted, and it is the default.
	expect(loose.degrees_of_freedom() == 6, "an unconfigured joint has all six")
	expect(not loose.is_weld(), "which is the opposite of a weld and just as useless")

func test_locked_axes_have_their_limit_on() -> void:
	print("locking")
	var door := DofSpec.door()
	# The bit that catches everyone: there is no "locked" flag. A locked axis is
	# one whose limit is *enabled* with a range of zero.
	expect(door.limit_enabled("linear", DofSpec.Axis.X),
		"a locked axis has its limit switched on")
	expect(door.bounds("linear", DofSpec.Axis.X) == Vector2.ZERO,
		"with a range of nothing, which is what locks it")

func test_free_axes_have_it_off() -> void:
	print("freeing")
	var ball := DofSpec.ball()
	expect(not ball.limit_enabled("angular", DofSpec.Axis.Y),
		"a free axis is the one with the limit switched off")

func test_the_bounds_written_for_each_kind() -> void:
	print("bounds")
	var shoulder := DofSpec.shoulder(1.0, 0.25)
	expect(shoulder.bounds("angular", DofSpec.Axis.X) == Vector2(-1.0, 1.0),
		"a limited axis writes the range it was given")
	expect(shoulder.bounds("linear", DofSpec.Axis.X) == Vector2.ZERO,
		"and a locked one writes zero, whatever is in the range array")

func test_describing_it() -> void:
	print("describing")
	var door := DofSpec.door()
	var text := door.describe()
	expect(text.contains("rYlim"), "a door reads as limited about Y (%s)" % text)
	expect(text.contains("Xloc"), "and locked along X")
	expect(DofSpec.ball().describe() != text, "and a ball joint reads differently")

# --- the real joint --------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real joint")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			_check_what_reached_the_joint()
		20:
			_shove_the_door()
		55:
			_check_the_door_swings()
			_report()

func _joint() -> Generic6DOFJoint3D:
	return _scene.get("_joint")

func _check_what_reached_the_joint() -> void:
	var joint := _joint()
	expect(joint != null, "the demo built a Generic6DOFJoint3D")
	expect(joint.node_a != NodePath() and joint.node_b != NodePath(),
		"with both ends attached — a joint missing one is silently inert")

	# The door preset: every axis limited, and only the Y rotation with a range.
	expect(joint.get_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT),
		"the locked linear X axis has its limit enabled")
	expect(is_zero_approx(joint.get_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT)),
		"with an upper bound of zero, which is what locks it")
	expect(joint.get_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT) > 0.1,
		"while the Y rotation has a real range to swing through")

	# And switching preset has to reach the joint, not just the readout.
	_scene.set("_spec", DofSpec.ball())
	_scene.call("_apply", _scene.get("_spec"))
	expect(not joint.get_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT),
		"switching to a ball joint turns the angular limits off")
	expect(joint.get_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT),
		"and leaves the linear ones on")

var _before_shove := Vector3.ZERO

## Back to a door, then shove it. Split across frames rather than awaited inside
## one, so the report cannot run before the assertions it is reporting on.
func _shove_the_door() -> void:
	_scene.set("_spec", DofSpec.door())
	_scene.call("_apply", _scene.get("_spec"))
	var body: RigidBody3D = _scene.get("_body")
	_before_shove = body.global_position
	body.apply_impulse(Vector3(0, 0, -8.0), Vector3(0.6, 0, 0))

func _check_the_door_swings() -> void:
	var body: RigidBody3D = _scene.get("_body")
	var moved := body.global_position.distance_to(_before_shove)
	var dropped := absf(body.global_position.y - _before_shove.y)
	print("   the door moved %.2f m, of which %.2f m vertically" % [moved, dropped])
	expect(moved > 0.05, "the shoved body moved (%.2f m)" % moved)
	# A joint that holds lets the body move on its one axis and far less on the
	# five that are locked. Not zero: a 6DOF limit is solved, not welded, and a
	# locked axis with a heavy body on it gives a little.
	expect(dropped < moved * 0.5,
		"and moved mostly on its one free axis (%.2f m of %.2f m vertically)" % [dropped, moved])
