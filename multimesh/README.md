# MultiMesh

<!-- tags: mesh, camera, ui, procedural, component, shows-its-working -->

Ten thousand instances in one draw call with MultiMeshInstance3D, and a distance cull that costs nothing.

## Purpose

A forest made of four thousand `MeshInstance3D` nodes is four thousand nodes the
engine has to cull, sort, and issue a draw call for. A forest made of one
`MultiMeshInstance3D` is one. That is the entire performance story, and it is
easy to find.

What is not in the manual is the two decisions that come with it. **Where do the
instances go** — pure random scattering clumps, leaving bald patches and three
trees on one spot — and **how do you draw fewer of them** when the whole point is
that they are not individual nodes you can hide.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Fewer or more instances |
| 3 / 4 | Shrink or grow the cull radius |
| C | Culling on or off |
| N | New seed — a different scattering |
| Space | Pause the orbiting camera |

## How It Works

**A MultiMesh is a mesh plus a list of transforms.** Set `transform_format` to
`TRANSFORM_3D`, set `instance_count`, then `set_instance_transform(i, xform)` for
each. Setting `instance_count` reallocates the buffer, so it is done once at
build time and never per frame.

**Placement is a jittered grid.** One instance per cell, displaced by up to half
a cell. It keeps the randomness — no visible rows — and loses the clumping,
because two instances can never land in the same cell. The suite checks exactly
that: a hundred instances occupy a hundred distinct cells.

**Instances rotate about Y only.** Trees, grass and rocks scattered with a full
random basis lean off the vertical and read as broken. One angle about `UP`,
scaled uniformly.

**The scatter is deterministic.** A seeded `RandomNumberGenerator`, so the same
seed gives the same forest on every run and on every machine. Without that,
nothing about placement can be tested — and a level that is different every load
is usually a bug rather than a feature.

**Culling is one integer.** `visible_instance_count` draws the first *n*
instances and stops. That only helps if the list is ordered by whether you want
them drawn, so the field is sorted by distance once when it is built; the
per-frame work is then finding the index where the range ends.

**Instances are not nodes.** There is nothing to hide, no `visible` property,
and no per-instance script. Anything an instance needs to *do* — be collided
with, be clicked, animate independently — is an argument for it not being in a
`MultiMesh` at all.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `MultiMeshInstance3D` / `MultiMesh` | Many copies of one mesh, one draw call |
| `MultiMesh.transform_format` | 2D or 3D transforms; must be set before the count |
| `MultiMesh.instance_count` | Allocates the buffer — a build-time operation |
| `MultiMesh.set_instance_transform()` | Where each copy goes |
| `MultiMesh.visible_instance_count` | Draw only the first n — the whole cull |
| `RandomNumberGenerator.seed` | A scattering that is the same every run |

## Files

| File | What it holds |
|------|---------------|
| `scripts/scatter_field.gd` | The `ScatterField` component: jittered placement, sorting, and the cull count |
| `scripts/main.gd` | Demo driver: filling the MultiMesh and setting the visible count |
| `scenes/main.tscn` | Ground, sun, camera, and the MultiMeshInstance3D |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/scatter_field.gd` — the `ScatterField` type.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `ScatterField.new(seed_value: int)`, `set_seed()`, `seed_value()`, `capacity()`
- `transforms(count: int, height := Callable()) -> Array[Transform3D]`
- `ScatterField.sorted_by_distance(items, viewer) -> Array[Transform3D]`
- `ScatterField.visible_within(sorted, viewer, radius) -> int`
- `area`, `cell`, `min_scale`, `max_scale`

**Integrate**
1. Pass your terrain's height function as the `height` callable and the
   instances land on the ground — see
   [noise-terrain](../noise-terrain), whose `height_at()` fits directly.
2. Sort once, at build time. Re-sorting per frame around a moving camera costs
   more than the cull saves at anything under a few thousand instances.
3. For a field that follows the player, keep several `MultiMesh` patches and
   rebuild whichever one falls behind, rather than re-sorting one giant list.

**Notes**
- `class_name ScatterField` is global to the project — rename it if you already
  define that type.
- Set `transform_format` **before** `instance_count`. The other order silently
  reinterprets the buffer.
- `MultiMesh` has no collision. Scenery you can walk through is fine; anything
  solid needs its own bodies, and at that point the instance count is bounded by
  the physics rather than by the rendering.
- The renderer still frustum-culls the whole `MultiMeshInstance3D` as one object,
  by its combined AABB. A field that spans the level is never off screen, which
  is another reason to break large fields into patches.

## Related demos

- [grid-map](../grid-map) — Level building with GridMap and a MeshLibrary made in code, from a room drawn as text.
- [navigation-3d](../navigation-3d) — Baking a NavigationRegion3D at runtime and driving an agent along the path it finds.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

