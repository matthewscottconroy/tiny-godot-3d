extends Node3D

# Demo driver. Walks a foot target over uneven ground and bends the leg to
# follow it, raycasting for the ground height as it goes.

const UPPER := 1.1
const LOWER := 1.1
const STRIDE_SPEED := 1.2

@onready var _hip: Node3D = $Rig/Hip
@onready var _thigh: MeshInstance3D = $Rig/Hip/Thigh
@onready var _shin: MeshInstance3D = $Rig/Hip/Shin
@onready var _knee_marker: MeshInstance3D = $Rig/Hip/KneeMarker
@onready var _foot: MeshInstance3D = $Rig/Foot
@onready var _ray: RayCast3D = $Rig/GroundRay
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _phase := 0.0
var _hip_height := 2.0
var _stride := 1.4
var _running := true

func _ready() -> void:
	_hint.text = "1/2 raise or lower the hip   3/4 stride size   Space pause"

func _physics_process(delta: float) -> void:
	if _running:
		_phase += delta * STRIDE_SPEED
	_hip.position.y = _hip_height

	# Where the foot wants to be: a circle over the ground, dropped onto
	# whatever is underneath it.
	var wanted := Vector3(cos(_phase) * _stride, 0.0, sin(_phase) * _stride)
	_ray.global_position = _hip.global_position + Vector3(wanted.x, 0.0, wanted.z)
	_ray.force_raycast_update()
	var ground_y := 0.0
	if _ray.is_colliding():
		ground_y = _ray.get_collision_point().y
	var target := Vector3(wanted.x, ground_y + 0.15 - _hip.position.y, wanted.z)

	# The pole: in front of the rig, so the knee bends forwards like a knee.
	var pole := Vector3(0.0, 0.0, -3.0)
	var solution := LimbSolver.solve(Vector3.ZERO, target, UPPER, LOWER, pole)

	_place(_thigh, Vector3.ZERO, solution.joint, UPPER)
	_place(_shin, solution.joint, solution.foot, LOWER)
	_knee_marker.position = solution.joint
	_foot.position = _hip.position + solution.foot

	_status.text = "hip %.2f m   stride %.1f   reach %.2f   distance %.2f   knee %.0f°   %s" % [
		_hip_height, _stride, LimbSolver.reach_of(UPPER, LOWER), target.length(),
		rad_to_deg(solution.bend),
		"reaching" if solution.reachable else "OUT OF REACH — leg straightened"]

## Put a capsule between two points, pointing along its own Y like a bone.
func _place(bone: MeshInstance3D, from: Vector3, to: Vector3, length: float) -> void:
	bone.position = (from + to) * 0.5
	var along := to - from
	if along.length() < 0.0001:
		return
	# The mesh is a capsule standing on Y, so the basis is built around its Y.
	var up := along.normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.0001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	bone.basis = Basis(side, up, side.cross(up)).orthonormalized()
	bone.scale = Vector3(1.0, along.length() / maxf(length, 0.0001), 1.0)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _hip_height = maxf(_hip_height - 0.15, 0.6)
		KEY_2: _hip_height = minf(_hip_height + 0.15, 3.2)
		KEY_3: _stride = maxf(_stride - 0.2, 0.2)
		KEY_4: _stride = minf(_stride + 0.2, 2.6)
		KEY_SPACE: _running = not _running
		_: return
