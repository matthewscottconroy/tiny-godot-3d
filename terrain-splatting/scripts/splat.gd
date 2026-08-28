class_name Splat
extends RefCounted

## Choosing what a patch of terrain is made of, from its height and its slope.
##
## Hand-painting a texture map is what you do when the terrain is authored.
## Generated terrain has to decide for itself, and the rule is almost always the
## same: sand at the water line, grass where it is flat, rock where it is steep,
## snow up high — with rock winning over everything, because a cliff is a cliff
## whatever altitude it is at.
##
## Three things separate splatting that looks like terrain from splatting that
## looks like a contour map:
##
##   * **The weights have to add up to one.** Four materials each contributing
##     0.6 is a surface 2.4 times too bright, and the error is worst exactly
##     where two bands meet.
##   * **Bands need a width.** A hard cutoff at 12 metres draws a line around
##     the hill at 12 metres. Real transitions are metres deep.
##   * **Slope comes from the normal, not from the height.** Two points at the
##     same height can be a plateau or a cliff face, and the height alone cannot
##     tell you which.

## How steep this surface is, in radians from flat.
##
## Zero is level ground, and half pi is a vertical wall.
static func slope_of(normal: Vector3) -> float:
	var up := clampf(normal.normalized().dot(Vector3.UP), -1.0, 1.0)
	return acos(up)


## A smooth 0..1 ramp across a band, rather than a cutoff.
##
## `smoothstep` rather than a comparison: a hard edge at a height draws a line
## around the hill at that height, and terrain does not have lines on it.
static func band(value: float, from: float, to: float) -> float:
	if is_equal_approx(from, to):
		return 0.0 if value < from else 1.0
	return smoothstep(from, to, value)


## The four material weights for a point, before normalising.
##
## Sand, grass, rock, snow. Rock is driven by slope and the others by height,
## which is what makes a cliff look like a cliff at any altitude.
static func raw_weights(height: float, slope: float, water_line: float = 1.5,
		snow_line: float = 12.0, cliff: float = 0.6) -> Color:
	var rock := band(slope, cliff - 0.25, cliff)
	var snow := band(height, snow_line - 3.0, snow_line)
	var sand := 1.0 - band(height, water_line, water_line + 2.0)
	# Grass is what is left over lower down: present in the middle heights and
	# absent at both ends.
	var grass := band(height, water_line, water_line + 2.0) * (1.0 - snow)
	# Rock suppresses the height-driven materials rather than competing with
	# them. Without this a sea cliff comes out half sand — the three of them tie
	# at the water line, and which one wins is down to the order they are
	# compared in.
	var exposed := 1.0 - rock
	return Color(sand * exposed, grass * exposed, rock, snow * exposed)


## The same weights, normalised so they add up to exactly one.
##
## Without this the surface is brighter wherever two materials overlap — which
## is precisely the transition you were trying to make look smooth.
static func normalise(weights: Color) -> Color:
	var total := weights.r + weights.g + weights.b + weights.a
	if total <= 0.0001:
		# Nothing claimed this point. Grass rather than black: a hole in the
		# weights should look like ordinary ground, not like a missing texture.
		return Color(0, 1, 0, 0)
	return Color(weights.r / total, weights.g / total, weights.b / total,
		weights.a / total)


## What a point is made of, ready to hand to a shader.
static func weights_for(height: float, slope: float, water_line: float = 1.5,
		snow_line: float = 12.0, cliff: float = 0.6) -> Color:
	return normalise(raw_weights(height, slope, water_line, snow_line, cliff))


## Which single material dominates here. For footstep sounds, particles, or a
## readout — the things that need one answer rather than four.
static func dominant(weights: Color) -> int:
	var best := 0
	var values := [weights.r, weights.g, weights.b, weights.a]
	for i in 4:
		if values[i] > values[best]:
			best = i
	return best


static func material_name(index: int) -> String:
	return ["sand", "grass", "rock", "snow"][clampi(index, 0, 3)]
