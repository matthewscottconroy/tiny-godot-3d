class_name Hearing
extends RefCounted

## How loud a sound is at a distance, and whether anything can hear it.
##
## `AudioStreamPlayer3D` already applies an attenuation curve — that is what it
## is for. The reason to write the curve down as well is that **the game usually
## needs to know the same answer**: whether the guard heard the footstep, whether
## the alarm reaches the next room, whether a sound is worth playing at all.
##
## Written twice, those two answers drift, and the bug is horrible: the player
## hears something the AI does not react to, or is caught by a guard who cannot
## possibly have heard them. Written once — here — the mixer and the game agree
## by construction, and the demo's job is to keep the two in step.
##
## The models below mirror `AudioStreamPlayer3D.AttenuationModel`. They are not
## bit-exact reproductions of the mixer's internals; they are the same curves, so
## a threshold chosen against one holds against the other.

enum Model {
	INVERSE,            ## halve the distance, double the loudness
	INVERSE_SQUARE,     ## physically correct for a point source
	LOGARITHMIC,        ## gentler; keeps distant sounds present
	DISABLED,           ## no falloff at all
}

## Below this many decibels a sound is treated as silent. -60 dB is a thousandth
## of the amplitude: present in the mix in a technical sense, and inaudible.
const SILENCE_DB := -60.0


## Linear gain (0..1) at `distance`, for a source whose `unit_size` is the
## distance at which it plays at full volume.
static func gain_at(distance: float, unit_size: float, max_distance: float,
		model: Model = Model.INVERSE) -> float:
	if max_distance > 0.0 and distance >= max_distance:
		return 0.0                        # the hard cutoff, same as the node's
	if model == Model.DISABLED:
		return 1.0
	# Inside the unit sphere a source is at full volume rather than infinitely
	# loud — the division below would otherwise run away as distance → 0.
	var scaled := maxf(distance, 0.0) / maxf(unit_size, 0.0001)
	if scaled <= 1.0:
		return 1.0
	match model:
		Model.INVERSE_SQUARE:
			return 1.0 / (scaled * scaled)
		Model.LOGARITHMIC:
			# Halves roughly every doubling of distance, but never as steeply as
			# inverse-square, which is why it is the usual choice for music and
			# ambience.
			return maxf(1.0 - log(scaled) / log(30.0), 0.0)
		_:
			return 1.0 / scaled


## The same, in decibels — the unit mixers and volume sliders actually use.
static func db_at(distance: float, unit_size: float, max_distance: float,
		model: Model = Model.INVERSE) -> float:
	var gain := gain_at(distance, unit_size, max_distance, model)
	return SILENCE_DB if gain <= 0.0 else maxf(linear_to_db(gain), SILENCE_DB)


## Can a listener at `distance` hear this at all?
##
## The question the AI should be asking, with the same curve the player is
## hearing. `threshold_db` is how good the listener's ears are: raise it for a
## distracted guard, lower it for one who is listening for you.
static func is_audible(distance: float, unit_size: float, max_distance: float,
		model: Model = Model.INVERSE, threshold_db: float = -40.0) -> bool:
	return db_at(distance, unit_size, max_distance, model) > threshold_db


## How far away a sound of this shape stops being audible.
##
## Useful for the reverse question: how far the noise you are about to make will
## carry, before making it.
static func range_of(unit_size: float, max_distance: float, model: Model = Model.INVERSE,
		threshold_db: float = -40.0, step: float = 0.25) -> float:
	var limit := max_distance if max_distance > 0.0 else 1000.0
	var distance := 0.0
	while distance < limit:
		if not is_audible(distance, unit_size, max_distance, model, threshold_db):
			return distance
		distance += step
	return limit


## Pitch multiplier from relative motion — the Doppler effect.
##
## `closing_speed` is positive when source and listener are approaching. Godot's
## own doppler tracking does this for the mixer; this is for anything else that
## should agree with it.
static func doppler(closing_speed: float, speed_of_sound: float = 343.0) -> float:
	if speed_of_sound <= 0.0:
		return 1.0
	# Clamped because a source moving at or past the speed of sound is a
	# division by zero followed by a negative pitch.
	var ratio := clampf(closing_speed / speed_of_sound, -0.9, 0.9)
	return 1.0 / (1.0 - ratio)


## How fast two things are closing, along the line between them.
static func closing_speed(source_position: Vector3, source_velocity: Vector3,
		listener_position: Vector3, listener_velocity: Vector3) -> float:
	var to_listener := listener_position - source_position
	if to_listener.length_squared() < 0.000001:
		return 0.0
	var direction := to_listener.normalized()
	return source_velocity.dot(direction) - listener_velocity.dot(direction)
