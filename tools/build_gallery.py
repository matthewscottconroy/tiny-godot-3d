#!/usr/bin/env python3
"""Build a visual index from the per-demo screenshots.

The root README is rows of text with no pictures — you cannot tell what any demo
looks like without cloning the repo and installing Godot. That costs more in 3D
than in 2D, where a name like `bouncing-ball` tells you most of it. This turns
the same index into a contact sheet, reusing the descriptions and categories
that are already there.

    tools/screenshots.sh          # capture docs/img/<demo>.png
    tools/build_gallery.py        # write docs/GALLERY.md

Demos without a screenshot are still listed, so a partial capture degrades to
the text index rather than silently dropping demos.
"""

import glob
import os
import re
import sys

IMG_DIR = "docs/img"
OUT = "docs/GALLERY.md"
COLUMNS = 3

HEADER = """# Gallery

Every demo, with a frame captured from its actual running scene. Click a demo to
open its README.

Screenshots are produced by `tools/screenshots.sh`, which runs each demo under a
virtual display and keeps one frame — so they show the real thing rather than
hand-picked marketing shots. A demo whose image is missing simply has not been
captured yet.

Looking for a route rather than a catalogue? See [learning paths](LEARNING_PATHS.md).

"""


def parse_index(readme):
    """Return [(category, [(demo, description), ...]), ...] from the root README."""
    categories = []
    current = None
    for line in readme.splitlines():
        heading = re.match(r"^### (.+)$", line)
        if heading:
            current = (heading.group(1).strip(), [])
            categories.append(current)
            continue
        row = re.match(r"^\| \[([a-z0-9-]+)\]\([a-z0-9-]+\) \| (.+?) \|$", line)
        if row and current is not None:
            current[1].append((row.group(1), row.group(2).strip()))
    return [c for c in categories if c[1]]


def cell(demo, description, has_image, has_motion=False):
    """One gallery cell: image (or placeholder), name, description.

    A large part of this collection is motion — a still of boid-flocking or
    wind-effect says almost nothing — so an animation is preferred when
    tools/screenshots.sh was run with MOTION=1.
    """
    if has_motion:
        image = "[![%s](img/%s.webp)](../%s)" % (demo, demo, demo)
    elif has_image:
        image = "[![%s](img/%s.png)](../%s)" % (demo, demo, demo)
    else:
        image = "_(no screenshot yet)_"
    return "%s<br>**[%s](../%s)**<br><sub>%s</sub>" % (image, demo, demo, description)


def main():
    if not os.path.exists("README.md"):
        print("run this from the repository root", file=sys.stderr)
        return 2

    with open("README.md", encoding="utf-8") as handle:
        categories = parse_index(handle.read())
    if not categories:
        print("could not parse any demos out of README.md", file=sys.stderr)
        return 2

    available = {os.path.basename(p)[:-4] for p in glob.glob(IMG_DIR + "/*.png")}
    animated = {os.path.basename(p)[:-5] for p in glob.glob(IMG_DIR + "/*.webp")}

    out = [HEADER]
    total = 0
    shown = 0
    for name, demos in categories:
        out.append("## %s\n" % name)
        out.append("| | | |")
        out.append("|---|---|---|")
        row = []
        for demo, description in demos:
            total += 1
            if demo in available:
                shown += 1
            row.append(cell(demo, description, demo in available, demo in animated))
            if len(row) == COLUMNS:
                out.append("| " + " | ".join(row) + " |")
                row = []
        if row:
            row += [""] * (COLUMNS - len(row))
            out.append("| " + " | ".join(row) + " |")
        out.append("")

    out.append("---\n")
    out.append("_%d demos, %d with screenshots, %d animated._" % (total, shown, len(animated)))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(out) + "\n")

    print("wrote %s — %d demos, %d with screenshots" % (OUT, total, shown))
    return 0


if __name__ == "__main__":
    sys.exit(main())
