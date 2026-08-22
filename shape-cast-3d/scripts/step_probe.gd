class_name StepProbe
extends RefCounted

## Telling a step you can walk up from a wall you cannot.
##
## `move_and_slide()` will slide a character along anything it hits, which is
## right for walls and wrong for a 10cm kerb: the character stops dead at a lip
## it should have stepped over, and the complaint is always "the collision is
## broken".
##
## The information needed to tell them apart is in the hit — a surface normal
## and a contact height — and the decision is three comparisons. What makes it
## worth writing down is that the same three comparisons decide *everything*
## about walkability: whether a slope is climbable, whether a lip is a step,
## whether the thing overhead is a ceiling you have just hit your head on.
##
## Why a shape cast rather than a ray: a ray finds the one gap it happens to
## point through. A character is a capsule, and the question is whether *the
## capsule* fits — a doorframe cleared by a millimetre in the middle is not
## cleared at the shoulders.

enum Surface {
	GROUND,      ## flat enough to stand on
	STEP,        ## a lip low enough to climb
	WALL,        ## too steep, too tall, or both
	CEILING,     ## above, facing down
}

## Steeper than this and a surface is a wall rather than a floor. 45° is the
## usual default, and it is the same number `CharacterBody3D.floor_max_angle`
## holds — keep the two in step or the character disagrees with itself.
const DEFAULT_MAX_SLOPE := 45.0


## What did we just hit?
##
## `feet_y` is the bottom of the character; `hit_y` the height of the contact.
static func classify(normal: Vector3, hit_y: float, feet_y: float, max_step: float,
		max_slope_degrees: float = DEFAULT_MAX_SLOPE) -> Surface:
	if normal.length() < 0.0001:
		return Surface.WALL               # no normal, no information: refuse it
	var up_dot := normal.normalized().dot(Vector3.UP)

	# Facing downward at all means it is over us, whatever its angle.
	if up_dot < -0.1:
		return Surface.CEILING

	if is_walkable(normal, max_slope_degrees):
		return Surface.GROUND

	# Too steep to walk on. It is still a step if its top is within reach —
	# which is the whole distinction move_and_slide() cannot make for you.
	var rise := hit_y - feet_y
	if rise > 0.0 and rise <= max_step:
		return Surface.STEP
	return Surface.WALL


## Is a surface flat enough to stand on?
static func is_walkable(normal: Vector3, max_slope_degrees: float = DEFAULT_MAX_SLOPE) -> bool:
	if normal.length() < 0.0001:
		return false
	# The dot product against up is the cosine of the slope angle, so the
	# comparison is against the cosine of the limit — no acos() needed, and no
	# NAN to guard.
	return normal.normalized().dot(Vector3.UP) >= cos(deg_to_rad(clampf(max_slope_degrees, 0.0, 90.0)))


## The slope of a surface in degrees, 0 for flat ground and 90 for a wall.
static func slope_degrees(normal: Vector3) -> float:
	if normal.length() < 0.0001:
		return 90.0
	return rad_to_deg(acos(clampf(normal.normalized().dot(Vector3.UP), -1.0, 1.0)))


## Can the character step up onto a surface whose top is at `top_y`?
##
## The forward sweep says *that* something is in the way; it cannot say how tall
## it is, because the contact can be anywhere on the obstruction's face. The
## height comes from a second cast, straight down from above it — and this is the
## question to ask of that second hit.
static func can_step_onto(normal: Vector3, top_y: float, feet_y: float, max_step: float,
		max_slope_degrees: float = DEFAULT_MAX_SLOPE) -> bool:
	if not is_walkable(normal, max_slope_degrees):
		return false                      # a slope you could not stand on anyway
	var rise := top_y - feet_y
	# A surface below the feet is a drop, not a step, and stepping "up" onto it
	# would teleport the character downward through the floor it is on.
	return rise > 0.0 and rise <= max_step


## Where to put the character to stand on top of a step.
##
## Lifted to the step's height plus a little clearance, and moved forward past
## the lip — a lift alone leaves the capsule intersecting the step's face, and
## the next frame pushes it back off.
static func step_target(position: Vector3, step_top_y: float, forward: Vector3,
		clearance: float = 0.02, forward_nudge: float = 0.05) -> Vector3:
	var flat := Vector3(forward.x, 0.0, forward.z)
	flat = flat.normalized() if flat.length() > 0.0001 else Vector3.ZERO
	return Vector3(position.x, step_top_y + clearance, position.z) + flat * forward_nudge


## How high a step is, from the character's feet.
static func rise_of(hit_y: float, feet_y: float) -> float:
	return hit_y - feet_y


## A readable name, for a HUD or a log.
static func name_of(surface: Surface) -> String:
	match surface:
		Surface.GROUND: return "ground"
		Surface.STEP: return "step"
		Surface.CEILING: return "ceiling"
		_: return "wall"
