extends Node

# Drives the real Refraction from scripts/refraction.gd, and then checks the real
# shader is loaded and parameterised — a shader nobody can assert on is still a
# shader whose uniforms can be wrong.
#
# mutate-driver: skip — the scene is instantiated to load a real ShaderMaterial, not to test main.gd

var _pass := 0
var _fail := 0
var _frame := 0
var _scene: Node3D = null

func _ready() -> void:
	test_a_surface_facing_you_bends_nothing()
	test_an_edge_on_surface_bends_most()
	test_the_offset_follows_the_normal()
	test_aspect_correction()
	test_a_square_viewport_changes_nothing()
	test_a_viewport_with_no_height()
	test_fresnel_face_on()
	test_fresnel_edge_on()
	test_fresnel_power()
	test_where_a_point_appears()
	test_what_a_screen_shader_cannot_see()
	test_fading_with_distance()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[screen-shader] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_a_surface_facing_you_bends_nothing() -> void:
	print("face-on")
	# The normal's screen-space X and Y are the direction to bend in, so a
	# surface pointing straight at the camera has nothing to bend along. It is
	# why glass looks like glass at its edges and like a window in the middle.
	expect(Refraction.screen_offset(Vector3(0, 0, 1), 0.05).is_zero_approx(),
		"a surface facing the camera samples the screen where it already is")

func test_an_edge_on_surface_bends_most() -> void:
	print("edge-on")
	var edge := Refraction.screen_offset(Vector3(1, 0, 0), 0.05)
	expect(is_equal_approx(edge.x, 0.05), "a surface turned side-on samples the full strength across")
	expect(is_zero_approx(edge.y), "and nothing vertically, because its normal has no Y")

func test_the_offset_follows_the_normal() -> void:
	print("direction")
	var up := Refraction.screen_offset(Vector3(0, 1, 0), 0.05)
	expect(is_equal_approx(up.y, 0.05) and is_zero_approx(up.x),
		"a normal pointing up bends the sample upward")
	expect(Refraction.screen_offset(Vector3(-1, 0, 0), 0.05).x < 0.0,
		"and one pointing the other way bends it the other way")
	expect(Refraction.screen_offset(Vector3(1, 0, 0), 0.1).x
		> Refraction.screen_offset(Vector3(1, 0, 0), 0.05).x,
		"more strength is more offset")

func test_aspect_correction() -> void:
	print("aspect")
	var offset := Vector2(0.05, 0.05)
	var wide := Refraction.aspect_corrected(offset, Vector2i(1920, 1080))
	# Without this, glass refracts further sideways than vertically on a wide
	# screen, and the effect stretches when the player resizes the window.
	expect(wide.x < offset.x, "on a wide screen the horizontal offset is reduced")
	expect(is_equal_approx(wide.y, offset.y), "and the vertical is left alone")
	expect(is_equal_approx(wide.x, 0.05 / (1920.0 / 1080.0)),
		"by exactly the aspect ratio")

func test_a_square_viewport_changes_nothing() -> void:
	print("square screens")
	var offset := Vector2(0.05, 0.05)
	expect(Refraction.aspect_corrected(offset, Vector2i(800, 800)).is_equal_approx(offset),
		"a square viewport needs no correction at all")

func test_a_viewport_with_no_height() -> void:
	print("degenerate viewports")
	var offset := Vector2(0.05, 0.05)
	expect(Refraction.aspect_corrected(offset, Vector2i(800, 0)).is_equal_approx(offset),
		"a viewport with no height does not divide by zero")

func test_fresnel_face_on() -> void:
	print("fresnel, face-on")
	# Face-on, glass is nearly invisible.
	expect(is_zero_approx(Refraction.fresnel(Vector3(0, 0, 1), Vector3(0, 0, 1))),
		"looking straight at a surface, there is no rim at all")

func test_fresnel_edge_on() -> void:
	print("fresnel, edge-on")
	# Edge-on, everything is a mirror. Getting this in is most of the difference
	# between "transparent object" and "glass".
	expect(Refraction.fresnel(Vector3(0, 0, 1), Vector3(1, 0, 0)) > 0.99,
		"looking along a surface, it is a mirror")
	var half := Refraction.fresnel(Vector3(0, 0, 1), Vector3(1, 0, 1))
	expect(half > 0.0 and half < 1.0, "and part-way round is part-way between (%.3f)" % half)

func test_fresnel_power() -> void:
	print("fresnel power")
	var direction := Vector3(0, 0, 1)
	var normal := Vector3(1, 0, 1)
	# A higher power keeps the rim to the very edge; a lower one spreads it
	# across the whole surface, which is the difference between glass and a
	# soap bubble.
	expect(Refraction.fresnel(direction, normal, 8.0)
		< Refraction.fresnel(direction, normal, 2.0),
		"a higher power confines the rim to the edge")

func test_where_a_point_appears() -> void:
	print("apparent position")
	var size := Vector2i(1000, 1000)
	var middle := Vector2(500, 500)
	var moved := Refraction.apparent_position(middle, Vector3(1, 0, 0), 0.05, size)
	# The CPU half: what the shader draws, in numbers the game can use — a
	# bullet that bends where the glass bends it, say.
	expect(is_equal_approx(moved.x, 550.0), "a fifth of the strength across a 1000px screen is 50px")
	expect(is_equal_approx(moved.y, 500.0), "and nothing vertically")
	expect(Refraction.apparent_position(middle, Vector3(0, 0, 1), 0.05, size).is_equal_approx(middle),
		"while a face-on surface shows what is already there")

func test_what_a_screen_shader_cannot_see() -> void:
	print("the limitation")
	# The screen texture is the frame *before* this object was drawn, so anything
	# drawn after it is simply not in the picture. Two panes of glass in a row is
	# the case everyone tries.
	expect(Refraction.can_refract(2.0, 5.0), "near glass can refract what is behind it")
	expect(not Refraction.can_refract(5.0, 2.0), "far glass cannot refract what is in front of it")
	expect(not Refraction.can_refract(3.0, 3.0),
		"and two surfaces at the same depth cannot refract each other either")

func test_fading_with_distance() -> void:
	print("distance")
	# A large screen-space offset on something a few pixels across samples half
	# the screen, which reads as noise rather than as glass.
	expect(is_equal_approx(Refraction.strength_at(2.0, 0.05), 0.05), "up close, the full strength")
	expect(Refraction.strength_at(40.0, 0.05) < 0.05, "across the room, less of it")
	expect(Refraction.strength_at(40.0, 0.05) > 0.0, "but not nothing, which would pop")

# --- the real shader -------------------------------------------------------

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			print("the real shader")
			_scene = load("res://scenes/main.tscn").instantiate()
			add_child(_scene)
		4:
			_check_the_material()
			_report()

func _check_the_material() -> void:
	var glass: MeshInstance3D = _scene.get_node("Glass")
	var material := glass.material_override as ShaderMaterial
	expect(material != null, "the glass carries a ShaderMaterial")
	expect(material.shader != null, "with a shader that compiled")

	var code: String = material.shader.code
	# `hint_screen_texture` is the Godot 4 spelling; the old SCREEN_TEXTURE
	# built-in is gone, and a shader written from a 3.x tutorial fails silently
	# by sampling nothing.
	expect(code.contains("hint_screen_texture"),
		"reading the screen through a hint_screen_texture uniform")
	# `repeat_disable`, or an offset that runs off the edge of the screen wraps
	# the far side of the frame into the glass.
	expect(code.contains("repeat_disable"), "with repeat disabled, so an offset off-screen does not wrap")
	expect(code.contains("depth_draw_never"),
		"and no depth writing, because the surface is a lens rather than an object")

	expect(is_equal_approx(material.get_shader_parameter(&"strength"), 0.05),
		"the demo set the strength the driver thinks it set")
	_scene.set("_strength", 0.12)
	_scene.call("_apply")
	expect(is_equal_approx(material.get_shader_parameter(&"strength"), 0.12),
		"and changing it reaches the material rather than only the readout")
