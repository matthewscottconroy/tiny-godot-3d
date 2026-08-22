# Save and Load 3D

<!-- tags: ui, procedural, persistence, component, shows-its-working, good-first-demo -->

Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration.

## Purpose

The tempting way to save a 3D scene is `ResourceSaver.save(PackedScene)` — take
the whole tree, write it out, load it back. It works exactly once. Then someone
edits the level, and the save file restores the *old* geometry, the old scripts
and the old node names over the new ones. Players who load an old save get last
week's level.

A save file should hold **state, not scenes**: which objects there were and
where, keyed by name. Restoring is then a lookup against whatever level is
actually loaded, and every mismatch — a node the file does not know about, an
entry with no node left to apply it to — is a shrug rather than an error.

The other half is the version number. It costs one line to write and is the only
thing that lets a file outlive the format it was written in, which it will, the
first time anyone adds a field.

## Controls

| Key | Action |
|-----|--------|
| R | Scatter the crates |
| S | Save where they are |
| L | Load them back |
| D | Delete the save file |

Scatter, save, scatter again, load. The path the file is written to is shown at
the bottom of the screen.

## How It Works

**`user://`, not `res://`.** An exported game's `res://` is inside the package
and read-only. `user://` maps to a per-user writable directory —
`~/.local/share/godot/app_userdata/<name>` on Linux, `%APPDATA%` on Windows —
and `ProjectSettings.globalize_path()` turns it into the real path, which the
demo prints so there is no mystery about where the file went.

**Transforms are three plain numbers each.** JSON has no `Vector3`, so a
position is an array of three floats. An array rather than a `{x, y, z}` object:
smaller, and it round-trips without ambiguity.

**Nothing in the file is trusted.** A save file is data from outside the
program — hand-edited, truncated, copied from another version. Every value is
type-checked on the way in and falls back to what the node already had. The
suite hands it a string where a position should be, a two-element rotation and a
null scale, and the scene survives all three.

**Corrupt files read as empty, not as errors.** `JSON.new().parse()` rather than
`JSON.parse_string()`: the instance form returns an error code, while the static
one prints an engine error first. A truncated save is an expected condition, and
expected conditions should not look like bugs in the log.

**Old files are migrated, not rejected.** Version 1 stored a bare position array
per node. `migrated()` fills in the rotation and scale it never had and stamps
the current version. "Unsupported save version" is, to a player, the same
sentence as "your progress is gone".

**Names are the key, so names matter.** Node names are unique per parent, and
renaming a node in the editor orphans its saved state. For anything that is
spawned rather than authored, save a stable id of your own instead.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `FileAccess.open()` / `store_string()` / `get_as_text()` | Reading and writing the file |
| `FileAccess.file_exists()` | Is there a save at all |
| `ProjectSettings.globalize_path()` | Where `user://` actually is |
| `JSON.stringify()` / `JSON.new().parse()` | Serialising, and parsing without noise |
| `DirAccess.remove_absolute()` | Deleting a save |
| `is_instance_valid()` | Skipping nodes freed since capture |

## Files

| File | What it holds |
|------|---------------|
| `scripts/scene_snapshot.gd` | The `SceneSnapshot` component: capture, apply, migrate, read, write |
| `scripts/main.gd` | Demo driver: the crates and the four keys |
| `scenes/main.tscn` | A floor, four crates, a camera and the HUD |
| `tests/test_logic.gd` | Headless test suite — including a real write to `user://` |

## Use as a building block

**Copy:** `scripts/scene_snapshot.gd` — the `SceneSnapshot` type.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `SceneSnapshot.capture(nodes: Array[Node3D]) -> Dictionary`
- `SceneSnapshot.apply(snapshot, nodes) -> int` — how many were restored
- `SceneSnapshot.save_to(path, snapshot) -> Error`, `load_from(path) -> Dictionary`
- `SceneSnapshot.migrated(snapshot) -> Dictionary`, `size_of(snapshot) -> int`
- `SceneSnapshot.VERSION`

**Integrate**
1. Save state, never scenes. Extend the per-node dictionary with whatever your
   objects need — hit points, inventory, whether a door is open — and leave the
   level geometry to the level.
2. Bump `VERSION` and add a step to `migrated()` in the same commit that changes
   the format. A migration written later has to guess what the old files
   contained.
3. Write to a temporary file and rename it over the real one if a partial write
   would be catastrophic. `FileAccess` has no atomic save; the rename is the
   trick.

**Notes**
- `class_name SceneSnapshot` is global to the project — rename it if you already
  define that type.
- JSON is chosen for being readable while debugging. `FileAccess.store_var()`
  is smaller and faster and produces a file nobody can inspect — which is the
  right trade only once the format has stopped changing.
- Nothing here encrypts or signs anything. A player who edits their own save is
  not an attacker; a leaderboard that trusts one is a different problem.

## Related demos

- [accessibility-3d](../accessibility-3d) — Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.
- [editor-tool-3d](../editor-tool-3d) — A @tool script that builds a fence along a Path3D and updates while you drag the curve in the editor.
- [navigation-obstacle](../navigation-obstacle) — Why a NavigationObstacle3D does not change the path, and the two mechanisms that do.
- [object-pool-3d](../object-pool-3d) — Recycling scene instances instead of allocating them, and the reset step that makes pooling safe.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

