# Level Streaming

<!-- tags: mesh, camera, ui, procedural, component, shows-its-working -->

Loading and freeing chunks around a moving player, with the keep-radius that stops them thrashing at a boundary.

## Purpose

Streaming is two questions asked every frame — what should be loaded, and what
should be thrown away — and the whole trick is that **they must not be the same
question**. Load and free at the same radius and a player standing on a boundary
loads and frees the same chunk forever: a loading system's worth of work, with
nothing to show for it.

Two smaller traps produce a world with a hole in it, both on the far side of the
origin, which makes them memorable to debug:

- `int(-0.5)` is 0 and so is `int(0.5)`, so two positions two chunks apart share
  an index. `floori()` is the entire fix.
- A square of chunks loads the corners, which are 1.4× further away than the
  edges — about 40% more chunks for no more view distance.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Smaller or larger load radius |
| 3 / 4 | Smaller or larger keep radius |
| Space | Stop the player moving |

The counters show chunks built and freed. Set the keep radius equal to the load
radius and watch them climb together.

## How It Works

**`plan()` answers both questions at once.** What to load comes from
`load_radius`; what to free comes from `keep_radius`, which is larger. The gap
between the two is the hysteresis, and the suite walks a player across a
boundary twenty times to assert that nothing is freed.

**Chunks are a disc, not a square.** `chunks_within()` keeps anything inside the
radius plus a half-chunk, which drops the corners. A square is available as a
flag because it is easier to reason about — and 40% more expensive.

**Loading is nearest-first.** The chunk the player is about to walk into matters
more than the one four chunks away; loading in index order makes things pop in
at the wrong end of the view. The plan comes back sorted.

**A budget per frame.** The driver builds at most two chunks a frame. Building
everything the moment it is asked for has moved the stall rather than removed
it — and for real content the answer is to do it off the main thread entirely,
which is [threaded-loading](../threaded-loading).

**Chunk content is generated from its coordinates.** A seeded RNG keyed on the
chunk index, so the same chunk is identical every time it streams in. Without
that, walking away and back rearranges the scenery, which is the most obvious
possible way for streaming to announce itself.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `floori()` | Chunk indices that work on both sides of the origin |
| `RandomNumberGenerator.seed` / `hash()` | Content that is the same every time a chunk returns |
| `Node.queue_free()` | Freeing a chunk's subtree |
| `Array.sort_custom()` | Nearest-first load order |

## Files

| File | What it holds |
|------|---------------|
| `scripts/chunk_grid.gd` | The `ChunkGrid` component: indices, radii, and the load/free plan |
| `scripts/main.gd` | Demo driver: the wandering player and the chunks it builds |
| `scenes/main.tscn` | A camera, a light, a marker — the world is all streamed |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/chunk_grid.gd` — the `ChunkGrid` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `ChunkGrid.chunk_of(position, size) -> Vector2i`
- `ChunkGrid.origin_of(chunk, size)`, `ChunkGrid.centre_of(chunk, size)`
- `chunks_within(centre, radius) -> Array[Vector2i]`, `wanted(position) -> Array[Vector2i]`
- `plan(position, loaded) -> {load: Array[Vector2i], free: Array[Vector2i]}`
- `ChunkGrid.distance_in_chunks(chunk, centre) -> float`
- `chunk_size`, `load_radius`, `keep_radius`, `square`

**Integrate**
1. Keep `keep_radius` at least one greater than `load_radius`. Equal radii is the
   bug this component exists to prevent.
2. Budget the loads per frame, and do the actual loading with
   `ResourceLoader.load_threaded_request` — the plan is cheap, the content is
   not.
3. Save per-chunk state (what the player changed) separately from the chunk
   itself, keyed by the same `Vector2i`. Freeing a chunk must not free what
   happened in it — see [save-load-3d](../save-load-3d).

**Notes**
- `class_name ChunkGrid` is global to the project — rename it if you already
  define that type.
- This grid is 2D: chunks on X and Z, unbounded Y. That fits nearly every game
  that streams. A genuinely volumetric world wants `Vector3i` and the same
  logic with one more axis.
- Chunk size is a trade rather than a tuning knob. Small chunks stream smoothly
  and multiply the bookkeeping; large ones are cheaper to track and stall harder
  when one arrives.

## Related demos

- [input-remapping](../input-remapping) — Rebinding actions at runtime, spotting the conflicts, and saving the result where it survives a restart.
- [threaded-loading](../threaded-loading) — Loading scenes on a background thread with a progress bar, instead of freezing the game with load().
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [lod-and-decals](../lod-and-decals) — Distance bands that drive mesh LOD, decal fade and update rates — with the hysteresis that stops them flickering.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

