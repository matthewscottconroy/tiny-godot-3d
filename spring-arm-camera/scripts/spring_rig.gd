class_name SpringRig
extends RefCounted

## Where the camera rig sits, and which way "forward" is once it has orbited.
##
## None of this is `SpringArm3D`'s job. The arm answers one question — how far
## back the camera may be — and everything here decides what it is measuring
## back *from*.
##
## It lives in its own file for the reason the rest of the collection does: a
## sign flip in a camera offset still renders a perfectly plausible scene, from
## the wrong place. Inline in the driver there is nothing a test can call and
## nothing a mutation run can reach; here it is four numbers a suite can state.


## The pivot the arm hangs off: the target's position, raised to head height.
##
## Raised rather than centred, because this is where the sweep *starts*. Put it
## low enough and the arm's first hit is the character's own collider, which is
## what `SpringArm3D.add_excluded_object()` exists to prevent.
static func pivot_position(target_position: Vector3, height: float) -> Vector3:
	return target_position + Vector3.UP * height


## The rig's forward and right, flattened onto the ground plane.
##
## Un-flattened, "forward" points slightly into the floor whenever the camera is
## pitched down, and holding forward walks the character into the ground over a
## few seconds — the slow, hard-to-see version of the bug.
##
## Pointed straight up or straight down the flattened vector degenerates to
## zero, and normalising that gives `(0, 0, 0)` rather than an error: movement
## silently stops. The demo's pitch limits keep it well short of that, but a
## component with an exported limit would not, so it is handled here.
static func ground_basis(pivot_basis: Basis) -> Dictionary:
	var forward := -pivot_basis.z
	forward.y = 0.0
	if forward.length() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	return {"forward": forward, "right": forward.cross(Vector3.UP).normalized()}


## Camera-relative movement for an arrow-key or stick vector.
##
## `input.y` is negated because Godot's "up" is -Y in a 2D input vector, while
## "away from the camera" is +forward here.
static func move_direction(pivot_basis: Basis, input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var basis := ground_basis(pivot_basis)
	var forward: Vector3 = basis["forward"]
	var right: Vector3 = basis["right"]
	return (forward * -input.y + right * input.x).normalized()
