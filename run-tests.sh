#!/usr/bin/env bash
#
# Run the checks for every demo (or the demos named as arguments).
#
#   ./run-tests.sh                 # check all demos
#   ./run-tests.sh state-machine   # check one or more specific demos
#   GODOT=/path/to/godot ./run-tests.sh
#   JOBS=4 ./run-tests.sh          # limit concurrency (default: CPU count)
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

GODOT="${GODOT:-godot}"

# Any of these in the output means the demo is broken, even when Godot exits 0.
ERROR_RE='Parse Error|SCRIPT ERROR|SHADER ERROR|Failed to load|Failed to instantiate|^ERROR: '

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
    "$GODOT" --headless --path "$demo" --import --quit >/dev/null 2>&1 || true
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
      smoke_out="$("$GODOT" --headless --path "$demo" "$main_scene" --quit-after 90 2>&1)"
      smoke_status=$?
      smoke_errors="$(printf '%s\n' "$smoke_out" | grep -E "$ERROR_RE")"
      if [ "$smoke_status" -ne 0 ] || [ -n "$smoke_errors" ]; then
        detail="smoke: $main_scene, exit $smoke_status"$'\n'"$(printf '%s\n' "$smoke_errors" | sed 's/^/      | /')"
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
      local output status n m
      output="$("$GODOT" --headless --path "$demo" res://tests/test.tscn --quit-after 5 2>&1)"
      status=$?
      summary="$(printf '%s\n' "$output" | grep -oE '[0-9]+/[0-9]+ passed' | tail -1)"
      n="${summary%%/*}"
      m="${summary#*/}"; m="${m%% passed}"
      if [ "$status" -ne 0 ] || [ -z "$summary" ] || [ "$n" != "$m" ]; then
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

JOBS="${JOBS:-$( (command -v nproc >/dev/null && nproc) || echo 4 )}"
[ "$JOBS" -gt "${#demos[@]}" ] && JOBS="${#demos[@]}"

RESULT_DIR="$(mktemp -d)"
trap 'rm -rf "$RESULT_DIR"' EXIT
export GODOT ERROR_RE RUN_SMOKE RUN_LOGIC FORCE_IMPORT RESULT_DIR

echo "Checking ${#demos[@]} demo(s) with $JOBS parallel job(s)…"

# Import first (demos that need it), then check. Both fan out; the import phase
# is a barrier because the checks below depend on its output.
printf '%s\n' "${demos[@]}" | xargs -P "$JOBS" -I{} "$0" --worker-import {}
printf '%s\n' "${demos[@]}" | xargs -P "$JOBS" -I{} "$0" --worker-check {}

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
