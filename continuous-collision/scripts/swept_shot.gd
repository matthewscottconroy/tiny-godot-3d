extends Node3D

# The raycast fix, as a node: move by hand, and cast a ray along the step about
# to be taken. Cheap, exact for something the size of a bullet, and unaffected
# by speed — the ray is as long as the step, whatever the step is.

var speed := 200.0
var _stopped := false

func stopped() -> bool:
	return _stopped

func _physics_process(delta: float) -> void:
	if _stopped:
		return
	var from := global_position
	var to := from + Vector3.RIGHT * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	# Stop at the surface rather than at the destination: that is where the
	# impact happened, and it is inside the frame rather than at the end of it.
	global_position = hit["position"]
	_stopped = true
