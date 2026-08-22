class_name ClipBuilder
extends RefCounted

## Building an `Animation` resource in code, key by key.
##
## Animation in Godot is usually authored in the editor's timeline and imported
## from a model, and both of those hide what an `Animation` actually is: a list
## of tracks, each a path to a property and a list of (time, value) keys. Nothing
## about it needs a file, an artist, or a rigged model.
##
## That matters beyond curiosity. Anything whose motion is decided at runtime —
## a procedural creature, a door whose swing depends on its size, a UI beat
## generated from a config file — is a clip you cannot author in advance, and the
## API for making one is small enough to fit on a page.
##
## The lesson underneath the API is phase. A walk is not four legs moving; it is
## four legs moving *out of step with each other by the right amounts*. Get the
## offsets wrong and the same keys produce a creature that hops.

## Godot 4 keeps animations in libraries, and a player with no library plays
## nothing. The empty name is the default library, so clips in it are addressed
## by their own name alone.
const DEFAULT_LIBRARY := ""


## An empty clip of `length` seconds.
static func new_clip(length: float, loop: bool = true) -> Animation:
	var clip := Animation.new()
	# A clip of zero length is not an animation, it is a division by zero
	# waiting for whoever samples it.
	clip.length = maxf(length, 0.001)
	clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return clip


## Add a position track for `path`, from `keys` of `[time, Vector3]` pairs.
##
## Returns the track index, which is what every other Animation call wants.
static func add_position_track(clip: Animation, path: NodePath, keys: Array) -> int:
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, path)
	for key in keys:
		clip.position_track_insert_key(track, float(key[0]), key[1])
	return track


## Add a rotation track, from `[time, Quaternion]` pairs.
##
## Rotation tracks hold quaternions, not Euler angles. That is not a detail to
## work around: interpolating Euler angles gives gimbal artefacts and the wrong
## path between two orientations, which is why the track type exists.
static func add_rotation_track(clip: Animation, path: NodePath, keys: Array) -> int:
	var track := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track, path)
	for key in keys:
		clip.rotation_track_insert_key(track, float(key[0]), key[1])
	return track


## A limb swinging back and forth about `axis`, `degrees` either way.
##
## `phase` shifts the whole swing through the cycle, 0..1. Four keys is enough
## for a sine-like swing once the clip loops: neutral, forward, neutral, back.
static func add_swing_track(clip: Animation, path: NodePath, axis: Vector3,
		degrees: float, phase: float = 0.0) -> int:
	var swing := deg_to_rad(degrees)
	# Neutral, forward, neutral, back: a quarter of the cycle each.
	var shape: Array[float] = [0.0, 1.0, 0.0, -1.0]
	var keys := []
	for step in 4:
		# Quarter-cycle steps, offset by the phase and wrapped into the clip.
		var time := fposmod((float(step) / 4.0 + phase) * clip.length, clip.length)
		var angle := swing * shape[step]
		keys.append([time, Quaternion(axis.normalized(), angle)])
	# No sorting: rotation_track_insert_key places each key at its own time
	# whatever order they arrive in, so sorting first would be doing the
	# engine's job twice and testing neither.
	var track := add_rotation_track(clip, path, keys)
	# A loop needs the last key to arrive back where the first one started, or
	# the wrap is a jump. The key at t=0 is duplicated at t=length to close it.
	var first := clip.rotation_track_interpolate(track, 0.0)
	clip.rotation_track_insert_key(track, clip.length, first)
	return track


## A four-legged walk cycle: diagonal pairs, half a cycle apart.
##
## `legs` are the four leg paths in the order front-left, front-right, back-left,
## back-right. The diagonal pairs move together — front-left with back-right —
## which is what a trot is, and what makes the result read as walking rather
## than as hopping.
static func walk_cycle(legs: Array[NodePath], degrees: float, period: float) -> Animation:
	var clip := new_clip(period, true)
	if legs.size() != 4:
		return clip
	var phases := [0.0, 0.5, 0.5, 0.0]
	for i in 4:
		add_swing_track(clip, legs[i], Vector3.RIGHT, degrees, phases[i])
	return clip


## Wrap a clip in a library and give it to a player, under `clip_name`.
static func install(player: AnimationPlayer, clip: Animation, clip_name: String) -> void:
	# has_animation_library() first: asking a player for a library it does not
	# have prints an engine error before returning null, and "there is no
	# library yet" is the normal state of a player nobody has installed a clip
	# into.
	var library: AnimationLibrary
	if player.has_animation_library(DEFAULT_LIBRARY):
		library = player.get_animation_library(DEFAULT_LIBRARY)
	else:
		library = AnimationLibrary.new()
		player.add_animation_library(DEFAULT_LIBRARY, library)
	if library.has_animation(clip_name):
		library.remove_animation(clip_name)
	library.add_animation(clip_name, clip)


## How far through the cycle a leg with this phase is, at `time`. Useful for
## anything that has to stay in step with the clip without being in it — a
## footstep sound, a dust puff.
static func phase_at(time: float, period: float, phase: float) -> float:
	if period <= 0.0:
		return 0.0
	return fposmod(time / period + phase, 1.0)
