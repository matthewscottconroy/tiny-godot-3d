@tool
extends Node3D

## Builds a fence along a Path3D, in the editor as well as in the game.
##
## `@tool` is the subject: this script runs inside the editor, so dragging the
## curve rebuilds the fence immediately. Three rules keep that from being
## dangerous:
##
##   * **Generated children are not saved.** A node added without an `owner` is
##     not written into the scene file. Without that, every rebuild leaves the
##     scene fatter than it was and a colleague's merge conflicts are hundreds of
##     posts long.
##   * **Rebuilding clears first.** `queue_free()` is deferred, so the children
##     are removed from the tree in the same frame with `remove_child()` — the
##     alternative is a rebuild that briefly doubles the fence.
##   * **Nothing else runs in the editor.** Anything that would move, play a
##     sound or touch the player is behind `Engine.is_editor_hint()`.

## Every setter rebuilds, which is what makes the tool feel live.
@export var spacing := 2.0:
	set(value):
		spacing = maxf(value, 0.2)
		_rebuild()

@export var post_height := 1.2:
	set(value):
		post_height = maxf(value, 0.1)
		_rebuild()

@export var rails := 2:
	set(value):
		rails = clampi(value, 0, 4)
		_rebuild()

## A checkbox that acts as a button: tick it to force a rebuild after editing
## the curve, which the Path3D does not tell us about on its own.
@export var rebuild_now := false:
	set(value):
		rebuild_now = false
		_rebuild()

var _generated: Array[Node3D] = []

func _ready() -> void:
	_rebuild()


## What the editor shows beside the node — better than a print, which goes to a
## log nobody has open, and it survives a scene reload.
func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null("Path3D") == null:
		return PackedStringArray(["Needs a Path3D child to build a fence along."])
	var path := get_node("Path3D") as Path3D
	if path.curve == null or path.curve.point_count < 2:
		return PackedStringArray(["The Path3D's curve needs at least two points."])
	return PackedStringArray()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var path := get_node_or_null("Path3D") as Path3D
	update_configuration_warnings()
	_clear()
	if path == null or path.curve == null or path.curve.point_count < 2:
		return

	var curve := path.curve
	var length := curve.get_baked_length()
	var distances := FencePlan.post_distances(length, spacing)

	var previous := Vector3.ZERO
	for i in distances.size():
		var point := curve.sample_baked(distances[i])
		var ahead := curve.sample_baked(minf(distances[i] + 0.1, length))
		_add_post(point, FencePlan.post_yaw(ahead - point))
		if i > 0:
			for rail in rails:
				var height := post_height * (0.35 + 0.5 * float(rail) / maxf(rails - 1, 1))
				_add_rail(previous + Vector3.UP * height, point + Vector3.UP * height)
		previous = point

func _clear() -> void:
	for node in _generated:
		if is_instance_valid(node):
			# Removed now rather than queued: queue_free is deferred, and a
			# rebuild that waits for it briefly shows two fences.
			remove_child(node)
			node.queue_free()
	_generated.clear()


func _add_post(at: Vector3, yaw: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, post_height, 0.14)

	var post := MeshInstance3D.new()
	post.name = "Post"
	# A group rather than the name: Godot dedups repeated names into forms like
	# "@Post@14", so anything looking for these nodes by name finds one of them.
	post.add_to_group(&"fence_post")
	post.mesh = mesh
	post.position = at + Vector3.UP * post_height * 0.5
	post.rotation.y = yaw
	_attach(post)

func _add_rail(from: Vector3, to: Vector3) -> void:
	# A unit-long mesh, scaled by the transform: one mesh for every rail.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 1.0)
	var rail := MeshInstance3D.new()
	rail.name = "Rail"
	rail.add_to_group(&"fence_rail")
	rail.mesh = mesh
	_attach(rail)
	rail.transform = FencePlan.rail_transform(from, to)

func _attach(node: Node3D) -> void:
	add_child(node)
	# No `owner`, so the node is not written into the scene file. This is the
	# line that keeps a generated fence out of version control.
	_generated.append(node)


## How many nodes the fence consists of, for the HUD and the suite.
func generated_count() -> int:
	return _generated.size()
