extends Node3D

# Demo driver. Builds a noise terrain, works out what each vertex is made of,
# and bakes those weights into the mesh's vertex colours for the shader to mix.
# The rule is in scripts/splat.gd.

@onready var _terrain: MeshInstance3D = $Terrain
@onready var _probe: MeshInstance3D = $Probe
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

const CELLS := 64
const SPACING := 1.2

var _noise := FastNoiseLite.new()
var _water_line := 1.5
var _snow_line := 12.0
var _cliff := 0.6
var _time := 0.0

func _ready() -> void:
	_hint.text = "1/2 water line   3/4 snow line   5/6 how steep counts as cliff   R defaults"
	_noise.seed = 7
	_noise.frequency = 0.012
	_noise.fractal_octaves = 5
	_build()
	var probe_mesh := SphereMesh.new()
	probe_mesh.radius = 0.6
	probe_mesh.height = 1.2
	_probe.mesh = probe_mesh

func height_at(x: float, z: float) -> float:
	return (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 18.0

## The normal from the height function itself, by sampling either side. Cheaper
## and smoother than reading it back off the mesh, and available anywhere —
## including to the game logic, which has no mesh to read.
func normal_at(x: float, z: float) -> Vector3:
	var step := SPACING * 0.5
	var dx := height_at(x + step, z) - height_at(x - step, z)
	var dz := height_at(x, z + step) - height_at(x, z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()

func _build() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(CELLS) * SPACING * 0.5
	for z in CELLS:
		for x in CELLS:
			var corners := [Vector2(x, z), Vector2(x + 1, z),
				Vector2(x + 1, z + 1), Vector2(x, z + 1)]
			for triangle in [[0, 2, 1], [0, 3, 2]]:
				for index in triangle:
					var corner: Vector2 = corners[index]
					var world_x := -half + corner.x * SPACING
					var world_z := -half + corner.y * SPACING
					var height := height_at(world_x, world_z)
					var normal := normal_at(world_x, world_z)
					# The weights ride in the vertex colour, so the shader mixes
					# exactly what the CPU decided — no second opinion.
					tool.set_color(Splat.weights_for(height,
						Splat.slope_of(normal), _water_line, _snow_line, _cliff))
					tool.set_normal(normal)
					tool.add_vertex(Vector3(world_x, height, world_z))
	tool.index()
	_terrain.mesh = tool.commit()
	_show()

func _process(delta: float) -> void:
	_time += delta
	# The probe wanders the terrain, reporting what it is standing on — the same
	# answer a footstep sound or a particle effect would need.
	var x := sin(_time * 0.25) * 26.0
	var z := cos(_time * 0.17) * 26.0
	var height := height_at(x, z)
	_probe.position = Vector3(x, height + 0.6, z)
	_show(x, z, height)

func _show(x: float = 0.0, z: float = 0.0, height: float = 0.0) -> void:
	var slope := Splat.slope_of(normal_at(x, z))
	var weights := Splat.weights_for(height, slope, _water_line, _snow_line, _cliff)
	var total := weights.r + weights.g + weights.b + weights.a
	_readout.text = "water line %.1f m   snow line %.1f m   cliff past %.2f rad (%.0f°)\nunder the probe: %.1f m up, slope %.2f rad (%.0f°)\nsand %.2f  grass %.2f  rock %.2f  snow %.2f  — adding to %.2f" % [
		_water_line, _snow_line, _cliff, rad_to_deg(_cliff),
		height, slope, rad_to_deg(slope),
		weights.r, weights.g, weights.b, weights.a, total]
	_status.text = "standing on %s" % Splat.material_name(Splat.dominant(weights))

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_water_line = maxf(_water_line - 0.5, 0.0)
		KEY_2:
			_water_line = minf(_water_line + 0.5, 10.0)
		KEY_3:
			_snow_line = maxf(_snow_line - 1.0, 2.0)
		KEY_4:
			_snow_line = minf(_snow_line + 1.0, 20.0)
		KEY_5:
			_cliff = maxf(_cliff - 0.05, 0.1)
		KEY_6:
			_cliff = minf(_cliff + 0.05, 1.4)
		KEY_R:
			_water_line = 1.5
			_snow_line = 12.0
			_cliff = 0.6
		_:
			return
	_build()
