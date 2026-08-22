extends Node

# Drives the real HingeControl from scripts/hinge_control.gd, then checks the
# real joints hold what they say they hold.
#
# mutate-driver: skip — the scene is instantiated to build real joints, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_angles_wrap()
	test_the_shortest_way_round()
	test_the_limits_clamp()
	test_driving_toward_a_target()
	test_it_stops_when_it_arrives()
	test_it_eases_in_rather_than_slamming()
	test_it_never_drives_past_a_limit()
	test_openness()
	test_being_open_is_a_game_question()
	test_sitting_against_a_limit()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[joints-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _control() -> HingeControl:
	var control := HingeControl.new()
	control.min_angle = 0.0
	control.max_angle = PI * 0.5
	control.speed = 2.0
	control.tolerance = 0.02
	control.approach = 0.4
	return control

func test_angles_wrap() -> void:
	print("wrapping")
	expect(is_zero_approx(HingeControl.normalise_angle(TAU)), "a full turn is no turn")
	expect(absf(HingeControl.normalise_angle(PI + 0.1) - (-PI + 0.1)) < 0.001,
		"just past half a turn comes out the other side")
	expect(is_equal_approx(HingeControl.normalise_angle(0.5), 0.5), "an ordinary angle is left alone")

func test_the_shortest_way_round() -> void:
	print("the short way")
	# A door at 179 degrees told to reach -179 should move two degrees, not
	# three hundred and fifty-eight.
	var delta := HingeControl.shortest_delta(deg_to_rad(179.0), deg_to_rad(-179.0))
	expect(absf(rad_to_deg(delta) - 2.0) < 0.01, "crossing the wrap point is a short move")
	expect(rad_to_deg(HingeControl.shortest_delta(0.0, deg_to_rad(90.0))) > 0.0,
		"and an ordinary move keeps its sign")
	expect(rad_to_deg(HingeControl.shortest_delta(deg_to_rad(90.0), 0.0)) < 0.0,
		"in both directions")

func test_the_limits_clamp() -> void:
	print("limits")
	var control := _control()
	expect(is_equal_approx(control.clamp_angle(-2.0), control.min_angle),
		"below the lower limit clamps to it")
	expect(is_equal_approx(control.clamp_angle(9.0), control.max_angle),
		"and above the upper one clamps to that")

func test_driving_toward_a_target() -> void:
	print("driving")
	var control := _control()
	expect(control.drive_toward(0.0, control.max_angle) > 0.0, "opening drives positive")
	expect(control.drive_toward(control.max_angle, 0.0) < 0.0, "closing drives negative")
	expect(absf(control.drive_toward(0.0, control.max_angle)) <= control.speed,
		"and never faster than the speed it was given")

func test_it_stops_when_it_arrives() -> void:
	print("arriving")
	var control := _control()
	# The number that stops the buzz. Without a tolerance the motor overshoots,
	# reverses, overshoots again, and the door vibrates against itself forever.
	expect(is_zero_approx(control.drive_toward(1.0, 1.0)), "at the target, the motor stops")
	expect(is_zero_approx(control.drive_toward(1.0, 1.0 + control.tolerance * 0.5)),
		"and inside the tolerance it stays stopped")
	expect(absf(control.drive_toward(1.0, 1.0 + control.tolerance * 4.0)) > 0.0,
		"while a real difference still drives")

func test_it_eases_in_rather_than_slamming() -> void:
	print("easing")
	var control := _control()
	var far := absf(control.drive_toward(0.0, control.max_angle))
	var near := absf(control.drive_toward(control.max_angle - 0.1, control.max_angle))
	expect(near < far, "the motor slows as it approaches")
	expect(near > 0.0, "without stopping short")
	expect(is_equal_approx(far, control.speed), "and runs at full speed when there is room")

func test_it_never_drives_past_a_limit() -> void:
	print("past the limits")
	var control := _control()
	# A motor still driving into a limit the solver is enforcing is two systems
	# pushing at each other for as long as the game runs.
	expect(is_zero_approx(control.drive_toward(control.max_angle, 10.0)),
		"asked to go beyond the upper limit while already there, it does nothing")
	expect(is_zero_approx(control.drive_toward(control.min_angle, -10.0)),
		"and the same at the lower one")
	expect(control.drive_toward(0.0, 10.0) > 0.0,
		"while an out-of-range target still drives it to the limit from further away")

func test_openness() -> void:
	print("openness")
	var control := _control()
	expect(is_zero_approx(control.openness(control.min_angle)), "shut is zero")
	expect(is_equal_approx(control.openness(control.max_angle), 1.0), "fully open is one")
	expect(absf(control.openness((control.min_angle + control.max_angle) * 0.5) - 0.5) < 0.001,
		"and halfway is a half")
	# A hinge whose closed position is not zero — a hatch that rests at 20
	# degrees, say. With min_angle at zero, adding and subtracting it are the
	# same thing, and half the arithmetic here goes unchecked.
	var offset := HingeControl.new()
	offset.min_angle = 0.4
	offset.max_angle = 1.4
	expect(is_zero_approx(offset.openness(0.4)), "shut is zero wherever shut happens to be")
	expect(is_equal_approx(offset.openness(1.4), 1.0), "and fully open is one")
	expect(absf(offset.openness(0.9) - 0.5) < 0.001, "with the middle halfway between them")

	var stuck := HingeControl.new()
	stuck.min_angle = 1.0
	stuck.max_angle = 1.0
	expect(is_zero_approx(stuck.openness(1.0)), "a hinge with no travel does not divide by zero")

func test_being_open_is_a_game_question() -> void:
	print("open enough")
	var control := _control()
	expect(not control.is_open(0.05), "a door ajar by three degrees is shut")
	expect(control.is_open(control.max_angle), "a door swung wide is open")
	expect(control.is_open(0.5, 0.4), "and where the line falls is the caller's choice")

	# And the same hatch that rests at 20 degrees: "open" is measured from
	# wherever shut happens to be, not from zero. With min_angle at zero, adding
	# and subtracting it are the same thing and this goes unchecked.
	var offset := HingeControl.new()
	offset.min_angle = 0.4
	offset.max_angle = 1.4
	expect(not offset.is_open(0.45), "a hatch a whisker off its resting angle is shut")
	expect(offset.is_open(1.2), "and one swung most of the way is open")

func test_sitting_against_a_limit() -> void:
	print("at a limit")
	var control := _control()
	expect(control.at_limit(control.min_angle), "resting shut is resting on a limit")
	expect(control.at_limit(control.max_angle), "and so is resting wide open")
	expect(not control.at_limit((control.min_angle + control.max_angle) * 0.5),
		"halfway through the swing is not")

# --- the real joints -------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real joints")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		6:
			var hinge: HingeJoint3D = _scene.get_node("Hinge")
			expect(hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
				"the driver enabled the hinge's own limits")
			expect(is_equal_approx(hinge.get_param(HingeJoint3D.PARAM_LIMIT_UPPER),
				HingeControl.new().max_angle),
				"and set them from the same numbers the controller uses")
			var joints := 0
			for child in _scene.get_children():
				if child is PinJoint3D:
					var joint := child as PinJoint3D
					# A joint whose paths do not resolve constrains nothing, and
					# says nothing about it either.
					if joint.get_node_or_null(joint.node_a) != null \
							and joint.get_node_or_null(joint.node_b) != null:
						joints += 1
			expect(joints == 6, "and built six pin joints that both resolve their bodies (%d)" % joints)
			(_scene.get_node("Door") as Node3D).rotation.y = 0.0
		40:
			var door: RigidBody3D = _scene.get_node("Door")
			# The door is held by the hinge rather than by its own transform: it
			# has not fallen over, and it has not left the frame.
			expect(door.global_position.distance_to(Vector3(-0.15, 1.3, 0)) < 1.5,
				"the hinge is still holding the door where it was hung")
			expect(absf(door.rotation.x) < 0.2 and absf(door.rotation.z) < 0.2,
				"and the door has not fallen over — a hinge constrains every axis but one")
			_report()
