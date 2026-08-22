# Distribution: why there is no addon

Every demo here ships a component with a `class_name` — `CharacterMotor`,
`OrbitRig`, `MeshBuilder` — each with a documented API and a test suite. Three is
not many, but the trajectory is obvious: a `SpringArm` rig, a `NavAgent` wrapper,
a `GridBuilder`, and at some point the obvious-looking next step is
`addons/tiny-godot-3d/` and one entry in the Godot Asset Library.

This document records the decision not to, and the conditions under which that
should be revisited. It is written down now, at three components, because the
decision is much harder to make once thirty exist and something already depends
on them.

## The tension

The repository's founding constraint is that **every folder is standalone**. No
shared library, no cross-demo imports; you copy one directory into your project
and it works. That constraint is what makes the demos readable — each one can be
understood without tracing into anything else — and it is why the collection
works as a teaching resource rather than a framework.

An addon inverts that. Once `OrbitRig` lives in a shared `addons/` folder it
stops being a file you read and starts being a dependency you install. The demo
folder becomes a usage example for a library rather than the thing itself, and
the lesson moves from "here is how a third-person camera works" to "here is how
to call our camera class".

The duplication this costs is real and worth naming: the test harness
(`expect` / `_report` / the pass-fail counters) is repeated in every suite. That
is the price of the design, not an oversight.

## The decision

**Keep the demos copy-and-go. Do not ship a combined addon.**

Reasons, in order of weight:

1. **The two goals want opposite things.** A good teaching demo is complete and
   self-contained. A good library is factored, general, and versioned. Trying to
   be both produces a mediocre version of each — files with abstraction the
   lesson does not need, and a library whose pieces are shaped by what made a
   nice demo.

2. **Copying is the honest interface for this size of code.** These components
   are 30 to 120 lines. Adding a dependency, a version constraint and an update
   path to acquire 80 lines of camera maths is worse for the adopter than
   copying it and owning it. Godot's `class_name` being globally scoped makes it
   worse still: an addon that defines `OrbitRig` collides with every project that
   already has one, which is why every reuse section says to rename.

3. **A library implies a support contract the repo cannot honour.** Published
   addons acquire issues, version-compatibility expectations, and semver
   pressure. A demo collection can freely rewrite a component when a better way
   to teach it appears; a library cannot.

4. **3D components are less generic than they look.** A camera rig encodes
   opinions about up-vectors, pitch limits and where zero yaw points; a character
   motor encodes opinions about air control and coyote time. Those are exactly
   the numbers an adopter must own and tune. A 2D `Health` component travels
   almost unchanged between projects — `OrbitRig` will not, and pretending
   otherwise by versioning it would be the wrong promise.

## What is done instead

- Every demo carries a **Use as a building block** section: what to copy, the
  public API, and any autoloads, input actions, or project settings the adopter
  needs. That is the packaging.
- Components live in their own file with a `class_name`, so copying one file is
  usually enough. `scripts/main.gd` is always the driver and is never needed.
- The reuse notes warn about `class_name` collisions explicitly, because that is
  the failure mode copying actually has.

## When to revisit

Ship an addon if **all** of these become true:

- Several components need to reference each other to be useful, so copying one
  stops being sufficient.
- The same component is being copied into enough projects that fixes are not
  reaching them, and that is causing real problems.
- Someone is prepared to maintain a versioned release with a compatibility
  policy, separately from the demos.

Until then the honest position is: this is a collection of examples, and the
best way to use one is to read it and take it.

## Asset Library, narrowly

Publishing individual entries — one component, not a bundle — sidesteps most of
the objections above and is worth considering for anything both self-contained
and widely wanted. Each would need its own `class_name` prefix to avoid
collisions, and its own README. That is a per-component decision rather than a
repo-wide one, and nothing here forecloses it.

## Pipelines that need more than Godot

Two of the tools here cannot run on a machine with only the editor installed:

| Pipeline | Needs | Why it is not in CI on every push |
|----------|-------|-----------------------------------|
| `tools/screenshots.sh` | a display (`xvfb-run`) | Godot's headless mode uses a dummy renderer, so a capture returns null |
| `tools/export_web.sh` | web export templates (~1GB) | a separate download from the editor |

`tools/preflight.sh` reports which pipelines can run here and what each missing
one needs, so the answer arrives before a capture starts rather than partway
through it. Both scripts refuse to run and say why, so a machine without the
prerequisites produces a message rather than blank images or failed exports.

Neither has been validated end to end from this repository. That is recorded
here rather than left to be discovered: the workflows exist and the scripts are
a starting point, and the first run of each should be treated as a bring-up
exercise. The web export in particular has an extra unknown in 3D — the web
target is WebGL2 through the Compatibility renderer, and these demos are written
for Forward+.
