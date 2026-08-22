# Known gaps

What the collection does not cover yet. Check here before opening a demo
request — and treat anything on this list as fair game to contribute.

This collection is young, and the list below is not a footnote: it is the
roadmap. It is ordered by how much a demo would be missed, not by how hard it is
to write.

The other honest signal is [TAGS.md](TAGS.md), where a tag with one demo is a
subject with a foothold rather than coverage — `tool-script` is in that state,
and `shader`, `audio`, `persistence` and `navigation` are on two apiece. Every
tag has at least one demo behind it; what is left is depth rather than the first
example.

## Physics

- **`Generic6DOFJoint3D`** — the joint that does everything, and the axes you
  have to configure to get there
- **Continuous collision for a character** — the same tunnelling as
  [continuous-collision](../continuous-collision), but for a `CharacterBody3D`
  falling through a floor
- **Active ragdolls** — a skeleton that stays partly animated while physics
  takes the rest, past the all-or-nothing hand-off in
  [ragdoll-3d](../ragdoll-3d)

## Cameras

- **Recursive portals** — [portal-3d](../portal-3d) draws one level; two portals
  that can see each other need a budget and an oblique near plane
- **Camera collision for a first-person view** — the near plane clipping through
  a wall the player is standing against

## Level building

- **Streaming the scenes themselves** — [level-streaming](../level-streaming)
  decides *which* chunks; loading them off the main thread with
  [threaded-loading](../threaded-loading) is the other half
- **Terrain texturing** — splatting by slope and height over the collider
  [terrain-collision](../terrain-collision) already lines up

## Rendering

- **Baked lighting** — `LightmapGI`, and what it buys over the real-time lights
  in [lights-and-shadows](../lights-and-shadows)

## Animation

- **`SkeletonModifier3D`** — the supported place to hang procedural pose changes,
  and how it sits next to an `AnimationTree`
- **Root motion with rotation** — `get_root_motion_rotation()`, and a turn that
  belongs to the clip as well as the step

## Systems

- **Lag compensation** — the server rewinding to where a client *saw* things
  when it decides whether a shot hit, which is the other half of
  [client-prediction](../client-prediction)
- **`MultiplayerSynchronizer`** — the built-in version of the same job
- **Screen readers** — the half of accessibility that
  [menu-navigation](../menu-navigation) does not cover: telling the player what
  is focused rather than only showing them

## Deliberately out of scope

- **C# and GDExtension.** The collection is GDScript so that every demo can be
  read without a build step.
- **Full games.** One concept per demo is the constraint that makes the whole
  thing browsable.
- **Anything needing paid or large assets.** Every demo generates its geometry in
  code or ships a small SVG, so a clone is fast and nothing has a licence
  question attached. This bites harder in 3D than in 2D — it rules out demos
  that only work with a rigged character model, which is why animation is thin
  and will stay thin until there is a way to show it without one.
- **XR.** It needs hardware to check, and CI cannot check it at all.

## How to claim one

Open an issue with the demo-request template saying which you are taking, then
`tools/new-demo.sh <name>`. See [CONTRIBUTING.md](../CONTRIBUTING.md).
