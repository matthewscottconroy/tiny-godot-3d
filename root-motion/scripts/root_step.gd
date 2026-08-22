class_name RootStep
extends RefCounted

## Turning the motion baked into an animation into motion in the world.
##
## Normally a character moves because code moved it, and the walk cycle is
## decoration played on top. The feet slide, because the animation's stride and
## the code's speed have no reason to agree.
##
## Root motion inverts that: the animation moves the root bone, the game reads
## how far it moved this frame, and *that* is the character's velocity. The feet
## cannot slide, because the feet are what decides the speed.
##
## The price is control. A clip that says "step forward 0.6 metres" says it
## whatever the player wanted, so anything that needs to respond immediately —
## a dodge, a knockback, a platformer jump — fights it. Root motion suits
## deliberate movement: melee attacks, mounting a ladder, a heavy character.
##
## Three things about the mechanics catch people:
##
##   * **The value is already per-frame.** `get_root_motion_position()` returns
##     how far the root moved *since the last call*, not a velocity. Multiplying
##     it by delta a second time is the classic bug: motion that is correct at
##     60fps and eight times slower at 8fps.
##   * **It is in the character's local space.** Turn the character and the same
##     clip has to push a different way.
##   * **You must consume it exactly once per frame.** Reading it twice gives the
##     second reader nothing.

## Where a local root-motion step lands in the world.
##
## The basis is the character's, so a clip that walks forward walks wherever the
## character is facing.
static func world_step(local_step: Vector3, basis: Basis) -> Vector3:
	return basis * local_step


## The velocity to hand to `move_and_slide()` for this step.
##
## The step is already the distance for this frame, so this divides rather than
## multiplies. Getting that backwards is the bug that only shows up on a
## different machine.
static func velocity_for(local_step: Vector3, basis: Basis, delta: float) -> Vector3:
	if delta <= 0.0:
		return Vector3.ZERO
	return world_step(local_step, basis) / delta


## How fast the clip itself is asking to move, in metres per second.
static func clip_speed(local_step: Vector3, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	return local_step.length() / delta


## Is the clip asking for any movement at all?
##
## An idle clip's root does not sit perfectly still — it breathes — so this is a
## threshold rather than a comparison with zero.
static func is_moving(local_step: Vector3, epsilon: float = 0.0005) -> bool:
	return local_step.length() > epsilon


## How fast to play the clip so its stride matches the speed you want.
##
## The honest way to make a root-motion character go faster: play the walk
## quicker, so the feet still land where the movement says they do. Scaling the
## *translation* instead is where sliding comes back.
static func playback_scale(clip_metres_per_second: float, wanted: float,
		slowest: float = 0.5, fastest: float = 2.0) -> float:
	if clip_metres_per_second <= 0.0001:
		return 1.0
	return clampf(wanted / clip_metres_per_second, slowest, fastest)


## Mix clip-driven motion with code-driven motion.
##
## `authority` is how much of the movement the animation owns: 1 is pure root
## motion, 0 is the ordinary character controller, and in between is where most
## games live — a locked attack animation that can still be steered a little.
static func blend(root_velocity: Vector3, input_velocity: Vector3,
		authority: float) -> Vector3:
	return input_velocity.lerp(root_velocity, clampf(authority, 0.0, 1.0))
