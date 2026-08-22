extends Node3D

# Demo driver. Loads three prop scenes on a background thread with a progress
# bar, and offers the blocking version next to it so the stall is visible.

const PROPS: Array[String] = [
	"res://scenes/prop_a.tscn",
	"res://scenes/prop_b.tscn",
	"res://scenes/prop_c.tscn",
]
const MISSING := "res://scenes/prop_that_does_not_exist.tscn"

@onready var _spawned: Node3D = $Spawned
@onready var _bar: ColorRect = $HUD/Bar
@onready var _spinner: Node3D = $Spinner
@onready var _status: Label = $HUD/StatusLabel
@onready var _hint: Label = $HUD/TitleLabel

var _queue := LoadQueue.new()
var _message := "press 1 to load in the background"
var _worst_frame := 0.0

func _ready() -> void:
	_hint.text = "1 threaded load   2 blocking load()   3 a path that does not exist   R reset"
	_queue.loaded.connect(_on_loaded)
	_queue.failed.connect(func(path: String) -> void:
		_message = "failed: %s" % path.get_file())
	_queue.all_done.connect(func() -> void:
		_message = "done — %d loaded, %d failed" % [
			_queue.results().size(), _queue.failures().size()])

func _process(delta: float) -> void:
	# The spinner is the whole point of the comparison: it keeps turning through
	# a threaded load and stops dead during a blocking one.
	_spinner.rotate_y(delta * 3.0)
	_worst_frame = maxf(_worst_frame, delta)

	# Nothing tells you when a threaded load finishes. You ask, every frame.
	_queue.poll()
	_bar.size.x = _queue.progress() * 300.0

	_status.text = "%s   |   progress %.0f%%   %d pending   worst frame %.0f ms" % [
		_message, _queue.progress() * 100.0, _queue.pending(), _worst_frame * 1000.0]

func _on_loaded(path: String, resource: Resource) -> void:
	var scene := resource as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate() as Node3D
	instance.position = Vector3(_spawned.get_child_count() * 2.0 - 2.0, 1.0, 0.0)
	_spawned.add_child(instance)
	_message = "loaded %s" % path.get_file()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_reset()
			for path in PROPS:
				_queue.queue(path)
			_message = "loading in the background…"
		KEY_2:
			_reset()
			# The version this replaces. Every frame of this is a frame the
			# game is not drawing — watch the spinner and the worst-frame time.
			for path in PROPS:
				var scene := load(path) as PackedScene
				var instance := scene.instantiate() as Node3D
				instance.position = Vector3(_spawned.get_child_count() * 2.0 - 2.0, 1.0, 0.0)
				_spawned.add_child(instance)
			_message = "loaded with load(), on the main thread"
		KEY_3:
			_queue.queue(MISSING)
			_message = "requested a path that does not exist"
		KEY_R: _reset()
		_: return

func _reset() -> void:
	for child in _spawned.get_children():
		child.queue_free()
	_queue.reset()
	_worst_frame = 0.0
	_message = "cleared"
