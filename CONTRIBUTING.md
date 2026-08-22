# Contributing

Thanks for wanting to add to this. This is the 3D companion to tiny-godot-games and shares its conventions.
The collection has a narrow shape on purpose,
and most of it is enforced by tooling so you get told immediately rather than in
review.

## The shape of a demo

**One demo teaches one thing, completely.** The average demo is about 100 lines
of GDScript. If yours needs three files and a diagram to follow, it is probably
two demos.

**Readability beats reusability.** If turning the mechanism into a generic
component would make the file harder to read as a lesson, don't. Package it
instead (`class_name`, `@export`, a signal) and say so in the reuse section.

**Every folder is standalone.** No shared library, no cross-demo imports. Someone
should be able to copy one directory into their project and have it work. That
means some duplication between demos, and that is the intended trade.

**Zero setup to run.** Demos use Godot's built-in `ui_*` actions rather than
defining an `[input]` map. Note that `ui_left`/`ui_right`/`ui_up`/`ui_down` are
bound to the **arrow keys only** — they do not include the letter keys — and
`ui_accept` is Enter/Space. If your demo wants the letter keys, bind
`KEY_A`/`KEY_D` explicitly in the script.

## Starting a demo

```bash
tools/new-demo.sh my-demo "One-line description for the index"
```

That scaffolds the project, a runnable scene, a script, a test suite, and a
README with the six required sections. It passes `./run-tests.sh` and
`tools/check_docs.py` from the start, so you edit down from green rather than up
from broken.

Then add a row to the index in the root `README.md` under the right category,
and bump the two demo counts (the intro and the footer). `tools/check_docs.py`
will tell you if you forget.

## Tests

Every demo has a headless suite in `tests/`, and `./run-tests.sh` runs two checks
per demo:

1. **Smoke** — boots the real `scenes/main.tscn` and fails on any script or
   scene error.
2. **Logic** — runs `tests/test_logic.gd`.

**Your suite must drive the demo's real scripts.** This is the one rule worth
belabouring: the 2D collection once had 63 demos that did not run at all while
their tests reported 100% green, because every suite reimplemented the mechanism
inline instead of loading the code it was supposedly testing. If your demo
exposes a `class_name`, instantiate it. If the component needs scene children,
instantiate `res://scenes/main.tscn` and drive the real nodes.

A suite that needs a physics step should do its work in `_physics_process` —
`direct_space_state` is only valid there. The runner allows a few frames for it.

```bash
./run-tests.sh my-demo        # one demo
./run-tests.sh                # all of them, in parallel
./run-tests.sh --smoke-only   # just boot everything
JOBS=4 ./run-tests.sh         # cap concurrency if memory is tight
```

Each parallel job is a Godot process holding a rendering server and an imported
project. The default concurrency is bounded by available memory as well as core
count for that reason; `JOBS=` overrides it. See [docs/MEMORY.md](docs/MEMORY.md).

**Six assertions is the minimum.** `tools/check_docs.py` fails a suite thinner
than that, because it is not really checking anything. `tools/mutate.py` answers
the harder question — whether the assertions you did write would notice a bug —
and CI ratchets the score, so a suite may not get weaker than the recorded
floor. [docs/TEST_INTEGRITY.md](docs/TEST_INTEGRITY.md) explains what that
measures and how to read a report.

## Checks that run in CI

| Check | What it catches |
|-------|-----------------|
| `./run-tests.sh` | Demos that fail to load, failing assertions, engine warnings, and suites that abort partway |
| `tools/check_docs.py` | Missing README sections, controls the code never binds, index drift, demo-count drift, demos that link to nothing, suites too thin to be checking much, scenes with no light in them |
| `tools/build_index.py --check` | A stale API index or stale related-demo links |
| `tools/build_tags.py --check` | Concept tags that no longer match the source they are derived from |
| `tools/mutate.py --check` | A test suite that got weaker (weekly, not per-push) |
| `gdlint` | Dead arguments, mixed tabs/spaces, tautological comparisons, naming |

`tools/preflight.sh` reports which of the repository's pipelines can run on your
machine. The tests and doc checks run anywhere Godot does; screenshots need a
display and the web export needs Godot's export templates, and preflight says so
before you start rather than partway through.

The test job runs against several Godot versions. Only the current release gates
the branch; the others are advisory early warning, because this collection has
been broken by engine API drift before and nobody noticed for a long time.

`gdformat` is deliberately **not** run. It would reformat almost every file in
the repo, collapsing the aligned constant tables that make the demos readable.
Indentation consistency is covered by gdlint's `mixed-tabs-and-spaces` instead.

## Concept tags

Every demo carries a line under its title:

```markdown
<!-- tags: physics, camera, component -->
```

Do not edit it by hand. `tools/build_tags.py` derives every tag from the demo's
own source — a demo that stops using a `RayCast3D` stops being tagged
`spatial-query` — and CI fails if the line disagrees with the code. Run the tool
after changing what a demo uses, and it writes both the line and
[docs/TAGS.md](docs/TAGS.md).

The one exception is `good-first-demo`, which is a judgement rather than
something the code can answer, so it is a hand-kept list at the top of
`tools/build_tags.py`. A demo belongs on it when it is short, teaches one idea,
and needs no concept from another demo first.

A tag with no demos is not a bug in the taxonomy — it is a subject this
collection does not cover yet, and it is listed in
[docs/GAPS.md](docs/GAPS.md) for that reason.

## What makes a demo 3D enough

`tools/check_docs.py` requires the main scene to contain a 3D node. That is not
bureaucracy: a demo that is really a 2D demo with a `Camera3D` bolted on belongs
in [tiny-godot-games](https://github.com/matthewscottconroy/tiny-godot-games), where people will find it.

It also requires the scene to contain a light or a `WorldEnvironment`. The
editor supplies a preview light that is not part of the scene, so a scene
written by hand — or copied out of the editor — renders perfectly in the editor
and black everywhere else. Nothing else in the pipeline notices: the scripts
parse, the suite passes, the smoke check boots it fine.

## README sections

All six are required, and `tools/check_docs.py` enforces their presence:

- **Purpose** — why this matters in a real game. Not a restatement of the title.
- **Controls** — every input. Say "none" if the demo is passive.
- **How It Works** — the mechanism, in the order it happens.
- **Key Godot APIs** — a table of what to look up in the docs.
- **Files** — what each file holds.
- **Use as a building block** — what to copy, the public API, and any autoloads,
  input actions, or project settings an adopter needs.

## Style

- Tabs for indentation, including continuation lines.
- Demos default to an 800x600 viewport (the 2D collection uses 640x480 — 3D
  scenes need the room).
- Put the maths in a `RefCounted` with a `class_name` and keep `scripts/main.gd`
  as the driver. It is what makes a demo testable without a scene, and in 3D
  that is the difference between a suite that states a number and one that
  cannot check anything at all.
- Type the things that matter. `var x := 5` is fine; `var x := some_dictionary[k]`
  will not compile, because Godot refuses to infer from a Variant.
- Comments explain *why*, not *what*. The code already says what.
- Prefer showing the mechanism over hiding it behind a helper.
