class_name ScenePicker
extends RefCounted

## What the mouse is pointing at, and what is currently selected.
##
## Two halves, because clicking in a 3D scene is two questions. "What did I
## hit?" is the physics server's to answer — `intersect_ray` does it, and
## reimplementing that would be worse in every way. "What do I do with the
## answer?" is the game's, and it is the half that is fiddly: additive selection,
## clicking the same thing twice, clicking nothing at all.
##
## The ground-plane maths is here too, because a click that hits nothing still
## has a meaningful answer in most games — the point on the floor you aimed at.
## It is a plane intersection, three lines, and it is wrong in a specific way
## when the ray is parallel to the plane, which is what makes it worth testing.

## Emitted whenever the selection changes, with how many things are now selected.
signal selection_changed(count: int)

var _selected: Array[Node3D] = []


## Where a ray meets a horizontal plane, or `null` if it never does.
##
## Returns `null` rather than a far-away point for the two cases that have no
## answer: a ray running parallel to the plane, and one pointing away from it.
## A game that treats those as a hit places things behind the camera.
static func ground_point(from: Vector3, direction: Vector3, plane_y: float) -> Variant:
	if is_zero_approx(direction.y):
		return null                        # parallel: never meets the plane
	var distance := (plane_y - from.y) / direction.y
	if distance < 0.0:
		return null                        # the plane is behind the ray
	return from + direction * distance


## Replace the selection with one node, or clear it when given `null`.
func select(node: Node3D) -> void:
	var wanted: Array[Node3D] = []
	if node != null:
		wanted.append(node)
	if wanted == _selected:
		return
	_selected = wanted
	selection_changed.emit(_selected.size())


## Add to the selection, or remove if it is already in it — the shift-click rule.
func toggle(node: Node3D) -> void:
	if node == null:
		return
	var index := _selected.find(node)
	if index == -1:
		_selected.append(node)
	else:
		_selected.remove_at(index)
	selection_changed.emit(_selected.size())


func clear() -> void:
	if _selected.is_empty():
		return
	_selected.clear()
	selection_changed.emit(0)


func is_selected(node: Node3D) -> bool:
	return _selected.has(node)


func selected() -> Array[Node3D]:
	return _selected.duplicate()


func count() -> int:
	return _selected.size()


## Drop anything that has been freed since it was selected.
##
## Selecting something and then destroying it is normal — a selected enemy dies.
## Without this the selection keeps a freed reference and the next iteration over
## it errors, somewhere far from the deletion that caused it.
func prune() -> void:
	var kept: Array[Node3D] = []
	for node in _selected:
		if is_instance_valid(node):
			kept.append(node)
	if kept.size() == _selected.size():
		return
	_selected = kept
	selection_changed.emit(_selected.size())
