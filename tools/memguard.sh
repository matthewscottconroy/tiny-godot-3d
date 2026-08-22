#!/usr/bin/env bash
#
# Shared memory safeguards for the tools that spawn Godot.
#
# Source this, do not run it:
#
#   source "$(dirname "$0")/memguard.sh"
#
# Why this exists: every tool here spawns Godot processes, and several of them
# spawn many at once. Godot peaks around 110MB resident per process, which is
# modest alone and is not modest multiplied by a core count. On a machine that
# is already busy — several editors, other agents, a browser — a run that scales
# purely on cores can push the box into swap or OOM. That happened repeatedly
# before these guards existed.
#
# Four separate protections, because any one of them alone leaves a hole:
#
#   1. Pre-flight    refuse to start when memory is already low
#   2. Bounded jobs  concurrency derived from free memory, not just cores
#   3. Live floor    abort mid-run if memory drops below a floor
#   4. Reaping       kill our own children on exit, interrupt, or abort
#
# Every threshold can be overridden by environment variable, because the right
# number depends on what else is running.

# Memory one Godot process is assumed to need. Measured peak RSS is ~107MB;
# 160 leaves headroom for a heavier demo without being wasteful.
MEM_PER_JOB_MB="${MEM_PER_JOB_MB:-160}"

# Never start if less than this is available.
MEM_MIN_START_MB="${MEM_MIN_START_MB:-2048}"

# Abort a run in progress if available memory falls below this.
MEM_FLOOR_MB="${MEM_FLOOR_MB:-1024}"

# Absolute ceiling on concurrent Godot processes, whatever the maths says.
MEM_MAX_JOBS="${MEM_MAX_JOBS:-8}"

# Per-process address-space cap, in MB. A runaway allocation gets the process
# killed rather than the machine. Generous, because Godot maps far more virtual
# address space than it commits — too tight a value breaks normal operation.
MEM_ULIMIT_MB="${MEM_ULIMIT_MB:-4096}"

mem_available_mb() {
	if [ -r /proc/meminfo ]; then
		awk '/^MemAvailable:/ {print int($2 / 1024); found=1} END {if (!found) print 99999}' /proc/meminfo
	else
		echo 99999          # unknown platform: do not block the user
	fi
}

# Godot processes already running that we did not start. Their memory is already
# accounted for in MemAvailable, but a high count means someone else is working
# and we should tread lightly.
mem_foreign_godot_count() {
	local total ours
	total="$(pgrep -x godot 2>/dev/null | wc -l)"
	ours="$(pgrep -x godot -P $$ 2>/dev/null | wc -l)"
	echo $(( total - ours < 0 ? 0 : total - ours ))
}

## Refuse to start when the machine is already under pressure.
mem_guard_preflight() {
	local avail foreign
	avail="$(mem_available_mb)"
	if [ "$avail" -lt "$MEM_MIN_START_MB" ]; then
		cat >&2 <<-MSG
		error: only ${avail}MB of memory available, need at least ${MEM_MIN_START_MB}MB.

		This tool spawns Godot processes (~${MEM_PER_JOB_MB}MB each) and refuses to
		start when that would risk exhausting memory. Close something, or lower
		the bar deliberately:

		  MEM_MIN_START_MB=512 JOBS=1 $0 ...
		MSG
		return 1
	fi

	foreign="$(mem_foreign_godot_count)"
	if [ "$foreign" -gt 0 ]; then
		echo "note: ${foreign} Godot process(es) already running — reducing concurrency" >&2
	fi
	return 0
}

## Concurrency that fits in memory. Never exceeds MEM_MAX_JOBS or half the cores.
mem_safe_jobs() {
	local cores avail by_mem limit foreign
	cores="$( (command -v nproc >/dev/null && nproc) || echo 4 )"
	limit=$(( cores / 2 ))
	[ "$limit" -lt 1 ] && limit=1

	# Leave the floor untouched rather than spending every last megabyte.
	avail="$(mem_available_mb)"
	by_mem=$(( (avail - MEM_FLOOR_MB) / MEM_PER_JOB_MB ))
	[ "$by_mem" -lt 1 ] && by_mem=1
	[ "$by_mem" -lt "$limit" ] && limit="$by_mem"

	# Someone else is using Godot; take half of what we would have.
	foreign="$(mem_foreign_godot_count)"
	if [ "$foreign" -gt 0 ]; then
		limit=$(( limit / 2 ))
		[ "$limit" -lt 1 ] && limit=1
	fi

	[ "$limit" -gt "$MEM_MAX_JOBS" ] && limit="$MEM_MAX_JOBS"
	echo "$limit"
}

## True while there is still room to keep going. Call between units of work.
mem_guard_ok() {
	local avail
	avail="$(mem_available_mb)"
	if [ "$avail" -lt "$MEM_FLOOR_MB" ]; then
		echo "" >&2
		echo "ABORTING: memory dropped to ${avail}MB, below the ${MEM_FLOOR_MB}MB floor." >&2
		echo "          Stopping before the machine runs out. Partial results above." >&2
		return 1
	fi
	return 0
}

# Hard cap on how much subprocess output a shell variable may hold. This is the
# one that actually mattered: the OOM kills were two *bash* processes at 40GB
# each, not Godot at 110MB. A command substitution buffers everything its child
# writes, so a demo that errors once per frame — or any run that does not
# terminate when expected — grows the shell itself without limit.
MEM_MAX_CAPTURE_KB="${MEM_MAX_CAPTURE_KB:-2048}"

# Where this file lives, so mem_capture can re-source it in the subshell it uses
# to apply `timeout` to a shell function.
MEMGUARD_PATH="${BASH_SOURCE[0]}"

# Wall-clock ceiling on a single Godot invocation. A process that never exits is
# how output becomes unbounded in the first place.
MEM_RUN_TIMEOUT="${MEM_RUN_TIMEOUT:-120}"

## Capture a command's output with both a time limit and a size limit.
##
## Use this instead of `out="$(cmd)"` anywhere the child could be chatty.
## Truncation is announced in the captured text so a caller never silently
## analyses a partial log.
## The child's exit status is returned, not `head`'s. Without the explicit
## `exit "${PIPESTATUS[0]}"` the pipe swallows it and every caller that checks
## `$?` sees a clean 0 — which is how a Godot suite that printed "23/23 passed"
## and then aborted at shutdown passed this harness for weeks.
mem_capture() {
	local out status
	out="$(timeout "$MEM_RUN_TIMEOUT" bash -c 'source "$0"; "$@"' "$MEMGUARD_PATH" "$@" 2>&1 | head -c $(( MEM_MAX_CAPTURE_KB * 1024 )); exit "${PIPESTATUS[0]}")"
	status=$?
	local size=${#out}
	if [ "$size" -ge $(( MEM_MAX_CAPTURE_KB * 1024 )) ]; then
		printf '%s\n[output truncated at %sKB by memguard — the child was too chatty]\n' \
			"$out" "$MEM_MAX_CAPTURE_KB"
	else
		printf '%s' "$out"
	fi
	return "$status"
}

## Run Godot with an address-space cap, so a runaway child dies alone.
mem_run_godot() {
	( ulimit -v $(( MEM_ULIMIT_MB * 1024 )) 2>/dev/null || true
	  exec "$@" )
}

## Kill anything we spawned. Installed as a trap by mem_guard_install_trap.
mem_reap_children() {
	local kids
	kids="$(pgrep -P $$ 2>/dev/null)"
	[ -n "$kids" ] && kill $kids 2>/dev/null
	# Godot children of our workers, which pgrep -P misses one level down.
	pkill -P $$ 2>/dev/null
	return 0
}

## Clean up on normal exit and on interrupt, so a Ctrl-C never strands Godot.
mem_guard_install_trap() {
	trap 'mem_reap_children; exit 130' INT TERM
	trap 'mem_reap_children' EXIT
}
