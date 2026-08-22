extends Node

# Drives the real Ragdoll from scripts/ragdoll.gd, and then knocks over a real
# skeleton with real physical bones — because the interesting claims here are
# about the two transitions, and both of them are transitions of the engine's
# state rather than of a number.
#
# mutate-driver: skip — the scene is instantiated to simulate real PhysicalBone3Ds, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _pose_before := Vector3.ZERO

func _ready() -> void:
	test_it_starts_animated()
	test_going_limp()
	test_it_does_not_settle_while_moving()
	test_settling_takes_time()
	test_one_flailing_arm_is_not_settled()
	test_settling_only_happens_once()
	test_recovering_blends_rather_than_snaps()
	test_recovery_finishes()
	test_recovering_from_the_wrong_state()
	test_momentum_carries_into_the_ragdoll()
	test_a_heavier_bone_takes_less_of_the_hit()
	test_resetting()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[ragdoll-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_it_starts_animated() -> void:
	print("the start")
	var ragdoll := Ragdoll.new()
	expect(ragdoll.state() == Ragdoll.State.ANIMATED, "a character starts animated")
	expect(not ragdoll.is_simulating(), "and is not simulating")
	expect(is_equal_approx(ragdoll.animation_weight(), 1.0), "with the animation entirely in charge")

func test_going_limp() -> void:
	print("going limp")
	var ragdoll := Ragdoll.new()
	ragdoll.go_limp()
	expect(ragdoll.is_simulating(), "being hit hands over to physics")
	expect(is_zero_approx(ragdoll.animation_weight()), "and the animation stops being in charge")

func test_it_does_not_settle_while_moving() -> void:
	print("still moving")
	var ragdoll := Ragdoll.new()
	ragdoll.go_limp()
	expect(not ragdoll.observe(4.0, 0.1), "a ragdoll still tumbling has not settled")
	expect(not ragdoll.observe(4.0, 10.0), "however long it tumbles for")

func test_settling_takes_time() -> void:
	print("settling")
	var ragdoll := Ragdoll.new()
	ragdoll.go_limp()
	expect(not ragdoll.observe(0.1, 0.1), "being still for a moment is not settled")
	expect(not ragdoll.observe(0.1, 0.2), "nor for a little longer")
	# The hold matters: a body resting on a slope reports still between bounces,
	# and a character that stands up mid-bounce looks broken.
	expect(ragdoll.observe(0.1, 0.2), "but held for long enough, it has settled")

func test_one_flailing_arm_is_not_settled() -> void:
	print("the fastest body")
	# The fastest body, not the average. An arm still swinging is not a character
	# ready to stand up, and averaging hides exactly that.
	var speeds: Array[float] = [0.0, 0.05, 3.0, 0.0, 0.0]
	expect(is_equal_approx(Ragdoll.fastest(speeds), 3.0), "the fastest body is the one that counts")
	expect(is_zero_approx(Ragdoll.fastest([] as Array[float])), "and no bodies at all are not moving")
	expect(is_equal_approx(Ragdoll.fastest([-2.0, 1.0] as Array[float]), 2.0),
		"direction does not make a body slower")

func test_settling_only_happens_once() -> void:
	print("settling once")
	var ragdoll := Ragdoll.new()
	ragdoll.go_limp()
	ragdoll.observe(0.0, 1.0)
	ragdoll.recover()
	expect(not ragdoll.observe(0.0, 1.0),
		"a ragdoll that is already getting up does not settle again")

func test_recovering_blends_rather_than_snaps() -> void:
	print("getting up")
	var ragdoll := Ragdoll.new()
	ragdoll.go_limp()
	ragdoll.recover()
	expect(ragdoll.state() == Ragdoll.State.RECOVERING, "getting up is its own state")
	var quarter := ragdoll.advance_recovery(ragdoll.recovery_time * 0.25)
	# Snapping to the first frame of "stand up" is the going-limp bug in reverse.
	expect(quarter > 0.0 and quarter < 1.0,
		"part-way through, the animation is part-way in charge (%.2f)" % quarter)
	expect(ragdoll.advance_recovery(ragdoll.recovery_time * 0.25) > quarter,
		"and further through, more so")

func test_recovery_finishes() -> void:
	print("back to animation")
	var ragdoll := Ragdoll.new()
	ragdoll.go_limp()
	ragdoll.recover()
	expect(is_equal_approx(ragdoll.advance_recovery(ragdoll.recovery_time + 0.1), 1.0),
		"once the blend is done the animation is fully in charge")
	expect(ragdoll.state() == Ragdoll.State.ANIMATED, "and the character is animated again")

func test_recovering_from_the_wrong_state() -> void:
	print("out of order")
	var ragdoll := Ragdoll.new()
	ragdoll.recover()
	expect(ragdoll.state() == Ragdoll.State.ANIMATED,
		"getting up when nothing knocked you over does nothing")
	expect(is_equal_approx(ragdoll.advance_recovery(0.1), 1.0),
		"and an animated character is already fully animated")

func test_momentum_carries_into_the_ragdoll() -> void:
	print("momentum")
	# A character shot while sprinting should fall forwards. Bodies started at
	# rest drop straight down, which reads as being switched off rather than hit.
	var running := Vector3(0, 0, -6.0)
	var launched := Ragdoll.launch_velocity(running, Vector3(0, 2.0, -2.0), 1.0)
	expect(launched.z < running.z, "the hit adds to the direction they were already going")
	expect(launched.y > 0.0, "and lifts them off the ground")
	expect(Ragdoll.launch_velocity(Vector3.ZERO, Vector3.ZERO).is_zero_approx(),
		"a character standing still, hit by nothing, does not move")

func test_a_heavier_bone_takes_less_of_the_hit() -> void:
	print("mass")
	var light := Ragdoll.launch_velocity(Vector3.ZERO, Vector3(0, 0, -10.0), 1.0)
	var heavy := Ragdoll.launch_velocity(Vector3.ZERO, Vector3(0, 0, -10.0), 5.0)
	expect(absf(heavy.z) < absf(light.z), "the same impulse moves a heavier bone less")
	expect(not is_nan(Ragdoll.launch_velocity(Vector3.ZERO, Vector3.ONE, 0.0).x),
		"and a massless bone does not divide by zero")

func test_resetting() -> void:
	print("reset")
	var ragdoll := Ragdoll.new()
	ragdoll.go_limp()
	ragdoll.observe(0.0, 1.0)
	ragdoll.reset()
	expect(ragdoll.state() == Ragdoll.State.ANIMATED, "reset puts the character back to animated")
	expect(not ragdoll.observe(0.0, 10.0), "with nothing left over from the fall")

# --- the real skeleton -----------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real ragdoll")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			_check_it_was_built()
			_pose_before = _hips_position()
			_scene.call("hit", Vector3(0, 2.0, -6.0))
		6:
			_check_the_hand_off()
		40:
			_check_it_fell()
			_report()

## The hips' physical body, not the bone pose. While the simulation runs, the
## bodies are the truth and the pose follows them — reading the pose during a
## fall is reading last frame's animation.
func _hips_position() -> Vector3:
	var bones: Array = _scene.get("_bones")
	return (bones[0] as PhysicalBone3D).global_position

func _check_it_was_built() -> void:
	var skeleton: Skeleton3D = _scene.get_node("Character/Skeleton")
	expect(skeleton.get_bone_count() == 7, "the skeleton has its seven bones")
	var simulator: PhysicalBoneSimulator3D = _scene.get("_simulator")
	expect(simulator != null, "and a simulator to hang the physical bones off")
	expect(simulator.get_child_count() == 7, "with one physical bone each")
	expect(not simulator.is_simulating_physics(), "not simulating yet")

func _check_the_hand_off() -> void:
	var simulator: PhysicalBoneSimulator3D = _scene.get("_simulator")
	expect(simulator.is_simulating_physics(), "being hit started the simulation")

	# Started from the pose, not from the rest pose. A ragdoll that begins at
	# rest snaps into a T-shape for one frame, which is the most recognisable
	# ragdoll bug there is.
	var moved := _pose_before.distance_to(_hips_position())
	expect(moved < 0.5, "and the bodies started where the pose was (%.3f m away)" % moved)

	# With the character's momentum in them, so a character hit while moving
	# falls the way they were going.
	var bones: Array = _scene.get("_bones")
	var fastest := 0.0
	for bone in bones:
		fastest = maxf(fastest, (bone as PhysicalBone3D).linear_velocity.length())
	expect(fastest > 1.0, "and with real velocity in them (%.2f m/s)" % fastest)

func _check_it_fell() -> void:
	var after := _hips_position()
	expect(after.y < _pose_before.y - 0.1,
		"the character fell (hips %.2f, from %.2f)" % [after.y, _pose_before.y])

	# And getting up is the other transition: the animation takes over from
	# wherever the bodies ended, rather than from the first frame of a clip.
	_scene.call("get_up")
	var simulator: PhysicalBoneSimulator3D = _scene.get("_simulator")
	expect(not simulator.is_simulating_physics(), "getting up stops the simulation")
	var ragdoll = _scene.get("_ragdoll")
	expect(ragdoll.state() == Ragdoll.State.RECOVERING, "and blends back rather than snapping")
	expect(ragdoll.animation_weight() < 1.0, "with the animation not yet fully in charge")
