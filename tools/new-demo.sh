#!/usr/bin/env bash
#
# Scaffold a new 3D demo with the structure the whole collection uses.
#
#   tools/new-demo.sh my-demo "One-line description for the index"
#
# Creates project.godot, icon.svg, a runnable 3D scene, a component script, a
# demo driver, a test suite that drives the component for real, and a README
# with all six required sections.
#
# What it scaffolds is a working demo, not a stub: a box that bobs, driven by a
# `class_name` component the suite exercises headlessly. That is the shape every
# demo here has — the maths in a RefCounted, the driver applying it to nodes —
# and starting from something green means you edit down rather than up.
#
# It does NOT add the demo to the root README index: that needs a category
# decision, and the cross-links and tags are generated from the index. So the
# last two steps below are yours. tools/check_docs.py will remind you.

set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -lt 1 ]; then
  echo "usage: tools/new-demo.sh <demo-name> [\"index description\"]" >&2
  exit 2
fi

name="${1%/}"
desc="${2:-One-line description of what this demo teaches.}"

if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: demo name must be lowercase-with-hyphens (got '$name')" >&2
  exit 2
fi

if [ -e "$name" ]; then
  echo "error: '$name' already exists" >&2
  exit 2
fi

# my-demo -> My Demo, and -> MyDemo for the class name.
title="$(echo "$name" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
classname="$(echo "$title" | tr -d ' ')"
# my-demo -> my_demo, for the component's file name.
snake="$(echo "$name" | tr '-' '_')"

mkdir -p "$name"/{scenes,scripts,tests}

cat > "$name/project.godot" <<EOF
; Engine configuration file.
config_version=5

[application]

config/name="$title"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"
run/main_scene="res://scenes/main.tscn"

[display]

window/size/viewport_width=800
window/size/viewport_height=600

[rendering]

renderer/rendering_method="forward_plus"
EOF

cat > "$name/icon.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="#8e44ad" rx="16"/>
  <path d="M64 24 L104 48 L104 88 L64 112 L24 88 L24 48 Z" fill="none" stroke="white" stroke-width="6"/>
  <path d="M64 24 L64 68 L24 48 M64 68 L104 48 M64 68 L64 112" stroke="white" stroke-width="4" fill="none"/>
</svg>
EOF

cat > "$name/scripts/$snake.gd" <<EOF
class_name $classname
extends RefCounted

## TODO: replace this with the mechanism the demo teaches.
##
## The maths lives here rather than in the driver, so the test suite can drive
## it headlessly — no scene, no camera, no frames. That separation is what makes
## the suites in this collection test the demo rather than a copy of it.

## How fast the motion runs, in cycles per second.
var speed := 1.5

## How far it travels either side of the origin, in metres.
var amplitude := 0.5

var _elapsed := 0.0

## Advance the mechanism by one frame.
func advance(delta: float) -> void:
	_elapsed += delta

## Where the thing should be, relative to its rest position.
func offset() -> Vector3:
	return Vector3(0.0, sin(_elapsed * speed * TAU) * amplitude, 0.0)

## Back to the start, without rebuilding the object.
func reset() -> void:
	_elapsed = 0.0

func elapsed() -> float:
	return _elapsed
EOF

cat > "$name/scripts/main.gd" <<EOF
extends Node3D

# Demo driver: owns the nodes, applies what the component works out, and shows
# the numbers on screen. Keep it thin — the lesson belongs in $snake.gd.

@onready var _box: MeshInstance3D = \$Box
@onready var _status: Label = \$HUD/StatusLabel
@onready var _hint: Label = \$HUD/TitleLabel

var _rest := Vector3.ZERO
var _mechanism := $classname.new()

func _ready() -> void:
	_hint.text = "$title — TODO: say what to look at"
	_rest = _box.position

func _process(delta: float) -> void:
	_mechanism.advance(delta)
	_box.position = _rest + _mechanism.offset()
	_status.text = "t %.2f    offset %.2f" % [_mechanism.elapsed(), _mechanism.offset().y]
EOF

cat > "$name/scenes/main.tscn" <<'EOF'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[sub_resource type="BoxMesh" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.866, 0.5, 0, -0.5, 0.866, 0, 3, 6)

; A hand-written 3D scene has no light unless you put one in it. The editor's
; preview light is not part of the scene, so without this the demo renders
; black everywhere except the editor — tools/check_docs.py fails on it.
[node name="Light" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.707, 0.707, 0, -0.707, 0.707, 0, 5, 0)

[node name="Box" type="MeshInstance3D" parent="."]
mesh = SubResource("1")

[node name="HUD" type="CanvasLayer" parent="."]

[node name="TitleLabel" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 12.0
offset_right = 784.0
offset_bottom = 36.0
theme_override_font_sizes/font_size = 18
text = "TODO: title"

[node name="StatusLabel" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 560.0
offset_right = 784.0
offset_bottom = 584.0
theme_override_font_sizes/font_size = 14
EOF

cat > "$name/tests/test.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/test_logic.gd" id="1"]

[node name="TestRunner" type="Node"]
script = ExtResource("1")
EOF

cat > "$name/tests/test_logic.gd" <<EOF
extends Node

# Drives the demo's real script from scripts/$snake.gd, not a copy of its
# logic. A suite that reimplements the mechanism stays green while the demo
# itself is broken — that is exactly how 63 demos in the 2D collection once
# passed their tests without running at all. See docs/TEST_INTEGRITY.md.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_it_starts_at_rest()
	test_it_moves_when_advanced()
	test_it_stays_within_amplitude()
	test_it_is_deterministic()
	test_amplitude_scales_the_motion()
	test_reset_returns_it_to_the_start()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# TODO: replace these with assertions about what your demo actually teaches.
# Six is the minimum tools/check_docs.py accepts, because a suite thinner than
# that is not really checking anything.

func test_it_starts_at_rest() -> void:
	print("at rest")
	var m := $classname.new()
	expect(m.offset() == Vector3.ZERO, "no offset before any time has passed")
	expect(m.elapsed() == 0.0, "and no time has passed")

func test_it_moves_when_advanced() -> void:
	print("advancing")
	var m := $classname.new()
	m.advance(0.1)
	expect(m.offset() != Vector3.ZERO, "advancing moves it off the rest position")

func test_it_stays_within_amplitude() -> void:
	print("bounds")
	var m := $classname.new()
	var worst := 0.0
	for i in 200:
		m.advance(1.0 / 60.0)
		worst = maxf(worst, absf(m.offset().y))
	expect(worst <= m.amplitude + 0.001, "it never travels past its amplitude")

func test_it_is_deterministic() -> void:
	print("determinism")
	var a := $classname.new()
	var b := $classname.new()
	for i in 10:
		a.advance(0.05)
		b.advance(0.05)
	expect(a.offset().is_equal_approx(b.offset()), "the same input gives the same result")

func test_amplitude_scales_the_motion() -> void:
	print("amplitude")
	var small := $classname.new()
	var large := $classname.new()
	large.amplitude = small.amplitude * 2.0
	small.advance(0.1)
	large.advance(0.1)
	expect(absf(large.offset().y) > absf(small.offset().y), "a larger amplitude travels further")

func test_reset_returns_it_to_the_start() -> void:
	print("reset")
	var m := $classname.new()
	m.advance(1.0)
	m.reset()
	expect(m.elapsed() == 0.0, "reset puts the clock back")
	expect(m.offset() == Vector3.ZERO, "and the offset with it")

func _report() -> void:
	var summary := "[$name] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)
EOF

cat > "$name/README.md" <<EOF
# $title

$desc

## Purpose

TODO: why this matters in a real game — the problem it solves, and what goes
wrong without it. Two or three sentences, not a restatement of the title.

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | TODO |

<!-- Godot's built-in \`ui_*\` actions are bound to the arrow keys only, and
     \`ui_accept\` is Enter/Space. Only claim the letter keys here if a script
     actually binds \`KEY_A\` / \`KEY_D\` / \`KEY_W\` / \`KEY_S\` — tools/check_docs.py
     enforces this. -->

## How It Works

TODO: the mechanism, in the order it happens.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| \`TODO\` | What it is for |

## Files

| File | What it holds |
|------|---------------|
| \`scripts/$snake.gd\` | The \`$classname\` component: TODO |
| \`scripts/main.gd\` | Demo driver: nodes, input, and the on-screen readout |
| \`scenes/main.tscn\` | The runnable scene |
| \`tests/test_logic.gd\` | Headless test suite |

## Use as a building block

**Copy:** \`scripts/$snake.gd\` — the \`$classname\` type. \`scripts/main.gd\` is the
demo driver and is not needed.

**Public API**
- TODO: the methods and exported properties an adopter calls.

**Notes**
- \`class_name $classname\` is global to the project — rename it if you already
  define that type.
- TODO: autoloads, input actions, or project settings an adopter needs.
EOF

# Give the README its tag line straight away, so the demo is not born failing a
# check. The tags are derived from the source, so this is the same command you
# rerun whenever the demo starts or stops using something.
tools/build_tags.py >/dev/null 2>&1 || true

echo "Created $name/"
echo
echo "Next:"
echo "  1. Build the mechanism in $name/scripts/$snake.gd"
echo "  2. Replace the placeholder assertions in $name/tests/test_logic.gd"
echo "  3. Fill in the TODOs in $name/README.md"
echo "  4. Add a row to the root README index under the right category,"
echo "     and bump the demo counts in the intro and the footer"
echo "  5. tools/build_tags.py && tools/build_index.py"
echo "  6. ./run-tests.sh $name && tools/check_docs.py"
