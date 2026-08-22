extends Node

# Drives the real PortalView from scripts/portal_view.gd, and then walks the real
# player through the real portal — because a transform that looks right on paper
# and a portal that puts you somewhere sensible are different claims.
#
# mutate-driver: skip — the scene is instantiated to walk through real SubViewport portals, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

## Two portals facing each other across the world, as the demo has them: A at
## x = -10 facing -Z, B at x = +10 turned around.
## Two portals in two rooms, both facing the way the player arrives from — which
## is the demo's own layout.
var _entry := Transform3D(Basis(Vector3.UP, PI), Vector3(-10, 1.5, -6))
var _exit := Transform3D(Basis(Vector3.UP, PI), Vector3(10, 1.5, -6))

func _ready() -> void:
	test_which_side_of_a_portal()
	test_facing_a_portal()
	test_the_camera_lands_in_the_other_room()
	test_the_camera_keeps_its_distance()
	test_the_flip_faces_outwards()
	test_a_portal_onto_itself()
	test_crossing_is_a_sign_change()
	test_crossing_the_other_way()
	test_the_wall_beside_a_portal()
	test_the_near_plane()
	test_the_resolution_worth_rendering()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[portal-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_which_side_of_a_portal() -> void:
	print("sides")
	# A portal's front is its own -Z, the same forward every other Node3D uses.
	expect(PortalView.side_of(_entry, Vector3(-10, 1.5, -4)) > 0.0,
		"a point two metres in front of the portal is in front of it")
	expect(PortalView.side_of(_entry, Vector3(-10, 1.5, -8)) < 0.0, "and one behind is behind")
	expect(is_zero_approx(PortalView.side_of(_entry, Vector3(-10, 1.5, -6))),
		"a point on the surface is on neither side")
	expect(is_equal_approx(PortalView.side_of(_entry, Vector3(-10, 1.5, -4)), 2.0),
		"and the number is metres, not a sign")

func test_facing_a_portal() -> void:
	print("facing")
	# Rendering the far side while standing behind the surface costs a full extra
	# scene render to produce something nobody can see.
	expect(PortalView.is_facing(_entry, Vector3(-10, 1.5, -3)), "standing in front, it is worth drawing")
	expect(not PortalView.is_facing(_entry, Vector3(-10, 1.5, -9)), "standing behind, it is not")
	expect(not PortalView.is_facing(_entry, Vector3(-10, 1.5, -6.05), 0.2),
		"and a margin keeps it off while the player is right against the surface")

func test_the_camera_lands_in_the_other_room() -> void:
	print("the transform")
	# The player two metres in front of the entry portal should put the far
	# camera two metres in front of the exit — in the other room, not this one.
	var viewer := Transform3D(Basis.IDENTITY, Vector3(-10, 1.5, -4))
	var camera := PortalView.camera_transform(viewer, _entry, _exit)
	expect(camera.origin.x > 5.0,
		"the far camera is in the other room (x %.2f)" % camera.origin.x)
	expect(is_equal_approx(camera.origin.y, 1.5), "at the same height")
	# Two metres *behind* the exit, not in front of it. That is the whole trick:
	# the virtual camera stands behind the far surface, so what it sees through
	# the far opening is what the player sees through the near one.
	expect(absf(PortalView.side_of(_exit, camera.origin) + 2.0) < 0.001,
		"and two metres behind the exit portal, looking through it")

func test_the_camera_keeps_its_distance() -> void:
	print("distance is preserved")
	var near := PortalView.camera_transform(
		Transform3D(Basis.IDENTITY, Vector3(-10, 1.5, -5)), _entry, _exit)
	var far := PortalView.camera_transform(
		Transform3D(Basis.IDENTITY, Vector3(-10, 1.5, -1)), _entry, _exit)
	# Step back from a portal and the view through it widens, because the far
	# camera stepped back too.
	expect(PortalView.side_of(_exit, far.origin) < PortalView.side_of(_exit, near.origin),
		"stepping back from the entry steps the far camera back from the exit too")

func test_the_flip_faces_outwards() -> void:
	print("the flip")
	var viewer := Transform3D(Basis.IDENTITY, Vector3(-10, 1.5, -4))
	var camera := PortalView.camera_transform(viewer, _entry, _exit)
	# Without the 180-degree turn, the far camera looks into the back of the exit
	# portal and the view is its own back wall — which reads as the portal
	# simply not working.
	var looking := -camera.basis.z.normalized()
	var out_of_exit := -_exit.basis.z.normalized()
	expect(looking.dot(out_of_exit) > 0.9,
		"the far camera looks out of the exit portal, not into the back of it")
	expect(is_equal_approx(PortalView.flip().basis.z.dot(Vector3.BACK), -1.0),
		"which is what the half-turn is for")

func test_a_portal_onto_itself() -> void:
	print("a portal onto itself")
	var viewer := Transform3D(Basis(Vector3.UP, 0.3), Vector3(-10, 1.5, -4))
	# Entry and exit the same portal: the transform reduces to the viewer,
	# turned around. A useful sanity check, and a real effect — a mirror.
	var camera := PortalView.camera_transform(viewer, _entry, _entry)
	expect(absf(PortalView.side_of(_entry, camera.origin) + 2.0) < 0.001,
		"the camera lands two metres behind the same portal, as a mirror image does")

func test_crossing_is_a_sign_change() -> void:
	print("walking through")
	# Not a proximity test: something moving quickly passes the plane in one
	# frame without ever being near it, and a distance check misses it entirely.
	expect(PortalView.crossed(_entry, Vector3(-10, 1.5, -5.9), Vector3(-10, 1.5, -6.1)),
		"a short step across the plane is a crossing")
	expect(PortalView.crossed(_entry, Vector3(-10, 1.5, 4.0), Vector3(-10, 1.5, -16.0)),
		"and so is a twenty-metre one that is never near it")
	expect(not PortalView.crossed(_entry, Vector3(-10, 1.5, -5.0), Vector3(-10, 1.5, -5.5)),
		"walking toward it without reaching it is not")

func test_crossing_the_other_way() -> void:
	print("the wrong way")
	# Back to front is not an entry: the player who walks out of a portal must
	# not immediately be sent back through it.
	expect(not PortalView.crossed(_entry, Vector3(-10, 1.5, -7.0), Vector3(-10, 1.5, -5.0)),
		"coming through from behind is not a crossing")

func test_the_wall_beside_a_portal() -> void:
	print("the opening")
	var half := Vector2(1.0, 1.5)
	expect(PortalView.within_opening(_entry, Vector3(-10, 1.5, -6), half),
		"the middle of the opening is in the opening")
	expect(PortalView.within_opening(_entry, Vector3(-10.9, 1.5, -6), half),
		"and so is a point near its edge")
	expect(not PortalView.within_opening(_entry, Vector3(-7, 1.5, -6), half),
		"three metres to the side is the wall, and the wall is still a wall")
	expect(not PortalView.within_opening(_entry, Vector3(-10, 4.0, -6), half),
		"and so is the space above the doorway")

func test_the_near_plane() -> void:
	print("clipping")
	# Anything nearer than this is between the exit portal and its camera: in
	# front of the view, behind the opening, and floating in the doorway.
	var camera := Transform3D(Basis.IDENTITY, Vector3(10, 1.5, -3))
	expect(is_equal_approx(PortalView.near_plane_for(camera, _exit), 3.0),
		"the near plane is the distance from the camera to the exit portal")
	var against := Transform3D(Basis.IDENTITY, Vector3(10, 1.5, -6))
	expect(PortalView.near_plane_for(against, _exit) > 0.0,
		"a camera on the portal itself still gets a usable near plane rather than zero")

func test_the_resolution_worth_rendering() -> void:
	print("resolution")
	var base := Vector2i(512, 768)
	expect(PortalView.resolution_for(1.0, base) == base, "up close, render it at full size")
	expect(PortalView.resolution_for(40.0, base).x < base.x, "across the room, at less")
	expect(PortalView.resolution_for(40.0, base).x >= 128,
		"but never so small it looks like a fault rather than a distant portal")

# --- the real portals ------------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			print("the real portals")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			_check_the_views()
		6:
			_walk_through()
			_report()

func _check_the_views() -> void:
	var view: SubViewport = _scene.get_node("PortalA/View")
	# A SubViewport with no world renders nothing at all, and the portal is a
	# black rectangle with no error to explain it.
	expect(view.world_3d == _scene.get_world_3d(),
		"the portal viewport shares the world it is meant to be showing")
	var surface: MeshInstance3D = _scene.get_node("PortalA/Surface")
	expect(surface.material_override != null, "the portal surface has the viewport's texture on it")

	var camera: Camera3D = _scene.get_node("PortalA/View/Camera")
	expect(camera.global_position.x > 5.0,
		"and its camera is in the other room (x %.2f)" % camera.global_position.x)

func _walk_through() -> void:
	var player: Node3D = _scene.get_node("Player")
	player.global_transform = Transform3D(Basis.IDENTITY, Vector3(-10, 0, -5.5))
	# One step, straight through the opening.
	_scene.call("_check_crossing", Vector3(-10, 0, -5.5), Vector3(-10, 0, -6.5))
	expect(_scene.get("_teleports") == 1, "walking into the portal counted as one crossing")
	expect(player.global_position.x > 5.0,
		"and put the player in the other room (x %.2f)" % player.global_position.x)

	# Into the wall a few metres to the side: not a doorway, however much of the
	# plane it crosses.
	var before: int = _scene.get("_teleports")
	_scene.call("_check_crossing", Vector3(-4, 0, -5.5), Vector3(-4, 0, -6.5))
	expect(_scene.get("_teleports") == before, "walking into the wall beside it does not")
