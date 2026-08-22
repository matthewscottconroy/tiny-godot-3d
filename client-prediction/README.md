# Client Prediction

<!-- tags: ui, component, shows-its-working -->

Moving before the server answers, and putting it right when the answer disagrees.

## Purpose

[multiplayer-3d](../multiplayer-3d) covers the other end of this: snapshots that
arrive ten times a second, interpolated into smooth motion. That works for
everyone *else's* character. It cannot work for your own, because it means your
input takes a round trip before anything happens — and 80 milliseconds of that
is the difference between a game and a demo.

So the client moves immediately and assumes it was right. The server, which
decides, sends back where it thinks the character actually is. Almost always
they agree and nothing happens. When they do not — a wall the client did not
know about, a shove from another player — the client has to end up where the
server says, without teleporting.

Press P to turn prediction off and feel what the same latency does without it.

## Controls

| Key | Action |
|-----|--------|
| Arrows | Move — straight into a wall only the server knows about |
| 1 / 2 | Less or more latency |
| P | Prediction on or off |
| R | Reset |

## How It Works

**Keep every input until it is acknowledged.** The correction arrives stamped
with the last input the server had seen; everything after that still has to
happen. A client that forgets its inputs cannot do the next part at all.

**Replay, do not snap.** Snapping to the server position throws away every input
the player has made since — half a second of running, at this latency. Replaying
them from the corrected start puts the character where those inputs *would* have
taken it. That is the entire difference between a correction the player notices
and one they do not.

**Simulate identically on both ends.** One `step()` function, called by the
client and by the server. If the server's version differs by so much as an
operator, the client is corrected constantly and the player feels it as
rubber-banding. It is also why the input is length-limited: unclamped diagonal
movement is 1.41 times as fast, and now it desynchronises two machines as well.

**Ignore corrections too small to be real.** Floating point drifts between two
machines running the same code; correcting a two-millimetre disagreement every
frame is visible jitter with no cause.

**Snap the ones too big to smooth.** A metre is a mistake. Forty metres is a
respawn, and easing it is a character flying across the level for a second and a
half.

**The disagreement stays small here for a reason.** A correction arrives every
frame, so the error never exceeds one frame of movement — about 10cm. A real
server ticks slower than the client, and that number grows with the gap. The
suite asserts the size rather than just the sign, because that is where the
lesson is.

**Authority means the server decides.** The wall is the server's; the client has
never heard of it. Watch the readout: the client walks past, the correction
arrives, and it ends up where the server always said it was.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `_physics_process()` | The fixed step both ends have to share |
| `Vector3.limit_length()` | Input clamped so diagonals are not faster on either end |
| `Vector3.lerp()` with `exp()` | Frame-rate-independent easing of an accepted correction |
| `Input.get_axis()` | The input that gets recorded, replayed, and sent |

## Files

| File | What it holds |
|------|---------------|
| `scripts/prediction.gd` | The `Prediction` component: the input buffer, the replay, the thresholds |
| `scripts/main.gd` | Demo driver: a fake server on a delay, and a wall it owns |
| `scenes/main.tscn` | Ground, a wall, the client's character, and a marker for the server's |
| `tests/test_logic.gd` | Headless test suite — including running the whole loop into the wall |
| `tests/frames` | Frames the suite needs, since the character has to walk and the packets to arrive |

## Use as a building block

**Copy:** `scripts/prediction.gd` — the `Prediction` type. `scripts/main.gd` is
the demo driver, and its fake server is worth reading before you write a real one.

**Public API**
- `Prediction.step(position, move, delta, speed := 6.0) -> Vector3` — the shared simulation
- `predict(position, move, delta, speed) -> Vector3`
- `reconcile(authoritative, acknowledged, speed) -> Vector3`
- `forget_up_to(acknowledged)`, `pending() -> int`, `last_sequence() -> int`, `reset()`
- `Prediction.worth_correcting(predicted, corrected, tolerance := 0.02) -> bool`
- `Prediction.should_snap(predicted, corrected, snap_beyond := 4.0) -> bool`
- `Prediction.ease_toward(shown, corrected, delta, rate := 12.0) -> Vector3`
- `tolerance`, `snap_beyond`

**Integrate**
1. Put the shared step somewhere neither end can specialise it. The moment there
   is a client version and a server version, they will drift apart in a patch
   nobody connects to the bug reports.
2. Send the sequence number with the input and echo it back with the state. Every
   part of this depends on knowing *which* input a correction answers.
3. Predict only what you own. Other players are interpolation, not prediction —
   you have no idea what they are about to press.
4. Cap the pending list. A client that stops receiving acknowledgements must not
   grow its input buffer for ever; drop the oldest and accept a correction.

**Notes**
- `class_name Prediction` is global to the project — rename it if you already
  define that type.
- The server here is a queue in the same process, which is exactly enough to
  show the technique and nothing like enough to test a network. See
  [multiplayer-3d](../multiplayer-3d) for two real peers.
- Prediction and physics are harder than prediction and arithmetic. Replaying
  through `move_and_slide()` means re-running collision for every unacknowledged
  input, every correction — which is why most games predict a simplified
  movement model and accept the small disagreements.
- None of this hides latency from *other* players. What it hides is the delay
  between your own key and your own character, which is the one that matters.

## Related demos

- [multiplayer-3d](../multiplayer-3d) — Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.
- [device-glyphs](../device-glyphs) — Button prompts that follow the device actually being used, including the face buttons Nintendo swapped.
- [input-remapping](../input-remapping) — Rebinding actions at runtime, spotting the conflicts, and saving the result where it survives a restart.
- [portal-3d](../portal-3d) — A portal you can see through and walk through, and the transform that puts the second camera in the right place.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

