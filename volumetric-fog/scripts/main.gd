extends Node3D

# Demo driver. Pillars marching away into fog, a lamp with a shaft in it, and a
# readout that says how far you can actually see. The model is in
# scripts/volumetrics.gd.

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _lamp: OmniLight3D = $Lamp
@onready var _camera: Camera3D = $Camera3D
@onready var _pillars: Node3D = $Pillars
@onready var _hint: Label = $HUD/TitleLabel
@onready var _readout: Label = $HUD/ReadoutLabel
@onready var _status: Label = $HUD/StatusLabel

var _density := 0.03
var _length := 64.0
var _shafts := true
var _time := 0.0

func _ready() -> void:
	_hint.text = "1/2 density   3/4 fog length   S light shafts   F fog on or off   R defaults"
	_apply()

func _apply() -> void:
	var environment := _environment.environment
	environment.volumetric_fog_density = _density
	environment.volumetric_fog_length = _length
	# The part everyone misses: a light contributes to the fog volume only if it
	# is told to. Without this the fog is a grey soup with no shafts in it, and
	# nothing says why.
	var energy := 1.0 if _shafts else 0.0
	_sun.light_volumetric_fog_energy = energy
	_lamp.light_volumetric_fog_energy = energy * 2.0
	_show()

func _process(delta: float) -> void:
	_time += delta
	_lamp.position.x = sin(_time * 0.4) * 5.0
	_show()

func _show() -> void:
	var environment := _environment.environment
	var visible_distance := Volumetrics.visibility(_density)
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))

	var furthest := 0.0
	for pillar in _pillars.get_children():
		furthest = maxf(furthest,
			_camera.global_position.distance_to((pillar as Node3D).global_position))

	_readout.text = "density %.3f per metre — you can see about %.0f m\nfog volume reaches %.0f m; the furthest pillar is %.0f m away (%.0f%% of the volume)\nlight shafts %s" % [
		_density, visible_distance, _length, furthest,
		Volumetrics.within_volume(furthest, _length) * 100.0,
		"on" if _shafts else "off — the fog has no light in it"]
	_status.text = "%s   %s   half the light survives %.0f m; a tenth survives %.0f m" % [
		"volumetric fog on" if environment.volumetric_fog_enabled else "volumetric fog off",
		"Forward+" if Volumetrics.supported(method) else "%s — volumetric fog is ignored here" % method,
		Volumetrics.visibility(_density, 0.5), Volumetrics.visibility(_density, 0.1)]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_density = maxf(_density - 0.01, 0.0)
		KEY_2:
			_density = minf(_density + 0.01, 0.3)
		KEY_3:
			_length = maxf(_length - 16.0, 16.0)
		KEY_4:
			_length = minf(_length + 16.0, 256.0)
		KEY_S:
			_shafts = not _shafts
		KEY_F:
			_environment.environment.volumetric_fog_enabled = \
				not _environment.environment.volumetric_fog_enabled
		KEY_R:
			_density = 0.03
			_length = 64.0
			_shafts = true
			_environment.environment.volumetric_fog_enabled = true
		_:
			return
	_apply()
