class_name SkeletonRig
extends RefCounted

## Building a `Skeleton3D` in code, and bending it.
##
## A skeleton is normally something an artist hands you inside a `.glb`, which
## makes it look like a thing you cannot inspect. It is not: bones are names,
## parents and transforms, and all three can be created from a script in about
## ten lines. Doing that once is the fastest way to understand what the imported
## version actually contains.
##
## Two things about the API are worth having straight before touching it, because
## both produce a limb that is silently in the wrong place:
##
##   * **Poses are local to the parent bone.** `set_bone_pose_rotation()` takes a
##     rotation relative to the parent's pose, not a world orientation. Handing
##     it a world-space rotation gives you a limb that is right only while the
##     character faces down -Z.
##   * **Rest is not pose.** The rest transform is where the bone sits when
##     nothing is animating it; the pose is the offset from that. Writing the
##     rest at runtime moves the skeleton out from under every animation that
##     refers to it.


## Build a chain of `count` bones, each `length` metres along `axis` from its
## parent. Returns the bone indices, root first.
static func build_chain(skeleton: Skeleton3D, count: int, length: float,
		axis: Vector3 = Vector3.UP, prefix: String = "bone") -> PackedInt32Array:
	var bones := PackedInt32Array()
	if skeleton == null:
		return bones
	var direction := axis.normalized() if axis.length() > 0.0001 else Vector3.UP
	var parent := -1
	for i in maxi(count, 0):
		skeleton.add_bone("%s_%d" % [prefix, i])
		var bone := skeleton.get_bone_count() - 1
		if parent != -1:
			skeleton.set_bone_parent(bone, parent)
		# The rest is relative to the parent, so each bone is one length further
		# along the axis — not one length from the origin.
		var offset := direction * (length if parent != -1 else 0.0)
		skeleton.set_bone_rest(bone, Transform3D(Basis(), offset))
		skeleton.reset_bone_pose(bone)
		bones.append(bone)
		parent = bone
	return bones


## The rotation that turns `from` toward `to`, applied at `strength` (0..1).
##
## Both directions are in the same space — for a bone pose, the parent's. A
## strength below one is what makes a chain curl rather than every bone snapping
## to the same angle.
static func bend_toward(from: Vector3, to: Vector3, strength: float,
		max_angle: float = PI) -> Quaternion:
	if from.length() < 0.0001 or to.length() < 0.0001:
		return Quaternion.IDENTITY
	var a := from.normalized()
	var b := to.normalized()
	var dot := clampf(a.dot(b), -1.0, 1.0)
	if dot > 0.9999:
		return Quaternion.IDENTITY        # already pointing there
	var angle := acos(dot) * clampf(strength, 0.0, 1.0)
	angle = clampf(angle, -absf(max_angle), absf(max_angle))
	var axis := a.cross(b)
	if axis.length() < 0.0001:
		# Exactly opposite: every axis perpendicular to `a` is a valid answer,
		# and acos() has already given us PI. Pick one that cannot be parallel.
		axis = a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT)
	return Quaternion(axis.normalized(), angle)


## How much of the bend belongs to the bone at `index` of `count`.
##
## A ramp from the root to the tip. `falloff` below one puts most of the bend
## near the tip, which is what a tentacle does; above one puts it at the root,
## which is what an arm reaching does.
##
## Separate from `curl()` because it is the part with a rule in it: the resulting
## joint angles also depend on where each bone already points, so the ramp is the
## only thing that can be asserted directly.
static func curl_weight(index: int, count: int, strength: float,
		falloff: float = 1.0) -> float:
	if count <= 0:
		return 0.0
	# `index + 1`, so the root gets a share rather than none and nothing goes
	# negative at the top of the chain.
	return strength * pow(float(index + 1) / float(count), falloff)


## Bend a whole chain toward a target, a little more at each bone.
##
## `falloff` below one puts most of the bend near the tip, which is what a
## tentacle does; above one puts it at the root, which is what an arm does.
static func curl(skeleton: Skeleton3D, bones: PackedInt32Array, target_local: Vector3,
		strength: float, falloff: float = 1.0, axis: Vector3 = Vector3.UP) -> void:
	if skeleton == null or bones.is_empty():
		return
	for i in bones.size():
		var weight := curl_weight(i, bones.size(), strength, falloff)
		var bone := bones[i]
		var rest_direction := axis
		var to_target := target_local - skeleton.get_bone_global_pose(bone).origin
		if to_target.length() < 0.0001:
			continue
		# The target is in skeleton space; the pose is in the parent's. Rotating
		# the target into the parent's space is the step people leave out, and
		# it is why their limb is right only while the character faces one way.
		var parent := skeleton.get_bone_parent(bone)
		var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent != -1 else Basis()
		var local_target := parent_basis.inverse() * to_target
		skeleton.set_bone_pose_rotation(bone,
			bend_toward(rest_direction, local_target, weight))


## Put every bone back to its rest position.
static func relax(skeleton: Skeleton3D, bones: PackedInt32Array) -> void:
	if skeleton == null:
		return
	for bone in bones:
		skeleton.reset_bone_pose(bone)


## Where a bone's tip ends up, in skeleton space.
static func tip_of(skeleton: Skeleton3D, bone: int, length: float,
		axis: Vector3 = Vector3.UP) -> Vector3:
	if skeleton == null or bone < 0 or bone >= skeleton.get_bone_count():
		return Vector3.ZERO
	var pose := skeleton.get_bone_global_pose(bone)
	return pose.origin + pose.basis * (axis.normalized() * length)
