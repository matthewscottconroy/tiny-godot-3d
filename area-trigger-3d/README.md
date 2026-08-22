# Area Triggers

<!-- tags: physics, ui, signals, component, shows-its-working -->

Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.

## Purpose

`Area3D` reports `body_entered` and `body_exited`, once per body. Almost nothing
in a game wants that.

A pressure plate wants to know when it *becomes* occupied and when it *becomes*
empty. Wire a door to `body_entered` and it opens twice for two crates; wire it
to `body_exited` and it slams shut on the second crate while the first is still
standing on the plate. The event you want is the transition, and the state you
want is a count.

The other half is layers. Whether the plate notices something is not a question
about where it is — it is a question about what it is, and getting that wrong
gives you a trigger that fires for stray debris and bullets.

## Controls

| Key | Action |
|-----|--------|
| 1 | Drop the crate onto the plate |
| 2 | Drop the debris onto the plate — the plate ignores it |
| R | Put both back |

Stand the crate on the plate for two seconds and the door locks open.

## How It Works

**The area reports; the `Occupancy` decides what it means.** `body_entered` and
`body_exited` are connected straight to `enter()` and `exit()`, which maintain a
list. `occupied` fires only on 0 → 1, `vacated` only on 1 → 0. The door reads
`is_occupied()`, so any number of crates keep it open and the last one to leave
closes it.

**The same body can be reported twice.** A body straddling two collision shapes
of the same area enters once per shape. A count that goes to two for one crate
never comes back to zero, and the plate stays pressed forever.

**A body freed inside the area never leaves it.** No `body_exited` is emitted
for a node that is destroyed, so the occupant list keeps a freed reference —
which both jams the trigger and errors the next time anything iterates it.
`prune()` runs every physics frame.

**Layers and masks are two different questions.** `collision_layer` is what you
*are*; `collision_mask` is what you *look for*. The plate has layer 0 and mask 2:
it is on no layer at all, because nothing needs to detect the plate, and it
watches layer 2, which is the crate's. The debris sits on layer 4 and is
invisible to the plate no matter where it lands — which the test asserts by
putting it in exactly the same place as the crate.

**`get_overlapping_bodies()` is the other half of the API.** Signals tell you
about changes; that call tells you the current state, and is what to use after
enabling an area, teleporting something, or loading a save.

**Dwell time is per body, not per zone.** "Stand here for three seconds" asks
whether *someone* has waited that long, not whether the zone has been busy for
three seconds while people came and went.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `Area3D.body_entered` / `body_exited` | The per-body events |
| `Area3D.get_overlapping_bodies()` | The current state, rather than the change |
| `Area3D.collision_layer` / `collision_mask` | What it is, and what it looks for |
| `Area3D.monitoring` | Whether it looks at all — switching it off is the cheap way to disable a trigger |
| `RigidBody3D.global_position` | Moving a body the solver owns |
| `is_instance_valid()` | Spotting an occupant that has been freed |

## Files

| File | What it holds |
|------|---------------|
| `scripts/occupancy.gd` | The `Occupancy` component: the count, the transitions, dwell time, pruning |
| `scripts/main.gd` | Demo driver: the plate, the door it drives, and the two droppable bodies |
| `scenes/main.tscn` | A floor, a plate on mask 2, a door, a crate on layer 2 and debris on layer 4 |
| `tests/test_logic.gd` | Headless test suite — including a real drop into the real area |
| `tests/frames` | How many frames the suite needs, since it waits on physics |

## Use as a building block

**Copy:** `scripts/occupancy.gd` — the `Occupancy` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `enter(body) -> bool`, `exit(body) -> bool`, `prune()`, `clear()`
- `contains(body) -> bool`, `count() -> int`, `is_occupied() -> bool`, `bodies() -> Array[Node]`
- `advance(delta)`, `dwell(body) -> float`, `longest_dwell() -> float`
- `signal occupied`, `signal vacated`, `signal count_changed(count: int)`

**Integrate**
1. Connect `body_entered` and `body_exited` straight to `enter` and `exit` —
   they take a `Node` and return whether anything changed, so they can be
   connected directly with no lambda in between.
2. Drive doors, lights and music off `occupied` / `vacated`, and anything
   per-body off the signals the area itself emits.
3. Call `prune()` wherever occupants can be destroyed. Once per physics frame
   costs nothing at this size.

**Notes**
- `class_name Occupancy` is global to the project — rename it if you already
  define that type.
- For areas that should detect other areas rather than bodies, connect
  `area_entered` / `area_exited` as well; they are separate signals and separate
  masks (`monitorable` on the other side).
- An area with `monitoring = false` emits nothing at all, and turning it back on
  does not replay what it missed. `get_overlapping_bodies()` on the next physics
  frame is how you catch up.

## Related demos

- [audio-3d](../audio-3d) — Positional audio with AudioStreamPlayer3D, and a hearing model the game logic can share with it.
- [lights-and-shadows](../lights-and-shadows) — The three 3D light types side by side, and a shadow budget that keeps the expensive ones near the camera.
- [continuous-collision](../continuous-collision) — A fast projectile that goes straight through a wall, and the three ways to stop it.
- [audio-buses](../audio-buses) — Audio buses built at runtime: sliders that are decibels, a mute that is not a volume, and a reverb you walk into.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

