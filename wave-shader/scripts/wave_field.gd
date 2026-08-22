class_name WaveField
extends RefCounted

## The height of a water surface, in GDScript — deliberately duplicating the
## shader that draws it.
##
## A vertex shader can move a surface beautifully and cannot tell anyone where it
## went. The GPU has the answer and the CPU needs it: a boat has to sit on the
## water, a buoy has to bob, a splash has to happen at the surface rather than at
## y = 0. So the maths exists twice, once in `res://shaders/water.gdshader` and
## once here.
##
## Duplication is the cost, and drift is the risk. The mitigation is that
## **neither copy owns the numbers**: this object does, and `apply_to()` pushes
## them into the shader. Nothing sets a uniform by hand, so the two can differ in
## language but not in parameters — which is the failure that actually happens.
## The suite checks that every uniform matches the field it came from.
##
## The waves are a sum of directional sines. Real water uses Gerstner waves,
## which also move points horizontally; sines are enough to float things on and
## are far easier to read.

## One wave: how tall, how long, how fast, and which way it travels.
class Wave extends RefCounted:
	var amplitude: float
	var wavelength: float
	var speed: float
	var direction: Vector2

	func _init(wave_amplitude: float, wave_length: float, wave_speed: float,
			wave_direction: Vector2) -> void:
		amplitude = wave_amplitude
		wavelength = maxf(wave_length, 0.001)
		speed = wave_speed
		direction = wave_direction.normalized() if wave_direction.length() > 0.0 \
			else Vector2.RIGHT


var waves: Array[Wave] = []

## Scales every wave at once, for a calm sea or a rough one.
var swell := 1.0


func _init(preset: bool = true) -> void:
	if preset:
		# Three waves at different scales and angles. Two is not enough to stop
		# the pattern looking like corrugated iron; four is not noticeably
		# better than three.
		waves = [
			Wave.new(0.42, 9.0, 1.1, Vector2(1.0, 0.25)),
			Wave.new(0.24, 5.0, 1.6, Vector2(-0.4, 1.0)),
			Wave.new(0.10, 2.3, 2.4, Vector2(0.8, -0.7)),
		]


## The surface height at a point, at a time.
func height_at(x: float, z: float, time: float) -> float:
	var height := 0.0
	for wave in waves:
		var k := TAU / wave.wavelength
		var phase := (wave.direction.x * x + wave.direction.y * z) * k + time * wave.speed * k
		height += sin(phase) * wave.amplitude
	return height * swell


## The surface normal, from the slope either side of a point.
##
## Sampled rather than differentiated analytically: the same trick as the terrain
## demo, and it keeps working when the wave set changes.
func normal_at(x: float, z: float, time: float, step: float = 0.25) -> Vector3:
	var dx := height_at(x + step, z, time) - height_at(x - step, z, time)
	var dz := height_at(x, z + step, time) - height_at(x, z - step, time)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


## The tallest the surface can possibly be, for a camera or a bounding box.
func crest_height() -> float:
	var total := 0.0
	for wave in waves:
		total += wave.amplitude
	return total * swell


## Push every parameter into the shader that draws the same water.
##
## The one function that matters. Both sides of the duplication read their
## numbers from here, so they can disagree in language but not in configuration.
func apply_to(material: ShaderMaterial) -> void:
	if material == null:
		return
	var amplitudes := PackedFloat32Array()
	var wavelengths := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	var directions := PackedVector2Array()
	for wave in waves:
		amplitudes.append(wave.amplitude)
		wavelengths.append(wave.wavelength)
		speeds.append(wave.speed)
		directions.append(wave.direction)
	material.set_shader_parameter("wave_count", waves.size())
	material.set_shader_parameter("amplitudes", amplitudes)
	material.set_shader_parameter("wavelengths", wavelengths)
	material.set_shader_parameter("speeds", speeds)
	material.set_shader_parameter("directions", directions)
	material.set_shader_parameter("swell", swell)


## Read the parameters back out of a material, for checking they agree.
static func parameters_of(material: ShaderMaterial) -> Dictionary:
	if material == null:
		return {}
	return {
		"wave_count": material.get_shader_parameter("wave_count"),
		"amplitudes": material.get_shader_parameter("amplitudes"),
		"wavelengths": material.get_shader_parameter("wavelengths"),
		"speeds": material.get_shader_parameter("speeds"),
		"directions": material.get_shader_parameter("directions"),
		"swell": material.get_shader_parameter("swell"),
	}
