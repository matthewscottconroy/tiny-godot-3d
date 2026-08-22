#!/usr/bin/env bash
#
# Export demos to the web, for a playable gallery.
#
#   tools/export_web.sh                  # every demo
#   tools/export_web.sh orbit-camera     # one or more
#   OUT=build/web tools/export_web.sh    # where the builds go
#
# ---------------------------------------------------------------------------
# STATUS: this has NOT been run end to end. It needs Godot's web export
# templates (~1GB), which are not present in the environment it was written in.
# Treat it as a starting point to validate rather than a working pipeline.
#
# `tools/preflight.sh` says whether the templates are installed before you
# start, rather than the export failing per demo when they are not.
# ---------------------------------------------------------------------------
#
# Godot exports from a named preset in export_presets.cfg, and none of the demos
# have one — a near-identical file per demo would be noise. This generates the
# preset per demo, exports, then removes it again.
#
# multiplayer-3d is skipped: ENet is UDP, and a browser cannot open a raw
# socket. A web build of it would need WebSocketMultiplayerPeer or WebRTC, which
# is a different demo rather than an export flag. Add others to SKIP the same
# way — with the reason — and mirror them in tools/build_web_index.py so the
# gallery explains the absence rather than showing a dead link.
#
# Two things to expect from 3D in particular: the web target is WebGL2 via the
# Compatibility renderer, so a demo written for Forward+ may render differently
# or not at all, and mouse capture only works after a click in the page.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
OUT="${OUT:-build/web}"
SKIP_DEFAULT="multiplayer-3d"
SKIP="${SKIP:-$SKIP_DEFAULT}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "error: Godot not found. Set GODOT=/path/to/godot or add it to PATH." >&2
  exit 127
fi

# The export templates are a separate download from the editor.
if ! "$GODOT" --headless --version >/dev/null 2>&1; then
  echo "error: cannot run Godot" >&2
  exit 127
fi

demos=("$@")
if [ "${#demos[@]}" -eq 0 ]; then
  for d in */; do
    [ -f "${d}project.godot" ] && demos+=("${d%/}")
  done
fi

exported=0
skipped=0
failed=0
failed_demos=()

for demo in "${demos[@]}"; do
  demo="${demo%/}"
  [ -f "$demo/project.godot" ] || continue

  if [[ " $SKIP " == *" $demo "* ]]; then
    echo "SKIP  $demo (does not work unchanged in a browser — see the header)"
    skipped=$((skipped + 1))
    continue
  fi

  preset="$demo/export_presets.cfg"
  had_preset=0
  [ -f "$preset" ] && had_preset=1

  if [ "$had_preset" -eq 0 ]; then
    cat > "$preset" <<'PRESET'
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
export_path=""

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
PRESET
  fi

  mkdir -p "$OUT/$demo"
  if "$GODOT" --headless --path "$demo" --export-release "Web" \
      "../$OUT/$demo/index.html" >/dev/null 2>&1; then
    echo "OK    $demo"
    exported=$((exported + 1))
  else
    echo "FAIL  $demo (export failed — are the web export templates installed?)"
    failed=$((failed + 1)); failed_demos+=("$demo")
    rm -rf "${OUT:?}/$demo"
  fi

  [ "$had_preset" -eq 0 ] && rm -f "$preset"
done

echo
echo "======================================"
echo "  $exported exported, $skipped skipped, $failed failed"
if [ "$failed" -gt 0 ]; then
  printf '  failed: %s\n' "${failed_demos[*]}"
fi
echo "======================================"

[ "$failed" -eq 0 ]
