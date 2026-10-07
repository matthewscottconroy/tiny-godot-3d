# Replication Visibility

<!-- tags: ui, component, shows-its-working, needs-network -->

Replicating state with MultiplayerSynchronizer instead of hand-written RPCs, and only to the peers close enough to need it.

## Purpose

[multiplayer-3d](../multiplayer-3d) sends positions by hand: a timer, an
unreliable RPC, a sender id, a buffer per peer. `MultiplayerSynchronizer`
replaces all of it. Name the property once in a `SceneReplicationConfig` and the
engine sends it — there is no `@rpc` anywhere in this demo, which is the first
half of the point.

The second half is the decision the engine does *not* make for you: who should
receive it. Replicating every player to every player is quadratic. Sixteen peers
is 240 streams of position, most of them describing somebody on the far side of
the level who cannot be seen and will not be seen this minute.

And it is not only bandwidth. A client cannot draw a wallhack of a player whose
position it was never sent, so interest management is the one anti-cheat measure
that costs nothing and cannot be beaten by a better client. Everything else is
an arms race; this is arithmetic.

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | Move the blue pawn |
| H | Host |
| J | Join `127.0.0.1` |
| R | Go offline and reset |

Walk out of the green bubble and the readout stops replicating. Walk back and
notice you have to get further in than you were when you left.

## How It Works

**Naming the property is the whole setup.** A `SceneReplicationConfig` with one
entry — `Pawn:position` — and the engine does the sending. `REPLICATION_MODE_ON_CHANGE`
rather than `ALWAYS`, so a player standing still costs nothing at all, which is
most players most of the time.

**`root_path` defaults to `..`**, so a synchronizer added under `Main` resolves
`Pawn:position` to `Main/Pawn`. Setting it before the node is in the tree is how
you get *"no path can be resolved between the nodes"* — the path is relative to
somewhere the node does not yet live.

**Visibility is off by default here, deliberately.** `set_visibility_public(false)`
means nobody is sent anything until a filter says otherwise, so the filter is
actually consulted. Leave it public and `add_visibility_filter()` is dead code
that looks like it is working.

**The filter needs two radii, not one.** A peer standing exactly on a single
boundary flips between sent and not-sent every frame, and each flip is a full
state resend — so the edge of the bubble costs more traffic than the middle of
it. Entering has to be closer than leaving. Same shape as the distance bands in
[lod-and-decals](../lod-and-decals), for the same reason: any threshold crossed
continuously needs two thresholds.

**Relevance is not really binary.** Someone across the map still has to exist —
on a minimap, as a distant silhouette — they just do not need twenty updates a
second to do it. `interval_for()` eases the send rate between a near and a far
band, and interpolating between those sparse updates is exactly what
[multiplayer-3d](../multiplayer-3d)'s `StateBuffer` is for.

**Authority decides who may write.** `set_multiplayer_authority()` on the
synchronizer says which peer owns the property. Get it wrong and both ends push
their own position at each other for ever, which looks like rubber-banding and
is usually blamed on the network.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `MultiplayerSynchronizer` | Replicating properties without writing an RPC |
| `SceneReplicationConfig.add_property()` | Naming what gets sent |
| `property_set_replication_mode()` | `ON_CHANGE`, so a still player costs nothing |
| `MultiplayerSynchronizer.add_visibility_filter()` | A callable per peer: should this one be told? |
| `set_visibility_public()` | Off, so the filter is the only thing that grants visibility |
| `replication_interval` | A bounded send rate rather than every frame |
| `Node.set_multiplayer_authority()` | Which peer is allowed to write the property |

## Files

| File | What it holds |
|------|---------------|
| `scripts/replication_visibility.gd` | The `Relevance` component: who is in range, with hysteresis, and how often to send |
| `scripts/main.gd` | Demo driver: builds the synchronizer, hosts or joins, and hangs the filter on it |
| `scenes/main.tscn` | Camera, light, the pawn, the stand-in for another player, and the bubble |
| `tests/test_logic.gd` | Headless test suite — including a check that the synchronizer really is doing the sending |
| `tests/frames` | How many frames the suite needs, since it inspects a node built in `_ready()` |

## Use as a building block

**Copy:** `scripts/replication_visibility.gd` — the `Relevance` type.
`scripts/main.gd` is the demo driver and is not needed.

**Public API**
- `Relevance.in_range(viewer, subject, radius) -> bool` — flat, on the XZ plane
- `Relevance.stays_relevant(was_relevant, viewer, subject, enter_radius, exit_radius) -> bool`
- `Relevance.interval_for(distance, near, far, near_interval := 0.05, far_interval := 0.5) -> float`
- `Relevance.audience(owner_id, positions, radius) -> Array[int]`
- `Relevance.streams_saved(peers, sent) -> float`

**Integrate**
1. Put a `MultiplayerSynchronizer` beside the thing being replicated, give it a
   config, and set the authority to the peer that owns it.
2. `set_visibility_public(false)` and add a filter, or the filter never runs.
3. Call `update_visibility()` when the answer could have changed — the default
   `VISIBILITY_PROCESS_IDLE` re-asks every frame, which is fine for a handful of
   peers and wasteful for hundreds.
4. Keep the enter and exit radii apart by more than a player can cross in one
   frame, or the hysteresis buys nothing.

**Notes**
- `class_name Relevance` is global to the project — rename it if you already
  define that type.
- Range is flat on the XZ plane on purpose: a player on a walkway directly
  overhead is as relevant as one beside you, and a spherical test would drop
  them.
- Visibility is not the same as authority. A peer can be allowed to write a
  property it is never sent, and the two are configured separately.
- Interest management by distance is the simple version. A real one asks whether
  the subject is *visible*, not merely near — a player behind a wall six metres
  away matters less than one thirty metres down a corridor.

## Related demos

- [multiplayer-3d](../multiplayer-3d) — Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.
- [client-prediction](../client-prediction) — Moving before the server answers, and putting it right when the answer disagrees.
- [editor-tool-3d](../editor-tool-3d) — A @tool script that builds a fence along a Path3D and updates while you drag the curve in the editor.
- [joints-3d](../joints-3d) — A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

