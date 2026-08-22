# Accessibility 3D

<!-- tags: ui, procedural, signals, component, shows-its-working -->

Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.

## Purpose

Accessibility work goes wrong the same way every time: it is implemented as
special cases scattered through the systems it affects. A check for "reduced
motion" inside the camera shake, another inside the head bob, another inside the
hit reaction — and the fourth one, added six months later by someone who did not
know the first three existed, does not have the check.

The alternative costs nothing. One object holds the answers; everything else
*reads* them. Shake asks for a motion scale and multiplies by it. Anything that
picks a colour asks for a role rather than choosing red. Nothing needs a
conditional, so nothing can forget one.

## Controls

| Key | Action |
|-----|--------|
| 1 / 2 | Less or more motion |
| 3 | Subtitles on or off |
| 4 | Cycle subtitle text size |
| C | Cycle colour mode |
| R | Back to defaults |

## How It Works

**Reduced motion is a scale, not a switch.** Some players want less rather than
none, and one slider covers both without a second option. The shake in
`_process()` multiplies by `motion_scale()` and has no conditional in it at all
— which is the property that makes the setting stay correct as the game grows.
`motion_disabled()` exists for the few effects that genuinely cannot be scaled.

**Colour-blind support is not a filter over the screen.** Post-processing the
whole frame to simulate or correct for colour blindness is the wrong shape: it
dims everything, it fights the art, and it does not help the player who simply
cannot tell your green health bar from your red one. Choosing cue colours that
differ in *lightness* does.

**The palettes are spaced by luminance, and the suite checks it.** Every pair of
role colours, in every mode, must differ by more than 0.12 in perceived
lightness. Three of the four palettes here failed that check when first written
— which is the whole argument for asserting it rather than eyeballing it. Green
and red at the same brightness are the commonest accessibility bug in games.

**Luminance is weighted, not averaged.** `0.2126 R + 0.7152 G + 0.0722 B`: green
looks far brighter than blue at the same value. A naive average calls pure green
and pure blue equally light and happily passes a palette nobody can read.

**Roles, not colours.** `colour_for(Role.ENEMY)` keeps working when the palette
changes; `Color.RED` does not. The demo repaints its four markers through one
line that never changes.

**A settings file outlives the build that wrote it.** `load_from()` restores
what it recognises, leaves defaults for what is missing, and ignores a palette
index that no longer exists. A player who loses their accessibility options to a
patch has lost more than a preference.

**One signal.** Systems connect to `changed` rather than polling, so the menu
does not need to know who cares.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Label.add_theme_font_size_override()` | Scaling text at runtime without a second theme |
| `StandardMaterial3D.albedo_color` | Repainting cues when the palette changes |
| Property setters (`set(value)`) | Clamping and announcing in one place |
| `Color` / `clampf()` | The palette arithmetic |
| `FastNoiseLite` | The camera shake the motion setting scales |

## Files

| File | What it holds |
|------|---------------|
| `scripts/accessibility_options.gd` | The `AccessibilityOptions` component: settings, palettes, persistence |
| `scripts/main.gd` | Demo driver: shaking camera, four role-coloured markers, subtitle bar |
| `scenes/main.tscn` | Ground, camera rig, the markers and the HUD |
| `tests/test_logic.gd` | Headless test suite — including the greyscale check on every palette |

## Use as a building block

**Copy:** `scripts/accessibility_options.gd` — the `AccessibilityOptions` type.
`scripts/main.gd` is the demo driver.

**Public API**
- `motion`, `subtitles`, `text_scale`, `colours` — settings, clamped on assignment
- `motion_scale() -> float`, `motion_disabled() -> bool`
- `colour_for(role: Role) -> Color`
- `AccessibilityOptions.luminance(colour) -> float`
- `AccessibilityOptions.lightness_gap(a, b) -> float`
- `subtitle_size(base: int) -> int`
- `to_dictionary()`, `load_from(data)`, `reset()`
- `changed` signal

**Integrate**
1. Make it an autoload. The point is that every system reads the same object;
   a copy passed around defeats it.
2. Multiply, do not branch. `shake * options.motion_scale()` is a line that
   cannot be forgotten in the way `if not options.reduced_motion:` can.
3. Put `lightness_gap()` in your own test suite over your own cue colours. It is
   four lines and it catches a class of bug that no amount of looking at the
   screen will, if the person looking can see the colours.
4. Save these settings separately from the rest, and load them earliest. They
   are the ones a player cannot play without.

**Notes**
- `class_name AccessibilityOptions` is global to the project — rename it if you
  already define that type.
- The palettes here are a starting point, not a standard. What is worth copying
  is the constraint they satisfy, not the specific colours.
- Motion sensitivity is not only camera shake: field-of-view changes, screen
  wobble, fast parallax and full-screen flashes all belong on this scale too.
- Subtitle *size* is the easy half. Background opacity, line length and speaker
  names are the rest, and none of them are 3D problems.

## Related demos

- [menu-navigation](../menu-navigation) — A menu that works with no mouse at all: focus worked out from the layout, and never lost.
- [save-load-3d](../save-load-3d) — Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration.
- [camera-shake-3d](../camera-shake-3d) — Camera shake as an offset a rig can carry, with trauma that decays and noise that is the same every run.
- [noise-terrain](../noise-terrain) — A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

