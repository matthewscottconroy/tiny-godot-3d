#!/usr/bin/env bash
#
# Report which of the repository's pipelines can run here, and why not.
#
#   tools/preflight.sh          # check everything
#   tools/preflight.sh --quiet  # exit status only
#
# The test suite and the doc checks run anywhere Godot does. The screenshot and
# web-export pipelines need things the editor does not bring with it — a
# display server and a ~1GB template download — and both were written in an
# environment that had neither. Rather than discovering that partway through a
# capture, ask first.
#
# Exit status is 0 when everything is available, 1 when something is missing.
# A missing optional pipeline is reported but does not fail the run unless
# --strict is given.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
QUIET=0
STRICT=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --strict) STRICT=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

missing_required=0
missing_optional=0

say() {
  [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"
}

report() {
  # report <state> <name> <detail>
  local state="$1" name="$2" detail="$3"
  case "$state" in
    ok)      say "  ready      $name — $detail" ;;
    missing) say "  missing    $name — $detail" ;;
  esac
}

say "Pipelines"
say ""

# --- Godot itself: everything else depends on it ----------------------------
if command -v "$GODOT" >/dev/null 2>&1; then
  version="$("$GODOT" --version 2>/dev/null | head -1)"
  report ok "godot" "${version:-found}"
else
  report missing "godot" "not on PATH; set GODOT=/path/to/godot"
  missing_required=1
fi

# --- Tests and doc checks ---------------------------------------------------
if [ "$missing_required" -eq 0 ]; then
  report ok "tests" "./run-tests.sh — headless, no display needed"
  report ok "doc checks" "tools/check_docs.py, build_index.py, build_tags.py"
fi

# --- Screenshots: need a virtual display ------------------------------------
if command -v xvfb-run >/dev/null 2>&1; then
  report ok "screenshots" "tools/screenshots.sh — xvfb-run available"
else
  report missing "screenshots" "xvfb-run not found (apt: xvfb, dnf: xorg-x11-server-Xvfb)"
  missing_optional=1
fi

if command -v ffmpeg >/dev/null 2>&1; then
  report ok "screenshot motion" "MOTION=1 loops — ffmpeg available"
else
  report missing "screenshot motion" "ffmpeg not found; stills would still work"
  missing_optional=1
fi

# --- Web export: needs the templates, which are a separate ~1GB download -----
templates_dir="${HOME}/.local/share/godot/export_templates"
if [ -d "$templates_dir" ] && [ -n "$(ls -A "$templates_dir" 2>/dev/null)" ]; then
  report ok "web export" "tools/export_web.sh — templates in $templates_dir"
else
  report missing "web export" "no export templates in $templates_dir (Editor → Manage Export Templates)"
  missing_optional=1
fi

# --- The gallery is only meaningful once screenshots exist ------------------
shots="$(ls docs/img/*.png 2>/dev/null | wc -l)"
if [ "$shots" -gt 0 ]; then
  report ok "gallery" "tools/build_gallery.py — $shots screenshots captured"
else
  report missing "gallery" "no screenshots in docs/img yet; run tools/screenshots.sh first"
  missing_optional=1
fi

say ""
if [ "$missing_required" -ne 0 ]; then
  say "Godot is missing, so nothing here can run."
  exit 1
fi

if [ "$missing_optional" -eq 0 ]; then
  say "Everything is available."
  exit 0
fi

say "The tests and doc checks can run. The pipelines marked missing cannot,"
say "and will say the same thing if you start them."
[ "$STRICT" -eq 1 ] && exit 1
exit 0
