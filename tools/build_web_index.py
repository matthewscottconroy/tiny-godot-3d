#!/usr/bin/env python3
"""Build the landing page for the playable web gallery.

Reads the categories and descriptions out of the root README, then writes an
index that links to whichever demos actually exported. Demos that did not export
— or that are skipped because they cannot work in a browser — are listed with
the reason instead of a dead link.

    tools/export_web.sh
    tools/build_web_index.py        # writes build/web/index.html
"""

import glob
import html
import os
import re
import sys

OUT_DIR = os.environ.get("OUT", "build/web")

# Demos tools/export_web.sh skips, and why. Shown on the page so a visitor
# understands the absence rather than assuming the gallery is broken.
# Demos tools/export_web.sh skips, and why. Shown on the page so a visitor
# understands the absence rather than assuming the gallery is broken.
UNAVAILABLE = {
    "multiplayer-3d": "needs UDP; browsers cannot open raw sockets",
}

PAGE = """<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tiny Godot 3D</title>
<style>
  :root {{ color-scheme: light dark; }}
  body {{ font: 16px/1.5 system-ui, sans-serif; margin: 0 auto; max-width: 1100px;
         padding: 2rem 1rem 4rem; }}
  h1 {{ margin-bottom: .25rem; }}
  .lede {{ opacity: .75; margin-top: 0; }}
  h2 {{ margin-top: 2.5rem; border-bottom: 1px solid rgba(128,128,128,.3);
        padding-bottom: .3rem; }}
  ul {{ list-style: none; padding: 0; display: grid; gap: .75rem;
        grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); }}
  li {{ border: 1px solid rgba(128,128,128,.3); border-radius: 8px; padding: .75rem; }}
  li.off {{ opacity: .55; }}
  a {{ font-weight: 600; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  p {{ margin: .35rem 0 0; font-size: .9rem; opacity: .8; }}
  .why {{ font-style: italic; }}
</style>
<h1>Tiny Godot 3D</h1>
<p class="lede">{count} demos, each isolating one 3D game-development concept.
Click any of them to run it in the browser —
<a href="https://github.com/matthewscottconroy/tiny-godot-3d">source on GitHub</a>.</p>
{body}
"""


def parse_index(readme):
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


def main():
    if not os.path.exists("README.md"):
        print("run this from the repository root", file=sys.stderr)
        return 2

    with open("README.md", encoding="utf-8") as handle:
        categories = parse_index(handle.read())

    built = {os.path.basename(os.path.dirname(p))
             for p in glob.glob(os.path.join(OUT_DIR, "*", "index.html"))}

    sections = []
    playable = 0
    for name, demos in categories:
        items = []
        for demo, description in demos:
            desc = html.escape(description)
            if demo in built:
                playable += 1
                items.append('<li><a href="%s/index.html">%s</a><p>%s</p></li>'
                             % (demo, demo, desc))
            else:
                why = UNAVAILABLE.get(demo, "not exported")
                items.append('<li class="off"><b>%s</b><p>%s</p>'
                             '<p class="why">unavailable in the browser — %s</p></li>'
                             % (demo, desc, html.escape(why)))
        sections.append("<h2>%s</h2>\n<ul>\n%s\n</ul>" % (html.escape(name), "\n".join(items)))

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "index.html"), "w", encoding="utf-8") as handle:
        handle.write(PAGE.format(count=playable, body="\n".join(sections)))

    print("wrote %s/index.html — %d playable" % (OUT_DIR, playable))
    return 0


if __name__ == "__main__":
    sys.exit(main())
