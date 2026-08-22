extends Node

# Drives the real PushForce from scripts/push_force.gd, then walks the real
# character into a real crate.
#
# mutate-driver: skip — the scene is instantiated to shove a real RigidBody3D, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null
var _start := Vector3.ZERO

const WALL := Vector3(0, 0, 1)      ## a wall the character walks into along -Z
const INTO := Vector3(0, 0, -4)     ## walking into it
const AWAY := Vector3(0, 0, 4)      ## walking away from it

func _ready() -> void:
	test_walking_into_something_is_a_push()
	test_walking_away_is_not()
	test_standing_still_is_not()
	test_the_floor_is_not_pushed()
	test_a_steep_slope_is_pushed()
	test_a_missing_normal()
	test_the_push_follows_the_speed()
	test_mass_decides_how_far_it_goes()
	test_a_crate_already_moving_is_not_shoved_again()
	test_a_massless_body()
	test_the_flat_push_does_not_lift()
	test_the_contact_offset()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[character-push] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_walking_into_something_is_a_push() -> void:
	print("pushing")
	expect(PushForce.should_push(WALL, INTO), "walking into a wall counts as a push")
	var impulse := PushForce.impulse_for(WALL, INTO, 80.0, 20.0)
	expect(impulse.z < 0.0, "and the impulse goes the way the character was walking")

func test_walking_away_is_not() -> void:
	print("not pushing")
	# A collision happens whenever two things touch. Only the part of the
	# velocity going into the surface is a shove.
	expect(not PushForce.should_push(WALL, AWAY), "walking away from a wall is not a push")
	expect(PushForce.impulse_for(WALL, AWAY, 80.0, 20.0) == Vector3.ZERO,
		"and produces no impulse at all")

func test_standing_still_is_not() -> void:
	print("standing")
	expect(not PushForce.should_push(WALL, Vector3.ZERO), "standing against a crate does not shove it")
	var sideways := Vector3(4, 0, 0)
	expect(not PushForce.should_push(WALL, sideways),
		"and neither does sliding along it, which collides every single frame")

func test_the_floor_is_not_pushed() -> void:
	print("the floor")
	# The floor is a collision too. Push it and the character launches itself,
	# which reads as a jump bug rather than as a push bug.
	expect(not PushForce.should_push(Vector3.UP, Vector3(0, -5, 0)),
		"the ground under the character is not something to shove")
	expect(PushForce.impulse_for(Vector3.UP, Vector3(0, -5, 0), 80.0, 20.0) == Vector3.ZERO,
		"however hard it is walked into")

func test_a_steep_slope_is_pushed() -> void:
	print("steep surfaces")
	var steep := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(70.0))
	expect(PushForce.should_push(steep, Vector3(0, 0, -4)),
		"a surface too steep to stand on is a wall, and walls get pushed")
	var gentle := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(20.0))
	expect(not PushForce.should_push(gentle, Vector3(0, 0, -4)),
		"a ramp you can walk up is not")

func test_a_missing_normal() -> void:
	print("no normal")
	expect(not PushForce.should_push(Vector3.ZERO, INTO),
		"a collision with no normal is not pushed rather than pushed in a random direction")

func test_the_push_follows_the_speed() -> void:
	print("speed")
	var slow := PushForce.impulse_for(WALL, Vector3(0, 0, -1), 80.0, 20.0)
	var fast := PushForce.impulse_for(WALL, Vector3(0, 0, -4), 80.0, 20.0)
	expect(fast.length() > slow.length(), "walking harder shoves harder")
	expect(absf(fast.length() - slow.length() * 4.0) < 0.001, "in proportion to the speed")
	# Only the component into the surface counts, so an oblique approach shoves
	# less than a square one.
	var oblique := PushForce.impulse_for(WALL, Vector3(3, 0, -1), 80.0, 20.0)
	expect(oblique.length() < slow.length() * 1.01, "and an oblique approach shoves less")

func test_mass_decides_how_far_it_goes() -> void:
	print("mass")
	# The impulse is momentum, so a heavier crate takes a *bigger* one — what
	# gets smaller is the speed it ends up at, which is what a player sees.
	var light := PushForce.impulse_for(WALL, INTO, 80.0, 4.0)
	var heavy := PushForce.impulse_for(WALL, INTO, 80.0, 400.0)
	expect(light.length() / 4.0 > heavy.length() / 400.0,
		"a light crate ends up moving faster than a heavy one")
	expect(heavy.length() > light.length(),
		"while the heavy one takes more momentum to move at all")
	var strong := PushForce.impulse_for(WALL, INTO, 160.0, 20.0)
	var weak := PushForce.impulse_for(WALL, INTO, 40.0, 20.0)
	expect(strong.length() > weak.length(), "and a heavier character shoves harder")

func test_a_crate_already_moving_is_not_shoved_again() -> void:
	print("no runaway")
	# A contact lasts many frames. An impulse on every one of them accelerates
	# the crate without limit and it ends up airborne — a loop bug that presents
	# as a physics bug.
	var first := PushForce.impulse_for(WALL, INTO, 80.0, 20.0, Vector3.ZERO)
	var speed := first.length() / 20.0
	var moving := PushForce.impulse_for(WALL, INTO, 80.0, 20.0, Vector3(0, 0, -speed))
	expect(is_zero_approx(moving.length()),
		"a crate already travelling at the shove speed takes no further impulse")
	var slower := PushForce.impulse_for(WALL, INTO, 80.0, 20.0, Vector3(0, 0, -speed * 0.5))
	expect(slower.length() > 0.0 and slower.length() < first.length(),
		"and one going half that fast takes only the difference")
	var faster := PushForce.impulse_for(WALL, INTO, 80.0, 20.0, Vector3(0, 0, -20.0))
	expect(is_zero_approx(faster.length()),
		"a crate running ahead of the character is never dragged backwards")

func test_a_massless_body() -> void:
	print("zero mass")
	var impulse := PushForce.impulse_for(WALL, INTO, 80.0, 0.0)
	expect(not is_nan(impulse.z), "a body with no mass does not divide by zero")
	expect(impulse.length() >= 0.0, "and produces a finite impulse")

func test_the_flat_push_does_not_lift() -> void:
	print("staying level")
	# Wall normals on anything sloped have a small vertical component, and over
	# a few frames it lifts the crate off the floor.
	var sloped := Vector3(0, 0.3, 1).normalized()
	var full := PushForce.impulse_for(sloped, INTO, 80.0, 20.0)
	var flat := PushForce.flat_impulse_for(sloped, INTO, 80.0, 20.0)
	expect(absf(full.y) > 0.0, "the raw impulse has a vertical component")
	expect(is_zero_approx(flat.y), "and the flat one does not")
	expect(is_equal_approx(flat.z, full.z), "while keeping the sideways push intact")

func test_the_contact_offset() -> void:
	print("where it lands")
	var origin := Vector3(0, 1, 0)
	var contact := Vector3(0.4, 1.3, 0)
	var offset := PushForce.offset_of(contact, origin)
	expect(offset.is_equal_approx(Vector3(0.4, 0.3, 0)), "the offset is the contact, relative to the body")
	# A contact far from the centre is a long lever arm and a crate that spins
	# like a top.
	var far := PushForce.offset_of(Vector3(50, 1, 0), origin, 1.0)
	expect(is_equal_approx(far.length(), 1.0), "and a distant contact is clamped")

# --- the real shove --------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		1:
			print("the real shove")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			# Put the character right behind the light crate and walk forward.
			var player: Node3D = _scene.get_node("Player")
			var crate: Node3D = _scene.get_node("Crates/CrateLight")
			crate.global_position = Vector3(0, 0.5, -1.0)
			player.global_position = Vector3(0, 0.9, 0.4)
			_start = crate.global_position
			Input.action_press(&"ui_up")
		40:
			var crate: RigidBody3D = _scene.get_node("Crates/CrateLight")
			var heavy: RigidBody3D = _scene.get_node("Crates/CrateHeavy")
			var moved := _start.distance_to(crate.global_position)
			expect(moved > 0.2, "walking into a crate moved it (%.2f m)" % moved)
			expect(crate.global_position.z < _start.z, "in the direction the character was walking")
			# The heavy crate is nowhere near the character and must not have
			# been shoved by a loop that pushes everything it can find.
			expect(heavy.global_position.distance_to(Vector3(0, 0.5, -4)) < 0.5,
				"while a crate nobody touched stayed where it was")
			Input.action_release(&"ui_up")
			_report()
