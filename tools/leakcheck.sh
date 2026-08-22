#!/usr/bin/env bash
#
# Find demos that leak memory.
#
#   tools/leakcheck.sh                 # every demo
#   tools/leakcheck.sh orbit-camera    # one or more
#   VERBOSE=1 tools/leakcheck.sh <demo>  # show what leaked
#
# Godot reports unfreed objects when it shuts down. Those messages are easy to
# miss in normal output — they arrive after the demo has finished and nothing
# fails — so this surfaces them deliberately.
#
# The usual cause in GDScript is a reference cycle between RefCounted objects.
# RefCounted is reference-counted, not garbage-collected, so a parent holding
# its children while each child holds its parent will never reach zero and never
# free. The 2D collection's state-machine-hfsm had exactly that: each state kept
# a strong `parent`, so the whole state tree leaked on every run. The fix was a
# WeakRef for the upward link. A 3D scene graph makes the same shape easy to
# write — a rig that holds its target while the target holds the rig.
#
# Runs strictly one demo at a time. Each Godot process peaks around 110MB, and
# this is a diagnostic rather than something to finish quickly.

set -uo pipefail
cd "$(dirname "$0")/.."

# Memory safeguards. This one is already serial, so the guards that matter here
# are the pre-flight refusal, the live floor between demos, and child reaping.
source "$(dirname "$0")/memguard.sh"

GODOT="${GODOT:-godot}"
VERBOSE="${VERBOSE:-0}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "error: Godot not found. Set GODOT=/path/to/godot or add it to PATH." >&2
  exit 127
fi

# What Godot prints at shutdown when something was not freed. --verbose is
# required: without it Godot prints only a summary count, and not even that for
# some cases, so a non-verbose scan silently under-reports.
LEAK_RE='ObjectDB instances were leaked|resources still in use at exit|orphaned lambdas|Leaked instance'

# Demos whose reported leak is Godot's own, not theirs. Each entry has to be
# confirmed by reproducing the same report in a minimal scene containing none of
# the demo's code — see docs/MEMORY.md. Without that evidence an entry here is
# just a check being switched off.
declare -A ENGINE_SIDE=(
  [audio-3d]="AudioStreamPlayer3D with a generated WAV: 2 instances, reproduced in a 12-line scene, 3 runs of 3, and unaffected by stopping the player first"
  [audio-buses]="the same AudioStreamPlayer shutdown report as audio-3d, same evidence"
)

run_once() {
  mem_run_godot "$GODOT" --headless --path "$1" "$2" --quit-after 60 --verbose 2>&1 \
    | grep -E "$LEAK_RE"
}

demos=("$@")
if [ "${#demos[@]}" -eq 0 ]; then
  for d in */; do
    [ -f "${d}project.godot" ] && demos+=("${d%/}")
  done
fi

mem_guard_preflight || exit 3
mem_guard_install_trap

clean=0
leaking=0
leaking_demos=()
aborted=0

for demo in "${demos[@]}"; do
  # Between demos, not mid-demo: a scan of the whole collection is long enough that
  # memory pressure can arrive partway, and stopping cleanly beats being killed.
  if ! mem_guard_ok; then
    aborted=1
    break
  fi

  demo="${demo%/}"
  [ -f "$demo/project.godot" ] || continue
  scene="$(sed -n 's/^run\/main_scene="\(.*\)"$/\1/p' "$demo/project.godot")"
  [ -z "$scene" ] && continue

  # --verbose is what makes Godot name the leaked instances rather than just
  # counting them.
  out="$(run_once "$demo" "$scene")"

  # Audio shutdown is racy: in the 2D collection one music demo reported a leak
  # in roughly one run in six and nothing the other five times. A one-shot check
  # would cry wolf at that rate, so a hit has to reproduce before it counts.
  if [ -n "$out" ]; then
    confirm="$(run_once "$demo" "$scene")"
    if [ -z "$confirm" ]; then
      [ "$VERBOSE" = "1" ] && echo "flaky $demo (reported once, did not reproduce — ignored)"
      clean=$((clean + 1))
      continue
    fi
  fi

  if [ -n "$out" ] && [ -n "${ENGINE_SIDE[$demo]:-}" ]; then
    echo "known $demo (engine-side: ${ENGINE_SIDE[$demo]})"
    clean=$((clean + 1))
  elif [ -n "$out" ]; then
    echo "LEAK  $demo"
    printf '%s\n' "$out" | sed 's/^/        /' | sort -u | head -6
    leaking=$((leaking + 1))
    leaking_demos+=("$demo")
  else
    [ "$VERBOSE" = "1" ] && echo "ok    $demo"
    clean=$((clean + 1))
  fi
done

echo
echo "======================================"
echo "  $clean clean, $leaking leaking"
[ "$aborted" -eq 1 ] && echo "  ABORTED early on low memory — this is a partial result"
if [ "$leaking" -gt 0 ]; then
  printf '  leaking: %s\n' "${leaking_demos[*]}"
  echo
  echo "  Most GDScript leaks are RefCounted reference cycles: A holds B and B"
  echo "  holds A, so neither count reaches zero. Make the back-reference a"
  echo "  WeakRef, or break the cycle explicitly on teardown."
fi
echo "======================================"

[ "$leaking" -eq 0 ]
