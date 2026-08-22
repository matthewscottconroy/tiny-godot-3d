class_name PushForce
extends RefCounted

## How hard a character shoves what it walks into.
##
## `move_and_slide()` does not push anything. A `CharacterBody3D` walking into a
## crate stops, slides along it, and leaves it exactly where it was — which is
## correct, because a character body is kinematic and the solver has no idea what
## it weighs or how hard it meant to walk.
##
## Making it push is a loop over the slide collisions with an impulse applied to
## whatever was hit. The loop is four lines; what matters is the impulse, and
## there are three ways to get it wrong that all *look* like physics:
##
##   * **Pushing when you were not pushing.** A collision happens whenever two
##     things touch. Only the part of the character's velocity going *into* the
##     surface is a push; standing next to a crate is not.
##   * **Ignoring mass.** A player and a barrel weigh different amounts. Applying
##     the same impulse to both means the barrel flies and the player's shove
##     does nothing to a crate.
##   * **Pushing the floor.** The floor is a collision too. Push it and the
##     character launches itself, which reads as a jump bug rather than as a
##     push bug.

## Slopes flatter than this are floor, not something to shove.
const DEFAULT_MAX_SLOPE := 45.0


## Is this collision something a character should push?
##
## Floors are excluded by slope, and so is anything the character is moving away
## from — a collision that is only a touch.
static func should_push(normal: Vector3, velocity: Vector3,
		max_slope_degrees: float = DEFAULT_MAX_SLOPE) -> bool:
	if normal.length() < 0.0001:
		return false
	var unit := normal.normalized()
	if unit.dot(Vector3.UP) >= cos(deg_to_rad(clampf(max_slope_degrees, 0.0, 90.0))):
		return false                      # walkable: this is the ground
	# The normal points back at the character, so moving into the surface means
	# a negative dot. Zero or positive is standing beside it or walking away.
	return velocity.dot(unit) < -0.01


## The impulse to apply to the body that was hit.
##
## Momentum, not a magic number: the body should end up moving at some share of
## the speed the character was walking into it, and the impulse that produces
## that is `mass x speed`. The share comes from the two masses, so a heavy
## character shifts a light crate briskly and a light one barely moves a heavy
## crate.
##
## `body_velocity` is what stops it running away. A contact lasts many frames,
## and an impulse applied on every one of them accelerates the crate without
## limit — it ends up airborne, which looks like a physics bug and is a loop
## bug. Asking only for the *difference* between the speed the body has and the
## speed it should have makes a sustained shove a steady push.
static func impulse_for(normal: Vector3, velocity: Vector3, character_mass: float,
		body_mass: float, body_velocity: Vector3 = Vector3.ZERO, strength: float = 1.0,
		max_slope_degrees: float = DEFAULT_MAX_SLOPE) -> Vector3:
	if not should_push(normal, velocity, max_slope_degrees):
		return Vector3.ZERO
	var unit := normal.normalized()
	var push := -unit
	# Only the component going into the surface counts. Walking along a wall is
	# a collision every frame and should move nothing.
	var into := -velocity.dot(unit)
	var mass := maxf(body_mass, 0.0001)
	var share := character_mass / (character_mass + mass)
	var wanted := into * share * strength
	var already := body_velocity.dot(push)
	var needed := maxf(wanted - already, 0.0)
	return push * needed * mass


## The same, kept flat.
##
## A character walking into a crate should slide it along the floor, not lift it.
## The vertical component of a wall normal is small but not zero on anything
## sloped, and over a few frames it launches the crate.
static func flat_impulse_for(normal: Vector3, velocity: Vector3, character_mass: float,
		body_mass: float, body_velocity: Vector3 = Vector3.ZERO, strength: float = 1.0,
		max_slope_degrees: float = DEFAULT_MAX_SLOPE) -> Vector3:
	var impulse := impulse_for(normal, velocity, character_mass, body_mass, body_velocity,
		strength, max_slope_degrees)
	return Vector3(impulse.x, 0.0, impulse.z)


## Where to apply the impulse, relative to the body's centre.
##
## `apply_impulse()` takes an offset, and passing the contact point makes the
## crate spin as it slides — which is most of what makes a shove look physical
## rather than like a conveyor belt.
static func offset_of(contact_point: Vector3, body_origin: Vector3,
		max_offset: float = 1.0) -> Vector3:
	var offset := contact_point - body_origin
	if offset.length() > max_offset:
		# A contact point far from the centre means a big lever arm and a crate
		# that spins like a top. Clamping keeps the spin plausible.
		offset = offset.normalized() * max_offset
	return offset
