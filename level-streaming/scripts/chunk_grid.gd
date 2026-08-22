class_name ChunkGrid
extends RefCounted

## Which pieces of the world should be in memory, given where the player is.
##
## Streaming is two questions asked every frame — what should be loaded, and what
## should be thrown away — and the interesting part is that they must not be the
## same question. Load and free at the same radius and a player standing on a
## boundary loads and frees the same chunk forever, which is the worst possible
## use of a loading system.
##
## Two smaller traps that both produce a level with a hole in it:
##
##   * **Truncation is not flooring.** `int(-0.5)` is 0, and so is `int(0.5)`, so
##     two positions two chunks apart share an index. Half the world ends up in
##     the wrong chunk, symmetrically about the origin, which looks like a
##     mirrored bug rather than an arithmetic one.
##   * **Square radii are not round ones.** Loading a square of chunks around the
##     player loads the corners, which are 1.4 times further away than the edges
##     — 40% more chunks than the view distance needs.

## Metres per chunk, on both axes.
var chunk_size := 16.0

## Chunks within this many of the player are loaded.
var load_radius := 2

## Chunks are kept until they are further than this. Larger than `load_radius`,
## and the difference is what stops a player on a boundary thrashing.
var keep_radius := 3

## Load a square rather than a disc. Cheaper to reason about, and about 40% more
## chunks than a disc of the same reach.
var square := false


## Which chunk a world position falls in.
##
## `floori`, not `int`: truncation rounds toward zero, so -0.5 and 0.5 both land
## in chunk 0 and the world is mirrored about the origin.
static func chunk_of(position: Vector3, size: float) -> Vector2i:
	var side := maxf(size, 0.0001)
	return Vector2i(floori(position.x / side), floori(position.z / side))


## The world position of a chunk's corner.
static func origin_of(chunk: Vector2i, size: float) -> Vector3:
	return Vector3(float(chunk.x) * size, 0.0, float(chunk.y) * size)


## The centre of a chunk, which is where you would put its content.
static func centre_of(chunk: Vector2i, size: float) -> Vector3:
	return origin_of(chunk, size) + Vector3(size * 0.5, 0.0, size * 0.5)


## Every chunk within `radius` of `centre`.
func chunks_within(centre: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach := maxi(radius, 0)
	for x in range(centre.x - reach, centre.x + reach + 1):
		for y in range(centre.y - reach, centre.y + reach + 1):
			var chunk := Vector2i(x, y)
			if square or Vector2(chunk - centre).length() <= float(reach) + 0.5:
				out.append(chunk)
	out.sort()
	return out


## The chunks that should be loaded for a player at this position.
func wanted(position: Vector3) -> Array[Vector2i]:
	return chunks_within(chunk_of(position, chunk_size), load_radius)


## What to load and what to free, given what is loaded now.
##
## Freeing uses the larger keep radius, so a chunk just outside the load radius
## stays in memory rather than being freed and immediately reloaded.
func plan(position: Vector3, loaded: Array[Vector2i]) -> Dictionary:
	var centre := chunk_of(position, chunk_size)
	var needed := chunks_within(centre, load_radius)
	var keep := chunks_within(centre, keep_radius)

	var to_load: Array[Vector2i] = []
	for chunk in needed:
		if not loaded.has(chunk):
			to_load.append(chunk)

	var to_free: Array[Vector2i] = []
	for chunk in loaded:
		if not keep.has(chunk):
			to_free.append(chunk)

	# Nearest first: the chunk the player is about to walk into matters more
	# than the one behind them, and a streaming system that loads in index order
	# pops in the wrong places.
	to_load.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - centre).length_squared() < Vector2(b - centre).length_squared())
	return {"load": to_load, "free": to_free}


## How far a chunk is from the player, in chunks. For a priority or a fade.
static func distance_in_chunks(chunk: Vector2i, centre: Vector2i) -> float:
	return Vector2(chunk - centre).length()
