extends Node3D

# Demo driver. A shaking camera, four role-coloured markers and a subtitle bar,
# all reading their settings from one options object.

@onready var _shaker: Node3D = $Rig/Shaker
@onready var _markers: Node3D = $Markers
@onready var _subtitle: Label = $HUD/Subtitle
@onready var _options_list: Label = $HUD/OptionList
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _options := AccessibilityOptions.new()
var _noise := FastNoiseLite.new()
var _time := 0.0
var _line := 0

const PALETTE_NAMES := ["default", "deuteranopia", "tritanopia", "high contrast"]

const LINES := [
	"Something moves in the dark.",
	"[door creaks open]",
	"\"Anyone there?\"",
	"[distant machinery]",
]

func _ready() -> void:
	_hint.text = "1/2 motion   3 subtitles   4 text size   C colour mode   R defaults"
	_noise.seed = 3
	# Everything that reads a setting reacts to one signal, rather than each
	# system polling for changes.
	_options.changed.connect(_apply)
	_apply()

func _apply() -> void:
	for i in _markers.get_child_count():
		var marker := _markers.get_child(i) as MeshInstance3D
		var material := marker.material_override as StandardMaterial3D
		if material != null:
			# Roles, not colours: this line never changes when the palette does.
			material.albedo_color = _options.colour_for(i as AccessibilityOptions.Role)
	_subtitle.visible = _options.subtitles
	_subtitle.add_theme_font_size_override("font_size", _options.subtitle_size(20))
	_options_list.text = "motion %.0f%%   subtitles %s   text %.2fx   palette %s" % [
		_options.motion * 100.0, "on" if _options.subtitles else "off",
		_options.text_scale, PALETTE_NAMES[_options.colours]]

func _process(delta: float) -> void:
	_time += delta
	if int(_time) % 4 == 0 and _line != int(_time / 4.0) % LINES.size():
		_line = int(_time / 4.0) % LINES.size()
		_subtitle.text = LINES[_line]

	# The camera shake asks for a scale and multiplies. There is no test for
	# "reduced motion" here, which is exactly the point — a system that has to
	# remember to check is a system that will forget.
	var scale := _options.motion_scale()
	_shaker.position = Vector3(
		_noise.get_noise_2d(_time * 40.0, 0.0),
		_noise.get_noise_2d(_time * 40.0, 100.0),
		0.0) * 0.25 * scale
	_shaker.rotation.z = _noise.get_noise_2d(_time * 30.0, 200.0) * 0.05 * scale

	var worst := _worst_lightness_gap()
	_status.text = "shake %.3f m   closest two cue colours differ by %.2f in lightness%s" % [
		_shaker.position.length(), worst,
		"" if worst > 0.12 else "   — too close to tell apart without colour"]

## How distinguishable the current palette is without colour at all.
func _worst_lightness_gap() -> float:
	var worst := 1.0
	for a in 4:
		for b in range(a + 1, 4):
			worst = minf(worst, AccessibilityOptions.lightness_gap(
				_options.colour_for(a as AccessibilityOptions.Role),
				_options.colour_for(b as AccessibilityOptions.Role)))
	return worst

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _options.motion = _options.motion - 0.25
		KEY_2: _options.motion = _options.motion + 0.25
		KEY_3: _options.subtitles = not _options.subtitles
		KEY_4: _options.text_scale = 1.0 if _options.text_scale > 1.4 else _options.text_scale + 0.25
		KEY_C: _options.colours = ((_options.colours + 1) % AccessibilityOptions.Colours.size()) \
			as AccessibilityOptions.Colours
		KEY_R: _options.reset()
		_: return
