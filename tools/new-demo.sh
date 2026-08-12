#!/usr/bin/env bash
#
# Scaffold a new 3D demo with the structure the collection uses.
#
#   tools/new-demo.sh my-demo "One-line description for the index"

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
[ -e "$name" ] && { echo "error: '$name' already exists" >&2; exit 2; }

title="$(echo "$name" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
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

cat > "$name/scripts/main.gd" <<'EOF'
extends Node3D

# TODO: replace this with the demo.

@onready var _label: Label = $HUD/StatusLabel

var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	_label.text = "Running for %.1fs" % _elapsed
EOF

cat > "$name/scenes/main.tscn" <<'EOF'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[sub_resource type="BoxMesh" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.866, 0.5, 0, -0.5, 0.866, 0, 3, 6)

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

# Drive the demo's real scripts here, not a copy of their logic.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_placeholder()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func test_placeholder() -> void:
	print("placeholder")
	expect(true, "the suite runs")

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

TODO: why this matters in a real game.

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | TODO |

## How It Works

TODO.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| \`TODO\` | What it is for |

## Files

| File | What it holds |
|------|---------------|
| \`scripts/main.gd\` | TODO |
| \`scenes/main.tscn\` | The runnable scene |
| \`tests/test_logic.gd\` | Headless test suite |

## Use as a building block

**Copy:** TODO.

**Notes**
- TODO.
EOF

echo "Created $name/"
