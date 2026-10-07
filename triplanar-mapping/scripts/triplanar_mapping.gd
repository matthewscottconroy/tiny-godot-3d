class_name Triplanar
extends RefCounted

## Projecting a texture from three axes at once, and blending by the normal.
##
## A terrain's UVs usually come from its X and Z: easy to generate, and correct
## as long as the ground is roughly flat. On a cliff it is a disaster. A vertical
## face has almost no extent in X or Z, so the whole height of it samples a
## sliver of the texture and smears it downwards — the "melted candle" look that
## every heightmap terrain has somewhere in it.
##
## Triplanar mapping stops deriving UVs from the surface at all. It projects the
## texture three times — down the X axis, down the Y axis, down the Z axis —
## using *world position* rather than UV, and blends the three by how much the
## surface faces each axis. A wall takes its texture from the projection that
## faces it, so nothing stretches, and the seams between projections fall where
## the blend is even.
##
## The cost is real and worth stating: three samples per texture instead of one.
## It is why this is normally used on terrain and rock and not on everything.
##
## The maths lives here rather than only in the shader so the suite can state
## it, and so anything on the CPU that needs to agree with what is drawn — a
## footstep sound picking a surface, a decal choosing an orientation — can ask
## the same question and get the same answer.

## Which axis a surface faces most: 0 for X, 1 for Y, 2 for Z.
##
## The projection a triplanar blend leans on hardest, and on its own the cheap
## approximation: pick one axis and skip the blend. That is visibly wrong at the
## 45° edges, which is what the blend below exists to fix.
static func dominant_axis(normal: Vector3) -> int:
	var a := normal.abs()
	if a.x >= a.y and a.x >= a.z:
		return 0
	return 1 if a.y >= a.z else 2


## How much each of the three projections contributes, as x/y/z summing to one.
##
## `sharpness` decides how quickly one projection takes over from another. At 1
## the blend is a broad wash and a 45° face is a mush of two projections; high
## values tighten it towards a hard seam. Between 4 and 8 is the usual range.
##
## A zero-length normal has no axis to favour, so it falls back to the upward
## projection rather than dividing by zero — geometry with a degenerate normal
## should look like ground, not like a hole.
static func weights(normal: Vector3, sharpness: float = 4.0) -> Vector3:
	var a := normal.normalized().abs()
	if a.length() < 0.0001:
		return Vector3(0.0, 1.0, 0.0)
	var w := Vector3(pow(a.x, sharpness), pow(a.y, sharpness), pow(a.z, sharpness))
	var total := w.x + w.y + w.z
	if total <= 0.0001:
		return Vector3(0.0, 1.0, 0.0)
	return w / total


## The texture coordinate one of the three projections reads, from world space.
##
## Each projection drops the axis it looks along and uses the other two, which
## is the whole reason nothing stretches: a vertical wall is sampled by a
## projection that still sees its full height.
static func planar_uv(world_position: Vector3, axis: int, scale: float = 1.0) -> Vector2:
	match axis:
		0:
			return Vector2(world_position.z, world_position.y) * scale
		1:
			return Vector2(world_position.x, world_position.z) * scale
		_:
			return Vector2(world_position.x, world_position.y) * scale


## How far a flat top-down UV stretches the texture at this normal.
##
## This is the number the demo exists to make visible. A top-down projection
## covers `|n.y|` of a surface's true area per unit of texture, so the texture is
## stretched by `1 / |n.y|` — 1 on flat ground, 1.41 on a 45° slope, and
## unbounded as the surface approaches vertical. Clamped, because "infinity" is
## not something to put on a HUD.
static func stretch_factor(normal: Vector3, limit: float = 99.0) -> float:
	var up := absf(normal.normalized().y)
	if up < 1.0 / limit:
		return limit
	return minf(1.0 / up, limit)


## Is a flat UV good enough here?
##
## Below this slope the stretch is small enough that the extra samples buy
## nothing, which is the judgement an adopter actually has to make.
static func needs_triplanar(normal: Vector3, tolerance: float = 1.3) -> bool:
	return stretch_factor(normal) > tolerance
