class_name Relevance
extends RefCounted

## Who needs to be told about what, and how often.
##
## `MultiplayerSynchronizer` replaces the hand-written RPCs in multiplayer-3d:
## name the properties once in a `SceneReplicationConfig` and the engine sends
## them. What it does not decide is *who to send them to*, and on any map bigger
## than a room that is the decision that matters. Replicating every player to
## every player is quadratic — sixteen peers is 240 streams of position, most of
## them describing someone on the other side of the level.
##
## It is not only bandwidth. A client cannot draw a wallhack of a player whose
## position it was never sent, so interest management is the one anti-cheat that
## costs nothing and cannot be defeated by a better client.
##
## `MultiplayerSynchronizer.add_visibility_filter()` takes a callable per peer,
## and this is what belongs inside it.

## Is this subject close enough to be worth sending to this viewer?
##
## Flat distance on the XZ plane: height rarely decides relevance, and a player
## directly overhead on a walkway is as relevant as one beside you.
static func in_range(viewer: Vector3, subject: Vector3, radius: float) -> bool:
	var flat := Vector2(subject.x - viewer.x, subject.z - viewer.z)
	return flat.length() <= maxf(radius, 0.0)


## The same question, with hysteresis, for something already being sent.
##
## A single radius makes a peer standing exactly on the boundary flip between
## sent and not sent every frame — and each flip is a full state resend, so the
## edge of the bubble costs more traffic than the middle of it. Entering needs
## to be closer than leaving.
##
## Same shape as the distance bands in lod-and-decals, for the same reason: any
## threshold crossed continuously needs two thresholds.
static func stays_relevant(was_relevant: bool, viewer: Vector3, subject: Vector3,
		enter_radius: float, exit_radius: float) -> bool:
	var leave := maxf(exit_radius, enter_radius)
	if was_relevant:
		return in_range(viewer, subject, leave)
	return in_range(viewer, subject, enter_radius)


## How often to send, given how far away the subject is.
##
## Relevance is not binary in practice. Someone across the map still has to
## exist — on a minimap, as a distant silhouette — they just do not need twenty
## updates a second to do it. Interpolating between sparse updates is what
## multiplayer-3d's StateBuffer is for.
##
## Returns seconds between sends, eased linearly between the two bands.
static func interval_for(distance: float, near: float, far: float,
		near_interval: float = 0.05, far_interval: float = 0.5) -> float:
	if far <= near:
		return near_interval
	var t := clampf((distance - near) / (far - near), 0.0, 1.0)
	return lerpf(near_interval, far_interval, t)


## What the filtering saved, as a fraction of the streams a naive server sends.
##
## The naive cost is every peer telling every other peer, which is `n * (n - 1)`
## — the number worth putting on screen, because it is the one that grows
## quadratically while the bandwidth bill grows with it.
static func streams_saved(peers: int, sent: int) -> float:
	var naive := maxi(peers, 0) * (maxi(peers, 0) - 1)
	if naive <= 0:
		return 0.0
	return clampf(1.0 - float(sent) / float(naive), 0.0, 1.0)


## The peers a subject should be replicated to, given where everyone is.
##
## `positions` maps peer id to position. The subject's own peer is never in the
## result: a synchronizer does not send a player their own state back, and doing
## so is how an authority fights its own client for a position.
static func audience(owner_id: int, positions: Dictionary, radius: float) -> Array[int]:
	var result: Array[int] = []
	if not positions.has(owner_id):
		return result
	var subject: Vector3 = positions[owner_id]
	for id in positions:
		if id == owner_id:
			continue
		if in_range(positions[id], subject, radius):
			result.append(id)
	result.sort()
	return result
