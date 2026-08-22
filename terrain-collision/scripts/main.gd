extends Node3D

# Demo driver. Builds a terrain mesh and a HeightMapShape3D from one height
# function, and drops balls on it. Press W to scale the collider wrongly and
# watch them land in mid-air.

const CELLS := 32
const SPACING := 1.25
const AMPLITUDE := 2.5

@onready var _mesh: MeshInstance3D = $Terrain
@onready var _body: StaticBody3D = $Terrain/Body
@onready var _shape_node: CollisionShape3D = $Terrain/Body/Shape
@onready var _balls: Node3D = $Balls
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _noise := FastNoiseLite.new()
var _correct := true
var _dropped := 0

func _ready() -> void:
	_hint.text = "Space drop a ball   W wrong scale (watch them float)   R clear"
	_noise.seed = 4
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mesh.mesh = _build_mesh()
	_shape_node.shape = HeightField.shape_for(CELLS, SPACING, _height)
	_apply_scale()

## The one height function. The mesh and the shape both come from this, which is
## the only way they can agree.
func _height(x: float, z: float) -> float:
	return _noise.get_noise_2d(x * 12.0, z * 12.0) * AMPLITUDE

func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := CELLS + 1
	var half := float(CELLS) * SPACING * 0.5
	for z in side:
		for x in side:
			var px := -half + float(x) * SPACING
			var pz := -half + float(z) * SPACING
			st.set_uv(Vector2(float(x) / CELLS, float(z) / CELLS))
			st.add_vertex(Vector3(px, _height(px, pz), pz))
	for z in CELLS:
		for x in CELLS:
			var i := z * side + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + side)
			st.add_index(i + 1)
			st.add_index(i + side + 1)
			st.add_index(i + side)
	st.generate_normals()
	return st.commit()

## The line the whole demo is about.
##
## HeightMapShape3D samples are one unit apart with no way to change that, so a
## terrain built at 1.25 metres per cell needs its collider scaled to match.
func _apply_scale() -> void:
	_body.scale = HeightField.scale_for(SPACING) if _correct else Vector3.ONE

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: _drop()
		KEY_W:
			_correct = not _correct
			_apply_scale()
		KEY_R:
			for ball in _balls.get_children():
				ball.queue_free()
			_dropped = 0
		_: return

func _drop() -> void:
	var ball := RigidBody3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	var view := MeshInstance3D.new()
	view.mesh = mesh
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	ball.add_child(view)
	ball.add_child(shape)
	ball.position = Vector3(randf_range(-8.0, 8.0), 8.0, randf_range(-8.0, 8.0))
	_balls.add_child(ball)
	_dropped += 1

func _process(_delta: float) -> void:
	var resting := 0
	var floating := 0
	for ball in _balls.get_children():
		var body := ball as RigidBody3D
		if body.linear_velocity.length() > 0.2:
			continue
		# A ball at rest should be sitting on the ground the mesh draws. If the
		# collider is the wrong size, it rests somewhere else entirely.
		var ground := _height(body.position.x, body.position.z)
		if absf(body.position.y - (ground + 0.4)) < 0.35:
			resting += 1
		else:
			floating += 1

	_status.text = "%s scale   %d dropped   %d on the ground   %d floating or sunk" % [
		"correct" if _correct else "WRONG (1 unit per sample)", _dropped, resting, floating]
