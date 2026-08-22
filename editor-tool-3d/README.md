# Editor Tool

<!-- tags: mesh, ui, component, tool-script, shows-its-working -->

A @tool script that builds a fence along a Path3D and updates while you drag the curve in the editor.

## Purpose

Everything else in this collection runs when you press play. A `@tool` script
runs **in the editor**, which is a different set of rules: the scene it is
editing is somebody's work in progress, the nodes it creates can end up
committed to version control, and a mistake shows up as a corrupted scene rather
than as a crash.

That makes editor tooling the one place where "it works" is not the bar. This
demo builds a fence along a curve — posts fitted to the length, rails between
them — and the interesting content is the three rules that keep it from doing
damage while it does so.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Wider or tighter post spacing |
| 3 / 4 | Fewer or more rails |
| Space | Stop animating the curve |

Better still, open `scenes/main.tscn` in the editor and drag the `Path3D`'s
points. The fence rebuilds as you drag.

## How It Works

**`@tool` on the first line, and `Engine.is_editor_hint()` around anything that
should not run there.** The annotation is all it takes to make a script run in
the editor; the guard is what keeps it from moving the player or playing a sound
while somebody is editing.

**Generated children have no `owner`, so they are never saved.** A node added
with `add_child()` and no owner is not written into the scene file. Without
that, every rebuild leaves the scene file fatter than it was, and a colleague's
merge conflict is hundreds of fence posts long. The suite asserts it: none of
the generated nodes would be saved.

**Rebuilding clears first, and clears *now*.** `queue_free()` is deferred, so a
rebuild that relies on it briefly has two fences. `remove_child()` then
`queue_free()` takes them out of the tree in the same frame.

**Property setters rebuild.** Each exported property has a setter that calls
`_rebuild()`, which is what makes the tool feel live rather than needing a
button. `rebuild_now` is a checkbox that acts as a button, for the case the
editor does not tell us about: dragging a point on the curve.

**`_get_configuration_warnings()` is the editor's own feedback channel.** A
missing `Path3D` or a curve with one point produces a warning attached to the
node, in the scene tree, where it survives a reload. `print()` in an editor
script goes to a log nobody has open.

**The arithmetic lives outside the tool script.** `FencePlan` is a plain
`RefCounted`, so the part that decides where things go can be tested like
anything else. The fitting is the reason it needs to be: a post every two metres
along a 9.4-metre path leaves a 1.4-metre gap and a post hanging past the end,
which reads as a broken tool. Dividing the length into equal spans instead is
three lines, and the suite pins them.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `@tool` | Run this script inside the editor |
| `Engine.is_editor_hint()` | Tell the two contexts apart |
| `Node.owner` | Whether a node is written into the scene file — leave it null |
| `Node._get_configuration_warnings()` | Warnings attached to the node in the scene tree |
| `Node.update_configuration_warnings()` | Asking the editor to re-read them |
| `Curve3D.sample_baked()` / `get_baked_length()` | Walking along the path |
| `@export` setters | Rebuilding as soon as a property changes |

## Files

| File | What it holds |
|------|---------------|
| `scripts/fence_plan.gd` | The `FencePlan` component: fitted spacing, post positions, rail transforms |
| `scripts/fence_builder.gd` | The `@tool` script: the three rules, and the nodes it makes |
| `scripts/main.gd` | Demo driver: animates the curve so the rebuild is visible without an editor |
| `scenes/main.tscn` | Ground, the fence builder, and its Path3D |
| `tests/test_logic.gd` | Headless test suite — including what the tool does to the tree |

## Use as a building block

**Copy:** `scripts/fence_builder.gd` and `scripts/fence_plan.gd` — the tool and
its arithmetic. `scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `FencePlan.post_distances(length, wanted_spacing) -> Array[float]`
- `FencePlan.fitted_spacing(length, wanted_spacing) -> float`
- `FencePlan.post_count(length, wanted_spacing) -> int`
- `FencePlan.rail_transform(from, to) -> Transform3D`
- `FencePlan.post_yaw(direction) -> float`
- `FenceBuilder.spacing`, `post_height`, `rails`, `rebuild_now`, `generated_count()`

**Integrate**
1. Never give generated nodes an owner unless you *want* them in the scene file.
   If you do want that — a bake step, deliberately triggered — set the owner
   only in that path, and say so in the property's name.
2. Guard anything with a side effect outside the node's own subtree with
   `Engine.is_editor_hint()`. A tool script that spawns a manager or writes to
   `user://` while the editor is open is a bad afternoon.
3. Keep the maths in a plain object. Everything in `FencePlan` is tested;
   nothing in `fence_builder.gd` could be tested as easily, and that asymmetry is
   the whole argument for the split.

**Notes**
- `class_name FencePlan` is global to the project — rename it if you already
  define that type.
- A `@tool` script that errors in the editor keeps erroring on every redraw.
  Fix it by closing the scene, correcting the script, and reopening — not by
  clicking through a hundred error dialogs.
- `EditorPlugin` is the next step up: gizmos, docks, importers, custom
  inspectors. `@tool` on a node is enough for anything that only needs to build
  its own children.

## Related demos

- [save-load-3d](../save-load-3d) — Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration.
- [object-pool-3d](../object-pool-3d) — Recycling scene instances instead of allocating them, and the reset step that makes pooling safe.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.
- [navigation-3d](../navigation-3d) — Baking a NavigationRegion3D at runtime and driving an agent along the path it finds.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

