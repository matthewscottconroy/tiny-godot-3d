#!/usr/bin/env python3
"""Generate the API cross-reference and the related-demos links.

A collection with no cross-links between its demos is a collection of islands:
someone who finishes `orbit-camera` gets no signal that `character-controller-3d`
is the natural next read.

This derives both connections from what already exists:

    docs/API_INDEX.md   engine API -> the demos that use it
    a "Related demos" block appended to each demo README

Relatedness is scored from shared engine APIs, weighted so a rare API counts far
more than a ubiquitous one — `Input.get_vector` appears in most demos and tells you
nothing, while `SurfaceTool` appearing in three tells you a lot. Learning
path adjacency is added on top, because a hand-curated ordering is better
evidence than any statistic.

    tools/build_index.py            # write both
    tools/build_index.py --check    # fail if either is out of date
"""

import argparse
import glob
import math
import os
import re
import sys
from collections import defaultdict

API_INDEX = "docs/API_INDEX.md"
PATHS_DOC = "docs/LEARNING_PATHS.md"
RELATED_HEADING = "## Related demos"

# Class.method( and bare built-ins worth indexing. Deliberately narrow: this is
# a "what do I look up in the docs" index, not a symbol dump.
CALL = re.compile(r"\b([A-Z][A-Za-z0-9]*)\.([a-z_][a-z0-9_]*)\s*\(")
BARE = re.compile(r"(?<![\w.])(move_and_slide|is_on_floor|is_on_wall|is_on_ceiling|"
                  r"get_wall_normal|get_floor_normal|get_last_slide_collision|"
                  r"create_tween|tween_property|instantiate|add_child|queue_free|"
                  r"lerp_angle|move_toward|look_at|look_at_from_position|rotated|"
                  r"project_ray_origin|project_ray_normal|unproject_position)\s*\(")
# The 3D types worth an index entry. 2D siblings are deliberately absent: a
# Camera2D in a 3D demo would be a mistake, not something to cross-reference.
TYPE = re.compile(r"\b(Node3D|Camera3D|SpringArm3D|CharacterBody3D|RigidBody3D|"
                  r"StaticBody3D|AnimatableBody3D|Area3D|MeshInstance3D|MultiMeshInstance3D|"
                  r"CollisionShape3D|RayCast3D|ShapeCast3D|GridMap|CSGShape3D|CSGBox3D|"
                  r"CSGCombiner3D|SurfaceTool|ArrayMesh|ImmediateMesh|MeshDataTool|"
                  r"NavigationAgent3D|NavigationRegion3D|NavigationServer3D|AStar3D|"
                  r"DirectionalLight3D|OmniLight3D|SpotLight3D|WorldEnvironment|"
                  r"Environment|ReflectionProbe|VoxelGI|LightmapGI|FogVolume|Decal|"
                  r"GPUParticles3D|AnimationPlayer|AnimationTree|Skeleton3D|"
                  r"SkeletonIK3D|BoneAttachment3D|AudioStreamPlayer3D|"
                  r"PhysicsDirectSpaceState3D|PhysicsRayQueryParameters3D|"
                  r"PhysicsShapeQueryParameters3D|PhysicsServer3D|RenderingServer|"
                  r"SubViewport|ShaderMaterial|StandardMaterial3D|FastNoiseLite|"
                  r"HTTPRequest|ConfigFile|Thread|Image|Tween)\b")

# Names that say nothing about what a demo teaches.
IGNORE = {"new", "call", "size", "append", "has", "get", "set", "duplicate", "clear",
          "keys", "values", "erase", "is_empty", "emit", "connect", "format", "front", "back"}


# Directories that hold a project.godot but are not demos. The browser is a tool
# that reads the collection; counting it as one of the demos would put it in the
# index, the tags and the count on the front page.
NOT_A_DEMO = {"browser"}


def demos():
    return sorted(d for d in (os.path.dirname(p)
                                for p in glob.glob("*/project.godot"))
                  if d not in NOT_A_DEMO)


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def apis_of(demo):
    """The set of engine APIs a demo uses."""
    found = set()
    for path in glob.glob(demo + "/scripts/*.gd"):
        source = read(path)
        for cls, method in CALL.findall(source):
            if method in IGNORE:
                continue
            # Skip ALL_CAPS receivers: those are constants like Color.CRIMSON,
            # not classes, and "CRIMSON.lerp()" is not an API anyone looks up.
            if cls.isupper():
                continue
            found.add("%s.%s()" % (cls, method))
        for name in BARE.findall(source):
            found.add(name + "()")
        for name in TYPE.findall(source):
            found.add(name)
    return found


def descriptions():
    """demo -> one-line description, from the root README index."""
    root = read("README.md")
    return dict(re.findall(r"^\| \[([a-z0-9-]+)\]\([a-z0-9-]+\) \| (.+?) \|$", root, re.M))


def path_neighbours():
    """demo -> demos adjacent to it in a learning path."""
    if not os.path.exists(PATHS_DOC):
        return {}
    neighbours = defaultdict(set)
    for block in read(PATHS_DOC).split("\n## "):
        steps = re.findall(r"^\| \d+ \| \[([a-z0-9-]+)\]", block, re.M)
        for i, demo in enumerate(steps):
            if i > 0:
                neighbours[demo].add(steps[i - 1])
            if i + 1 < len(steps):
                neighbours[demo].add(steps[i + 1])
    return neighbours


def build_api_index(usage, descs):
    lines = ["# API index", "",
             "Which demo shows a given engine API. Generated by `tools/build_index.py`",
             "from the demos' actual source, so it cannot drift from the code.", "",
             "APIs used by a single demo are the most useful entries here — they are the",
             "ones where you are looking for *the* example rather than *an* example.", ""]

    by_count = defaultdict(list)
    for api, users in usage.items():
        by_count[len(users)].append(api)

    single = sorted(by_count.get(1, []))
    if single:
        lines += ["## Shown by exactly one demo", "", "| API | Demo |", "|-----|------|"]
        for api in single:
            demo = sorted(usage[api])[0]
            lines.append("| `%s` | [%s](../%s) |" % (api, demo, demo))
        lines.append("")

    lines += ["## Everything else", "", "| API | Demos |", "|-----|-------|"]
    for api in sorted(usage):
        users = sorted(usage[api])
        if len(users) == 1:
            continue
        links = ", ".join("[%s](../%s)" % (d, d) for d in users[:8])
        if len(users) > 8:
            links += " _(+%d more)_" % (len(users) - 8)
        lines.append("| `%s` | %s |" % (api, links))

    lines += ["", "---", "", "_%d APIs across %d demos._" % (len(usage), len(descs))]
    return "\n".join(lines) + "\n"


def tags_of():
    """demo -> its concept tags, as tools/build_tags.py wrote them."""
    tags = {}
    for demo in demos():
        path = os.path.join(demo, "README.md")
        if not os.path.exists(path):
            continue
        match = re.search(r"<!-- tags: ([^>]*?) -->", read(path))
        if not match or match.group(1).strip() == "none":
            tags[demo] = set()
            continue
        tags[demo] = {t.strip() for t in match.group(1).split(",") if t.strip()}
    return tags


def categories():
    """demo -> the index section it is listed under in the root README."""
    section = None
    found = {}
    for line in read("README.md").split("\n"):
        heading = re.match(r"^### (.+)$", line)
        if heading:
            section = heading.group(1).strip()
            continue
        row = re.match(r"^\| \[([a-z0-9-]+)\]", line)
        if row and section:
            found[row.group(1)] = section
    return found


def related_for(demo, apis, usage, neighbours, tags, categories_by_demo, limit=4):
    """Score every other demo by shared APIs, weighted toward rare ones."""
    scores = defaultdict(float)
    for api in apis.get(demo, ()):
        users = usage[api]
        if len(users) < 2 or len(users) > 25:
            continue                      # unique to this demo, or too common to mean anything
        # A rare shared API is strong evidence; a common one is nearly none.
        weight = 1.0 / math.log(1.0 + len(users))
        for other in users:
            if other != demo:
                scores[other] += weight

    # A curated ordering beats any statistic, so path neighbours outrank it.
    for other in neighbours.get(demo, ()):
        scores[other] += 5.0

    ranked = sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))
    chosen = [name for name, score in ranked[:limit] if score > 0.4]
    if chosen:
        return chosen

    # Nothing shared an API worth counting. Rather than leave the demo a dead
    # end, fall back to concept tags: a weaker signal, but "these three are
    # also about shaders" still beats sending the reader back to the index.
    mine = tags.get(demo, set())
    by_overlap = defaultdict(float)
    for other, theirs in tags.items():
        if other == demo or not mine:
            continue
        shared = mine & theirs
        if not shared:
            continue
        # A tag only a few demos carry says more than one half of them share.
        for tag in shared:
            holders = sum(1 for t in tags.values() if tag in t)
            by_overlap[other] += 1.0 / math.log(2.0 + holders)
    ranked = sorted(by_overlap.items(), key=lambda kv: (-kv[1], kv[0]))
    if ranked:
        return [name for name, score in ranked[:limit]]

    # No API in common and no tag in common — the smallest demos land here.
    # The index already sorts every demo into a category, which is the last
    # honest thing to relate them by.
    mine = categories_by_demo.get(demo)
    if not mine:
        return []
    siblings = sorted(other for other, category in categories_by_demo.items()
                      if category == mine and other != demo)
    return siblings[:limit]


def write_related(demo, related, descs):
    """Replace or append the Related demos block in a README."""
    path = demo + "/README.md"
    text = read(path)
    block_lines = [RELATED_HEADING, ""]
    for other in related:
        block_lines.append("- [%s](../%s) — %s" % (other, other, descs.get(other, "")))
    block_lines.append("")
    block_lines.append("<sub>Generated by `tools/build_index.py` from shared APIs and "
                       "[learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>")
    block = "\n".join(block_lines) + "\n"

    existing = re.search(r"^## Related demos\n.*?(?=^## |\Z)", text, re.S | re.M)
    if existing:
        updated = text[:existing.start()] + block + "\n" + text[existing.end():]
    else:
        updated = text.rstrip() + "\n\n" + block
    return path, updated


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="fail if the generated files are out of date")
    args = parser.parse_args()

    names = demos()
    apis = {d: apis_of(d) for d in names}
    usage = defaultdict(set)
    for demo, found in apis.items():
        for api in found:
            usage[api].add(demo)

    descs = descriptions()
    neighbours = path_neighbours()
    tags = tags_of()
    categories_by_demo = categories()

    pending = {API_INDEX: build_api_index(usage, descs)}
    linked = 0
    for demo in names:
        related = related_for(demo, apis, usage, neighbours, tags, categories_by_demo)
        if not related:
            continue
        path, content = write_related(demo, related, descs)
        pending[path] = content
        linked += 1

    stale = [p for p, content in pending.items()
             if not os.path.exists(p) or read(p) != content]

    if args.check:
        if stale:
            print("out of date — run tools/build_index.py:", file=sys.stderr)
            for path in sorted(stale)[:10]:
                print("  " + path, file=sys.stderr)
            if len(stale) > 10:
                print("  ... and %d more" % (len(stale) - 10), file=sys.stderr)
            return 1
        print("API index and related-demo links are up to date")
        return 0

    os.makedirs(os.path.dirname(API_INDEX), exist_ok=True)
    for path, content in pending.items():
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content)

    print("wrote %s (%d APIs) and related links for %d/%d demos"
          % (API_INDEX, len(usage), linked, len(names)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
