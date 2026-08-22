# Menu Navigation

<!-- tags: ui, component, shows-its-working -->

A menu that works with no mouse at all: focus worked out from the layout, and never lost.

## Purpose

A menu that only works with a mouse does not work on a sofa, and does not work
for anyone who cannot use a mouse. Godot has focus neighbours built in — and
they are set by hand, per control, per direction. That is four properties on
every button, and a broken menu the first time somebody inserts a row.

Working them out from the layout instead is about thirty lines, and it stays
right however the menu is rearranged afterwards.

Nothing in this demo responds to the mouse. Every button has
`focus_mode = FOCUS_NONE` and ignores mouse events, so what you see is exactly
what a player with a controller sees.

## Controls

| Key | Action |
|-----|--------|
| Arrows / d-pad | Move focus |
| D | Disable the focused item — the case that quietly kills a menu |
| R | Restore everything |

## How It Works

**Nearest is not the answer.** The nearest control to a button is often the one
*beside* it rather than the one below it. `next_in_direction()` filters
candidates by direction first — a dot product against the pressed direction — and
only then picks between them by distance, with a penalty for drifting sideways
so a button directly below beats one below and far to the left.

**Something must be focused when the menu opens.** A gamepad has no pointer, so
a menu with nothing focused does nothing when the player pushes the stick, and
looks frozen. `first()` never returns -1 for a menu with anything in it.

**Focus is lost when the thing holding it disappears.** Hide or disable a focused
control and the menu goes dead, silently. Nobody notices, because with a mouse
it never comes up. `after_losing()` picks the next usable item below, then above,
then reports that there is nothing — and never returns the item it was told was
lost, whatever the flags claim.

**Move past disabled items, do not stop on them.** Focus that lands somewhere
unpressable is focus the player has to move again for no reason.

**Off the end, wrap.** A menu that stops dead at the last item is one where the
player holds the stick and nothing happens. `furthest_against()` finds the item
furthest back the other way — measured from the coordinate origin, because
subtracting the current position adds the same constant to every candidate and
cannot change which one wins.

**Seed a search from a real candidate, not from `INF`.** `first()` originally
compared against `INF`, which made the comparison unfalsifiable: reverse it and
the function still returned index 0. The mutation testing found that, and the
fix was to start from the first candidate.

**Bound the skip.** Wrapping plus "keep going past disabled items" is a loop
with no end when everything is disabled — which is what a menu looks like while
a dialogue has greyed it all out. It hangs with nothing printed. The loop runs
at most once per item, and the suite disables the whole menu to prove it
returns.

**Key repeats are not presses.** A held key repeats, and a menu that acts on
every repeat disables four items while the player is still deciding about the
first.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Control.focus_mode` / `mouse_filter` | Turning the mouse off entirely, so the demo is honest |
| `InputEvent.is_action_pressed()` | Directional input from keys, d-pad, or stick |
| `InputEventKey.echo` | Telling a repeat from a press |
| `Rect2.get_center()` | The layout the neighbours are derived from |
| `Control.add_theme_color_override()` | Showing where focus is without a focus style |

## Files

| File | What it holds |
|------|---------------|
| `scripts/focus_ring.gd` | The `FocusRing` component: directional movement, first focus, recovery |
| `scripts/main.gd` | Demo driver: a ragged two-column menu built in code |
| `scenes/main.tscn` | A 3D scene behind a HUD, so the menu is a menu over a game |
| `tests/test_logic.gd` | Headless test suite — including working the real menu with real key events |

## Use as a building block

**Copy:** `scripts/focus_ring.gd` — the `FocusRing` type. `scripts/main.gd` is
the demo driver.

**Public API**
- `next_in_direction(rects, from, direction) -> int`
- `furthest_against(rects, from, direction) -> int`
- `FocusRing.first(rects, direction := Vector2.DOWN) -> int`
- `FocusRing.after_losing(rects, lost, usable) -> int`
- `FocusRing.direction_of(left, right, up, down) -> Vector2`
- `alignment`, `wrap`

**Integrate**
1. Feed it `get_global_rect()` for real controls, in the same order as your list
   of them. The rects are the only thing it knows about, which is what makes it
   survive a redesign.
2. Call `after_losing()` from wherever you hide or disable a control, not from
   the menu's `_process`. It is one line at the point of change and a polling
   loop otherwise.
3. Keep `alignment` loose. 0.35 is about 70 degrees either side; tighter starts
   refusing moves that look obviously right to the player.
4. Test it with the mouse switched off. A menu that is navigable in principle
   and untested in practice is a menu with one unreachable button.

**Notes**
- `class_name FocusRing` is global to the project — rename it if you already
  define that type.
- Godot's own `focus_neighbor_*` properties do the same job when the layout is
  fixed and small. This is for menus built at runtime, or ones that change.
- Scrolling containers need more than this: focus that moves off screen has to
  bring the view with it, which is `ensure_control_visible()`.
- Prompts are the other half of playing without a mouse — see
  [device-glyphs](../device-glyphs) — and
  [accessibility-3d](../accessibility-3d) covers the settings underneath both.

## Related demos

- [accessibility-3d](../accessibility-3d) — Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.
- [device-glyphs](../device-glyphs) — Button prompts that follow the device actually being used, including the face buttons Nintendo swapped.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

