#!/usr/bin/env bash
#
# Capture one screenshot per demo.
#
#   tools/screenshots.sh                 # every demo
#   tools/screenshots.sh orbit-camera    # one or more
#   OUT=docs/img tools/screenshots.sh    # where the PNGs go (default: docs/img)
#
# ---------------------------------------------------------------------------
# REQUIRES A DISPLAY. Godot's --headless mode uses a dummy rendering driver:
# there is no framebuffer, so get_viewport().get_texture().get_image() returns
# null and nothing can be captured. This script therefore runs Godot under
# xvfb-run, a virtual X server.
#
#   Debian/Ubuntu:  sudo apt-get install xvfb
#   Fedora:         sudo dnf install xorg-x11-server-Xvfb
#
# If xvfb is missing the script says so and exits rather than producing blank
# images. `tools/preflight.sh` reports the same thing without starting a
# capture, which is the cheaper way to find out.
# ---------------------------------------------------------------------------
#
# Capture uses Godot's Movie Maker mode (--write-movie) rather than a script
# injected into each demo, so no demo needs to know it is being screenshotted.
# Movie Maker writes a numbered PNG per frame; we keep one from partway in — by
# then a demo has drawn its first real frame, and anything that animates on
# entry has settled.
#
# MOTION=1 additionally writes a short looping animation. Much of this collection
# IS motion, and 3D adds a second reason to want it: a still frame flattens the
# scene, so depth, parallax and camera behaviour — the subject of several demos —
# barely survive the capture.
# Needs ffmpeg; without it the still is still produced and the animation skipped.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
OUT="${OUT:-docs/img}"
# Which frame to keep. Early enough to be quick, late enough that _ready() work,
# procedural generation, and intro tweens have all happened.
FRAME="${FRAME:-45}"
# With MOTION, keep capturing past the still so there is a loop to assemble.
MOTION="${MOTION:-0}"
MOTION_FRAMES="${MOTION_FRAMES:-120}"
if [ "$MOTION" = "1" ]; then
  TOTAL_FRAMES=$((FRAME + MOTION_FRAMES))
else
  TOTAL_FRAMES=$((FRAME + 5))
fi

have_ffmpeg=1
if [ "$MOTION" = "1" ] && ! command -v ffmpeg >/dev/null 2>&1; then
  echo "note: ffmpeg not found — capturing stills only, skipping animations" >&2
  have_ffmpeg=0
fi

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "error: Godot not found. Set GODOT=/path/to/godot or add it to PATH." >&2
  exit 127
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
  cat >&2 <<'MSG'
error: xvfb-run not found.

Screenshots need a real framebuffer. Godot's --headless renderer is a dummy
driver that cannot produce an image, so this script runs Godot under a virtual
X server instead.

  Debian/Ubuntu:  sudo apt-get install xvfb
  Fedora:         sudo dnf install xorg-x11-server-Xvfb
MSG
  exit 127
fi

demos=("$@")
if [ "${#demos[@]}" -eq 0 ]; then
  for d in */; do
    [ -f "${d}project.godot" ] && demos+=("${d%/}")
  done
fi

mkdir -p "$OUT"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

captured=0
failed=0
failed_demos=()

for demo in "${demos[@]}"; do
  demo="${demo%/}"
  [ -f "$demo/project.godot" ] || { echo "SKIP  $demo (no project.godot)"; continue; }

  scene="$(sed -n 's/^run\/main_scene="\(.*\)"$/\1/p' "$demo/project.godot")"
  if [ -z "$scene" ]; then
    echo "FAIL  $demo (no run/main_scene)"
    failed=$((failed + 1)); failed_demos+=("$demo"); continue
  fi

  frames="$work/$demo"
  mkdir -p "$frames"

  # Movie Maker forces a fixed frame rate and writes one PNG per frame, so the
  # capture is deterministic regardless of how fast the machine is.
  xvfb-run -a "$GODOT" --path "$demo" "$scene" \
      --write-movie "$frames/frame.png" \
      --fixed-fps 60 --quit-after "$TOTAL_FRAMES" >/dev/null 2>&1

  # Movie Maker numbers frames; take the newest one at or before FRAME.
  shot="$(ls "$frames"/*.png 2>/dev/null | sort | sed -n "${FRAME}p")"
  [ -z "$shot" ] && shot="$(ls "$frames"/*.png 2>/dev/null | sort | tail -1)"

  if [ -z "$shot" ] || [ ! -s "$shot" ]; then
    echo "FAIL  $demo (no frames written)"
    failed=$((failed + 1)); failed_demos+=("$demo"); continue
  fi

  cp "$shot" "$OUT/$demo.png"

  # Assemble the frames after the still into a small looping WebP. WebP rather
  # than GIF: far smaller at this frame count, and every browser renders it.
  if [ "$MOTION" = "1" ] && [ "$have_ffmpeg" -eq 1 ]; then
    ffmpeg -y -loglevel error -framerate 30 \
        -start_number "$FRAME" -i "$frames/frame%08d.png" \
        -frames:v "$MOTION_FRAMES" -loop 0 -q:v 60 -vf "scale=480:-1" \
        "$OUT/$demo.webp" 2>/dev/null || echo "      (animation failed for $demo)"
  fi

  echo "OK    $demo -> $OUT/$demo.png"
  captured=$((captured + 1))
done

echo
echo "======================================"
echo "  $captured captured, $failed failed"
if [ "$failed" -gt 0 ]; then
  printf '  failed: %s\n' "${failed_demos[*]}"
fi
echo "======================================"

[ "$failed" -eq 0 ]
