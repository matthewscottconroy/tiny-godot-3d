# Memory

Two separate things live here: leaks inside the demos, and the memory the test
tooling itself consumes. They have different causes and different fixes.

Both the tooling and the safeguards below came over from the 2D collection,
where the problems were found. Where this document cites an incident, it happened
there — but the tools are the same tools, so the reasoning is why they are shaped
the way they are here too.

## Leaks in the demos

Godot reports unfreed objects when it shuts down. Those messages arrive after
everything has finished and nothing fails, so they are easy to never notice.
`tools/leakcheck.sh` surfaces them deliberately:

```bash
tools/leakcheck.sh                    # every demo
VERBOSE=1 tools/leakcheck.sh <demo>   # show clean results too
```

**Current state: 59 projects, all clean, two reports allowlisted as engine-side.**

The allowlist is the part to keep honest: every entry has to be justified with a
reproduction in a scene containing none of the demo's code, and an allowlist that
grows without that evidence is how a check stops being read.

### Engine-side: `audio-3d` and `audio-buses`

```
2 ObjectDB instances were leaked at exit   —   3 runs of 3
```

Reproduced in a twelve-line scene that creates an `AudioStreamWAV`, hands it to
an `AudioStreamPlayer3D` and plays it. No demo code, same two instances, every
run. Stopping the player and clearing its `stream` in `_exit_tree()` made no
difference, so there is nothing for the demo to do differently.

Both audio demos report it, for the same reason and with the same evidence.
`tools/leakcheck.sh` carries them on its allowlist with that evidence attached, and
`run-tests.sh` already tolerates the message via `WARN_ALLOW` — an
audio-shutdown report is the one warning this collection expects to see. The 2D
collection reached the same conclusion about two of its own audio demos.

### What to look for in GDScript

Two shapes account for almost every real leak.

**`RefCounted` cycles.** `RefCounted` is reference-counted, not
garbage-collected, so A holding B while B holds A never reaches zero. The 2D
collection's hierarchical state machine had exactly that — each state kept a
strong `parent` while the parent kept its children, and the whole tree leaked on
every run. The fix is a `WeakRef` for the upward link, with a property getter so
callers still write `state.parent`.

The rigs in this collection are all one-directional today (`OrbitRig` knows
nothing about its camera; `CharacterMotor` knows nothing about its body), which
is what keeps them clean. A rig that holds its target while the target holds the
rig would be the first thing to go wrong.

**`Object`-derived helpers.** `UndoRedo`, `Thread` and friends extend `Object`,
not `RefCounted`. Nothing counts references to them, so one held in a variable is
never collected and has to be `free()`d by hand — usually in `_exit_tree()`,
guarded by `is_instance_valid()`.

**Lambdas connected to a `RefCounted`'s signals.** Found here rather than
inherited: `threaded-loading`'s test suite connected three lambdas to a
`LoadQueue`'s signals and leaked two objects at exit, every run. The identical
code with plain methods leaks nothing.

```gdscript
_queue.loaded.connect(func(path: String, _r: Resource) -> void: …)   # 2 leaked
_queue.loaded.connect(_on_loaded)                                     # clean
```

A lambda captures the scope it was written in, and connecting it to a signal on
a reference-counted object keeps both alive for as long as either survives. It
is easy to miss because the demo itself scans clean — the leak was in the suite,
which `tools/leakcheck.sh` does not run. Prefer a method whenever the emitter is
a `RefCounted` rather than a node.

### Not a leak, but found the same way

**A threaded load that is never collected aborts the process at shutdown.**
`ResourceLoader.load_threaded_request()` has no cancel, and a request still
outstanding when the engine exits takes the process down with `SIGABRT` — after
everything has run, with nothing printed. `threaded-loading`'s own suite did
this: a test that queued a path to prove duplicates are refused left the request
in flight, and Godot aborted on the way out roughly four runs in five.

It stayed hidden because the suite reported `23/23 passed` first and
`run-tests.sh` reads the summary. `tools/mutate.py` checks the exit code as well
— a mutant that crashes is a mutant caught — so it saw the demo as
`already-failing` and refused to score it. That is how it surfaced.

Anything that starts a threaded request owns collecting it, including tests.

Collecting it leaves its own trace, and this one is the engine's: a threaded
load collected early in a run that also loads a batch later reports **one**
`RefCounted` leaked at exit. Reproduced with two bare `ResourceLoader` calls and
no demo code in between, so it is not `LoadQueue`. It is not gated —
`tools/leakcheck.sh` runs demos rather than suites — and it is recorded here so
the next person does not spend an afternoon bisecting a test file for it.

The related trap in that suite is not engine-side. Polling a threaded load in a
`for` loop that never yields is a race with the loader's own thread: it passed
on this machine and failed under the address-space limit `tools/mutate.py` runs
demos with, where the loader had less room to get ahead. Poll across frames, the
way a game does.

### The 3D-specific one to watch

3D demos allocate `Resource`s at runtime in a way 2D ones rarely do: a rebuilt
`ArrayMesh` every time a parameter changes, a `StandardMaterial3D` per object, an
`ImageTexture` generated for a viewport. Resources *are* reference-counted, so
replacing `mesh_instance.mesh` releases the old mesh — but only if nothing else
kept a reference. A demo that also stores its meshes in an array "for later"
holds every version it ever built.

`procedural-mesh` and `noise-terrain` both rebuild on every parameter change and
keep nothing, which is why they scan clean; a cache added to either would need an
eviction rule, not just an array. `multimesh` is the interesting counter-example:
its four thousand instances are rows in one buffer rather than objects, so they
cannot leak individually — which is a side benefit of `MultiMesh` worth knowing
about.

## Safeguards in the tooling

`tools/memguard.sh` is sourced by every Godot-spawning tool. Six protections,
because any one alone leaves a hole:

| Guard | What it does | Override |
|-------|--------------|----------|
| Pre-flight | Refuses to start below 2GB available | `MEM_MIN_START_MB` |
| Bounded jobs | Concurrency from free memory, not just cores; halved again if another Godot is already running; hard cap 8 | `JOBS`, `MEM_MAX_JOBS` |
| Live floor | Aborts mid-run below 1GB, checked between chunks | `MEM_FLOOR_MB` |
| Reaping | Kills our own children on exit or interrupt | — |
| **Bounded capture** | **Caps captured output at 2MB — the guard that addresses the actual cause** | `MEM_MAX_CAPTURE_KB` |
| Run timeout | Kills a single Godot invocation that will not exit | `MEM_RUN_TIMEOUT` |

Every Godot spawn also runs under an address-space `ulimit` (`MEM_ULIMIT_MB`,
4GB) so a runaway child is killed alone rather than taking the machine with it.

### Why bounded capture is the one that matters

Worth recording, because the first two guesses were both wrong. When this
tooling produced OOM kills, the kernel log named the victims:

```
Out of memory: Killed process (bash) anon-rss:41926808kB   # 40.4 GB
Out of memory: Killed process (bash) anon-rss:41926808kB   # 40.0 GB
```

**Two bash processes at 40GB each.** Not Godot, which measures ~107MB. The cause
is that `out="$(cmd)"` buffers everything the child writes into a shell
variable, and the test runner captured a whole demo run that way with no cap. A
demo that errors once per frame — or any run that does not terminate when
expected — grows the *shell* without limit. `subprocess.run(capture_output=True)`
in Python has exactly the same property.

`mem_capture` applies both a time limit and a size limit to every capture, and
announces truncation in the captured text so nothing silently analyses a partial
log. `tools/mutate.py` streams and truncates for the same reason.

Two theories the evidence did not support:

- *"Too many parallel Godot processes."* 24 jobs is ~2.6GB on a 55GB machine.
  Capping concurrency is still right, but it was never the cause.
- *"A leaking demo."* The leaks that did exist were a few objects at shutdown,
  not gigabytes.

`run-tests.sh` processes demos in chunks so the floor is re-checked as it goes
and reports a partial result rather than dying. `tools/mutate.py` checks between
demos and, crucially, **refuses to write or check the mutation baseline after an
aborted run** — a partial sweep is not comparable, and recording it would
silently lower the floor.

## Memory used by the test tooling

`run-tests.sh` runs demos in parallel. Each job is a full Godot process holding
a rendering server and an imported project — measured at ~107MB peak RSS for a
2D demo. Expect somewhat more here: a 3D project imports meshes and materials
and brings up more of the rendering server even headless, which is another
reason the concurrency default is derived from free memory rather than cores.

```
half the core count, capped at 8, and further capped at roughly 1 job per GB of
MemAvailable
```

Override with `JOBS=`:

```bash
JOBS=4 ./run-tests.sh        # tighter
JOBS=16 ./run-tests.sh       # a big machine with nothing else running
```

`tools/mutate.py` and `tools/leakcheck.sh` are deliberately serial: they are
diagnostics rather than something to finish quickly, and one process at a time
keeps their footprint at a single Godot instance.

If you are running several things at once and hit memory pressure, `JOBS=1`
makes the suite entirely sequential at the cost of wall-clock time.
