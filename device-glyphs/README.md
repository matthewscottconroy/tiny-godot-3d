# Device Glyphs

<!-- tags: ui, signals, component, shows-its-working -->

Button prompts that follow the device actually being used — including the face buttons Nintendo swapped.

## Purpose

"Press A to jump" while the player is typing on a keyboard is one of the most
common small failures in games, and it is entirely avoidable. So is its
opposite: "Press E" ten seconds after they picked up a controller.

Three things make it harder than it looks, and all three are in the component
here:

- **What matters is the last input, not what is plugged in.** Almost everyone
  has a controller connected to something.
- **A stick at rest is not at rest.** Analogue sticks drift, and drift that
  counts as input makes the prompts flicker on their own.
- **Face buttons are positional and their names are not.** Godot's
  `JOY_BUTTON_A` means *the bottom button*, which is A on Xbox, ✕ on PlayStation
  and **B** on Nintendo.

## Controls

| Key | Action |
|-----|--------|
| ← / → | Move, so there is something to press buttons about |
| 1–5 | Pretend to be keyboard, Xbox, PlayStation, Nintendo, or an unknown pad |
| R | Back to the real device |

## How It Works

**Prompts start on the keyboard and follow the events.** `Prompts.note()` is
called with every event; it decides which ones count. Choosing by
`Input.get_connected_joypads()` instead is what shows gamepad glyphs to someone
who has never touched their controller.

**Some events deliberately say nothing.** A stick inside the deadzone is a
controller sitting on a table. Mouse *motion* is a mouse nudged by a passing
cat — a click counts, a wobble does not. `device_for()` returns `null` for
those rather than guessing.

**The change is a signal, fired on the transition only.** Three pad presses in a
row are one device change. Rebuilding every label on every event is how a prompt
system turns into a frame-rate problem.

**`JOY_BUTTON_A` is a position, not a name.** The bottom face button is A on
Xbox, ✕ on PlayStation, and B on Nintendo, whose A and B are the other way round
from everyone else. Labelling by index without asking which family the pad
belongs to gives Nintendo players confidently wrong prompts — and the suite
asserts that specific swap, because it is the one nobody remembers.

**Family detection is substring matching on the reported name.** It is unlovely,
and it is what everyone ends up doing, because controller names are not
consistent. Anything unrecognised gets neutral prompts rather than a guess.

**Keyboard prompts come from the bindings themselves.** `prompt_for()` reads the
action's own events, so a key remapped at runtime changes the prompt with no
extra work — see [input-remapping](../input-remapping) for the other half of
that.

**A game needs the pretend switch.** You cannot check PlayStation prompts
without a PlayStation pad, so the demo can be told to be one. Every shipped game
has this somewhere, usually in a debug menu.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `InputEventJoypadButton` / `InputEventJoypadMotion` | What a pad actually sends |
| `Input.get_joy_name()` | The string the family is worked out from |
| `InputMap.action_get_events()` | Reading a prompt out of the binding rather than hard-coding it |
| `OS.get_keycode_string()` | Turning a keycode into something printable |
| `JOY_BUTTON_A` … `JOY_BUTTON_Y` | Positional face-button indices |

## Files

| File | What it holds |
|------|---------------|
| `scripts/prompts.gd` | The `Prompts` component: device tracking, families, and labels |
| `scripts/main.gd` | Demo driver: the readout and the pretend switch |
| `scenes/main.tscn` | A capsule to move and a HUD full of prompts |
| `project.godot` | Three actions with both a key and a face button, so there is something to read |
| `tests/test_logic.gd` | Headless test suite — real InputEvents, no controller required |

## Use as a building block

**Copy:** `scripts/prompts.gd` — the `Prompts` type. `scripts/main.gd` is the
demo driver.

**Public API**
- `note(event) -> bool`, `device() -> Device`, `device_changed` signal
- `Prompts.device_for(event, deadzone := 0.5) -> Variant`
- `Prompts.family_of(joy_name) -> Device`
- `Prompts.face_label(button, device) -> String`
- `Prompts.swaps_face_buttons(device) -> bool`
- `Prompts.prompt_for(action, device) -> String`
- `Prompts.device_name(device) -> String`
- `deadzone`

**Integrate**
1. Make it an autoload and feed it from `_input()` once. Every prompt in the
   game then reads the same answer.
2. Rebuild labels on the signal, never per frame. That is the difference between
   this being free and this being a profiler entry.
3. Swap the strings for textures when you have them. The structure is the same —
   `face_label()` becomes `face_texture()` — and the Nintendo swap still applies.
4. Ship the pretend switch. It is the only way to check three families of prompt
   without three controllers on the desk.

**Notes**
- `class_name Prompts` is global to the project — rename it if you already
  define that type.
- Steam and some drivers rewrite controller names, so a DualSense can arrive
  reporting as an Xbox pad. The families here are a best effort, not a
  guarantee, and neutral prompts for an unknown pad are the honest fallback.
- Godot's built-in `ui_*` actions do not carry joypad bindings in every context.
  This demo defines its own actions, which is what a game does anyway.
- Prompts are only half of accessibility for input. See
  [accessibility-3d](../accessibility-3d) for the settings that decide whether
  the game is playable at all.

## Related demos

- [input-remapping](../input-remapping) — Rebinding actions at runtime, spotting the conflicts, and saving the result where it survives a restart.
- [menu-navigation](../menu-navigation) — A menu that works with no mouse at all: focus worked out from the layout, and never lost.
- [gamepad-3d](../gamepad-3d) — Analogue stick handling in 3D: a radial deadzone that does not jump, a response curve, and camera-relative movement.
- [client-prediction](../client-prediction) — Moving before the server answers, and putting it right when the answer disagrees.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

