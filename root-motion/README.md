# Root Motion

<!-- tags: physics, animation, ui, component, shows-its-working -->

Motion that comes from the animation rather than from the code, and the sliding feet it exists to fix.

## Purpose

Normally a character moves because code moved it, and the walk cycle is
decoration played on top. The feet slide, because the animation's stride and the
code's speed have no reason to agree.

Root motion inverts that. The animation moves the root bone, the game reads how
far it moved this frame, and *that* is the character's velocity. The feet cannot
slide, because the feet are what decides the speed.

The price is control. A clip that says "step forward 0.6 metres" says it whether
or not the player wanted 0.6 metres, so anything that must respond immediately —
a dodge, a knockback, a platformer jump — fights it. Root motion suits
deliberate movement: melee attacks, climbing a ladder, a heavy character.

## Controls

| Key | Action |
|-----|--------|
| A / D | Turn — the same clip then walks somewhere else |
| 1 / 2 | The speed you *want*, against the speed the clip has |
| B | Hand the movement to the code instead, and watch the feet stop agreeing |
| R | Reset |

## How It Works

**The value is already per-frame.** `get_root_motion_position()` returns how far
the root moved *since the last call* — a distance, not a velocity. Multiplying
it by delta a second time gives motion that is correct at 60fps and eight times
slower at 8fps, which is the version of this bug that ships.
`RootStep.velocity_for()` divides.

**It is in the character's local space.** Turn, and the same clip pushes a
different way. Applied in world space it walks north for ever, whatever the
character is facing.

**Consume it exactly once per frame.** The tree hands over the accumulated
motion and resets; a second reader in the same frame gets nothing. The suite
checks that too, because it is the sort of thing a refactor breaks silently.

**Tell the tree which track carries it.** `root_motion_track` is a `NodePath` to
the animation track — here `^"Root"`, matching a `TYPE_POSITION_3D` track on the
node called `Root`. Get it wrong and every read comes back zero, with no error.

**Step the tree on physics.** `callback_mode_process` defaults to idle frames. A
tree processed on idle handing motion to a body that moves on physics gives two
clocks that disagree by however far apart they happen to be.

**Go faster by playing the clip faster.** `playback_scale()` is the honest fix:
the stride still lands where the movement says it does. Scaling the *translation*
instead is where sliding comes back, with extra steps.

**Authority is a blend, not a switch.** `blend()` mixes clip-driven and
code-driven velocity: 1 is pure root motion, 0 is an ordinary character
controller, and most games live in between — a locked attack the player can
still steer a little.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `AnimationTree.root_motion_track` | Which track is motion rather than pose |
| `AnimationTree.get_root_motion_position()` | This frame's motion, consumed on read |
| `AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS` | Stepping the tree where the body moves |
| `Animation.add_track(TYPE_POSITION_3D)` | The track the stride is baked into |
| `CharacterBody3D.move_and_slide()` | Where the resulting velocity ends up |

## Files

| File | What it holds |
|------|---------------|
| `scripts/root_step.gd` | The `RootStep` component: local-to-world, velocity, stride matching, blending |
| `scripts/main.gd` | Demo driver: the clip, the tree, and the character it moves |
| `scenes/main.tscn` | Ground, a character body, and a rig with a root node that travels |
| `tests/test_logic.gd` | Headless test suite — including a real walk driven by a real AnimationTree |
| `tests/frames` | Frames the suite needs, since the character has to actually walk |

## Use as a building block

**Copy:** `scripts/root_step.gd` — the `RootStep` type. `scripts/main.gd` is the
demo driver, though `_physics_process()` is the shape worth taking.

**Public API**
- `RootStep.world_step(local_step, basis) -> Vector3`
- `RootStep.velocity_for(local_step, basis, delta) -> Vector3`
- `RootStep.clip_speed(local_step, delta) -> float`
- `RootStep.is_moving(local_step, epsilon := 0.0005) -> bool`
- `RootStep.playback_scale(clip_metres_per_second, wanted, slowest := 0.5, fastest := 2.0) -> float`
- `RootStep.blend(root_velocity, input_velocity, authority) -> Vector3`

**Integrate**
1. Decide per state, not per project. Attacks and climbs take their motion from
   the clip; running around usually should not.
2. Keep the vertical axis out of it unless the clip really owns it. Gravity and
   a jump arc are code's job, and a root-motion Y that fights `move_and_slide()`
   produces a character that sinks.
3. Match the stride once, at import. If the clip walks at 1.2 m/s and the game
   wants 4, that is a run clip, not a scale of 3.3.
4. Blend the authority over a few frames when entering and leaving a
   root-motion state, or control changes hands with a visible jolt.

**Notes**
- `class_name RootStep` is global to the project — rename it if you already
  define that type.
- The clip here is built in code so the demo ships no binary assets; in a real
  project it comes from the animation package with the same track on the root
  bone. See [animation-in-code](../animation-in-code) for how the tracks and
  keys are made.
- Root motion and networking are an awkward pair: the authority over a
  character's position is now the animation, which every peer has to be playing
  at the same point. See [multiplayer-3d](../multiplayer-3d).
- `get_root_motion_rotation()` exists too, and everything above applies to it —
  including consuming it exactly once.

## Related demos

- [animation-tree](../animation-tree) — An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching.
- [skeleton-3d](../skeleton-3d) — Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for.
- [character-controller-3d](../character-controller-3d) — Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.
- [character-push](../character-push) — A CharacterBody3D that pushes crates — because move_and_slide() slides past them and does nothing else.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

