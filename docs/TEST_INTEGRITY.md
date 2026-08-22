# Test integrity

## The problem this measures

Every demo ships a test suite. The easy way to write one is to reimplement the
demo's mechanism inline — a `class FakeMotor`, or the maths copied out of the
real script — and then test the copy. Such a suite stays green no matter what
happens to the demo.

That is not a hypothetical weakness. It is how this collection's 2D sibling once
had **63 demos that did not run at all** while every suite reported 100%
passing. The smoke check in `run-tests.sh` closes the catastrophic case: a demo
whose scripts do not parse, or whose scene warns, now fails immediately. It does
not close the subtler one, where the demo runs fine and is quietly wrong.

`tools/mutate.py` measures that. It makes a small deliberate change to a demo's
real scripts — flips a comparison, swaps `and` for `or`, negates a constant — and
re-runs only the logic suite. If the suite still passes, that mutation
**survived**, and nothing in the suite depends on the mutated behaviour.

```bash
tools/mutate.py                      # every demo
tools/mutate.py orbit-camera --verbose   # one demo, listing what survived
tools/mutate.py --json report.json   # machine-readable
```

`scripts/main.gd` is excluded by default: it is the demo driver — scene wiring,
HUD, input plumbing — and is not unit-tested by design. `--include-driver`
overrides that.

## Why 3D makes this worse

A wrong 2D number usually shows: the sprite is in the wrong place, on screen,
where you are looking. A wrong 3D number frequently does not. A sign flip in a
camera offset puts the camera on the far side of the target, which still renders
a scene. A wrong index in a mesh builder produces geometry that is only wrong
from an angle you did not check. A movement basis that is not flattened drifts
into the floor over several seconds.

So every demo here puts its maths in a `RefCounted` — `CharacterMotor`,
`OrbitRig`, `MeshBuilder`, `TerrainField`, `ShadowBudget` and the rest —
precisely so a suite can state the number rather than look at the picture. Mutation testing is how we find out whether the suite
actually does.

## The baseline

First full run, four mutations per demo:

```
8/16 mutations caught (50%)
0 suites caught everything, 0 caught nothing
```

Every suite was catching something and none was catching much. What survived was
specific and worth reading:

| Survived | Why the suite missed it |
|----------|-------------------------|
| `position_for()` returning `target - offset()` | the suite checked the offset's length and direction, never that it was added to the target |
| `pitch + relative.y` becoming `pitch - relative.y` | pitch limits were tested; the direction the mouse moves it was not |
| `hit_distance - padding` becoming `+ padding` | pull-in was checked as "closer than before", not as a number |
| ring indices `(i + 1) % count` becoming `(i - 1) % count` | the suite counted indices and checked every vertex was used, which both hold for the wrong winding |
| `_was_on_floor = false` in `reset()` | nothing checked the motor's state *after* a reset, only its velocity |

Each of those is a real bug the demo could have shipped with. Six assertions
fixed all five, and they are the kind that name a number: `position_for(t) ==
t + offset()`, `pulled_in(4.0, 0.5).length() == 3.5`, the ring's index list
written out in full.

### A correction to the measurement

Two of the mesh mutations were recorded as survivors when they were nothing of
the sort. `add_index(-1)` raises an error, the error abandons `grid()`, the test
that would have caught it never runs — and the suite prints a *smaller*
`n/n passed` with the counts still agreeing. `run-tests.sh` has gated on that
since it was written; `mutate.py` did not, so it read "suite passed" and scored
the mutation as missed. It now applies the same abort check, which has since
been widened twice — see [below](#a-gap-in-the-abort-check-found-the-same-way).

With the assertions added and the measurement fixed, at six mutations per demo:

```
23/24 mutations caught (96%)
3 suites caught everything, 0 caught nothing
```

Each demo added since has been measured the same way before being committed, and
each sweep has been worth running: the batches that took the collection to
eighteen and then twenty-four demos turned up a region classifier whose
thresholds nothing checked, a mesh row loop that could subtract where it added,
a route that reported itself finished before it started, a camera arm that moved
in zero time, a pooled instance left physics-processing while parked, a step
height measured from the world origin instead of from the character's feet, and
an `aim()` that would have passed every assertion by returning the identity
basis. All of them were real. All of them were fixed by assertions that state a
number.

At twenty-five projects the floor is:

```
144/144 mutations caught (100%)
25 suites caught everything, 0 caught nothing
```

100% is not a target to defend at any cost — a score chased by writing
assertions about the mutations themselves would be worthless. It is where this
collection happens to be, and the two things that got it there are worth more
than the number.

### Killing the last survivor: input the suite presses itself

`character-controller-3d/scripts/player.gd` had one line nothing could reach:

```gdscript
direction = direction.normalized() if direction.length() > 0.001 else Vector3.ZERO
```

It lives in the `CharacterBody3D` script, between `Input` and
`move_and_slide()`, and it was listed here for a long time as a gap that would
need "a physics scene and synthesised input".

Both turn out to be available. `Input.action_press()` sets an action's strength
directly — no window, no keyboard, no device — and it is what `Input.get_vector`
reads. The suite instantiates the real scene, presses `ui_up`, runs physics
frames, and asserts the body moved in the direction pressed:

```gdscript
Input.action_press(&"ui_up")
# ... some physics frames later
expect(player.global_position.z < _start.z, "in the direction that was pressed")
```

That closed the only genuine hole in the collection. Anything else that reads
`Input` can be tested the same way.

### Equivalent mutants are a code smell, not an exception

Four mutations survived every attempt to write a test for them, because no test
exists: they cannot change the answer.

| Survivor | Why it could not be caught |
|----------|---------------------------|
| `cos((h - 12) / 24 * TAU)` → `cos((h + 12) / …)` | the two differ by exactly one period |
| `seen[tag] = true` → `false` | a Dictionary used as a set; only `has()` was ever read |
| `advance()`'s `or finished()` guard → `and` | the clamp below already made it a no-op |
| `sun_energy`'s night branch → `and` | both ramps clamp to zero, so the branch never decided anything |

The tempting move is to list them as exceptions. The better one turned out to be
to take each as a hint that the code said something twice:

- The cosine became `-cos(hours / 24 * TAU)` — "lowest at midnight", with no
  offset in it to get wrong.
- The dictionary went away; the list is its own seen-set.
- The redundant guard and the unreachable branch were deleted.

All four demos got shorter, and the mutants disappeared with the duplication
that made them equivalent. A mutation that cannot change behaviour is usually
pointing at a line that was not doing anything.

### Suites that instantiate their own scene

Several suites load `scenes/main.tscn` and drive it, because a physics query, a
`SpringArm3D` sweep, a navigation bake or an `Area3D` overlap has no meaning
without a real world to run in. 3D needs that far more often than 2D does.

`mutate.py` reads "instantiates the scene" as evidence that the suite is testing
`scripts/main.gd`, and starts mutating the driver. For most of these that is the
wrong conclusion: the scene is there to exercise the *engine*, and the driver's
mouse handling remains as untestable as everyone else's. Those suites carry a
marker, with the reason:

```gdscript
# mutate-driver: skip — the scene is instantiated to fire a real ray, not to test main.gd
```

Ignoring a measurement is worse than fixing it, so the marker is deliberately
explicit and takes a reason, the same way `check_docs.py`'s `size-exempt` does.

### A gap in the abort check, found the same way

Two mutations were once recorded as survivors when what actually happened was an
error. GDScript aborts the function an error occurs in and returns **the return
type's default** — and for a function typed `-> Vector3` that default is
`Vector3.ZERO`, which happened to be exactly what the test expected. The suite
passed, through the error path, with the error printed above it.

Both gates now match `Out of bounds` and `Invalid access to index` as well; they
had only `Invalid index`, which Godot does not say. A suite that errors is a
suite whose score means nothing, and the list of ways it can error is worth
keeping current.

### A survivor that was a hang

`menu-navigation` skips past disabled items when focus moves, and wraps off the
end of a column. Those two together are a loop with no end when *everything* is
disabled — which is what a menu looks like while a dialogue has greyed it all
out. It does not error; the game stops.

The mutation that surfaced it was on the loop's escape clause, and the honest
fix was not to assert harder on that clause but to bound the loop at one step
per item. The suite now disables the whole menu and checks that moving returns.

That is the useful shape of a survivor: not "how do I kill this mutation" but
"what does the suite not know" — and here the answer was a case the code could
not survive.

### Three equivalent mutants, three simplifications

A round of this collection produced three survivors that no assertion could
honestly kill, and each one was pointing at a line that said nothing:

- `clampi(button, JOY_BUTTON_A, JOY_BUTTON_Y) - JOY_BUTTON_A`. `JOY_BUTTON_A` is
  zero, so the subtraction was decoration. Removed, with a comment saying why the
  clamped value *is* the position.
- `is_instance_valid(tween) and tween.is_valid()`. A `Tween` is reference-counted
  and the dictionary held a reference, so the first half was always true.
  Removed.
- A ray-crossing point-in-polygon test, where casting the ray left or right gives
  the same answer for any closed polygon. Replaced with a convex test — which
  has no ray direction to get backwards, and which suits the domain, since
  navigation obstacle outlines have to be convex anyway. Its own `(i + 1) % count`
  then survived for the same reason, and became a previous-and-current loop with
  no index arithmetic at all.

None of those changes were made to move a number. Each one deleted a choice that
had no consequence, which is what an equivalent mutant is reporting.

### A demo that crashed after passing

`tools/mutate.py` treats a killed process as a caught mutant, so it checks the
exit code as well as the summary. That is how `threaded-loading` turned up as
`already-failing` while `run-tests.sh` had it green: the suite printed
`23/23 passed` and then Godot aborted on the way out, roughly four runs in five,
because a threaded load had been requested and never collected.

Two things were wrong, and only one of them was in the demo:

- The suite left a `ResourceLoader.load_threaded_request()` outstanding. There
  is no cancel, and an outstanding request at shutdown takes the process down
  with `SIGABRT`. It is collected now.
- `run-tests.sh` was already checking the exit status — but `mem_capture` piped
  the child through `head -c` and returned *`head`'s* status, so every caller
  saw a clean 0. The pipeline now propagates `${PIPESTATUS[0]}`.

The lesson is not about threads. A harness that reads a suite's self-report and
not its exit code believes the suite about its own death, and the only reason
this was ever noticed is that a second tool measured the same run differently.

## Reading a report

```
part   procedural-mesh              4/6 caught  ( 67%)
         survived scripts/mesh_builder.gd:44  arithmetic  st.add_index(i + 1) -> st.add_index(i - 1)
```

A survivor names a file, a line, and the exact edit. The useful question is not
"how do I make this mutation fail" but "what should the suite have known that it
did not" — the assertion that answers it usually catches several mutations at
once, and often describes the demo better than the ones already there.

**A survivor from a full sweep may not reproduce on its own.** One `random.Random`
is shared across the whole run, so which five mutations a demo gets depends on
how many demos ran before it. `tools/mutate.py one-demo` re-rolls a different
five and can come back clean while the sweep still has a survivor. That is not a
flake, and the fix is not to keep re-running: take the file and line from the
sweep's `--verbose` output and write the assertion for *that* edit. Raising
`--limit` on the single demo is the cheap way to see more of its surface at once.

Two failure modes to avoid while chasing a score:

- **Asserting the implementation.** A test that recomputes the demo's expression
  and compares it to itself kills mutations and checks nothing. State the
  expected number.
- **Testing the mutation.** Six assertions about the sign of one variable raise
  the score and teach nobody anything. If the surviving mutation does not
  correspond to a way the demo could plausibly be wrong, say so here instead.

## Where it runs

The full sweep is several hundred Godot invocations, so it does not gate a push.
`.github/workflows/tests.yml` runs it weekly and on manual dispatch, against the
baseline. Scripts are restored after every run, including on Ctrl-C — and any
run that finds a leftover mutation from a killed process restores it before
starting.
