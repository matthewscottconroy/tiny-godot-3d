# Threaded Loading

<!-- tags: ui, signals, component, shows-its-working -->

Loading scenes on a background thread with a progress bar, instead of freezing the game with `load()`.

## Purpose

`load()` blocks. For one texture that is a frame nobody notices; for a level's
worth of scenes it is a freeze, and a freeze during play is the difference
between a loading screen and a bug report.

`ResourceLoader`'s threaded API fixes the freeze and hands you three chores in
exchange, all of which have to be got right before it is an improvement:

- **Polling.** Nothing tells you when a load finishes. You ask, every frame, and
  the answer is one of four statuses — one of which means "you never requested
  this", which is what a typo in a path gets you.
- **Aggregate progress.** Each request reports its own 0..1. A bar wants one
  number for the lot, and it must never go backwards, because a bar that jumps
  back reads as a hang.
- **Failure.** A missing file is a *status*, not an exception. Code that only
  handles success waits forever for a load that will never arrive.

## Controls

| Key | Action |
|-----|--------|
| 1 | Load three props on a background thread |
| 2 | Load the same three with blocking `load()` |
| 3 | Request a path that does not exist |
| R | Clear |

Watch the spinner and the worst-frame figure. Threaded, the ring keeps turning;
blocking, it stops dead and the worst frame jumps.

## How It Works

**Request, then poll.** `load_threaded_request(path)` starts the work;
`load_threaded_get_status(path, progress)` reports on it and fills an array with
that request's progress; `load_threaded_get(path)` collects the finished
resource. `LoadQueue` does all three once per frame for everything in flight.

**Four statuses, not two.** `IN_PROGRESS`, `LOADED`, `FAILED` and
`INVALID_RESOURCE` — the last meaning the loader has never heard of this path.
Both failure cases are recorded as failures, so a caller sees one consistent
story rather than a request that quietly never completes.

**Bad paths fail at the request.** `load_threaded_request()` returns an error
before any thread starts for a path that cannot be opened. That is recorded like
any other failure rather than thrown away, which keeps the progress total
honest. The engine also logs its own "cannot open file" error — that noise in
the output is Godot's, and it is telling the truth.

**Duplicates are refused.** Queueing the same path twice would count it twice in
the total, and the second copy completes instantly — so the bar reaches half and
stops. `queue()` returns false rather than double-counting.

**Progress only climbs.** The suite records every value it sees while loading
and asserts the sequence never decreases. A progress bar that goes backwards is
read as a hang by everyone who sees it.

**There is no cancel.** `reset()` forgets the queue; it does not stop work
already in flight, because `ResourceLoader` cannot. Pretending otherwise would
be a lie in the API, so it is a line in the doc comment instead.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `ResourceLoader.load_threaded_request()` | Start a load on a background thread |
| `ResourceLoader.load_threaded_get_status()` | Which of the four states it is in, and how far along |
| `ResourceLoader.load_threaded_get()` | Collect the finished resource |
| `PackedScene.instantiate()` | Turning the result into nodes |
| `load()` | The blocking version, kept for comparison |

## Files

| File | What it holds |
|------|---------------|
| `scripts/load_queue.gd` | The `LoadQueue` component: requests, polling, aggregate progress, failures |
| `scripts/main.gd` | Demo driver: the two loading paths, the spinner and the bar |
| `scenes/prop_a.tscn`, `prop_b`, `prop_c` | The scenes being loaded |
| `scenes/main.tscn` | Ground, spinner, progress bar, HUD |
| `tests/test_logic.gd` | Headless test suite — polling the real loader across real frames |
| `tests/frames` | How many frames the suite needs, since it waits on the loader |

## Use as a building block

**Copy:** `scripts/load_queue.gd` — the `LoadQueue` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `queue(path) -> bool`, `poll()`, `reset()`
- `progress() -> float`, `is_done() -> bool`, `pending() -> int`
- `results() -> Dictionary`, `get_result(path) -> Resource`, `failures() -> Array[String]`
- `signal loaded(path, resource)`, `signal failed(path)`, `signal all_done()`

**Integrate**
1. Call `poll()` from `_process`, unconditionally. It costs nothing when the
   queue is empty, and a poll that only runs "while loading" is a poll that
   stops one frame before the last resource arrives.
2. Queue a whole batch before showing a progress bar. Adding to a batch already
   in flight is what makes a bar jump backwards.
3. Handle `failed`. On desktop it is usually a typo; on a platform with
   removable storage or a patched install it is a Tuesday.

**Notes**
- `class_name LoadQueue` is global to the project — rename it if you already
  define that type.
- Threaded loading does not make instantiation free. `instantiate()` still runs
  on the main thread, so a large scene can stall when it arrives — spread the
  instantiation over frames as well if that shows.
- **Collect every request you start.** There is no cancel, and a threaded
  request still outstanding when the engine shuts down aborts the process with
  `SIGABRT` — after everything has run, with nothing printed. This demo's own
  suite did it, and reported `23/23 passed` on the way down. See
  [docs/MEMORY.md](../docs/MEMORY.md).
- Connect signals to **methods, not lambdas**, when the emitter is a
  `RefCounted`. A lambda connected that way showed up as two leaked objects at
  exit in this demo's own suite; the same code with methods leaks nothing. See
  [docs/MEMORY.md](../docs/MEMORY.md).

## Related demos

- [level-streaming](../level-streaming) — Loading and freeing chunks around a moving player, with the keep-radius that stops them thrashing at a boundary.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

