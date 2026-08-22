# Multiplayer

<!-- tags: mesh, ui, component, shows-its-working, needs-network -->

Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.

## Purpose

Getting two Godot peers talking is half a page: `ENetMultiplayerPeer`,
`create_server()`, `create_client()`, an `@rpc` function. That part is easy and
well documented.

The part that decides whether the result is playable is what you do with the
data once it arrives. A networked game sends position perhaps ten times a
second. Applying each update as it lands gives ten movements per second inside
sixty frames of rendering — which looks exactly like a stutter, and no amount of
raising the send rate fixes it, because the send rate is not the problem.

Every networked game solves this the same way: **render the past**. Keep the
updates in a buffer and draw remote players slightly behind now, interpolating
between the two updates that straddle that moment.

## Controls

| Key | Action |
|-----|--------|
| H | Host on port 47212 |
| J | Join 127.0.0.1 |
| Arrow keys | Move your own cube |
| I | Interpolation on or off — watch the other cube stutter |

Run two copies of the demo: `godot --path multiplayer-3d` twice. Press `H` in
one and `J` in the other.

## How It Works

**A hundred milliseconds behind.** `StateBuffer.sample(now)` reads the buffer at
`now - delay` and interpolates between the samples either side. The delay is the
price: remote players are always slightly out of date. In exchange their motion
is continuous, which is the thing players notice.

**Position updates are unreliable and unordered.** `@rpc("unreliable")` — a
position packet that arrives late is worthless, and waiting for it holds up the
ones behind it. Reliability is for events that must happen once: a door opening,
a shot being fired.

**Late and duplicate packets are refused.** UDP delivers neither in order nor
exactly once. `push()` rejects anything not newer than the newest sample;
accepting a straggler would rewind the buffer and jerk the remote player
backwards.

**Running dry holds rather than guesses.** When the network hiccups there is
nothing to interpolate toward. Holding the last known position is honest;
extrapolating puts players through walls and then snaps them back when the next
packet lands. `is_interpolating()` says which of the two is happening, so a HUD
or a debug view can show it.

**`latest()` exists for hit tests.** The player being shot at is where they *are*,
not where they are drawn. Interpolated positions are for the eye; the newest
sample is for the rules.

**Peers must be polled.** `MultiplayerPeer.poll()` is what advances a handshake.
The `SceneTree` does it for the peer assigned to `multiplayer`; a peer you hold
yourself — as this demo's test suite does — will sit at `CONNECTION_CONNECTING`
forever if you forget.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `ENetMultiplayerPeer.create_server()` / `create_client()` | Opening and joining a session |
| `MultiplayerAPI.multiplayer_peer` | Handing the peer to the scene tree |
| `@rpc("any_peer", "call_remote", "unreliable")` | Sending a position without waiting for lost packets |
| `MultiplayerAPI.get_remote_sender_id()` | Which peer that call came from |
| `peer_connected` / `peer_disconnected` | Players arriving and leaving |
| `MultiplayerPeer.poll()` / `get_connection_status()` | Advancing and inspecting a handshake |

## Files

| File | What it holds |
|------|---------------|
| `scripts/state_buffer.gd` | The `StateBuffer` component: the delay, the interpolation, and the packet rules |
| `scripts/main.gd` | Demo driver: hosting, joining, sending, and drawing remote pawns |
| `scenes/main.tscn` | A floor, your pawn, and the HUD |
| `tests/test_logic.gd` | Headless test suite — including a real ENet server and client, in one process |
| `tests/frames` | How many frames the suite needs, since a handshake takes some |

## Use as a building block

**Copy:** `scripts/state_buffer.gd` — the `StateBuffer` type. `scripts/main.gd`
is the demo driver and is not needed.

**Public API**
- `push(time, state) -> bool` — false for a late or duplicate packet
- `sample(now) -> Vector3` — where to draw, `delay` seconds in the past
- `latest() -> Vector3`, `latest_time() -> float` — the newest data, undelayed
- `is_interpolating(now) -> bool`, `count() -> int`, `clear()`
- `delay`, `history`

**Integrate**
1. One buffer per remote peer, cleared when they disconnect. Reusing a buffer
   across a reconnection replays the old session's positions.
2. Set `delay` to one and a half send intervals or so. Too short and the buffer
   runs dry constantly; too long and remote players feel laggy for no reason.
3. Send a timestamp with the position and use *that*, not the arrival time.
   Arrival time bakes the jitter you are trying to remove straight back in.

**Notes**
- `class_name StateBuffer` is global to the project — rename it if you already
  define that type.
- This buffers `Vector3`. Rotation wants the same treatment with `Quaternion`
  and `slerp`; the structure is identical.
- `MultiplayerSynchronizer` does a lot of this for you and is the right starting
  point for a real game. Writing it once by hand is how you understand what it
  is doing, and what to reach for when its defaults do not fit.
- This demo cannot run in the web gallery: ENet is UDP, and browsers cannot open
  raw sockets. `tools/export_web.sh` skips it by name and says so.

## Related demos

- [client-prediction](../client-prediction) — Moving before the server answers, and putting it right when the answer disagrees.
- [object-pool-3d](../object-pool-3d) — Recycling scene instances instead of allocating them, and the reset step that makes pooling safe.
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [skeleton-3d](../skeleton-3d) — Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

