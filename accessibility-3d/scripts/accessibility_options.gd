class_name AccessibilityOptions
extends RefCounted

## The options that decide whether the game is playable, held in one place.
##
## Accessibility work goes wrong in the same way every time: it is implemented
## as special cases scattered through the systems it affects. A check for
## "reduced motion" inside the camera shake, another inside the head bob,
## another inside the hit reaction — and the fourth one, added six months later,
## does not have the check.
##
## The alternative is that this object holds the answers and everything else
## *reads* them. Shake asks for a motion scale and multiplies by it. Anything
## that picks a colour asks for a role rather than choosing red. Nothing needs a
## conditional, so nothing can forget one.
##
## Two things worth knowing about the specifics:
##
##   * **Reduced motion is a scale, not a switch.** Some players want less rather
##     than none, and a scale covers both without a second option.
##   * **Colour-blind support is not a filter over the screen.** It is choosing
##     colours that differ in *lightness* as well as hue, so they survive being
##     seen without colour at all — which is also what makes them survive a bad
##     monitor, a bright room, and a screenshot in a bug report.

signal changed()

enum Colours {
	NORMAL,
	DEUTERANOPIA,   ## red/green, the common one
	TRITANOPIA,     ## blue/yellow
	HIGH_CONTRAST,  ## no colour cue at all: lightness only
}

## What the game's cue colours mean, rather than what they are.
enum Role { FRIEND, ENEMY, NEUTRAL, OBJECTIVE }

## 0 turns motion effects off entirely, 1 leaves them as authored.
var motion := 1.0:
	set(value):
		motion = clampf(value, 0.0, 1.0)
		changed.emit()

var subtitles := true:
	set(value):
		subtitles = value
		changed.emit()

## Multiplies the subtitle font size.
var text_scale := 1.0:
	set(value):
		text_scale = clampf(value, 0.75, 3.0)
		changed.emit()

var colours := Colours.NORMAL:
	set(value):
		colours = value
		changed.emit()


## The scale to multiply a camera shake, a head bob or a hit reaction by.
##
## Everything that moves the view reads this. Nothing tests a boolean.
func motion_scale() -> float:
	return motion


## True when motion effects are off entirely, for the few things that cannot be
## scaled — a screen-space blur, say, which is either on or not.
func motion_disabled() -> bool:
	return motion <= 0.001


## The colour to draw something of this role in.
##
## Roles, not colours: a system that asks for "the enemy colour" keeps working
## when the palette changes, and one that asks for red does not.
func colour_for(role: Role) -> Color:
	match colours:
		Colours.DEUTERANOPIA:
			# Red and green are the pair that merges, so the cues move to blue
			# and orange — and, more importantly, are spaced in lightness:
			# 0.48, 0.33, 0.80, 0.94.
			return [Color(0.25, 0.5, 1.0), Color(0.7, 0.25, 0.0),
				Color(0.8, 0.8, 0.82), Color(1.0, 0.95, 0.6)][role]
		Colours.TRITANOPIA:
			# Blue and yellow merge here, so the hues move to teal and red —
			# again at four separated lightnesses: 0.49, 0.35, 0.80, 0.93.
			return [Color(0.1, 0.6, 0.55), Color(0.85, 0.2, 0.3),
				Color(0.8, 0.8, 0.8), Color(1.0, 0.93, 0.7)][role]
		Colours.HIGH_CONTRAST:
			# No hue cue at all: four steps of lightness, which is what every
			# palette above has to survive being reduced to anyway.
			return [Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.15),
				Color(0.55, 0.55, 0.55), Color(0.78, 0.78, 0.78)][role]
		_:
			# Even the default palette is spaced by lightness: 0.59, 0.30,
			# 0.75, 0.88. Green and red at the same brightness are the
			# commonest accessibility bug in games.
			return [Color(0.3, 0.7, 0.35), Color(0.85, 0.15, 0.15),
				Color(0.75, 0.75, 0.78), Color(1.0, 0.9, 0.35)][role]


## Perceived lightness of a colour, 0..1.
##
## Weighted for how the eye actually responds — green looks far brighter than
## blue at the same value, which is why a naive average passes palettes that are
## indistinguishable in practice.
static func luminance(colour: Color) -> float:
	return colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722


## How far apart two colours are in lightness alone.
##
## The honest test for a cue palette: if two roles are only distinguishable by
## hue, a player who cannot see that hue cannot tell them apart, and neither can
## anyone looking at a greyscale screenshot.
static func lightness_gap(a: Color, b: Color) -> float:
	return absf(luminance(a) - luminance(b))


## The font size a subtitle should be drawn at.
func subtitle_size(base: int) -> int:
	return maxi(int(round(float(base) * text_scale)), 1)


func to_dictionary() -> Dictionary:
	return {
		"motion": motion,
		"subtitles": subtitles,
		"text_scale": text_scale,
		"colours": int(colours),
	}


## Restore settings, ignoring anything unrecognised.
##
## A settings file outlives the build that wrote it, and a player who loses their
## accessibility options to a patch has lost more than a preference.
func load_from(data: Dictionary) -> void:
	if data.has("motion"):
		motion = float(data["motion"])
	if data.has("subtitles"):
		subtitles = bool(data["subtitles"])
	if data.has("text_scale"):
		text_scale = float(data["text_scale"])
	if data.has("colours"):
		var value := int(data["colours"])
		if value >= 0 and value < Colours.size():
			colours = value as Colours


func reset() -> void:
	motion = 1.0
	subtitles = true
	text_scale = 1.0
	colours = Colours.NORMAL
