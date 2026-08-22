# Animation in Code

<!-- tags: animation, ui, component, shows-its-working -->

Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk.

## Purpose

Animation in Godot is normally authored in the editor's timeline or imported
from a model, and both of those hide what an `Animation` actually *is*: a list
of tracks, each one a path to a property and a list of (time, value) keys.
Nothing about it needs a file, an artist, or a rigged character.

That matters beyond curiosity, because some motion cannot be authored in
advance. A door whose swing depends on how wide it is. A creature assembled at
runtime. A beat generated from a config file. All of those are clips you have to
build, and the API for building one is small enough to fit on a page.

The lesson underneath the API is **phase**. A walk is not four legs moving; it is
four legs moving out of step with each other by the right amounts. The same keys
with the wrong offsets give you a creature that hops.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Shorter or longer stride |
| 3 / 4 | Slower or faster tempo |
| Space | Stop and start |

## How It Works

**A clip is tracks, and a track is keys.** `add_track(TYPE_POSITION_3D)`,
`track_set_path()`, `position_track_insert_key(track, time, value)`. Three calls
and there is an animation. `ClipBuilder` is a thin layer over exactly that.

**Rotation tracks hold quaternions.** Not Euler angles — and that is not an
inconvenience to work around. Interpolating Euler angles takes the wrong path
between two orientations and hits gimbal problems on the way, which is why the
track type exists at all.

**A looping clip needs its last key to match its first.** Otherwise the wrap
from the end of the cycle back to the start is a jump, and a limb that snaps
once per cycle reads as a dropped frame. `add_swing_track()` closes the loop by
sampling t=0 and inserting that value at t=length.

**Diagonal pairs, half a cycle apart.** `walk_cycle()` gives front-left and
back-right the same phase, and front-right and back-left the opposite one. That
is a trot, and it is what makes the result read as walking. All four in step is
a hop — same keys, wrong phases.

**Godot 4 keeps animations in libraries.** An `AnimationPlayer` with no
`AnimationLibrary` plays nothing, and there is no implicit one. The empty string
is the default library's name, so clips added to it are addressed by their own
name alone.

**Ask before you fetch.** `player.get_animation_library("")` on a player that has
none prints an engine error before returning null. `has_animation_library()`
first — "no library yet" is the normal state of a fresh player, and normal states
should not print like bugs.

**The clip is rebuilt, not edited.** Changing the stride throws the whole
`Animation` away and makes another. Resources are cheap; editing keys in place is
much harder to follow.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Animation.add_track()` / `track_set_path()` | Making a track and pointing it at a node |
| `Animation.position_track_insert_key()` / `rotation_track_insert_key()` | Adding keys |
| `Animation.position_track_interpolate()` / `rotation_track_interpolate()` | Sampling a clip — what the tests assert on |
| `Animation.length` / `loop_mode` | How long the cycle is, and whether it repeats |
| `AnimationLibrary.add_animation()` | Where a clip has to live to be playable |
| `AnimationPlayer.play()` / `current_animation_position` | Playing it, and where it is now |

## Files

| File | What it holds |
|------|---------------|
| `scripts/clip_builder.gd` | The `ClipBuilder` component: tracks, keys, swings, the gait, and installation |
| `scripts/main.gd` | Demo driver: the creature, the rebuild, and the circle it walks in |
| `scenes/main.tscn` | A four-legged creature made of primitives, and an empty AnimationPlayer |
| `tests/test_logic.gd` | Headless test suite — including sampling the built clips |

## Use as a building block

**Copy:** `scripts/clip_builder.gd` — the `ClipBuilder` type. `scripts/main.gd`
is the demo driver and is not needed.

**Public API**
- `ClipBuilder.new_clip(length, loop := true) -> Animation`
- `add_position_track(clip, path, keys) -> int`, `add_rotation_track(clip, path, keys) -> int`
- `add_swing_track(clip, path, axis, degrees, phase := 0.0) -> int`
- `walk_cycle(legs: Array[NodePath], degrees, period) -> Animation`
- `install(player, clip, clip_name)`, `phase_at(time, period, phase) -> float`

**Integrate**
1. Track paths are relative to the `AnimationPlayer`'s `root_node`, which
   defaults to its parent. A path that does not resolve is silently ignored —
   the commonest reason a hand-built clip appears to do nothing.
2. Use `phase_at()` for anything that must stay in step with the clip without
   being part of it: footstep sounds, dust puffs, screen shake on a landing.
3. Value tracks (`TYPE_VALUE`) animate any property at all — a light's energy, a
   material's albedo, an exported script variable. The mechanics are identical.

**Notes**
- `class_name ClipBuilder` is global to the project — rename it if you already
  define that type.
- Four keys per swing is enough because the interpolation does the smoothing. If
  a limb needs to ease rather than travel linearly, set the key's transition
  curve with `track_set_key_transition()` rather than adding more keys.
- For blending between clips — walk into run — the next step is `AnimationTree`
  with a blend space, which consumes the same `Animation` resources this builds.

## Related demos

- [animation-tree](../animation-tree) — An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching.
- [lod-and-decals](../lod-and-decals) — Distance bands that drive mesh LOD, decal fade and update rates — with the hysteresis that stops them flickering.
- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.
- [tween-3d](../tween-3d) — Tween or AnimationPlayer — what each is for, and the two tweens that end up fighting over one property.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

