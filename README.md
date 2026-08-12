# Tiny Godot 3D

A collection of **3 tiny, self-contained Godot 4 demos** — each one isolates a single 3D game-development concept in the smallest complete project that teaches it. Every demo is its own Godot project with a focused `README.md`, runnable scene, and an automated test suite.

Built for **Godot 4.7** (Forward+). This is the 3D companion to
[tiny-godot-games](https://github.com/matthewscottconroy/tiny-godot-games), which
covers 2D in 165 demos and shares this repository's conventions and tooling.

> **Status: early.** Three demos so far. The harness, conventions, and CI are in
> place, so the shape is settled — what is missing is breadth. See
> [what's next](#whats-next).

## Using a demo

Each folder is a standalone project. Open one directly in Godot:

```bash
godot --path orbit-camera        # open in the editor
godot --path orbit-camera res://scenes/main.tscn
```

Every demo follows the same layout:

```
<demo>/
├── README.md            # what it teaches, controls, how it works, key APIs
├── project.godot        # standalone Godot project
├── scenes/main.tscn     # the runnable demo
├── scripts/             # the GDScript
└── tests/               # headless logic tests (test.tscn + test_logic.gd)
```

## Running the tests

Every demo gets two checks — a **smoke** check that boots the real scene and
fails on any script or scene error, and a **logic** suite that drives the demo's
own scripts:

```bash
./run-tests.sh                 # all demos, in parallel
./run-tests.sh orbit-camera    # one demo
./run-tests.sh --smoke-only    # just boot everything
tools/check_docs.py            # README structure and index consistency
tools/new-demo.sh <name>       # scaffold a demo that is green from the start
```

## The demos

### 🎮 Movement & Cameras
| Demo | Description |
|------|-------------|
| [character-controller-3d](character-controller-3d) | Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body. |
| [orbit-camera](orbit-camera) | A third-person camera that orbits a target, with pitch limits and camera-relative movement. |

### 🧱 Geometry
| Demo | Description |
|------|-------------|
| [procedural-mesh](procedural-mesh) | Building geometry with `SurfaceTool`: vertices, winding order, indices, and normals. |

## What's next

The 2D collection's categories suggest the shape this one should grow into. The
gaps that matter most, roughly in order:

- **Physics** — `RigidBody3D`, joints, raycast picking, character-vs-rigid interaction
- **Level building** — `GridMap`, CSG blockouts, `NavigationRegion3D` pathfinding
- **Rendering** — lighting and shadows, environment and fog, decals, LOD
- **Animation** — `AnimationTree` blend spaces, IK, root motion
- **Cameras** — spring arm with real collision, first-person, cinematic tracks

## Why a separate repository

The 2D collection is explicitly 2D-only, and that is a real strength: someone
looking for a platformer camera should not wade past mesh generation. The
conventions and tooling port directly — this repo uses the same `run-tests.sh`,
the same `check_docs.py`, and the same six README sections — but the audiences
and the browsing experience are different enough to keep separate.

---

*3 demos. Each teaches one thing, completely.*
