extends Node3D

# Demo driver. Nudges the curve at runtime so the rebuild is visible without an
# editor, and reports what the tool script produced.

@onready var _fence = $FenceBuilder
@onready var _path: Path3D = $FenceBuilder/Path3D
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _time := 0.0
var _animating := true

func _ready() -> void:
	_hint.text = "1/2 spacing   3/4 rails   Space animate the curve   (open it in the editor too)"

func _process(delta: float) -> void:
	if _animating:
		# Moving a curve point is what dragging it in the editor does; the fence
		# follows either way.
		_time += delta
		_path.curve.set_point_position(1, Vector3(0.0, 0.0, -4.0 + sin(_time) * 2.5))
		_fence.rebuild_now = true

	var length := _path.curve.get_baked_length()
	_status.text = "%.1f m of fence   %d posts   spacing %.2f m (asked for %.2f)   %d nodes" % [
		length, FencePlan.post_count(length, _fence.spacing),
		FencePlan.fitted_spacing(length, _fence.spacing), _fence.spacing,
		_fence.generated_count()]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _fence.spacing -= 0.25
		KEY_2: _fence.spacing += 0.25
		KEY_3: _fence.rails -= 1
		KEY_4: _fence.rails += 1
		KEY_SPACE: _animating = not _animating
		_: return
