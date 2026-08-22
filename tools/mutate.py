#!/usr/bin/env python3
"""Measure whether a demo's test suite actually catches bugs in the demo.

A suite that reimplements the mechanism inline stays green no matter what
happens to the code it claims to test. That is not hypothetical here: this
collection's 2D sibling once had 63 demos that did not run at all while every
suite reported 100% passing. The smoke check in run-tests.sh catches "does not run"; nothing
catches "runs, but is wrong".

This does. For each demo it makes a small, deliberate change to the demo's real
scripts — flip a comparison, negate a constant, swap and/or — and re-runs only
the logic suite. If the suite still passes, that mutation SURVIVED: nothing in
the suite depends on the mutated behaviour.

    tools/mutate.py                    # every demo
    tools/mutate.py orbit-camera       # one or more
    tools/mutate.py --limit 3          # mutations per demo (default 5)
    tools/mutate.py --json report.json # machine-readable output

A score of 0% killed means the suite is testing a copy of the logic rather than
the logic. 100% means every change it tried was noticed.

Scripts are restored after every run, including on Ctrl-C.
"""

import argparse
import glob
import io
import json
import math
import os
import random
import re
import resource
import subprocess
import sys
import threading

GODOT = os.environ.get("GODOT", "godot")

# --- Memory safeguards -----------------------------------------------------
#
# The bash tools get these from tools/memguard.sh; this is the same policy in
# Python. A full sweep is hundreds of Godot invocations, so a run that starts
# fine can still meet memory pressure partway through — stopping cleanly with a
# partial result beats being OOM-killed.

MEM_MIN_START_MB = int(os.environ.get("MEM_MIN_START_MB", "2048"))
MEM_FLOOR_MB = int(os.environ.get("MEM_FLOOR_MB", "1024"))
MEM_ULIMIT_MB = int(os.environ.get("MEM_ULIMIT_MB", "4096"))

# Cap on captured subprocess output. subprocess.run(capture_output=True) buffers
# everything the child writes, exactly like a shell command substitution — which
# is what produced two 40GB bash processes and the OOM kills. A mutated script
# can easily error once per frame, so this is not a hypothetical.
MEM_MAX_CAPTURE_KB = int(os.environ.get("MEM_MAX_CAPTURE_KB", "2048"))

# --- Crash safety -----------------------------------------------------------
#
# This tool edits the demos in place and restores them afterwards. A `finally`
# block is not enough: a SIGKILL, an OOM kill, or a terminal that goes away
# leaves the mutation on disk. That is not hypothetical — it happened, the
# leftover was committed by a blanket `git add -A`, and the resulting infinite
# recursion in a demo produced the 40GB output that caused the OOM crashes in
# the first place.
#
# So every mutation is journalled to disk before it is applied. Any later run
# restores whatever a previous run left behind before doing anything else.

JOURNAL = ".mutate-journal.json"


def _journal_write(entries):
    """Record the pristine content of every file we are about to modify."""
    if entries:
        with open(JOURNAL, "w", encoding="utf-8") as handle:
            json.dump(entries, handle)
    elif os.path.exists(JOURNAL):
        os.remove(JOURNAL)


def restore_from_journal():
    """Undo anything a previous run left behind. Returns files restored."""
    if not os.path.exists(JOURNAL):
        return []
    try:
        with open(JOURNAL, encoding="utf-8") as handle:
            entries = json.load(handle)
    except (ValueError, OSError):
        os.remove(JOURNAL)
        return []
    restored = []
    for path, content in entries.items():
        try:
            if os.path.exists(path) and open(path, encoding="utf-8").read() != content:
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(content)
                restored.append(path)
        except OSError:
            pass
    os.remove(JOURNAL)
    return restored


def available_mb():
    """Available memory, or a large number on platforms without /proc."""
    try:
        with open("/proc/meminfo", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) // 1024
    except OSError:
        pass
    return 99999


def preflight():
    avail = available_mb()
    if avail < MEM_MIN_START_MB:
        print("error: only %dMB available, need %dMB to start.\n"
              "       This spawns Godot processes one at a time but many of them.\n"
              "       Override deliberately with MEM_MIN_START_MB=512."
              % (avail, MEM_MIN_START_MB), file=sys.stderr)
        return False
    return True


def _limit_address_space():
    """Cap the child's address space so a runaway allocation dies alone."""
    limit = MEM_ULIMIT_MB * 1024 * 1024
    try:
        resource.setrlimit(resource.RLIMIT_AS, (limit, limit))
    except (ValueError, OSError):
        pass          # not fatal: the other guards still apply

# Ordered by how likely each is to be a behaviour change rather than a crash.
# Each entry is (name, pattern, replacement).
MUTATIONS = [
    ("comparison", re.compile(r"(?<![<>=!])>=(?!=)"), "<="),
    ("comparison", re.compile(r"(?<![<>=!])<=(?!=)"), ">="),
    ("comparison", re.compile(r"(?<![<>=!+\-*/])>(?![=>])"), "<"),
    ("comparison", re.compile(r"(?<![<>=!+\-*/])<(?![=<])"), ">"),
    ("equality", re.compile(r"(?<![<>=!])==(?!=)"), "!="),
    ("equality", re.compile(r"!=(?!=)"), "=="),
    ("boolean", re.compile(r"\band\b"), "or"),
    ("boolean", re.compile(r"\bor\b"), "and"),
    ("literal", re.compile(r"\btrue\b"), "false"),
    ("literal", re.compile(r"\bfalse\b"), "true"),
    ("arithmetic", re.compile(r"(?<=[\w\)\]]) \+ (?=[\w\(])"), " - "),
    ("arithmetic", re.compile(r"(?<=[\w\)\]]) - (?=[\w\(])"), " + "),
]

# Lines we must not touch: comments, annotations, class/extends declarations,
# and anything inside a string (approximated by skipping lines that are mostly
# string, which is good enough to avoid rewriting printed labels).
SKIP_LINE = re.compile(r"^\s*(#|##|@|class_name|extends|signal)")
FUNC_LINE = re.compile(r"^func\s+(\w+)")


# main.gd is the demo driver — it builds the scene, wires the HUD, and draws the
# visualisation. None of that is unit-tested by design, so mutating it would
# score every demo badly for a legitimate reason. Excluded unless asked for.
DRIVER = "main.gd"

# A suite can say that instantiating the scene is not an attempt to test the
# driver. 3D needs that distinction more than 2D does: a physics query, a
# SpringArm3D sweep or a navigation bake can only be checked against a real
# scene in a real world, and doing so says nothing about the input handling in
# main.gd. The marker takes a reason, like check_docs.py's size-exempt.
#
#   # mutate-driver: skip — the scene is instantiated to drive the engine
DRIVER_EXEMPT = re.compile(r"^#\s*mutate-driver:\s*skip\b(.*)$", re.M)


def _suite_drives_main(demo):
    """Does this demo's suite deliberately exercise scripts/main.gd?

    Excluding main.gd is right when it is only a driver — scene wiring, HUD,
    _draw(). It is wrong for the demos whose actual logic lives there, because
    then the exclusion hides the very code the suite was rewritten to cover.

    A suite reaches main.gd two ways: by loading the script, or by instantiating
    the scene it is attached to. Both count — several demos are only testable
    the second way, because the logic reads nodes the scene supplies.
    """
    suite = os.path.join(demo, "tests", "test_logic.gd")
    if not os.path.exists(suite):
        return False
    with io.open(suite, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    if "scripts/main.gd" in text:
        return True                       # loading the script is unambiguous
    if DRIVER_EXEMPT.search(text):
        return False                      # the suite says the scene is not the driver
    return _main_scene(demo) in text


def _main_scene(demo):
    """The res:// path of the demo's main scene, or a string nothing matches."""
    project = os.path.join(demo, "project.godot")
    if os.path.exists(project):
        with io.open(project, encoding="utf-8", errors="replace") as handle:
            match = re.search(r'^run/main_scene="([^"]+)"', handle.read(), re.M)
        if match:
            return match.group(1)
    return "\0"


def demo_scripts(demo, include_driver=False):
    paths = sorted(glob.glob(os.path.join(demo, "scripts", "*.gd")))
    if include_driver or _suite_drives_main(demo):
        return paths
    logic = [p for p in paths if os.path.basename(p) != DRIVER]
    # A demo whose only script IS main.gd has its logic there; measure it.
    return logic or paths


def strip_strings(line):
    """Blank out string contents so mutations never land inside a literal."""
    return re.sub(r'"[^"]*"', lambda m: '"' + " " * (len(m.group(0)) - 2) + '"', line)


def candidates(demo, include_driver=False):
    """Every (path, line_no, name, new_line) mutation available in this demo."""
    out = []
    for path in demo_scripts(demo, include_driver):
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().split("\n")
        drawing = False
        in_text_block = False
        for i, line in enumerate(lines):
            # Triple-quoted blocks are content, not code. strip_strings() only
            # masks single-line literals, so without this the tool mutates the
            # English inside a demo's help text and scores suites on prose.
            fences = line.count('"""')
            if in_text_block:
                if fences:
                    in_text_block = False
                continue
            if fences % 2 == 1:
                in_text_block = True
                continue
            if FUNC_LINE.match(line):
                # A _draw() body is pixels, not logic: mutating a colour or a
                # fill flag produces a demo that still behaves identically and a
                # survivor nobody can kill. Skipping it makes the score mean
                # what docs/TEST_INTEGRITY.md says it means. `_draw_grid` and
                # friends are helpers of the same kind.
                drawing = FUNC_LINE.match(line).group(1).startswith("_draw")
            if drawing or SKIP_LINE.match(line) or not line.strip():
                continue
            # Trailing comments are prose. strip_strings() has already blanked
            # any '#' inside a string literal, so the first one left starts a
            # real comment — subviewport lost a mutation to the words in one.
            masked = strip_strings(line)
            hash_at = masked.find("#")
            if hash_at != -1:
                masked = masked[:hash_at]
            for name, pattern, replacement in MUTATIONS:
                match = pattern.search(masked)
                if not match:
                    continue
                mutated = line[:match.start()] + replacement + line[match.end():]
                if mutated == line:
                    continue
                out.append((path, i, name, mutated))
    return out


def _frame_budget(demo):
    """Frames the suite gets before the engine quits.

    Matches run-tests.sh: a demo that has to watch physics play out asks for
    more in tests/frames; everyone else keeps the cheap default, which is paid
    once per mutant and so dominates a mutation run.
    """
    path = os.path.join(demo, "tests", "frames")
    if os.path.exists(path):
        with io.open(path, encoding="utf-8") as fh:
            digits = "".join(c for c in fh.read() if c.isdigit())
        if digits:
            return digits
    return "5"

# Errors that abandon the function they happen in — the same list run-tests.sh
# gates on. This matters more here than anywhere else: a mutation bad enough to
# raise an error aborts the test that would have caught it, the suite prints a
# smaller "n/n passed" with the counts still agreeing, and the mutation is
# recorded as one nothing noticed. Two of procedural-mesh's index mutations hid
# exactly there — add_index(-1) errors, grid() never returns, and the assertion
# about the indices never runs.
SUITE_ABORT = re.compile(
    r"previously freed|Invalid access to (property|index)|Nonexistent function|"
    r"Invalid type in function|Invalid index|[Oo]ut of bounds|null (instance|value)|"
    r"Division By Zero|Invalid assignment|Trying to assign value of type|"
    r"Invalid call|Condition .* is true")


def run_suite(demo, timeout=90):
    """Run only the logic suite. True if it passed."""
    if not os.path.exists(os.path.join(demo, "tests", "test.tscn")):
        return None
    limit = MEM_MAX_CAPTURE_KB * 1024
    try:
        # Stream and truncate rather than buffer: a mutation that makes a demo
        # error every frame would otherwise grow this process without bound.
        proc = subprocess.Popen(
            [GODOT, "--headless", "--path", demo, "res://tests/test.tscn",
             "--quit-after", _frame_budget(demo)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            preexec_fn=_limit_address_space)
        # The deadline has to cover the read, not just the wait. A mutation can
        # leave a demo spinning in a loop that prints nothing — read() then
        # blocks until EOF that never comes, and the run hangs forever. Two of
        # these outlived their parent by an hour before this was added.
        watchdog = threading.Timer(timeout, proc.kill)
        watchdog.start()
        try:
            captured = proc.stdout.read(limit)
            proc.stdout.close()
            proc.wait()
        finally:
            watchdog.cancel()
        if proc.returncode is not None and proc.returncode < 0:
            return False      # killed: a mutant that hangs is a mutant caught
    except OSError:
        return False
    if SUITE_ABORT.search(captured):
        return False          # the suite errored partway; its score means nothing
    summary = re.findall(r"(\d+)/(\d+) passed", captured)
    if not summary:
        return False          # no summary at all: the suite did not complete
    passed, total = summary[-1]
    return passed == total


def check_demo(demo, limit, rng, include_driver=False):
    """Return a per-demo result dict."""
    available = candidates(demo, include_driver)
    if not available:
        return {"demo": demo, "status": "no-mutations", "killed": 0, "survived": 0, "detail": []}

    baseline = run_suite(demo)
    if baseline is None:
        return {"demo": demo, "status": "no-suite", "killed": 0, "survived": 0, "detail": []}
    if baseline is False:
        # A suite that is already failing tells us nothing about mutations.
        return {"demo": demo, "status": "already-failing", "killed": 0, "survived": 0, "detail": []}

    chosen = rng.sample(available, min(limit, len(available)))
    killed, survived, detail = 0, 0, []

    backups = {}
    try:
        # Journal before the first edit, so a hard kill is recoverable.
        for path, _, _, _ in chosen:
            if path not in backups:
                backups[path] = open(path, encoding="utf-8").read()
        _journal_write(backups)
        for path, line_no, name, mutated in chosen:
            if path not in backups:
                backups[path] = open(path, encoding="utf-8").read()
            lines = backups[path].split("\n")
            original = lines[line_no]
            lines[line_no] = mutated
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))

            caught = not run_suite(demo)
            # Restore before the next mutation so they never compound.
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(backups[path])

            detail.append({
                "file": os.path.relpath(path, demo),
                "line": line_no + 1,
                "kind": name,
                "was": original.strip()[:90],
                "became": mutated.strip()[:90],
                "caught": caught,
            })
            if caught:
                killed += 1
            else:
                survived += 1
    finally:
        for path, content in backups.items():
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(content)
        _journal_write({})

    return {"demo": demo, "status": "ok", "killed": killed, "survived": survived, "detail": detail}


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("demos", nargs="*", help="demos to check (default: all)")
    parser.add_argument("--limit", type=int, default=5, help="mutations per demo")
    parser.add_argument("--seed", type=int, default=1, help="RNG seed, for reproducible runs")
    parser.add_argument("--json", help="write a machine-readable report here")
    parser.add_argument("--verbose", action="store_true", help="list surviving mutations")
    parser.add_argument("--include-driver", action="store_true",
                        help="also mutate scripts/main.gd (the demo driver, normally untested)")
    parser.add_argument("--check", action="store_true",
                        help="fail if the score dropped below the recorded baseline")
    parser.add_argument("--update", action="store_true",
                        help="record the current score as the new baseline")
    args = parser.parse_args()

    demos = args.demos or sorted(os.path.dirname(p) for p in glob.glob("*/project.godot"))
    rng = random.Random(args.seed)

    # Before anything else: undo a previous run that did not get to clean up.
    stranded = restore_from_journal()
    if stranded:
        print("restored %d file(s) left mutated by an interrupted run:" % len(stranded),
              file=sys.stderr)
        for path in stranded:
            print("  " + path, file=sys.stderr)

    if not preflight():
        return 3

    results = []
    total_killed = total_survived = 0
    aborted = False
    for demo in demos:
        # Between demos: a sweep is long enough that pressure can arrive partway.
        avail = available_mb()
        if avail < MEM_FLOOR_MB:
            print("\nABORTING: memory dropped to %dMB, below the %dMB floor.\n"
                  "          Partial results above; the baseline was NOT updated."
                  % (avail, MEM_FLOOR_MB), file=sys.stderr)
            aborted = True
            break

        result = check_demo(demo, args.limit, rng, args.include_driver)
        results.append(result)
        total_killed += result["killed"]
        total_survived += result["survived"]

        tried = result["killed"] + result["survived"]
        if result["status"] != "ok":
            print("  --   %-28s %s" % (result["demo"], result["status"]))
        else:
            score = 100.0 * result["killed"] / tried if tried else 0.0
            flag = "WEAK" if score == 0.0 else ("    " if score == 100.0 else "part")
            print("%s   %-28s %d/%d caught  (%3.0f%%)"
                  % (flag, result["demo"], result["killed"], tried, score))
            if args.verbose:
                for entry in result["detail"]:
                    if not entry["caught"]:
                        print("         survived %s:%d  %s  %s -> %s"
                              % (entry["file"], entry["line"], entry["kind"],
                                 entry["was"], entry["became"]))

    tried = total_killed + total_survived
    print()
    print("======================================")
    if tried:
        print("  %d/%d mutations caught (%.0f%%)" % (total_killed, tried, 100.0 * total_killed / tried))
    weak = [r["demo"] for r in results if r["status"] == "ok" and r["killed"] == 0 and r["survived"]]
    strong = [r["demo"] for r in results if r["status"] == "ok" and r["survived"] == 0 and r["killed"]]
    print("  %d suites caught everything, %d caught nothing" % (len(strong), len(weak)))
    print("======================================")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as handle:
            json.dump({"results": results, "killed": total_killed, "survived": total_survived},
                      handle, indent=1)
        print("wrote %s" % args.json)

    # The ratchet. The score may only go up; improving a suite means recording a
    # new floor with --update. Compared as a ratio so the baseline survives new
    # demos being added.
    if aborted:
        # A partial sweep must never write or check a baseline: the ratio is not
        # comparable, and recording it would silently lower the floor.
        print("run was aborted early — baseline untouched", file=sys.stderr)
        return 4
    if args.update:
        _write_baseline(total_killed, tried, len(demos))
        return 0
    if args.check:
        return _check_baseline(total_killed, tried)

    return 0


BASELINE = "docs/mutation-baseline.json"


def _write_baseline(killed, tried, demo_count):
    data = {
        "killed": killed,
        "tried": tried,
        "demos": demo_count,
        # Rounded *down*, not to nearest: rounding up records a floor the very
        # same run cannot clear, and "98.1% against a floor of 98.2%" reads like
        # a regression when nothing has changed.
        "ratio": math.floor(killed / tried * 10000) / 10000 if tried else 0.0,
        "note": "Mutation score floor. Raise it by improving suites; never lower it. "
                "See docs/TEST_INTEGRITY.md.",
    }
    with open(BASELINE, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=1)
        handle.write("\n")
    print("recorded baseline: %d/%d (%.1f%%)" % (killed, tried, 100.0 * data["ratio"]))


def _check_baseline(killed, tried):
    if not os.path.exists(BASELINE):
        print("no baseline recorded — run with --update first", file=sys.stderr)
        return 2
    with open(BASELINE, encoding="utf-8") as handle:
        recorded = json.load(handle)
    current = killed / tried if tried else 0.0
    floor = float(recorded.get("ratio", 0.0))
    # A small tolerance: the sample is random, so an identical suite can vary a
    # little between runs with different seeds.
    if current + 0.02 < floor:
        print("FAIL: mutation score fell from %.1f%% to %.1f%%" % (100 * floor, 100 * current),
              file=sys.stderr)
        print("      A suite got weaker, or a demo's logic moved out from under its tests.",
              file=sys.stderr)
        return 1
    print("OK: %.1f%% against a floor of %.1f%%" % (100 * current, 100 * floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
