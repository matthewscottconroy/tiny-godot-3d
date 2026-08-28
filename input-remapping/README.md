# Input Remapping

<!-- tags: ui, persistence, signals, component, shows-its-working -->

Rebinding actions at runtime, spotting the conflicts, and saving the result where it survives a restart.

## Purpose

Godot's `InputMap` is a global singleton with no memory. It is the *current*
state of the bindings and nothing else: it cannot tell you what the defaults
were, it will happily let two actions share a key without mentioning it, and it
does not persist.

A rebinding screen needs all three. So the bindings live in an object, and the
`InputMap` becomes the thing that object writes to — which also means every
question a settings screen wants to ask is a question about data rather than
about global state.

## Controls

| Key | Action |
|-----|--------|
| 1 – 4 | Rebind that action — then press any key |
| R | Back to the defaults |
| S | Save the bindings |
| L | Load them |
| W A S D | Move the cube (until you rebind them) |

## How It Works

**Events compare with `is_match()`, not `==`.** Two `InputEventKey`s for the same
key are different objects. Comparing them by identity finds no conflicts at all,
which is a rebinding screen that silently allows a player to bind jump to the key
that already opens the map.

**A conflict is refused unless the caller asks to steal.** `rebind()` returns
false if something else holds the key; passing `steal` takes it away from
whoever had it, leaving that action unbound rather than sharing. Which of those
happens is a design decision, so it is a parameter rather than a policy.

**Applying clears before it adds.** `InputMap.action_erase_events()` first: adding
without clearing leaves the old key working too, and the player rebinds jump only
to find that both keys jump.

**Physical keycodes, not keycodes.** `physical_keycode` is "the key where W is",
so bindings survive a player switching keyboard layout. A binding saved as the
letter `W` moves to a different physical position on an AZERTY keyboard, which
is a bug report nobody enjoys.

**The defaults never go away.** `Bindings` keeps them alongside the current
bindings, so `reset()` works, and `is_default()` can put a *(changed)* marker
next to the actions the player has touched.

**Saving is plain data.** `to_dictionary()` produces something `JSON.stringify`
accepts. `load_from()` skips actions that no longer exist and entries it cannot
read, returning how many it restored — a save file from an older build should
restore what it can rather than being rejected whole.

**The rebinding screen reserves nothing.** Whatever the player presses becomes
the binding, Escape included. A screen that keeps keys for itself is a screen
that cannot bind them.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `InputMap.add_action()` / `action_add_event()` | Creating actions and their bindings at runtime |
| `InputMap.action_erase_events()` | Clearing before applying, so old keys stop working |
| `InputMap.action_has_event()` | Asking the global map what it currently holds |
| `InputEvent.is_match()` | Comparing two events by what they mean, not by identity |
| `InputEventKey.physical_keycode` | Bindings that survive a keyboard layout change |
| `OS.get_keycode_string()` | Turning a keycode into something a player can read |

## Files

| File | What it holds |
|------|---------------|
| `scripts/bindings.gd` | The `Bindings` component: defaults, conflicts, persistence, and applying |
| `scripts/main.gd` | Demo driver: the rebinding screen and the cube it drives |
| `scenes/main.tscn` | A floor, a cube, and the binding list |
| `tests/test_logic.gd` | Headless test suite — including against the real `InputMap` |

## Use as a building block

**Copy:** `scripts/bindings.gd` — the `Bindings` type. `scripts/main.gd` is the
demo driver and is not needed.

**Public API**
- `Bindings.new(defaults: Dictionary)` — action name to array of `InputEvent`
- `actions()`, `events_for(action)`, `conflicts(event, ignoring := &"")`
- `rebind(action, event, steal := false) -> bool`, `add_binding(...)`
- `reset(action)`, `reset_all()`, `is_default(action) -> bool`
- `apply_to_input_map()`, `to_dictionary()`, `load_from(data) -> int`
- `Bindings.describe(event) -> String`, `serialise()`, `deserialise()`
- `signal changed(action)`

**Integrate**
1. Build the defaults once, in code, and treat the project's own input map as a
   starting point rather than the source of truth.
2. Call `apply_to_input_map()` after every change, and on load. Nothing else
   should touch `InputMap` for these actions.
3. Serialise only the event types you support. `serialise()` returns an empty
   dictionary for anything else, which is better than writing a half-formed
   entry that fails to load later.

**Notes**
- `class_name Bindings` is global to the project — rename it if you already
  define that type.
- The `InputMap` is global state, which is why this demo's own suite uses
  prefixed action names and removes them again afterwards. A test that adds
  actions and walks away has broken the next suite.
- Mouse buttons and axes serialise the same way; the two types here are the
  ones a keyboard-and-pad game needs. Stick axes want a threshold as well, which
  is where [gamepad-3d](../gamepad-3d)'s deadzone belongs.

## Related demos

- [device-glyphs](../device-glyphs) — Button prompts that follow the device actually being used, including the face buttons Nintendo swapped.
- [level-streaming](../level-streaming) — Loading and freeing chunks around a moving player, with the keep-radius that stops them thrashing at a boundary.
- [save-load-3d](../save-load-3d) — Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration.
- [camera-clipping](../camera-clipping) — Why the wall you stand against disappears, and what the near plane costs to fix it.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

