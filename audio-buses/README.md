# Audio Buses

<!-- tags: physics, audio, ui, component, shows-its-working -->

Audio buses built at runtime: sliders that are decibels, a mute that is not a volume, and a reverb you walk into.

## Purpose

`AudioServer` is a global mixer with a flat list of buses addressed by index —
and the indices move whenever a bus is added or removed. Everything an options
screen wants to do with it runs into one of four things:

- **Volume is decibels, not a fraction.** A slider at 0.5 is not half as loud,
  and writing `volume_db = 0.5` is very nearly full volume. The conversion is
  logarithmic, and getting it wrong gives a slider where all the useful range is
  in the last centimetre.
- **Mute is not volume zero.** A muted bus remembers what its volume was.
  Implementing mute as −80 dB throws away the setting the player chose.
- **Solo is mute for everyone else** — so undoing it has to restore what was
  muted before, not unmute everything.
- **Indices move.** Code that remembers "bus 3" starts writing to the wrong one
  as soon as a bus is added.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Select a bus |
| 3 / 4 | Turn it down or up |
| M | Mute it |
| S | Solo it, or clear the solo |

The moving sphere plays a blip. When it passes through the blue box its sound is
routed to the reverb bus, which is what an audio "room" is.

## How It Works

**The slider curve is `linear_to_db(value²)`.** Squaring before converting gives
a slider where halfway sounds like about half as loud — roughly −12 dB — rather
than the −6 dB a straight linear-to-dB conversion produces. The suite pins both
ends and the middle, and checks the round trip, because a saved decibel value has
to put the slider back where the player left it.

**Buses are found by name.** `AudioServer.get_bus_index(name)` every time.
Nothing here stores an index, which is also why `remove_all()` works backwards:
removing a bus shifts the indices of everything after it.

**Mute is `set_bus_mute()`.** Separate from volume, so the level survives being
muted and unmuted — the suite asserts exactly that.

**Solo remembers.** Before muting everything else, the mixer records which buses
were already muted; clearing the solo restores that snapshot. Unmuting
everything instead would quietly undo the player's own choices.

**A reverb is an effect on a bus, not a property of a sound.** Anything routed
through the reverb bus is in the room, and moving a sound between rooms is a
one-line change to `AudioStreamPlayer3D.bus` — which is what the `Area3D` here
does on entry and exit.

**The tones are generated.** No audio files, as everywhere else in this
collection. The music is a looping low tone; the blip is a short decaying one.

**Buses created at runtime outlive the scene.** The `AudioServer` is global, so
the demo removes its buses in `_exit_tree()` and the suite removes its own in
the report. A test that leaves buses behind has changed the mixer for whatever
runs next.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `AudioServer.add_bus()` / `set_bus_name()` / `remove_bus()` | Building the mixer at runtime |
| `AudioServer.get_bus_index()` | Finding a bus by name, because indices move |
| `AudioServer.set_bus_volume_db()` / `set_bus_mute()` | Volume and mute, which are different things |
| `AudioServer.set_bus_send()` | Routing one bus into another |
| `AudioServer.add_bus_effect()` / `AudioEffectReverb` | Making a bus sound like a room |
| `AudioStreamPlayer3D.bus` | Which bus a sound goes down |
| `linear_to_db()` / `db_to_linear()` | The conversion the slider needs |

## Files

| File | What it holds |
|------|---------------|
| `scripts/bus_mixer.gd` | The `BusMixer` component: buses by name, the slider curve, mute, solo, persistence |
| `scripts/main.gd` | Demo driver: the buses, the tones, and the reverb area |
| `scenes/main.tscn` | A floor, a reverb zone, a moving emitter and a listener |
| `tests/test_logic.gd` | Headless test suite — against the real AudioServer |

## Use as a building block

**Copy:** `scripts/bus_mixer.gd` — the `BusMixer` type. `scripts/main.gd` is the
demo driver and is not needed.

**Public API**
- `BusMixer.slider_to_db(value) -> float`, `BusMixer.db_to_slider(db) -> float`
- `ensure_bus(name, send := &"Master") -> int`, `has_bus(name) -> bool`
- `set_level(name, value) -> bool`, `level_of(name) -> float`
- `set_muted(name, muted) -> bool`, `is_muted(name) -> bool`
- `solo(name) -> bool`, `clear_solo()`, `soloed() -> StringName`
- `add_effect(name, effect) -> bool`, `to_dictionary()`, `load_from(data) -> int`
- `buses() -> Array[StringName]`, `remove_all()`

**Integrate**
1. Author your buses in the editor's Audio panel for a real project — the file
   is `default_bus_layout.tres`, and it is easier to reason about than code.
   `ensure_bus()` is for buses that depend on runtime data, and for demos.
2. Save the slider values, not the decibels. Decibels are an implementation
   detail of the mixer; the slider position is what the player set.
3. Route by bus, not by editing sounds. "Which room am I in" then becomes one
   assignment, and adding a new room is a bus rather than a code path.

**Notes**
- `class_name BusMixer` is global to the project — rename it if you already
  define that type.
- This demo leaks two engine objects at shutdown, exactly as
  [audio-3d](../audio-3d) does. It is the engine's audio shutdown, reproduced in
  a twelve-line scene containing none of this code, and it is documented with
  its evidence in [docs/MEMORY.md](../docs/MEMORY.md).
- A reverb per room is fine; a reverb per *sound* is not. Effects are per bus
  precisely because they are expensive.

## Related demos

- [continuous-collision](../continuous-collision) — A fast projectile that goes straight through a wall, and the three ways to stop it.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.
- [audio-3d](../audio-3d) — Positional audio with AudioStreamPlayer3D, and a hearing model the game logic can share with it.
- [area-trigger-3d](../area-trigger-3d) — Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

