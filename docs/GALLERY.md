# Gallery

Every demo, with a frame captured from its actual running scene. Click a demo to
open its README.

Screenshots are produced by `tools/screenshots.sh`, which runs each demo under a
virtual display and keeps one frame — so they show the real thing rather than
hand-picked marketing shots. A demo whose image is missing simply has not been
captured yet.

Looking for a route rather than a catalogue? See [learning paths](LEARNING_PATHS.md).


## 🎮 Movement & Controllers

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[character-controller-3d](../character-controller-3d)**<br><sub>Walking, running and jumping a `CharacterBody3D`, with the movement rules separated from the body.</sub> | _(no screenshot yet)_<br>**[first-person-controller](../first-person-controller)**<br><sub>Mouse look, WASD movement and head bob on a CharacterBody3D — the rig separated from the body.</sub> | _(no screenshot yet)_<br>**[gamepad-3d](../gamepad-3d)**<br><sub>Analogue stick handling in 3D: a radial deadzone that does not jump, a response curve, and camera-relative movement.</sub> |
| _(no screenshot yet)_<br>**[shape-cast-3d](../shape-cast-3d)**<br><sub>Sweeping a shape ahead of a character with ShapeCast3D to tell a step it can climb from a wall it cannot.</sub> | _(no screenshot yet)_<br>**[character-push](../character-push)**<br><sub>A CharacterBody3D that pushes crates — because move_and_slide() slides past them and does nothing else.</sub> |  |

## 🎥 Cameras

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[orbit-camera](../orbit-camera)**<br><sub>A third-person camera that orbits a target, with pitch limits and camera-relative movement.</sub> | _(no screenshot yet)_<br>**[spring-arm-camera](../spring-arm-camera)**<br><sub>A third-person camera on a SpringArm3D that collides with the level, and eases back out when it clears.</sub> | _(no screenshot yet)_<br>**[cinematic-camera](../cinematic-camera)**<br><sub>A camera on a Path3D, and the blend between gameplay and cutscene that Godot does not do for you.</sub> |
| _(no screenshot yet)_<br>**[camera-shake-3d](../camera-shake-3d)**<br><sub>Camera shake as an offset a rig can carry, with trauma that decays and noise that is the same every run.</sub> | _(no screenshot yet)_<br>**[camera-framing](../camera-framing)**<br><sub>A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.</sub> | _(no screenshot yet)_<br>**[split-screen-3d](../split-screen-3d)**<br><sub>Two players, two viewports, one world — and the shared World3D that makes the second view show anything at all.</sub> |
| _(no screenshot yet)_<br>**[portal-3d](../portal-3d)**<br><sub>A portal you can see through and walk through, and the transform that puts the second camera in the right place.</sub> |  |  |

## ⚙️ Physics & Queries

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[rigid-body-3d](../rigid-body-3d)**<br><sub>RigidBody3D boxes that fall, stack, and scatter — impulses versus setting a transform.</sub> | _(no screenshot yet)_<br>**[raycast-picking](../raycast-picking)**<br><sub>Turning a mouse position into a world ray, and asking the physics space what it hit.</sub> | _(no screenshot yet)_<br>**[area-trigger-3d](../area-trigger-3d)**<br><sub>Area3D triggers that fire on the transition rather than per body, with collision layers deciding what counts.</sub> |
| _(no screenshot yet)_<br>**[joints-3d](../joints-3d)**<br><sub>A HingeJoint3D door with limits and a motor, and a PinJoint3D chain — physics constraints instead of animation.</sub> | _(no screenshot yet)_<br>**[terrain-collision](../terrain-collision)**<br><sub>A HeightMapShape3D that lines up with the mesh it came from — and what happens when the spacing does not match.</sub> | _(no screenshot yet)_<br>**[continuous-collision](../continuous-collision)**<br><sub>A fast projectile that goes straight through a wall, and the three ways to stop it.</sub> |
| _(no screenshot yet)_<br>**[vehicle-3d](../vehicle-3d)**<br><sub>A VehicleBody3D that drives, the arithmetic that keeps it drivable, and the sign that catches everyone.</sub> | _(no screenshot yet)_<br>**[ragdoll-3d](../ragdoll-3d)**<br><sub>The hand-off from animation to physics, and the blend back that stops it snapping.</sub> |  |

## 🗺️ Level Building & Navigation

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[grid-map](../grid-map)**<br><sub>Level building with GridMap and a MeshLibrary made in code, from a room drawn as text.</sub> | _(no screenshot yet)_<br>**[navigation-3d](../navigation-3d)**<br><sub>Baking a NavigationRegion3D at runtime and driving an agent along the path it finds.</sub> | _(no screenshot yet)_<br>**[navigation-obstacle](../navigation-obstacle)**<br><sub>Why a NavigationObstacle3D does not change the path, and the two mechanisms that do.</sub> |
| _(no screenshot yet)_<br>**[editor-tool-3d](../editor-tool-3d)**<br><sub>A @tool script that builds a fence along a Path3D and updates while you drag the curve in the editor.</sub> | _(no screenshot yet)_<br>**[csg-blockout](../csg-blockout)**<br><sub>Greyboxing a level with CSG: rooms added, doorways subtracted, and the bake that turns it into a mesh.</sub> | _(no screenshot yet)_<br>**[level-streaming](../level-streaming)**<br><sub>Loading and freeing chunks around a moving player, with the keep-radius that stops them thrashing at a boundary.</sub> |

## 🧱 Geometry & Procedural

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[procedural-mesh](../procedural-mesh)**<br><sub>Building geometry with `SurfaceTool`: vertices, winding order, indices, and normals.</sub> | _(no screenshot yet)_<br>**[noise-terrain](../noise-terrain)**<br><sub>A heightmap from FastNoiseLite turned into a mesh, with slope-shaded regions and a seed you can change.</sub> | _(no screenshot yet)_<br>**[multimesh](../multimesh)**<br><sub>Ten thousand instances in one draw call with MultiMeshInstance3D, and a distance cull that costs nothing.</sub> |

## 💡 Rendering & Light

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[lights-and-shadows](../lights-and-shadows)**<br><sub>The three 3D light types side by side, and a shadow budget that keeps the expensive ones near the camera.</sub> | _(no screenshot yet)_<br>**[environment-fog](../environment-fog)**<br><sub>A day-night cycle driven by a WorldEnvironment: sun angle, sky, ambient light and fog from one clock.</sub> | _(no screenshot yet)_<br>**[volumetric-fog](../volumetric-fog)**<br><sub>Fog with light in it: the settings that make it appear, and the three reasons it usually does not.</sub> |
| _(no screenshot yet)_<br>**[transparency-3d](../transparency-3d)**<br><sub>Why transparent objects draw in the wrong order, and the three ways out: sorting, scissor, and hash.</sub> | _(no screenshot yet)_<br>**[lod-and-decals](../lod-and-decals)**<br><sub>Distance bands that drive mesh LOD, decal fade and update rates — with the hysteresis that stops them flickering.</sub> | _(no screenshot yet)_<br>**[wave-shader](../wave-shader)**<br><sub>A water surface displaced in a shader, with the same wave maths in GDScript so things can float on it.</sub> |
| _(no screenshot yet)_<br>**[render-to-texture](../render-to-texture)**<br><sub>A security monitor: a second camera rendered onto a screen in the world, and the update mode that keeps it affordable.</sub> | _(no screenshot yet)_<br>**[screen-shader](../screen-shader)**<br><sub>A shader that reads the screen behind it — refraction, fresnel, and the thing it cannot see.</sub> |  |

## 🎬 Animation & Audio

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[animation-in-code](../animation-in-code)**<br><sub>Building an Animation and an AnimationPlayer at runtime — a walk cycle with no animation data on disk.</sub> | _(no screenshot yet)_<br>**[animation-tree](../animation-tree)**<br><sub>An AnimationTree blend space driven by speed, built in code — and the deadzone that stops a standing character twitching.</sub> | _(no screenshot yet)_<br>**[root-motion](../root-motion)**<br><sub>Motion that comes from the animation rather than the code, and the sliding feet it fixes.</sub> |
| _(no screenshot yet)_<br>**[tween-3d](../tween-3d)**<br><sub>Tween or AnimationPlayer — what each is for, and the two tweens that end up fighting over one property.</sub> | _(no screenshot yet)_<br>**[skeleton-3d](../skeleton-3d)**<br><sub>Building a Skeleton3D in code and posing its bones — local poses, rests, and what BoneAttachment3D is for.</sub> | _(no screenshot yet)_<br>**[two-bone-ik](../two-bone-ik)**<br><sub>Two-bone inverse kinematics: where the knee goes when the foot is planted, and what happens when it cannot reach.</sub> |
| _(no screenshot yet)_<br>**[audio-3d](../audio-3d)**<br><sub>Positional audio with AudioStreamPlayer3D, and a hearing model the game logic can share with it.</sub> | _(no screenshot yet)_<br>**[audio-buses](../audio-buses)**<br><sub>Audio buses built at runtime: sliders that are decibels, a mute that is not a volume, and a reverb you walk into.</sub> |  |

## 💾 Data & Systems

| | | |
|---|---|---|
| _(no screenshot yet)_<br>**[save-load-3d](../save-load-3d)**<br><sub>Saving and restoring a 3D scene's transforms as JSON under `user://`, including a version migration.</sub> | _(no screenshot yet)_<br>**[object-pool-3d](../object-pool-3d)**<br><sub>Recycling scene instances instead of allocating them, and the reset step that makes pooling safe.</sub> | _(no screenshot yet)_<br>**[input-remapping](../input-remapping)**<br><sub>Rebinding actions at runtime, spotting the conflicts, and saving the result where it survives a restart.</sub> |
| _(no screenshot yet)_<br>**[device-glyphs](../device-glyphs)**<br><sub>Button prompts that follow the device actually being used, including the face buttons Nintendo swapped.</sub> | _(no screenshot yet)_<br>**[menu-navigation](../menu-navigation)**<br><sub>A menu that works with no mouse at all: focus worked out from the layout, and never lost.</sub> | _(no screenshot yet)_<br>**[threaded-loading](../threaded-loading)**<br><sub>Loading scenes on a background thread with a progress bar, instead of freezing the game with load().</sub> |
| _(no screenshot yet)_<br>**[multiplayer-3d](../multiplayer-3d)**<br><sub>Two peers over ENet, and the interpolation buffer that makes ten updates a second look smooth.</sub> | _(no screenshot yet)_<br>**[client-prediction](../client-prediction)**<br><sub>Moving before the server answers, and putting it right when the answer disagrees.</sub> | _(no screenshot yet)_<br>**[accessibility-3d](../accessibility-3d)**<br><sub>Reduced motion, subtitle scaling and colour-blind-safe cue palettes, held in one options object everything else reads.</sub> |

---

_54 demos, 0 with screenshots, 0 animated._
