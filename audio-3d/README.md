# Positional Audio

<!-- tags: audio, ui, component, shows-its-working -->

Positional audio with AudioStreamPlayer3D, and a hearing model the game logic can share with it.

## Purpose

`AudioStreamPlayer3D` attenuates a sound with distance — that is what it is for.
The reason to write the attenuation curve down *as well* is that the game
usually needs the same answer: did the guard hear the footstep, does the alarm
reach the next room, is this sound worth playing at all.

Written twice, those two answers drift, and the resulting bug is horrible to
play. The player hears something no enemy reacts to, or is caught by a guard who
could not possibly have heard them. Written once, the mixer and the game agree by
construction.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Previous or next attenuation model |
| 3 / 4 | Slow down or speed up the orbit |
| Space | Stop and start the emitter |

The readout shows the distance, the level in decibels, whether the model calls it
audible, and the Doppler shift the motion would produce.

## How It Works

**`unit_size` is the distance at which the sound is at full volume**, not a
radius or a maximum. Inside that sphere everything plays at 0 dB; outside it the
curve starts. Reading it as "how far the sound reaches" is the usual first
mistake, and it makes every sound in the game too quiet.

**`max_distance` is a hard cutoff, not a fade.** Past it the sound is simply not
mixed. Setting it to zero disables the cutoff entirely — which is what a
long-range ambience wants and what a footstep very much does not.

**Four models, three shapes.** Inverse halves the volume each time the distance
doubles. Inverse-square is what physics does to a point source and is noticeably
quieter at range. Logarithmic falls off gently and keeps distant sounds present,
which is why it suits music and ambience. Disabled is for anything that should
be heard wherever the listener is.

**The game asks the same question the mixer does.** `Hearing.is_audible()` takes
the same `unit_size`, `max_distance` and model as the node, and adds a threshold
in decibels — how good this listener's ears are. `Hearing.range_of()` answers it
backwards: how far the noise you are about to make will carry.

**Doppler is one division, with one trap.** The pitch ratio is
`1 / (1 - closing_speed / speed_of_sound)`, which divides by zero at exactly the
speed of sound and goes negative past it. Clamped here, because a negative pitch
is either silence or a crash depending on the mixer.

**The tone is generated.** An `AudioStreamWAV` filled with 16-bit samples in
`_ready()`, looping. The collection ships no audio files, and a steady tone is
the clearest thing to hear a falloff curve through anyway.

**A listener is a node.** `AudioListener3D` makes the listening position
explicit; without one, the current `Camera3D` listens. Those are different
places in any third-person game, and the difference is audible.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `AudioStreamPlayer3D.unit_size` | The distance at which the sound is at full volume |
| `AudioStreamPlayer3D.max_distance` | The hard cutoff |
| `AudioStreamPlayer3D.attenuation_model` | Which falloff curve to use |
| `AudioListener3D` | Where the listening happens, when it is not the camera |
| `AudioStreamWAV` (`format`, `mix_rate`, `data`, `loop_mode`) | A sound built in code |
| `PackedByteArray.encode_s16()` | Writing 16-bit PCM samples |
| `linear_to_db()` | Turning a gain into the unit mixers use |

## Files

| File | What it holds |
|------|---------------|
| `scripts/hearing.gd` | The `Hearing` component: attenuation curves, audibility, range, Doppler |
| `scripts/main.gd` | Demo driver: the generated tone, the orbit, and the readout |
| `scenes/main.tscn` | A listener, an orbiting emitter, and the HUD |
| `tests/test_logic.gd` | Headless test suite |

## Use as a building block

**Copy:** `scripts/hearing.gd` — the `Hearing` type. `scripts/main.gd` is the
demo driver, though its `_tone()` is worth stealing on its own.

**Public API**
- `Hearing.gain_at(distance, unit_size, max_distance, model) -> float`
- `Hearing.db_at(...) -> float`, `Hearing.is_audible(..., threshold_db) -> bool`
- `Hearing.range_of(unit_size, max_distance, model, threshold_db) -> float`
- `Hearing.doppler(closing_speed, speed_of_sound := 343.0) -> float`
- `Hearing.closing_speed(source_position, source_velocity, listener_position, listener_velocity) -> float`
- `Hearing.Model`, `Hearing.SILENCE_DB`

**Integrate**
1. Set the node's `attenuation_model` and the `Hearing.Model` from the same
   value — a single exported property, not two. The whole benefit is that they
   cannot be chosen separately.
2. Give each listener its own threshold. A guard who is distracted, asleep or
   wearing a helmet is a number, not a special case.
3. `range_of()` before making a noise is much cheaper than asking every listener
   afterwards: it gives you a radius to query with.

**Notes**
- `class_name Hearing` is global to the project — rename it if you already
  define that type.
- These curves match the shapes the mixer uses; they are not bit-exact
  reproductions of its internals. A threshold chosen against one holds against
  the other, which is what the model is for.
- Godot's own Doppler tracking (`doppler_tracking` on the player) handles the
  mixer side. `Hearing.doppler()` is for everything else that should agree with
  it.
- This demo leaks two engine objects at shutdown. It is not the demo's: the same
  report comes from a twelve-line scene containing none of this code, and it is
  documented with its reproduction in [docs/MEMORY.md](../docs/MEMORY.md).

## Related demos

- [area-trigger-3d](../area-trigger-3d) — Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.
- [audio-buses](../audio-buses) — Audio buses built at runtime: sliders that are decibels, a mute that is not a volume, and a reverb you walk into.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

