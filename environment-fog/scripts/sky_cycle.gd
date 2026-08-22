class_name SkyCycle
extends RefCounted

## The whole sky as a function of one number: the hour of the day.
##
## A `WorldEnvironment` has dozens of properties, and a day-night cycle is what
## happens when half a dozen of them are driven together. Written inline in a
## driver that becomes a hundred lines of `lerp` nobody can check; written here
## it is a set of curves with names, and "the sun is up at 6am" is a test rather
## than something you squint at.
##
## Hours run 0..24 and wrap, so 25.0 is 1am and -1.0 is 11pm. Every function
## takes the hour and returns one thing. There is no state at all — which means
## a save file only has to store the clock, and rewinding it is free.

## Sun above the horizon between these hours.
const SUNRISE := 6.0
const SUNSET := 18.0

## How long dawn and dusk take, in hours. The interesting part of the day.
const TWILIGHT := 1.5


## Bring any hour into 0..24.
static func normalise(hours: float) -> float:
	return fposmod(hours, 24.0)


## How high the sun is, from -1 (midnight) through 0 (horizon) to 1 (noon).
##
## A cosine rather than a triangle wave: the sun moves slowly near noon and
## quickly at the horizon, which is what makes a sunset brief and a midday long.
static func sun_height(hours: float) -> float:
	# Written as "lowest at midnight" rather than "highest at noon": the same
	# curve, with no offset in it to get wrong.
	return -cos(normalise(hours) / 24.0 * TAU)


## The direction sunlight travels, as a `DirectionalLight3D` would point.
##
## The sun rises in the east (+X here) and sets in the west, so the light points
## the other way — the vector is where the light is *going*, not where the sun is.
static func sun_direction(hours: float) -> Vector3:
	var angle := (normalise(hours) - 6.0) / 24.0 * TAU
	var position := Vector3(cos(angle), sin(angle), 0.2).normalized()
	return -position


## True while the sun is above the horizon.
static func is_daytime(hours: float) -> bool:
	var hour := normalise(hours)
	return hour >= SUNRISE and hour < SUNSET


## Brightness of the sun, 0 at night rising to 1 in full day.
##
## Zero at night matters: a directional light left at full energy through the
## night gives you a scene lit from below by nothing, which reads as broken
## rather than as dark.
static func sun_energy(hours: float) -> float:
	var hour := normalise(hours)
	# No separate "it is night" branch: both ramps clamp at zero, so night falls
	# out of the same two lines. A third branch that can never change the answer
	# is a third branch to keep correct.
	if hour < SUNRISE + TWILIGHT:
		return clampf((hour - (SUNRISE - TWILIGHT)) / (TWILIGHT * 2.0), 0.0, 1.0)
	if hour > SUNSET - TWILIGHT:
		return clampf(((SUNSET + TWILIGHT) - hour) / (TWILIGHT * 2.0), 0.0, 1.0)
	return 1.0


## The sun's colour: warm at the horizon, white overhead.
##
## Real sunlight reddens near the horizon because it travels through more
## atmosphere. Faking it with a blend toward orange as the sun drops is most of
## what makes a sunset look like one.
static func sun_colour(hours: float) -> Color:
	var high := Color(1.0, 0.98, 0.94)
	var low := Color(1.0, 0.55, 0.28)
	# Full white only well above the horizon; the blend runs over the first
	# third of the sun's climb, where the change is actually visible.
	return low.lerp(high, clampf(sun_height(hours) * 3.0, 0.0, 1.0))


## Ambient light, which is what stops the night being pure black.
##
## Never zero. A scene with no ambient at midnight is not dark, it is invisible,
## and players read that as the game having failed to load.
static func ambient_energy(hours: float) -> float:
	return lerpf(0.08, 0.55, sun_energy(hours))


## Fog thickens overnight and burns off during the day.
static func fog_density(hours: float) -> float:
	return lerpf(0.035, 0.004, sun_energy(hours))


## The colour to tint fog and the sky horizon with.
static func horizon_colour(hours: float) -> Color:
	var night := Color(0.04, 0.05, 0.10)
	var day := Color(0.55, 0.68, 0.85)
	var base := night.lerp(day, sun_energy(hours))
	# Near the horizon the sun's own colour bleeds into the sky. The band is
	# deliberately generous: a sunset that only looks like one for the sixty
	# seconds the sun is exactly on the horizon is a sunset nobody sees.
	var glow := clampf(1.0 - absf(sun_height(hours)) * 2.5, 0.0, 1.0) * sun_energy(hours)
	return base.lerp(sun_colour(hours), glow * 0.85)


## A readable clock, for a HUD.
static func clock(hours: float) -> String:
	var hour := normalise(hours)
	return "%02d:%02d" % [int(hour), int(fposmod(hour * 60.0, 60.0))]
