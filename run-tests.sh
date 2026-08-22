#!/usr/bin/env bash
#
# Run the checks for every demo (or the demos named as arguments).
#
#   ./run-tests.sh                 # check all demos
#   ./run-tests.sh orbit-camera    # check one or more specific demos
#   GODOT=/path/to/godot ./run-tests.sh
#   JOBS=4 ./run-tests.sh          # limit concurrency (see the default below)
#   ./run-tests.sh --smoke-only    # skip the logic suites
#   ./run-tests.sh --tests-only    # skip the smoke check
#   ./run-tests.sh --reimport      # force a re-import even if nothing changed
#
# Each demo gets two checks:
#
#   1. Smoke — actually boot the demo's main scene headless for a few frames and
#      fail on any script/scene error. The logic suites below construct their own
#      objects, so without this a demo whose scripts do not even parse can still
#      report a green suite. This is the check that covers the real scenes.
#
#   2. Logic — tests/test.tscn runs tests/test_logic.gd, which prints a
#      "[demo] N/M passed" summary line. A demo fails if N != M, if that line is
#      missing, or if Godot exits non-zero.
#
# Demos are independent projects, so both checks run concurrently across them.

set -uo pipefail
cd "$(dirname "$0")"

# Memory safeguards: bounded concurrency, a pre-flight refusal, a live floor,
# and child reaping on interrupt. See tools/memguard.sh and docs/MEMORY.md.
source "$(dirname "$0")/tools/memguard.sh"

GODOT="${GODOT:-godot}"

# Any of these in the output means the demo is broken, even when Godot exits 0.
ERROR_RE='Parse Error|SCRIPT ERROR|SHADER ERROR|Failed to load|Failed to instantiate|^ERROR: '

# Errors that abandon the function they happen in, which is the dangerous kind
# inside a test: the assertions after them never run, the suite prints a
# smaller n/n passed, and the counts still agree. Deliberately narrower than
# ERROR_RE — a suite that drives a script outside its scene logs "Node not
# found" for each @onready, which is noise rather than a failure.
SUITE_ABORT_RE='previously freed|Invalid access to (property|index)|Nonexistent function|Invalid type in function|Invalid index|[Oo]ut of bounds|null (instance|value)|Division By Zero|Invalid assignment|Trying to assign value of type|Invalid call'

# Warnings count too. Godot reports a refused operation as a warning rather
# than an error, so a feature can silently do nothing and still pass every
# other gate: in the 2D collection a demo set a SubViewport size its container
# owned, and both of its modes rendered identically for as long as it existed.
# 3D has more of these than 2D — an unsupported shadow mode, a mesh with no
# surface, a viewport with no camera all warn and then carry on.
WARN_RE='^WARNING: '

# Except the ones we have already chased down and cannot fix from here — the
# audio-shutdown leaks documented in docs/MEMORY.md.
WARN_ALLOW='ObjectDB instance.*leaked at exit'

# ---------------------------------------------------------------------------
# Worker modes. The script re-invokes itself through xargs to get concurrency;
# each worker handles one demo and writes its result to $RESULT_DIR/<demo>.
# ---------------------------------------------------------------------------

# Godot resolves class_name globals and imported assets from .godot/, which a
# fresh clone does not have. Re-importing when nothing changed costs ~1.7s per
# demo and does nothing, so only import when the cache is missing or stale.
needs_import() {
  local demo=$1
  local marker="$demo/.godot/global_script_class_cache.cfg"
  [ -f "$marker" ] || return 0
  [ -n "$(find "$demo" -path "$demo/.godot" -prune -o -type f -newer "$marker" -print -quit)" ]
}

do_import() {
  local demo=$1
  if [ "$FORCE_IMPORT" -eq 1 ] || needs_import "$demo"; then
    mem_run_godot "$GODOT" --headless --path "$demo" --import --quit >/dev/null 2>&1 || true
  fi
}

do_check() {
  local demo=$1
  local out="$RESULT_DIR/$demo"
  local failed=0 summary="" detail=""

  # --- 1. Smoke: boot the real main scene ---
  if [ "$RUN_SMOKE" -eq 1 ]; then
    local main_scene
    main_scene="$(sed -n 's/^run\/main_scene="\(.*\)"$/\1/p' "$demo/project.godot")"
    if [ -z "$main_scene" ]; then
      detail="smoke: project.godot has no run/main_scene"
      failed=1
    else
      local smoke_out smoke_status smoke_errors
      smoke_out="$(mem_capture mem_run_godot "$GODOT" --headless --path "$demo" "$main_scene" --quit-after 90)"
      smoke_status=$?
      smoke_errors="$(printf '%s\n' "$smoke_out" | grep -E "$ERROR_RE")"
      local smoke_warnings
      smoke_warnings="$(printf '%s\n' "$smoke_out" | grep -E "$WARN_RE" | grep -Ev "$WARN_ALLOW")"
      if [ "$smoke_status" -ne 0 ] || [ -n "$smoke_errors" ] || [ -n "$smoke_warnings" ]; then
        detail="smoke: $main_scene, exit $smoke_status"$'\n'"$(printf '%s\n' "$smoke_errors$smoke_warnings" | grep -v '^$' | sed 's/^/      | /')"
        failed=1
      fi
    fi
  fi

  # --- 2. Logic: headless test suite ---
  if [ "$RUN_LOGIC" -eq 1 ] && [ "$failed" -eq 0 ]; then
    if [ ! -f "$demo/tests/test.tscn" ]; then
      detail="no tests/test.tscn"
      failed=1
    else
      # --quit-after (a few frames) rather than --quit (one frame): a suite that
      # needs a physics step — direct_space_state is only valid inside
      # _physics_process — would otherwise never run. Suites that finish in
      # _ready are unaffected.
      #
      # A demo that has to watch a body move over time needs more than a few
      # frames, so it can ask for them in tests/frames. Everyone else keeps the
      # cheap default: the budget is paid on every run, including every mutant.
      local output status n m frames
      frames="$(test -f "$demo/tests/frames" && tr -cd '0-9' < "$demo/tests/frames")"
      output="$(mem_capture mem_run_godot "$GODOT" --headless --path "$demo" res://tests/test.tscn --quit-after "${frames:-5}")"
      status=$?
      summary="$(printf '%s\n' "$output" | grep -oE '[0-9]+/[0-9]+ passed' | tail -1)"
      n="${summary%%/*}"
      m="${summary#*/}"; m="${m%% passed}"
      # A runtime error abandons the function it happened in, so the
      # assertions after it never run: the suite prints a smaller n/n passed
      # and the counts still agree. Four suites were quietly skipping the tail
      # of a test this way before the check existed.
      local suite_errors
      suite_errors="$(printf '%s\n' "$output" | grep -E "$SUITE_ABORT_RE")"
      if [ "$status" -ne 0 ] || [ -z "$summary" ] || [ "$n" != "$m" ] || [ -n "$suite_errors" ]; then
        detail="tests: ${summary:-no summary}, exit $status"$'\n'"$(printf '%s\n' "$output" | sed 's/^/      | /')"
        failed=1
      fi
    fi
  fi

  if [ "$failed" -eq 0 ]; then
    printf 'PASS\t%s\n' "$summary" > "$out"
  else
    printf 'FAIL\t%s\n%s\n' "$summary" "$detail" > "$out"
  fi
}

# Dispatch for the xargs-spawned children.
if [ "${1:-}" = "--worker-import" ]; then
  shift; do_import "$1"; exit 0
fi
if [ "${1:-}" = "--worker-check" ]; then
  shift; do_check "$1"; exit 0
fi

# ---------------------------------------------------------------------------
# Parent: parse args, fan out, aggregate.
# ---------------------------------------------------------------------------

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "error: Godot not found. Set GODOT=/path/to/godot or add it to PATH." >&2
  exit 127
fi

RUN_SMOKE=1
RUN_LOGIC=1
FORCE_IMPORT=0
demos=()
for arg in "$@"; do
  case "$arg" in
    --smoke-only) RUN_LOGIC=0 ;;
    --tests-only) RUN_SMOKE=0 ;;
    --reimport)   FORCE_IMPORT=1 ;;
    -*) echo "error: unknown option $arg" >&2; exit 2 ;;
    *)  demos+=("${arg%/}") ;;
  esac
done

# Default to every demo in the repo.
if [ "${#demos[@]}" -eq 0 ]; then
  for d in */; do
    [ -f "${d}project.godot" ] && demos+=("${d%/}")
  done
fi

# Drop anything without a project, reporting it once.
valid=()
for demo in "${demos[@]}"; do
  if [ -f "$demo/project.godot" ]; then
    valid+=("$demo")
  else
    echo "SKIP  $demo (no project.godot)"
  fi
done
demos=("${valid[@]}")
[ "${#demos[@]}" -eq 0 ] && { echo "nothing to check"; exit 0; }

# Concurrency comes from tools/memguard.sh: bounded by free memory as well as
# cores, halved again if someone else is already running Godot, capped at 8.
JOBS="${JOBS:-$(mem_safe_jobs)}"
[ "$JOBS" -gt "${#demos[@]}" ] && JOBS="${#demos[@]}"

# Refuse to start on a machine that is already short of memory.
mem_guard_preflight || exit 3

RESULT_DIR="$(mktemp -d)"
mem_guard_install_trap
trap 'mem_reap_children; rm -rf "$RESULT_DIR"' EXIT
export GODOT ERROR_RE RUN_SMOKE RUN_LOGIC FORCE_IMPORT RESULT_DIR

echo "Checking ${#demos[@]} demo(s) with $JOBS parallel job(s)…"
echo "  (each job is a Godot process; set JOBS= to change)"

# Import first (demos that need it), then check. Both fan out; the import phase
# is a barrier because the checks below depend on its output.
printf '%s\n' "${demos[@]}" | xargs -P "$JOBS" -I{} "$0" --worker-import {}
mem_guard_ok || exit 4

# Chunked rather than one xargs over everything, so the memory floor is
# re-checked as the run proceeds and an abort can happen partway instead of only
# at the end.
chunk=$(( JOBS * 4 ))
total="${#demos[@]}"
offset=0
while [ "$offset" -lt "$total" ]; do
  printf '%s\n' "${demos[@]:$offset:$chunk}" | xargs -P "$JOBS" -I{} "$0" --worker-check {}
  offset=$(( offset + chunk ))
  mem_guard_ok || { echo "  (checked $offset of $total before aborting)" >&2; break; }
done

pass=0
fail=0
failed_demos=()
for demo in "${demos[@]}"; do
  result="$RESULT_DIR/$demo"
  if [ ! -f "$result" ]; then
    echo "FAIL  $demo (no result — the worker died)"
    fail=$((fail + 1)); failed_demos+=("$demo"); continue
  fi
  status="$(head -1 "$result" | cut -f1)"
  summary="$(head -1 "$result" | cut -f2)"
  if [ "$status" = "PASS" ]; then
    echo "PASS  $demo${summary:+ ($summary)}"
    pass=$((pass + 1))
  else
    echo "FAIL  $demo ($(sed -n '2p' "$result"))"
    tail -n +3 "$result"
    fail=$((fail + 1))
    failed_demos+=("$demo")
  fi
done

echo
echo "======================================"
echo "  $pass passed, $fail failed, $((pass + fail)) total"
if [ "$fail" -gt 0 ]; then
  printf '  failed: %s\n' "${failed_demos[*]}"
fi
echo "======================================"

[ "$fail" -eq 0 ]
