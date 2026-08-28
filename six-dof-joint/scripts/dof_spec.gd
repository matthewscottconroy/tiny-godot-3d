class_name DofSpec
extends RefCounted

## Saying what you mean with a `Generic6DOFJoint3D`.
##
## The other joints in Godot are named after what they do: a hinge hinges, a
## slider slides. `Generic6DOFJoint3D` is named after its *mechanism* — six
## degrees of freedom, three linear and three angular, each independently free,
## limited or locked — and configuring it means holding all six in your head at
## once while ticking about twenty boxes.
##
## Which is why it has a reputation for producing a joint that does nothing, or
## everything. Both have the same cause: **a degree of freedom is locked by
## enabling its limit and setting the range to zero, not by a "locked" flag.**
## A joint with no limits enabled is a ball joint that slides — six axes, all
## free — and that is also the default.
##
## So the useful thing is not a wrapper around the node. It is a way to say "this
## is a door" and get the six axes that mean it.

enum Axis { X, Y, Z }
enum Freedom { LOCKED, LIMITED, FREE }

## What each of the six degrees of freedom is doing.
var linear: Array[Freedom] = [Freedom.LOCKED, Freedom.LOCKED, Freedom.LOCKED]
var angular: Array[Freedom] = [Freedom.LOCKED, Freedom.LOCKED, Freedom.LOCKED]

## Lower and upper bounds for the limited ones. Metres and radians.
var linear_range: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var angular_range: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]


## A door: swings about one upright axis, held everywhere else.
static func door(swing: float = PI * 0.6) -> DofSpec:
	var spec := DofSpec.new()
	spec.angular[Axis.Y] = Freedom.LIMITED
	spec.angular_range[Axis.Y] = Vector2(-swing, swing)
	return spec


## A drawer: slides along one axis, held everywhere else.
static func drawer(travel: float = 0.6) -> DofSpec:
	var spec := DofSpec.new()
	spec.linear[Axis.Z] = Freedom.LIMITED
	spec.linear_range[Axis.Z] = Vector2(0.0, travel)
	return spec


## A ball joint: turns freely in every direction, goes nowhere.
static func ball() -> DofSpec:
	var spec := DofSpec.new()
	spec.angular = [Freedom.FREE, Freedom.FREE, Freedom.FREE]
	return spec


## A shoulder: turns, but not all the way round in any direction.
static func shoulder(reach: float = PI * 0.4, twist: float = PI * 0.25) -> DofSpec:
	var spec := DofSpec.new()
	spec.angular = [Freedom.LIMITED, Freedom.LIMITED, Freedom.LIMITED]
	spec.angular_range = [Vector2(-reach, reach), Vector2(-reach, reach),
		Vector2(-twist, twist)]
	return spec


## Everything free: a ball joint that also slides, which is what you get by
## dropping the node in and changing nothing.
static func unconstrained() -> DofSpec:
	var spec := DofSpec.new()
	spec.linear = [Freedom.FREE, Freedom.FREE, Freedom.FREE]
	spec.angular = [Freedom.FREE, Freedom.FREE, Freedom.FREE]
	return spec


## How many of the six axes can move at all.
##
## Zero is a weld — two bodies that could have been one. Six is the default, and
## almost never what anybody wanted.
func degrees_of_freedom() -> int:
	var count := 0
	for freedom in linear + angular:
		if freedom != Freedom.LOCKED:
			count += 1
	return count


func is_weld() -> bool:
	return degrees_of_freedom() == 0


## Whether an axis's limit should be switched on.
##
## The bit that catches everyone: a *locked* axis has its limit enabled with a
## range of zero. Only a genuinely free axis has the limit switched off.
func limit_enabled(kind: String, axis: Axis) -> bool:
	var freedom: Freedom = angular[axis] if kind == "angular" else linear[axis]
	return freedom != Freedom.FREE


## The bounds to write into the joint for an axis.
##
## Zero for a locked one, the configured range for a limited one, and untouched
## for a free one — where the numbers are ignored anyway.
func bounds(kind: String, axis: Axis) -> Vector2:
	var freedom: Freedom = angular[axis] if kind == "angular" else linear[axis]
	if freedom == Freedom.LOCKED:
		return Vector2.ZERO
	return angular_range[axis] if kind == "angular" else linear_range[axis]


## A one-line summary, for a HUD or for working out what you actually built.
func describe() -> String:
	var names := ["locked", "limited", "free"]
	var parts: Array[String] = []
	for i in 3:
		parts.append("%s%s" % ["XYZ"[i], names[linear[i]].substr(0, 3)])
	for i in 3:
		parts.append("r%s%s" % ["XYZ"[i], names[angular[i]].substr(0, 3)])
	return " ".join(parts)
