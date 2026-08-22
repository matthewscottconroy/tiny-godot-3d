class_name Refraction
extends RefCounted

## The arithmetic behind a shader that reads the screen, kept where the game can
## reach it too.
##
## `SCREEN_TEXTURE` — `hint_screen_texture` in Godot 4 — is what glass, heat haze
## and cloaking are made of: sample the frame behind this surface, offset by
## something, and draw that instead. It is cheap compared with a second camera,
## and it comes with one hard limitation:
##
## **The screen it reads is the frame *before* this object was drawn.** So a
## refracting object cannot see itself, cannot see another refracting object
## drawn after it, and cannot see anything the depth prepass has not resolved.
## Two panes of glass in a row is the case everyone tries, and the second pane
## shows the world without the first.
##
## The maths below is small on purpose. It lives here rather than only in the
## shader because a game that wants to *agree* with what it is drawing — a
## bullet that bends where the glass bends it, a heat shimmer that matches a
## damage radius — needs the same numbers on the CPU.

## How far, in screen units, to sample behind a surface with this normal.
##
## The normal's screen-space X and Y are the direction; a surface facing the
## camera bends nothing, which is why glass looks like glass at the edges and
## like a window in the middle.
static func screen_offset(view_normal: Vector3, strength: float) -> Vector2:
	return Vector2(view_normal.x, view_normal.y) * strength


## The offset corrected for a non-square viewport.
##
## Without this, glass refracts further sideways than vertically on a wide
## screen, and the effect stretches when the player resizes the window.
static func aspect_corrected(offset: Vector2, viewport: Vector2i) -> Vector2:
	if viewport.y <= 0:
		return offset
	var aspect := float(viewport.x) / float(viewport.y)
	if aspect <= 0.0:
		return offset
	return Vector2(offset.x / aspect, offset.y)


## Schlick's approximation: how reflective a surface is at this viewing angle.
##
## Edge-on, everything is a mirror. Face-on, glass is nearly invisible. Getting
## this in is most of the difference between "transparent object" and "glass".
static func fresnel(view_direction: Vector3, normal: Vector3, power: float = 5.0) -> float:
	var facing := absf(view_direction.normalized().dot(normal.normalized()))
	return pow(1.0 - facing, power)


## Where a point behind the glass appears to be, in screen coordinates.
##
## The CPU half: what the shader draws, in numbers the game can use.
static func apparent_position(screen_point: Vector2, view_normal: Vector3,
		strength: float, viewport: Vector2i) -> Vector2:
	return screen_point + aspect_corrected(
		screen_offset(view_normal, strength), viewport) * Vector2(viewport)


## Can a surface at this depth refract a surface at that one?
##
## No, if the other one is drawn later: the screen texture is the frame before
## this object, so anything drawn after it is simply not in the picture. This is
## the rule that makes two panes of glass in a row disappointing.
static func can_refract(this_depth: float, other_depth: float) -> bool:
	return other_depth > this_depth


## The strength to use at a distance, so distant glass does not shimmer.
##
## A large screen-space offset on something a few pixels across samples half the
## screen, which reads as noise rather than as glass.
static func strength_at(distance: float, base: float, fades_from: float = 8.0) -> float:
	if distance <= fades_from:
		return base
	return base * clampf(fades_from / maxf(distance, 0.0001), 0.0, 1.0)
