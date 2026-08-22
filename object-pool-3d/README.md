# Object Pool

<!-- tags: ui, signals, component, shows-its-working -->

Recycling scene instances instead of allocating them, and the reset step that makes pooling safe.

## Purpose

In 2D the thing people pool is a node. In 3D it is a whole scene instance —
nodes, meshes, collision shapes, materials — and `instantiate()` plus
`queue_free()` sixty times a second produces exactly the periodic stutter that
makes a game feel bad while never showing up as a low average frame rate.

Pooling is a simple idea with one hard part. A recycled object arrives carrying
whatever state it had when it was released: a velocity, a timer, a half-finished
tween, a trail of particles. The resulting bug looks like a physics bug or a
spawn bug, and the pool is the last place anyone looks.

## Controls

| Key | Action |
|-----|--------|
| Space | Switch between pooling and instantiating every shot |
| R | Clear the sky and reset the counters |

Watch the "instances created" figure. Pooled, it stops climbing. Unpooled, it
climbs forever — one scene instantiated and freed per shot.

## How It Works

**A pool is two lists.** Free and in use. `acquire()` moves an instance from one
to the other, `release()` moves it back. Everything else is policy.

**Reset is a required step, not a convention.** `pool.reset` is a `Callable` the
pool calls on every acquisition, so no caller has to remember. Given how the bug
presents — a projectile that spawns where the last one died — the reset belongs
next to the pool, not scattered across everything that uses it.

**Reset runs before the instance wakes.** A physics frame can land between waking
an instance and resetting it, and a body woken first gets one frame with last
life's velocity — during which it moves. The order is asserted in the suite.

**Parked instances are properly asleep.** Invisible, not processing, not
physics-processing, `PROCESS_MODE_DISABLED` for collision objects. Leaving them
processing is the commonest pooling bug there is: the pool works, the frame rate
does not improve, and nothing explains why.

**Collision changes are deferred.** A body cannot change its collision state
during a physics callback, which is precisely when things get released — a
projectile releasing itself on impact is inside the collision it is reacting to.

**Running out returns null.** Not a busy instance: two callers sharing one object
teleport it onto each other, which is far worse than a missing bullet. Callers
handle null; the demo skips the shot.

**`created()` is the number worth watching.** If it keeps climbing during play,
something is acquiring without releasing — the pool has become an allocator with
extra steps.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `PackedScene.instantiate()` | The cost pooling exists to avoid repeating |
| `Node.process_mode` / `PROCESS_MODE_DISABLED` | Switching a parked instance off entirely |
| `Node.set_process()` / `set_physics_process()` | The per-node half of the same thing |
| `Object.set_deferred()` | Changing collision state safely from inside a physics callback |
| `is_instance_valid()` | Spotting an instance freed behind the pool's back |
| `Callable` | The reset step, held by the pool rather than by its callers |

## Files

| File | What it holds |
|------|---------------|
| `scripts/scene_pool.gd` | The `ScenePool` component: acquire, release, grow, park, reset |
| `scripts/main.gd` | Demo driver: a turret firing either from the pool or from `instantiate()` |
| `scenes/projectile.tscn` | The pooled scene |
| `scenes/main.tscn` | Ground, turret, camera, HUD |
| `tests/test_logic.gd` | Headless test suite, against the real projectile scene |

## Use as a building block

**Copy:** `scripts/scene_pool.gd` — the `ScenePool` type. `scripts/main.gd` is
the demo driver and is not needed.

**Public API**
- `ScenePool.new(scene: PackedScene, parent: Node, initial_size := 0)`
- `acquire() -> Node3D` (null when exhausted and capped), `release(instance) -> bool`
- `prewarm(count) -> int`, `release_all() -> int`, `prune()`
- `available()`, `in_use()`, `total()`, `created()`
- `reset: Callable`, `can_grow: bool`, `max_size: int`, `signal grew(new_size)`

**Integrate**
1. Set `reset` when you build the pool, and put *everything* transient in it —
   transform, velocity, visibility, timers, particle emitters, tween state.
2. Prewarm during loading. A pool that grows during a firefight has moved the
   stutter rather than removed it, which is what the `grew` signal is for
   telling you.
3. Handle a null from `acquire()`. Skipping a shot is a design decision; sharing
   an instance is a bug.

**Notes**
- `class_name ScenePool` is global to the project — rename it if you already
  define that type.
- Pool what is expensive and frequent. A pool for something spawned twice a
  level is complexity with no payoff, and it keeps memory alive for the whole
  game.
- For thousands of identical *static* objects, do not pool at all — draw them in
  one call with [multimesh](../multimesh). Pooling is for things that need to be
  nodes.

## Related demos

- [multiplayer-3d](../multiplayer-3d) — Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.
- [ragdoll-3d](../ragdoll-3d) — The hand-off from animation to physics, and the blend back that stops it snapping.
- [save-load-3d](../save-load-3d) — Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration.
- [editor-tool-3d](../editor-tool-3d) — A @tool script that builds a fence along a Path3D and updates while you drag the curve in the editor.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

