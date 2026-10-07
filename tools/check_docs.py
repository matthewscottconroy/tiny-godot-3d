#!/usr/bin/env python3
"""Structural checks for the demo collection.

These encode invariants that were established by hand and then quietly drifted:
demos advertising keys they never bind, READMEs missing sections, the index
falling out of sync with the directories. Godot cannot catch any of it — the
project still runs fine — so it has to be checked here.

Run with no arguments to check everything:

    tools/check_docs.py

Exits non-zero and prints one line per problem.
"""

import glob
import os
import re
import sys

# Every demo README carries these, in this order.
REQUIRED_SECTIONS = [
    "Purpose",
    "Controls",
    "How It Works",
    "Key Godot APIs",
    "Files",
    "Use as a building block",
]

# Files every demo project must have.
REQUIRED_FILES = [
    "project.godot",
    "README.md",
    "icon.svg",
    "tests/test.tscn",
    "tests/test_logic.gd",
]

# Godot binds these to the arrow keys only; ui_accept is Enter/Space. A README
# that promises WASD or Space is lying unless the demo binds those keys itself.
WASD_KEYS = re.compile(r"\bKEY_[ADWS]\b")
SPACE_KEYS = re.compile(r"KEY_SPACE|ui_accept")
CONTROLS_SECTION = re.compile(r"^## Controls.*?(?=^## |\Z)", re.S | re.M)

# "Tiny" is the premise. Past this many lines of demo script, ask whether it
# should be two demos — a warning, not a failure, since some concepts genuinely
# need the space. Opt out with a `# size-exempt: <reason>` comment in main.gd.
SIZE_WARN_LINES = 250
SIZE_EXEMPT = re.compile(r"^#\s*size-exempt:\s*(.+)$", re.M)

# APIs Godot has deprecated or renamed. The 2D collection lost 63 demos to API
# drift once; catching a rename while it is still only deprecated is much
# cheaper than catching it after it becomes an error.
#
# The 3D entries are mostly Godot 3 spellings that still read plausibly — a
# tutorial from 2021 says `Spatial` and `translation`, and copying one line out
# of it produces a script that fails somewhere far from the mistake.
DEPRECATED = {
    r"\bSpatial\b(?!Material)": "renamed to Node3D",
    r"\bSpatialMaterial\b": "renamed to StandardMaterial3D",
    r"\bKinematicBody\b": "renamed to CharacterBody3D (move_and_slide changed shape too)",
    r"\bMeshInstance\b(?!3D)": "renamed to MeshInstance3D",
    r"\bImmediateGeometry\b": "replaced by ImmediateMesh",
    r"\bGIProbe\b": "renamed to VoxelGI",
    r"\bVisualServer\b": "renamed to RenderingServer",
    r"\bPhysicsServer\b(?!3D)(?!2D)": "renamed to PhysicsServer3D",
    r"\bSpringArm\b(?!3D)": "renamed to SpringArm3D",
    r"\bARVR[A-Za-z]*\b": "the ARVR* classes are now XR*",
    r"\.cast_to\b": "RayCast3D.cast_to is now target_position",
    r"\.translation\b": "Node3D.translation is now position",
    r"\byield\(": "removed in Godot 4 — use await",
    r"\bOS\.get_ticks_msec\b": "moved to Time.get_ticks_msec()",
    r"\bEngine\.get_target_fps\b": "renamed to Engine.max_fps",
    r"\.instance\(\)": "renamed to instantiate()",
    r"\bconnect\(\"": "Godot 4 uses signal.connect(callable), not connect(\"name\", ...)",
    r"\bempty\(\)": "renamed to is_empty()",
    r"\bPoolStringArray\b": "renamed to PackedStringArray",
    r"\.get_stylebox\(": "renamed to get_theme_stylebox()",
    r"\.get_font\(": "renamed to get_theme_font()",
    r"(?<!Input)(?<!Input\b)\bevent\.is_action_just_(pressed|released)\(":
        "InputEvent has no is_action_just_* — those are on the Input singleton; "
        "calling one raises an error that aborts the handler",
}

# Demos allowed to mention WASD without binding it, with the reason.
WASD_EXEMPT = {}

problems = []
# Drift worth seeing that the person running this cannot fix from here.
notes = []


def fail(demo, message):
    problems.append("%s: %s" % (demo, message))


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


# Directories that hold a project.godot but are not demos. The browser is a tool
# that reads the collection; counting it as one of the demos would put it in the
# index, the tags and the count on the front page.
NOT_A_DEMO = {"browser"}


def demo_dirs():
    return sorted(d for d in (os.path.dirname(p)
                                for p in glob.glob("*/project.godot"))
                  if d not in NOT_A_DEMO)


def scripts_of(demo):
    return "".join(read(f) for f in sorted(glob.glob(demo + "/scripts/*.gd")))


def check_required_files(demo):
    for rel in REQUIRED_FILES:
        if not os.path.exists(os.path.join(demo, rel)):
            fail(demo, "missing %s" % rel)
    main_scene = re.search(r'run/main_scene="res://(.+)"', read(demo + "/project.godot"))
    if not main_scene:
        fail(demo, "project.godot has no run/main_scene")
    elif not os.path.exists(os.path.join(demo, main_scene.group(1))):
        fail(demo, "run/main_scene points at a missing file: %s" % main_scene.group(1))


def check_sections(demo):
    text = read(demo + "/README.md")
    headings = re.findall(r"^## (.+)$", text, re.M)
    for section in REQUIRED_SECTIONS:
        if section not in headings:
            fail(demo, "README is missing the '%s' section" % section)
    duplicates = {h for h in headings if headings.count(h) > 1}
    for dup in sorted(duplicates):
        fail(demo, "README has two '%s' sections" % dup)


# tools/build_index.py appends a "Related demos" block to every README, quoting
# each neighbour's one-line description. Those are someone else's words: a demo
# that links to first-person-controller would otherwise be caught claiming WASD.
GENERATED_BLOCK = "## Related demos"


def authored(demo):
    """A README with the generated blocks removed — what the author wrote."""
    text = read(demo + "/README.md")
    index = text.find(GENERATED_BLOCK)
    return text if index == -1 else text[:index]


def check_control_claims(demo):
    text = authored(demo)
    code = scripts_of(demo)
    controls = CONTROLS_SECTION.search(text)
    controls_text = controls.group(0) if controls else ""

    if "wasd" in text.lower() and not WASD_KEYS.search(code) and demo not in WASD_EXEMPT:
        fail(demo, "README mentions WASD but no script binds KEY_A/KEY_D/KEY_W/KEY_S "
                   "(ui_* is arrow keys only)")

    if re.search(r"space.*jump|jump.*space", controls_text, re.I) and not SPACE_KEYS.search(code):
        fail(demo, "Controls promise Space-to-jump but no script reads KEY_SPACE or ui_accept")


def check_stale_version_prose(demo):
    """Flag prose that pins the version the demo was *built for*.

    "Godot 4.3+" is fine — that is a floor, documenting when an API appeared.
    Bare "Godot 4.2" is the pattern that went stale across 24 READMEs: it claims
    a target, and nothing updates it when the target moves. Those should say
    "Godot 4", with the concrete version living in the root README and CI so
    there is exactly one place to change it.
    """
    text = authored(demo)
    for match in re.finditer(r"Godot (4\.\d+)(\+?)", text):
        if match.group(2) != "+":
            fail(demo, "README pins a minor version in prose (%r) — say 'Godot 4', "
                       "or 'Godot %s+' if it documents an API floor"
                       % (match.group(0), match.group(1)))


def check_size(demo):
    """Warn when a demo drifts past 'tiny'."""
    scripts = sorted(glob.glob(os.path.join(demo, "scripts", "*.gd")))
    if not scripts:
        return
    total = sum(len(read(p).split("\n")) for p in scripts)
    if total <= SIZE_WARN_LINES:
        return
    exemption = None
    for path in scripts:
        match = SIZE_EXEMPT.search(read(path))
        if match:
            exemption = match.group(1).strip()
            break
    if exemption:
        return
    fail(demo, "%d lines of demo script (over %d) — consider splitting it, or add "
               "`# size-exempt: <reason>` if the concept genuinely needs the space"
               % (total, SIZE_WARN_LINES))


def check_deprecated_apis(demo):
    """Flag APIs Godot has deprecated, before they become errors."""
    for path in sorted(glob.glob(os.path.join(demo, "scripts", "*.gd"))):
        source = read(path)
        for i, line in enumerate(source.split("\n"), 1):
            if line.lstrip().startswith("#"):
                continue
            for pattern, advice in DEPRECATED.items():
                match = re.search(pattern, line)
                if match:
                    fail(demo, "%s:%d uses a deprecated API (%s) — %s"
                         % (os.path.basename(path), i, match.group(0).strip(), advice))


def check_scene_groups(demo):
    """Catch group membership written as a property instead of on the header.

    Godot reads a node's groups from its header — `[node ... groups=["room"]]`.
    A `groups = PackedStringArray("room")` line parses fine and does nothing, so
    get_nodes_in_group() comes back empty and whatever depended on it silently
    never runs. camera-rooms shipped like this: its camera never moved.
    """
    for path in sorted(glob.glob(os.path.join(demo, "scenes", "*.tscn"))):
        for i, line in enumerate(read(path).split("\n"), 1):
            if re.match(r"^groups\s*=\s*PackedStringArray\(", line):
                fail(demo, "%s:%d sets groups as a property — Godot reads them "
                           "from the node header, so this joins no group at all"
                     % (os.path.basename(path), i))


# Nodes that put light into a 3D scene. Without one of these — and without an
# environment supplying ambient light — a scene full of correct geometry renders
# black, and every other check in this file still passes.
LIGHT_NODES = re.compile(r'type="(DirectionalLight3D|OmniLight3D|SpotLight3D|'
                         r'WorldEnvironment|VoxelGI|LightmapGI)"')

# Enough to say a scene is a 3D scene at all.
SPATIAL_NODES = re.compile(r'type="([A-Za-z]+3D|GridMap|CSG[A-Za-z]*)"')


def main_scene_of(demo):
    """The path of the scene the project actually runs, or None."""
    match = re.search(r'run/main_scene="res://(.+)"', read(demo + "/project.godot"))
    if not match:
        return None
    path = os.path.join(demo, match.group(1))
    return path if os.path.exists(path) else None


def check_scene_is_lit(demo):
    """Catch a 3D scene that renders black.

    This is the 3D equivalent of a 2D demo drawing off-screen: the geometry, the
    script and the tests are all fine, and the window shows nothing. It is the
    first thing to go wrong when a scene is written by hand rather than in the
    editor, because the editor's preview light is not part of the scene.
    """
    scene = main_scene_of(demo)
    if scene is None:
        return
    text = read(scene)
    if not SPATIAL_NODES.search(text):
        return                      # not a 3D scene; check_is_actually_3d has it
    if not LIGHT_NODES.search(text):
        fail(demo, "%s has 3D geometry but no light and no WorldEnvironment — it "
                   "renders black outside the editor" % os.path.basename(scene))


def check_is_actually_3d(demo):
    """This collection is 3D. A demo with no 3D node belongs in the 2D one."""
    scene = main_scene_of(demo)
    if scene is None:
        return
    if not SPATIAL_NODES.search(read(scene)):
        fail(demo, "%s contains no 3D node — this is the 3D collection; 2D demos "
                   "belong in tiny-godot-games" % os.path.basename(scene))


# A demo whose README links to no other demo is a dead end: the reader has to
# go back to the index to find the next thing, and the connections between
# ideas — which is most of what a collection is for — go unsaid.
#
# Exempt where there is genuinely nothing adjacent, with the reason.
CROSSLINK_EXEMPT = {}

# Below this a suite is not really checking the demo, whatever its score.
MIN_ASSERTIONS = 6

# The "Key Godot APIs" table promises "what to look up for this demo", and a
# reader takes every row as something the code in front of them calls. Six
# READMEs had drifted into listing an API the demo never touches — advice for an
# adopter, formatted identically to the rows that are demonstrated, with nothing
# to tell them apart. This is the API-table twin of check_control_claims().
#
# A row that is genuinely advice belongs in prose, or in the table marked with
# the suffix below, which says so in the rendered README rather than only here.
API_ADVISORY = "(not used here)"
API_SECTION = re.compile(r"^## Key Godot APIs.*?(?=^## |\Z)", re.S | re.M)

# docs/COMPATIBILITY.md is generated from the CI matrix — but by a job that
# uploads it as an artifact for a maintainer to copy in, because CI does not
# push. Every other generated file here has a --check that fails on drift; this
# one could not, since build_compat.py needs the run's results to regenerate it.
#
# What *is* checkable without those results is the claim the table makes about
# which versions were tested. That is the half that actually drifted: the matrix
# moved to 4.7.1 and the table went on saying 4.7.
CI_WORKFLOW = ".github/workflows/tests.yml"
COMPAT_DOC = "docs/COMPATIBILITY.md"
COMPAT_COUNT = re.compile(r"^_(\d+) demos across \d+ versions\._$", re.M)
CI_MATRIX = re.compile(r"^\s*godot:\s*\[([^\]]*)\]", re.M)
COMPAT_VERSIONS = re.compile(r"^Versions tested:\s*(.+)$", re.M)


def _api_symbols(span):
    """The names a `Key Godot APIs` cell is really pointing at.

    A cell is written for a reader, not a parser: `Skeleton3D.get_bone_pose()`,
    `Generic6DOFJoint3D.set_flag_x/y/z()`, `PARAM_LIMIT_*`, and shader syntax
    like `sampler2D : hint_screen_texture`. What matters is the member — the
    class name is almost always present in the demo anyway, so matching on that
    would pass every row regardless.

    Returns compiled patterns, because a cell may legitimately use `*` to stand
    for a family of constants rather than name one.
    """
    span = re.sub(r"\(.*?\)", "", span).replace("()", "")
    out = []
    for token in re.split(r"[/\s:,]+", span):
        token = token.strip().split(".")[-1]
        if not token or not re.search(r"\w", token):
            continue
        out.append(re.compile("".join(r"\w*" if c == "*" else re.escape(c)
                                      for c in token)))
    return out


def demo_source(demo):
    """Every line of the demo a reader gets — including the suite.

    The suite counts: it is shipped with the demo and read as part of it, and
    several READMEs quite reasonably cite the API you would *verify* the
    mechanism with rather than the one that drives it. `get_overlapping_bodies()`
    is the state-query counterpart to the signals, and the suite is where asking
    for state rather than waiting for a transition actually makes sense.
    """
    text = []
    for sub, pattern in (("scripts", "*.gd"), ("scenes", "*.tscn"),
                         ("shaders", "*.gdshader"),
                         ("tests", "*.gd"), ("tests", "*.tscn")):
        for path in sorted(glob.glob(os.path.join(demo, sub, pattern))):
            text.append(read(path))
    return "\n".join(text)


def check_api_claims(demo):
    """Flag a `Key Godot APIs` row the demo never actually uses.

    check_control_claims() does this for the Controls section; this is the same
    invariant one section down. A row here is read as "what this demo calls, go
    look it up" — four READMEs had drifted into listing an API that only appears
    in the adoption advice, formatted identically to the rows that are real.
    """
    text = authored(demo)
    section = API_SECTION.search(text)
    if not section:
        return
    source = demo_source(demo)
    for line in section.group(0).split("\n"):
        if not line.startswith("|"):
            continue
        cell = line.split("|")[1] if line.count("|") >= 2 else ""
        if API_ADVISORY in line:
            continue
        for span in re.findall(r"`([^`]+)`", cell):
            symbols = _api_symbols(span)
            if symbols and not any(s.search(source) for s in symbols):
                fail(demo, "README lists `%s` under Key Godot APIs but no script "
                           "or scene uses it — move it into the prose, or mark "
                           "the row %s" % (span, API_ADVISORY))


def check_cross_links(demo):
    """Every demo should point at least one other demo."""
    if demo in CROSSLINK_EXEMPT:
        return
    text = read(os.path.join(demo, "README.md"))
    for match in re.finditer(r"\]\(\.\./([a-z0-9-]+)", text):
        if match.group(1) != demo and os.path.isdir(match.group(1)):
            return
    fail(demo, "README links to no other demo — add a 'Related demos' line, or "
               "list it in CROSSLINK_EXEMPT with the reason")


def check_suite_depth(demo):
    """Flag a suite too thin to be checking much."""
    path = os.path.join(demo, "tests", "test_logic.gd")
    if not os.path.exists(path):
        return
    source = read(path)
    # expect() and its quiet variant are the only assertion calls in a suite;
    # the definitions themselves are skipped.
    assertions = len(re.findall(r"^\s+expect(?:_quiet)?\(", source, re.M))
    if assertions < MIN_ASSERTIONS:
        fail(demo, "tests/test_logic.gd makes only %d assertions (want %d or more)"
             % (assertions, MIN_ASSERTIONS))


def check_tags(demo):
    """Every README carries the tag line tools/build_tags.py writes."""
    text = read(os.path.join(demo, "README.md"))
    if "<!-- tags:" not in text:
        fail(demo, "README has no tag line — run tools/build_tags.py")


def check_index():
    root = read("README.md")
    listed = re.findall(r"^\| \[([a-z0-9-]+)\]\(([a-z0-9-]+)\)", root, re.M)
    listed_names = [name for name, _ in listed]

    for name, link in listed:
        if name != link:
            problems.append("README.md: index row for '%s' links to '%s'" % (name, link))

    seen = set()
    for name in listed_names:
        if name in seen:
            problems.append("README.md: '%s' is listed twice in the index" % name)
        seen.add(name)

    actual = set(demo_dirs())
    for missing in sorted(actual - seen):
        problems.append("README.md: '%s' exists but is not in the index" % missing)
    for extra in sorted(seen - actual):
        problems.append("README.md: index lists '%s' but there is no such demo" % extra)

    stated = re.search(r"\*\*(\d+) tiny, self-contained", root)
    if not stated:
        problems.append("README.md: cannot find the demo count in the intro")
    elif int(stated.group(1)) != len(actual):
        problems.append("README.md: intro says %s demos, there are %d"
                        % (stated.group(1), len(actual)))

    footer = re.search(r"\*(\d+) demos\. Each teaches one thing", root)
    if footer and int(footer.group(1)) != len(actual):
        problems.append("README.md: footer says %s demos, there are %d"
                        % (footer.group(1), len(actual)))


# The learning paths are what make the collection more than an index: they order
# it, and tools/build_index.py turns that order into each demo's "Related demos"
# links. A demo on no path gets no links from its neighbours, and nobody walking
# a route ever reaches it — four demos had quietly ended up that way.
PATHS_DOC = "docs/LEARNING_PATHS.md"
PATH_STEP = re.compile(r"^\| \d+ \| \[([a-z0-9-]+)\]\(\.\./([a-z0-9-]+)\)", re.M)


def check_learning_paths():
    """Every demo is a step on at least one learning path."""
    if not os.path.exists(PATHS_DOC):
        return
    steps = PATH_STEP.findall(read(PATHS_DOC))
    for name, link in steps:
        if name != link:
            problems.append("%s: step '%s' links to '%s'" % (PATHS_DOC, name, link))
    placed = {name for name, _ in steps}
    for demo in sorted(set(demo_dirs()) - placed):
        problems.append("%s: '%s' is not on any learning path" % (PATHS_DOC, demo))
    for name in sorted(placed - set(demo_dirs())):
        problems.append("%s: a path includes '%s' but there is no such demo"
                        % (PATHS_DOC, name))


def check_compat_versions():
    """The compatibility table must name the versions CI actually runs."""
    if not (os.path.exists(CI_WORKFLOW) and os.path.exists(COMPAT_DOC)):
        return
    matrix = CI_MATRIX.search(read(CI_WORKFLOW))
    claimed = COMPAT_VERSIONS.search(read(COMPAT_DOC))
    if not matrix:
        problems.append("%s: cannot find the Godot version matrix" % CI_WORKFLOW)
        return
    if not claimed:
        problems.append("%s: no 'Versions tested:' line to check" % COMPAT_DOC)
        return

    tested = re.findall(r"[0-9]+(?:\.[0-9]+)+", matrix.group(1))
    stated = re.findall(r"[0-9]+(?:\.[0-9]+)+", claimed.group(1))
    if sorted(tested) != sorted(stated):
        problems.append(
            "%s says it covers %s but %s runs %s — regenerate it from the CI "
            "results (tools/build_compat.py) rather than editing the numbers"
            % (COMPAT_DOC, ", ".join(stated), CI_WORKFLOW, ", ".join(tested)))
        return

    # A demo added since the table was last copied in has never been through the
    # matrix at all, and the badge goes on saying N/N with the newcomer outside
    # the N. That is the other half that drifted: 58/58 next to 61 demos.
    #
    # A note rather than a failure: the fix is an artifact from a CI run that
    # already includes the new demo, which the person adding it cannot produce
    # before pushing. Failing here would only turn every new-demo PR red.
    counted = COMPAT_COUNT.search(read(COMPAT_DOC))
    if counted and int(counted.group(1)) != len(demo_dirs()):
        notes.append(
            "%s covers %s demos but there are %d — copy in the `compatibility` "
            "artifact from a CI run that includes them" % (COMPAT_DOC, counted.group(1),
                                                           len(demo_dirs())))

    # The README badge is generated alongside the table and goes stale with it.
    newest = tested[-1]
    badge = re.search(r"<!-- compat-badge -->(.*?)<!-- /compat-badge -->",
                      read("README.md"), re.S)
    if badge and newest not in badge.group(1):
        problems.append("README.md: the compat badge does not mention %s, the "
                        "newest version CI runs" % newest)


def main():
    if not os.path.exists("README.md"):
        print("run this from the repository root", file=sys.stderr)
        return 2

    demos = demo_dirs()
    if not demos:
        print("no demos found — is this the repository root?", file=sys.stderr)
        return 2

    for demo in demos:
        check_required_files(demo)
        check_size(demo)
        check_deprecated_apis(demo)
        check_scene_groups(demo)
        check_is_actually_3d(demo)
        check_scene_is_lit(demo)
        check_suite_depth(demo)
        if os.path.exists(demo + "/README.md"):
            check_sections(demo)
            check_control_claims(demo)
            check_api_claims(demo)
            check_stale_version_prose(demo)
            check_cross_links(demo)
            check_tags(demo)
    check_index()
    check_learning_paths()
    check_compat_versions()

    for note in notes:
        print("note: " + note)

    if problems:
        print("%d problem(s):\n" % len(problems))
        for problem in problems:
            print("  " + problem)
        return 1

    print("checked %d demos — no problems found" % len(demos))
    return 0


if __name__ == "__main__":
    sys.exit(main())
