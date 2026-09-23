#!/usr/bin/env bash
#
# Export demos to the web, for a playable gallery.
#
#   tools/export_web.sh                  # every demo
#   tools/export_web.sh orbit-camera     # one or more
#   OUT=build/web tools/export_web.sh    # where the builds go
#
# ---------------------------------------------------------------------------
# Needs Godot's web export templates (~1GB), which are a separate download from
# the editor. `tools/preflight.sh` says whether they are installed before you
# start, rather than the export failing per demo when they are not.
# ---------------------------------------------------------------------------
#
# THE ENGINE IS SHARED. Godot emits a complete runtime beside every export —
# a 37.7MB `index.wasm` plus its loader — and it is byte-identical for every
# demo, because it is the same engine build. Exported naively that is 58 copies
# of the same 37.7MB: 2.2GB, against a GitHub Pages limit of 1GB, so the gallery
# could not deploy at all.
#
# So the runtime is lifted into `_engine/` once and every demo points at it. The
# loader supports exactly this: `executable` gives the base path it derives the
# wasm and audio worklets from, and `mainPack` names the pack separately, so a
# demo directory needs to hold nothing but its own ~15KB of content.
#
#   _engine/index.wasm     37.7MB, once
#   <demo>/index.pck       ~15KB each
#
# That is ~39MB for the whole gallery rather than 2.2GB.
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

# mem_capture: bounded, timed output capture, so a chatty or hung export
# cannot grow this shell without limit. See tools/memguard.sh.
source "$(dirname "$0")/memguard.sh"

GODOT="${GODOT:-godot}"
# Godot exports with --path <demo>, so a relative output has to be reached from
# inside the demo directory. Resolving it to an absolute path up front means
# OUT= can be either, instead of silently producing "../<abs path>" and an
# export failure blamed on the templates.
OUT="${OUT:-build/web}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
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

# Files the engine emits identically for every demo. The icons are per-demo in
# principle — each project has its own icon.svg — so they stay put.
ENGINE_FILES="index.wasm index.js index.audio.worklet.js index.audio.position.worklet.js"

## Move a demo's copy of the runtime into _engine/, and point the demo at it.
##
## The first demo populates _engine/; every one after it checks its own copy is
## identical and then deletes it. The check matters: a runtime that differed
## between demos would mean the shared copy is wrong for all but one of them,
## and the failure would be a demo that loads and then behaves oddly.
share_engine() {
  local demo=$1
  local dir="$OUT/$demo" engine="$OUT/_engine"
  mkdir -p "$engine"

  local f
  for f in $ENGINE_FILES; do
    [ -f "$dir/$f" ] || continue
    if [ ! -f "$engine/$f" ]; then
      mv "$dir/$f" "$engine/$f"
    elif cmp -s "$dir/$f" "$engine/$f"; then
      rm -f "$dir/$f"
    else
      echo "FAIL  $demo ($f differs from the shared runtime — engine builds do not match)" >&2
      return 1
    fi
  done

  # Repoint the loader. `executable` is the base path the wasm and the audio
  # worklets are derived from; `mainPack` is the pack, which stays local. Both
  # are documented loader options, not a trick.
  local wasm_size
  wasm_size="$(stat -c%s "$engine/index.wasm" 2>/dev/null || echo 0)"
  python3 - "$dir/index.html" "$wasm_size" <<'REWRITE'
import io, re, sys
path, wasm_size = sys.argv[1], sys.argv[2]
html = io.open(path, encoding="utf-8").read()
html = html.replace('<script src="index.js"></script>',
                    '<script src="../_engine/index.js"></script>')
html = html.replace('"executable":"index"',
                    '"executable":"../_engine/index","mainPack":"index.pck"')
# fileSizes drives the progress bar, and the loader looks each entry up by the
# URL it actually fetches — so the wasm key has to move with the wasm.
html = html.replace('"index.wasm":', '"../_engine/index.wasm":')
html = re.sub(r'("\.\./_engine/index\.wasm":)\d+', r'\g<1>' + wasm_size, html)
io.open(path, "w", encoding="utf-8").write(html)
REWRITE
  return 0
}

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
  export_log="$(mem_capture "$GODOT" --headless --path "$demo" \
      --export-release "Web" "$OUT/$demo/index.html")"
  if [ $? -eq 0 ] && [ -f "$OUT/$demo/index.html" ]; then
    share_engine "$demo" || { failed=$((failed + 1)); failed_demos+=("$demo"); continue; }
    echo "OK    $demo"
    exported=$((exported + 1))
  else
    # The real reason, rather than a guess about templates. A missing template
    # is only one of the ways this fails, and blaming it sends you to reinstall
    # a 1GB download when the actual problem was a path or a bad preset.
    echo "FAIL  $demo"
    printf '%s\n' "$export_log" | grep -E "ERROR|error:|Cannot|No export template" \
      | head -3 | sed 's/^/      | /'
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
