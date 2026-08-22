extends Node3D

# Demo driver. Four translucent panes and one that intersects them, with the
# three transparency modes to switch between.

enum Mode { BLEND, SCISSOR, HASH }

@onready var _panes: Node3D = $Panes
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _pivot: Node3D = $CameraPivot
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _mode := Mode.BLEND
var _sorting := true
var _angle := 0.0
var _orbiting := true

func _ready() -> void:
	_hint.text = "1 blend   2 scissor   3 hash   S manual sort order   Space pause the orbit"
	_apply_mode()

func _process(delta: float) -> void:
	if _orbiting:
		_angle += delta * 0.5
	_pivot.rotation.y = _angle

	var positions: Array[Vector3] = []
	for pane in _panes.get_children():
		positions.append((pane as Node3D).global_position)
	var forward := -_camera.global_transform.basis.z
	var order := AlphaSorter.back_to_front(positions, _camera.global_position, forward)

	if _sorting:
		# Godot sorts transparent objects by priority first, depth second. Only
		# the cases depth cannot express need this — but when they do, nothing
		# else will serve.
		var priorities := AlphaSorter.priorities(order.size())
		for slot in order.size():
			var pane := _panes.get_child(order[slot]) as GeometryInstance3D
			var material := pane.material_override as StandardMaterial3D
			if material != null:
				material.render_priority = priorities[slot]
	else:
		for pane in _panes.get_children():
			var material := (pane as GeometryInstance3D).material_override as StandardMaterial3D
			if material != null:
				material.render_priority = 0

	var furthest := _panes.get_child(order[0]).name
	var clashes := _count_unsortable(forward)
	_status.text = "%s   %s   furthest: %s   %d pair(s) that no order can fix" % [
		_mode_name(), "manual order" if _sorting else "depth order only",
		furthest, clashes]

## How many pairs of panes overlap along the view direction.
##
## Those are the pairs a per-object sort cannot resolve at all: one is in front
## along part of the screen and behind along the rest.
func _count_unsortable(forward: Vector3) -> int:
	var boxes: Array[AABB] = []
	for pane in _panes.get_children():
		var mesh := pane as MeshInstance3D
		boxes.append(mesh.global_transform * mesh.get_aabb())
	var clashes := 0
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if AlphaSorter.depth_ranges_overlap(boxes[i], boxes[j],
					_camera.global_position, forward):
				clashes += 1
	return clashes

func _apply_mode() -> void:
	for pane in _panes.get_children():
		var material := (pane as GeometryInstance3D).material_override as StandardMaterial3D
		if material == null:
			continue
		match _mode:
			Mode.BLEND:
				# The one everyone reaches for: correct colours, no depth
				# writing, and therefore an ordering problem.
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			Mode.SCISSOR:
				# Each pixel is either drawn or not, so it writes depth and
				# sorts itself. Hard edges, no ordering problem at all.
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.5
			Mode.HASH:
				# A dither: still per-pixel, still depth-writing, but noisy
				# rather than hard-edged. Temporal antialiasing cleans it up.
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH

func _mode_name() -> String:
	match _mode:
		Mode.SCISSOR: return "alpha scissor"
		Mode.HASH: return "alpha hash"
		_: return "alpha blend"

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _mode = Mode.BLEND
		KEY_2: _mode = Mode.SCISSOR
		KEY_3: _mode = Mode.HASH
		KEY_S:
			_sorting = not _sorting
			return
		KEY_SPACE:
			_orbiting = not _orbiting
			return
		_: return
	_apply_mode()
