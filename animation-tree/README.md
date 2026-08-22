# Animation Tree

<!-- tags: animation, ui, component, shows-its-working -->

An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching.

## Purpose

[animation-in-code](../animation-in-code) builds clips. This is what you do with
more than one of them: an `AnimationTree` blending between idle, walk and run
according to how fast the character is actually moving.

Feeding the character's speed straight into the blend is the obvious approach
and is wrong in three ways, all of which a player feels rather than sees:

- **Idle twitch.** A character standing still is never exactly still — a stick
  drifts, a body settles, a slope nudges — so the idle clip flickers into the
  walk clip several times a second.
- **A snapping blend.** Speed can change instantly; a gait cannot, or the legs
  change between one frame and the next.
- **Blend space units are not metres per second.** Blend points sit at 0, 1 and
  2 because that is how they were authored. Passing raw speed works until
  someone tunes the movement.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Slower or faster |
| 3 | Stop |
| 4 | Sprint |

The readout shows the speed, the blend position, and which clip is doing most of
the work.

## How It Works

**The whole tree is built at runtime.** Three clips into an `AnimationLibrary`,
an `AnimationNodeBlendSpace1D` with a point per clip, `tree_root` set to the
space, `anim_player` pointed at the player. Six lines, and it makes the shape of
an `AnimationTree` visible in a way the editor's graph does not.

**Blend points want names.** `add_blend_point(node, position, at_index, name)` —
leave the name out and Godot warns, because an unnamed point is referenced by
index, and indices move when points are added or removed. Anything built from
one goes quietly stale.

**An inactive tree does nothing.** `tree.active = true` is the last line of the
setup and the commonest reason a correctly built tree animates nothing at all.
Setting it also stops the `AnimationPlayer` being in charge — the tree drives
the player from then on.

**Speed is mapped, not passed.** `position_for()` puts the character's walk
speed on the walk point and its run speed on the run point, so the blend space
keeps its own units. Change `WALK_SPEED` in the driver and the animation still
lines up.

**The deadzone measures from itself.** Below the idle threshold, the blend is
zero. Just above it, the blend starts from zero too — the span is measured from
the threshold rather than from zero speed, so the first moving frame is not
already a quarter of the way into a walk.

**The blend chases the speed.** `1 - exp(-rate·delta)`, frame-rate independent,
so a gait change takes the same time on any machine. The suite asserts two
half-steps land where one whole step does.

**Foot sliding is a playback rate.** `time_scale_for()` scales the clip's speed
by how fast the character is really moving relative to how fast the clip was
authored for. Clamped, because a sprint at 3× playback is a blur rather than a
run.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `AnimationTree.tree_root` / `anim_player` / `active` | The three properties that make a tree work |
| `AnimationNodeBlendSpace1D.add_blend_point()` | A clip at a position in the space, with a name |
| `AnimationNodeAnimation.animation` | Which clip a blend point plays |
| `tree.set("parameters/blend_position", x)` | Driving the blend — parameters are set by path |
| `AnimationLibrary.add_animation()` | Where the clips have to live |
| `AnimationPlayer` | Still needed: the tree plays *its* clips |

## Files

| File | What it holds |
|------|---------------|
| `scripts/blend_driver.gd` | The `BlendDriver` component: speed to blend position, deadzone, smoothing, time scale |
| `scripts/main.gd` | Demo driver: the clips, the tree, and the pawn that walks |
| `scenes/main.tscn` | A strip of ground, a two-legged pawn, an empty player and tree |
| `tests/test_logic.gd` | Headless test suite — including the real tree the driver builds |

## Use as a building block

**Copy:** `scripts/blend_driver.gd` — the `BlendDriver` type. `scripts/main.gd`
is the demo driver, though its `_build_tree()` is worth reading twice.

**Public API**
- `BlendDriver.position_for(speed, walk_speed, run_speed, idle_threshold := 0.15) -> float`
- `update(speed, walk_speed, run_speed, delta) -> float`, `blend()`, `snap(...)`, `reset()`
- `BlendDriver.dominant_clip(blend_position) -> String`
- `BlendDriver.time_scale_for(speed, clip_speed, limits := Vector2(0.6, 1.8)) -> float`
- `idle_threshold`, `smoothing`

**Integrate**
1. Feed it the speed the character *actually* moved at — measure it after
   `move_and_slide()` — rather than the input. Walking into a wall should not
   animate a walk.
2. Author the blend space in the editor for a real project; this builds one in
   code because the collection ships no scenes to inherit. The driver is the same
   either way.
3. Use `dominant_clip()` for anything that has to stay in step without being in
   the tree: footstep sounds, dust, camera bob.

**Notes**
- `class_name BlendDriver` is global to the project — rename it if you already
  define that type.
- A 1D blend space handles speed. Strafing wants
  `AnimationNodeBlendSpace2D` with a direction vector, and the mapping problem is
  the same one in two axes.
- `AnimationNodeStateMachine` is the other half of `AnimationTree` — states and
  transitions rather than a continuous blend — and the two nest inside each
  other, which is how a real character rig is usually built.

## Related demos

- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.
- [animation-in-code](../animation-in-code) — Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk.
- [area-trigger-3d](../area-trigger-3d) — Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

