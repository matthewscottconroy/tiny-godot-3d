# Tween 3D

<!-- tags: animation, ui, component, shows-its-working -->

Tween or AnimationPlayer — what each is actually for, and the two tweens that end up fighting over one property.

## Purpose

`Tween` and `AnimationPlayer` overlap enough to argue about and are not
interchangeable:

- **`AnimationPlayer` is for motion you authored.** It is a timeline. It can be
  seeked, looped, blended and previewed, and it plays the same way every time.
  A door swinging, a walk cycle, a UI flourish that never varies.
- **`Tween` is for motion you decided at runtime.** From wherever the thing is
  *now* to wherever it needs to be, over a length of time that may depend on how
  far that is. It is code, not data, and it does not outlive the node.

The bug that brings people here is neither of those. Tweens are fire-and-forget:
press the key twice and two of them are now writing the same property every
frame. Nothing errors. The motion just goes strange — usually only when someone
presses the button quickly, which is why it survives testing.

Three cubes here: one on an authored loop, one tweened through a guard, one
tweened with no guard at all.

## Controls

| Key | Action |
|-----|--------|
| Space | Raise or lower — press it repeatedly and watch the red one |
| R | Reset all three |

## How It Works

**A second tween does not interrupt the first. It joins it.** Both run, both
write, and the property ends up wherever whichever ran last wanted it. The red
cube is that, live: the readout counts how many tweens are writing its height.

**The fix is to remember what is running.** `Transitions.start()` kills whatever
was animating that node and property before creating the replacement, so there
is always exactly one. It is a dictionary and about fifteen lines.

**Forget a tween when it finishes.** `Transitions` connects to `finished` and
drops the key, because otherwise the dictionary becomes a list of every
transition the game has ever played, and `is_running()` starts answering
questions about tweens that no longer exist.

**And check it is still the same tween before forgetting.** By the time a tween
finishes, `start()` may already have replaced it; erasing blindly would forget
the *new* one and let the next call create a second.

**Duration should come from distance.** A fixed duration makes small moves feel
sluggish and big ones feel teleported. `duration_for()` is one line, clamped at
both ends so a tiny move is still visible as a move and a huge one does not take
eight minutes.

**A tween starts from wherever the property is.** That is the property that
makes it right for runtime motion and wrong for authored motion: interrupt it
half way and the replacement starts from half way, with no keyframe anywhere
that says so.

**The blue cube's animation is built in code** only so the demo ships no binary
data. In a real project that is what the animation editor writes — see
[animation-in-code](../animation-in-code) for the tracks and keys in detail.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Node.create_tween()` | A tween bound to the node's lifetime |
| `Tween.tween_property()` | Animate a property to a value over a duration |
| `Tween.set_trans()` / `.set_ease()` | The curve, which is most of how a transition feels |
| `Tween.kill()` / `.is_valid()` / `.is_running()` | Interrupting, and knowing what is still going |
| `Tween.finished` | The signal that lets a tracker stay honest |
| `AnimationPlayer.play()` | The other tool, for motion that was authored |

## Files

| File | What it holds |
|------|---------------|
| `scripts/transitions.gd` | The `Transitions` component: one tween per property, and durations |
| `scripts/main.gd` | Demo driver: three cubes, one of them deliberately unguarded |
| `scenes/main.tscn` | Ground, three cubes, and an AnimationPlayer for the authored one |
| `tests/test_logic.gd` | Headless test suite — including two real tweens fighting over one property |
| `tests/frames` | Frames the suite needs, since tween durations are wall-clock seconds |

## Use as a building block

**Copy:** `scripts/transitions.gd` — the `Transitions` type. `scripts/main.gd`
is the demo driver.

**Public API**
- `start(node, property, to, duration, trans, ease) -> Tween`
- `stop(node, property) -> bool`
- `is_running(node, property) -> bool`
- `count() -> int`, `stop_all()`
- `Transitions.duration_for(distance, speed, shortest := 0.08, longest := 1.0) -> float`

**Integrate**
1. Route every runtime tween through one of these. The moment two places in the
   codebase tween the same property, the guard is the only thing that stops the
   result depending on call order.
2. Use `AnimationPlayer` when a designer needs to see it, seek it, or change it
   without you. Use `Tween` when the target is not known until it happens.
3. Tweens are bound to the node that created them and die with it. That is
   usually what you want, and it is why `create_tween()` on a node about to be
   freed is not a leak.
4. Set the transition and ease deliberately. `TRANS_LINEAR` is the default shape
   of nothing in the physical world, and it is what makes UI motion feel cheap.

**Notes**
- `class_name Transitions` is global to the project — rename it if you already
  define that type.
- A `Tween` created in `_ready()` starts on the next frame, so it will not be
  `is_running()` in the same frame you created it.
- `tween_property` with a `NodePath` like `^"position:y"` animates one component.
  Tweening `position` and `position:y` at once is the same fight in a subtler
  form: both write `position`, and one of them writes all three axes.
- There is no "reverse" on a running tween. Kill it and start a new one toward
  the old target — which, because tweens start from where the property is, does
  the right thing.

## Related demos

- [animation-in-code](../animation-in-code) — Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk.
- [animation-tree](../animation-tree) — An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching.
- [root-motion](../root-motion) — Motion that comes from the animation rather than the code, and the sliding feet it fixes.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

