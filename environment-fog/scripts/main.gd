extends Node3D

# Demo driver. Runs a clock and pushes SkyCycle's answers into a
# WorldEnvironment and a DirectionalLight3D.

const DEFAULT_SPEED := 0.5      ## hours per second

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _hours := 6.5
var _speed := DEFAULT_SPEED
var _running := true

func _ready() -> void:
	_hint.text = "1/2 wind the clock   3/4 slower or faster   Space pause   F fog on/off"
	_apply()

func _process(delta: float) -> void:
	if _running:
		_hours = SkyCycle.normalise(_hours + _speed * delta)
	_apply()

func _apply() -> void:
	# One clock in, every sky property out. Nothing here decides anything: if
	# the sunset looks wrong, it is wrong in sky_cycle.gd, where it can be
	# tested rather than eyeballed.
	_sun.rotation = Vector3.ZERO
	_sun.look_at_from_position(Vector3.ZERO, SkyCycle.sun_direction(_hours), Vector3.UP)
	_sun.light_energy = SkyCycle.sun_energy(_hours)
	_sun.light_color = SkyCycle.sun_colour(_hours)
	# A light with zero energy still renders its shadow map. Switching shadows
	# off with the sun is free and saves the whole pass overnight.
	_sun.shadow_enabled = _sun.light_energy > 0.01

	var environment := _environment.environment
	var horizon := SkyCycle.horizon_colour(_hours)
	environment.ambient_light_energy = SkyCycle.ambient_energy(_hours)
	environment.ambient_light_color = horizon
	environment.fog_light_color = horizon
	environment.fog_density = SkyCycle.fog_density(_hours)
	environment.background_color = horizon

	_status.text = "%s   %s   sun %.2f   ambient %.2f   fog %.3f   x%.1f" % [
		SkyCycle.clock(_hours),
		"day" if SkyCycle.is_daytime(_hours) else "night",
		_sun.light_energy, environment.ambient_light_energy, environment.fog_density,
		_speed / DEFAULT_SPEED]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _hours = SkyCycle.normalise(_hours - 1.0)
		KEY_2: _hours = SkyCycle.normalise(_hours + 1.0)
		KEY_3: _speed = maxf(_speed * 0.5, DEFAULT_SPEED * 0.125)
		KEY_4: _speed = minf(_speed * 2.0, DEFAULT_SPEED * 16.0)
		KEY_SPACE: _running = not _running
		KEY_F:
			var environment := _environment.environment
			environment.fog_enabled = not environment.fog_enabled
		_: return
	_apply()
