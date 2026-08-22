# Tiny Godot 3D

A collection of **54 tiny, self-contained Godot 4 demos** — each one isolates a single 3D game-development concept in the smallest complete project that teaches it. Every demo is its own Godot project with a focused `README.md`, runnable scene, and an automated test suite.

Built for **Godot 4.7** (Forward+). Every demo is **3D** — 2D lives in its own
collection, [tiny-godot-games](https://github.com/matthewscottconroy/tiny-godot-games), which covers it in 165
demos and shares this repository's conventions and tooling.

<!-- compat-badge -->
**Godot 4.7** — 54/54 demos passing. [Full table](docs/COMPATIBILITY.md)
<!-- /compat-badge -->

> **Status: growing.** Fifty-four demos so far. The harness, conventions,
> tooling and CI are in place, so the shape is settled — what is missing is
> breadth. The gaps are enumerated in [docs/GAPS.md](docs/GAPS.md), and anything
> on that list is fair game to contribute.

Prefer to browse and run rather than read? `godot --path browser` opens the
**[demo browser](browser)** — search the collection, filter it by concept tag,
and launch any demo. See also **[concept tags](docs/TAGS.md)** for the same
demos grouped by what they use rather than what they are about.

New here, or want a route rather than an index? **[Learning paths](docs/LEARNING_PATHS.md)**
orders these demos into tracks, with a difficulty marker on each step. Looking
for a specific engine API rather than a subject? The **[API index](docs/API_INDEX.md)**
maps every API the demos use back to the demo that shows it.

## Using a demo

Each folder is a standalone project. Open one directly in Godot:

```bash
godot --path orbit-camera        # open in the editor
godot --path orbit-camera res://scenes/main.tscn   # or just run it
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

Every demo gets two checks. Run them all:

```bash
./run-tests.sh
```

1. **Smoke** — boots the demo's real `scenes/main.tscn` headless for a few frames
   and fails on any script error, scene error, or engine warning. This is what
   catches a demo that does not actually run. Warnings count because Godot
   reports a refused operation as a warning rather than an error, and 3D has
   plenty of those — an unsupported shadow mode, a mesh with no surface, a
   viewport with no camera.
2. **Logic** — `tests/test.tscn` runs `tests/test_logic.gd`, which exercises the
   demo's own scripts and prints a `[demo] N/M passed` summary. A suite that
   errors partway fails too, rather than quietly reporting a smaller `n/n`.

Both checks run against a specific demo too, and either can be run on its own:

```bash
./run-tests.sh orbit-camera         # one demo (or several)
./run-tests.sh --smoke-only         # just boot every demo
./run-tests.sh --tests-only         # just the logic suites
JOBS=4 ./run-tests.sh               # cap concurrency
```

Each job is a full Godot process, so the default concurrency is bounded by
available memory as well as core count — a many-core machine would otherwise
run out of RAM long before it saturated the CPU. Set `JOBS=` to override.

...or invoke one demo's suite directly:

```bash
godot --headless --path orbit-camera res://tests/test.tscn --quit-after 5
```

Other tooling:

```bash
tools/preflight.sh        # which of these pipelines can run on this machine
tools/check_docs.py       # README structure, control claims, index drift, unlit scenes
tools/new-demo.sh <name>  # scaffold a demo that is green from the start
tools/build_tags.py       # derive each demo's concept tags from its source
tools/build_index.py      # API cross-reference and related-demo links
tools/mutate.py           # do the suites actually catch bugs? (docs/TEST_INTEGRITY.md)
tools/leakcheck.sh        # demos that leak objects at shutdown (docs/MEMORY.md)
tools/screenshots.sh      # capture one PNG per demo (needs xvfb)
tools/build_gallery.py    # write docs/GALLERY.md from those screenshots
tools/export_web.sh       # export demos for the browser (needs export templates)
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the conventions these enforce, and
[docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) for why the components are copied
rather than shipped as an addon.

The script imports each project first (generating `.godot/`) so `class_name`
globals and assets resolve the same way they do in CI, which runs the identical
script on every push — see [.github/workflows/tests.yml](.github/workflows/tests.yml).

## The demos

### 🎮 Movement & Controllers
| Demo | Description |
|------|-------------|
| [character-controller-3d](character-controller-3d) | Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body. |
| [first-person-controller](first-person-controller) | Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body. |
| [gamepad-3d](gamepad-3d) | Analogue stick handling in 3D: a radial deadzone that does not jump, a response curve, and camera-relative movement. |
| [shape-cast-3d](shape-cast-3d) | Sweeping a shape ahead of a character with ShapeCast3D to tell a step it can climb from a wall it cannot. |
| [character-push](character-push) | A CharacterBody3D that pushes crates — because move_and_slide() slides past them and does nothing else. |

### 🎥 Cameras
| Demo | Description |
|------|-------------|
| [orbit-camera](orbit-camera) | A third-person camera that orbits a target, with pitch limits and camera-relative movement. |
| [spring-arm-camera](spring-arm-camera) | A third-person camera on a SpringArm3D that collides with the level, and eases back out when it clears. |
| [cinematic-camera](cinematic-camera) | A camera on a Path3D, and the blend between gameplay and cutscene that Godot does not do for you. |
| [camera-shake-3d](camera-shake-3d) | Camera shake as an offset a rig can carry, with trauma that decays and noise that is the same every run. |
| [camera-framing](camera-framing) | A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic. |
| [split-screen-3d](split-screen-3d) | Two players, two viewports, one world — and the shared World3D that makes the second view show anything at all. |
| [portal-3d](portal-3d) | A portal you can see through and walk through, and the transform that puts the second camera in the right place. |

### ⚙️ Physics & Queries
| Demo | Description |
|------|-------------|
| [rigid-body-3d](rigid-body-3d) | RigidBody3D boxes that fall, stack, and scatter — impulses versus setting a transform. |
| [raycast-picking](raycast-picking) | Turning a mouse position into a world ray, and asking the physics space what it hit. |
| [area-trigger-3d](area-trigger-3d) | Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts. |
| [joints-3d](joints-3d) | A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation. |
| [terrain-collision](terrain-collision) | A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match. |
| [continuous-collision](continuous-collision) | A fast projectile that goes straight through a wall, and the three ways to stop it. |
| [vehicle-3d](vehicle-3d) | A VehicleBody3D that drives, the arithmetic that keeps it drivable, and the sign that catches everyone. |
| [ragdoll-3d](ragdoll-3d) | The hand-off from animation to physics, and the blend back that stops it snapping. |

### 🗺️ Level Building & Navigation
| Demo | Description |
|------|-------------|
| [grid-map](grid-map) | Level building with GridMap and a MeshLibrary made in code, from a room drawn as text. |
| [navigation-3d](navigation-3d) | Baking a NavigationRegion3D at runtime and driving an agent along the path it finds. |
| [navigation-obstacle](navigation-obstacle) | Why a NavigationObstacle3D does not change the path, and the two mechanisms that do. |
| [editor-tool-3d](editor-tool-3d) | A @tool script that builds a fence along a Path3D and updates while you drag the curve in the editor. |
| [csg-blockout](csg-blockout) | Greyboxing a level with CSG: rooms added, doorways subtracted, and the bake that turns it into a mesh. |
| [level-streaming](level-streaming) | Loading and freeing chunks around a moving player, with the keep-radius that stops them thrashing at a boundary. |

### 🧱 Geometry & Procedural
| Demo | Description |
|------|-------------|
| [procedural-mesh](procedural-mesh) | Building geometry with `SurfaceTool`: vertices, winding order, indices, and normals. |
| [noise-terrain](noise-terrain) | A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change. |
| [multimesh](multimesh) | Ten thousand instances in one draw call with MultiMeshInstance3D, and a distance cull that costs nothing. |

### 💡 Rendering & Light
| Demo | Description |
|------|-------------|
| [lights-and-shadows](lights-and-shadows) | The three 3D light types side by side, and a shadow budget that keeps the expensive ones near the camera. |
| [environment-fog](environment-fog) | A day-night cycle driven by a WorldEnvironment: sun angle, sky, ambient light and fog from one clock. |
| [volumetric-fog](volumetric-fog) | Fog with light in it: the settings that make it appear, and the three reasons it usually does not. |
| [transparency-3d](transparency-3d) | Why transparent objects draw in the wrong order, and the three ways out: sorting, scissor, and hash. |
| [lod-and-decals](lod-and-decals) | Distance bands that drive mesh LOD, decal fade and update rates — with the hysteresis that stops them flickering. |
| [wave-shader](wave-shader) | A water surface displaced in a shader, with the same wave maths in GDScript so things can float on it. |
| [render-to-texture](render-to-texture) | A security monitor: a second camera rendered onto a screen in the world, and the update mode that keeps it affordable. |
| [screen-shader](screen-shader) | A shader that reads the screen behind it — refraction, fresnel, and the thing it cannot see. |

### 🎬 Animation & Audio
| Demo | Description |
|------|-------------|
| [animation-in-code](animation-in-code) | Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk. |
| [animation-tree](animation-tree) | An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching. |
| [root-motion](root-motion) | Motion that comes from the animation rather than the code, and the sliding feet it fixes. |
| [tween-3d](tween-3d) | Tween or AnimationPlayer — what each is for, and the two tweens that end up fighting over one property. |
| [skeleton-3d](skeleton-3d) | Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for. |
| [two-bone-ik](two-bone-ik) | Two-bone inverse kinematics: where the knee goes when the foot is planted, and what happens when it cannot reach. |
| [audio-3d](audio-3d) | Positional audio with AudioStreamPlayer3D, and a hearing model the game logic can share with it. |
| [audio-buses](audio-buses) | Audio buses built at runtime: sliders that are decibels, a mute that is not a volume, and a reverb you walk into. |

### 💾 Data & Systems
| Demo | Description |
|------|-------------|
| [save-load-3d](save-load-3d) | Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration. |
| [object-pool-3d](object-pool-3d) | Recycling scene instances instead of allocating them, and the reset step that makes pooling safe. |
| [input-remapping](input-remapping) | Rebinding actions at runtime, spotting the conflicts, and saving the result where it survives a restart. |
| [device-glyphs](device-glyphs) | Button prompts that follow the device actually being used, including the face buttons Nintendo swapped. |
| [menu-navigation](menu-navigation) | A menu that works with no mouse at all: focus worked out from the layout, and never lost. |
| [threaded-loading](threaded-loading) | Loading scenes on a background thread with a progress bar, instead of freezing the game with load(). |
| [multiplayer-3d](multiplayer-3d) | Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth. |
| [client-prediction](client-prediction) | Moving before the server answers, and putting it right when the answer disagrees. |
| [accessibility-3d](accessibility-3d) | Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads. |

## What's next

The 2D collection's categories suggest the shape this one should grow into, and
[docs/TAGS.md](docs/TAGS.md) shows the same thing from the other side: the tags
with no demos are the subjects nothing here covers yet. The gaps that matter
most, roughly in order:

- **Animation** — `AnimationTree` blend spaces and root motion, over the clips and rigs already here
- **Level building** — CSG blockouts, level streaming, `NavigationObstacle3D`, terrain collision
- **Rendering** — render-to-texture, volumetric fog, a shader that reads the screen
- **Physics** — vehicles, continuous collision detection, `Generic6DOFJoint3D`
- **Multiplayer** — authority and prediction, on top of what `multiplayer-3d` starts

[docs/GAPS.md](docs/GAPS.md) is the full list, with what each demo would need to
show.

## Why a separate repository

The 2D collection is explicitly 2D-only, and that is a real strength: someone
looking for a platformer camera should not wade past mesh generation. The
conventions and tooling port directly — the same `run-tests.sh`, the same
`check_docs.py`, the same six README sections — but the audiences and the
browsing experience are different enough to keep separate.

What does not port is the taxonomy. Half of 3D work is geometry, space and
light, which in 2D are either trivial or the engine's problem, so the concept
tags, the API index and the doc checks here describe 3D on its own terms rather
than translating the 2D ones.

---

*54 demos. Each teaches one thing, completely.*
