#!/usr/bin/env python3
"""Flag a captured screenshot that shows nothing.

`tools/check_docs.py` already refuses a main scene with no light in it, because
the editor supplies a preview light that is not part of the scene: a scene
written by hand renders perfectly in the editor and black everywhere else. That
check reads the scene file and reasons about it.

This is the same question asked of the render instead. It cannot be fooled by a
scene that is lit and still shows nothing — a camera pointing at the sky, a mesh
built with no surface, a subject a hundred metres away — because it looks at the
pixels that actually came out.

It found `lod-and-decals`, whose camera started forty metres from props whose
losing detail was the entire subject: 97.8% of the viewport was a single colour,
the highest in the collection by a wide margin and a demo you could not learn
anything from.

    tools/check_gallery.py            # every captured screenshot
    tools/check_gallery.py --list     # print every score, worst first

Screenshots are optional — `docs/GALLERY.md` says so — and a demo with no image
is not a failure here. Only a captured one that turned out empty is.

No third-party imports, like every other tool here. Godot's Movie Maker writes
8-bit RGB non-interlaced PNGs, which zlib and forty lines of un-filtering can
read; requiring Pillow to run the doc checks would be a poor trade.
"""

import collections
import glob
import os
import struct
import sys
import zlib

# Above this share of the viewport in one flat colour, a frame is not showing
# the demo. Measured against the collection: the worst honest frame sits around
# 81% — a demo with a large plain floor and sky — and the broken one sat at
# 97.8%, so there is a wide gap to put the line in.
FLAT_LIMIT = 0.92

# The HUD is drawn in bands at the top and bottom of every demo. Text there is
# busy enough to disguise an otherwise empty viewport, so it is cropped out
# before measuring rather than counted as content.
CROP_TOP = 0.18
CROP_BOTTOM = 0.90

# Demos whose frame is legitimately near-flat, with the reason. Empty so far.
FLAT_EXEMPT = {}

IMG_DIR = "docs/img"


def _unfilter(raw, width, height, bpp):
    """Undo the per-scanline PNG filters. Returns the raw pixel bytes."""
    stride = width * bpp
    out = bytearray(stride * height)
    previous = bytearray(stride)
    pos = 0
    for row in range(height):
        filter_type = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filter_type == 1:            # Sub
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif filter_type == 2:          # Up
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == 3:          # Average
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filter_type == 4:          # Paeth
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                up = previous[i]
                up_left = previous[i - bpp] if i >= bpp else 0
                estimate = left + up - up_left
                da, db, dc = (abs(estimate - left), abs(estimate - up),
                              abs(estimate - up_left))
                if da <= db and da <= dc:
                    nearest = left
                elif db <= dc:
                    nearest = up
                else:
                    nearest = up_left
                line[i] = (line[i] + nearest) & 0xFF
        elif filter_type != 0:
            raise ValueError("unsupported PNG filter %d" % filter_type)
        out[row * stride:(row + 1) * stride] = line
        previous = line
    return bytes(out)


def read_png(path):
    """(width, height, pixel bytes) for an 8-bit RGB non-interlaced PNG."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    width = height = None
    idat = []
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(
                ">IIBBBBB", body[:13])
            if (depth, colour, interlace) != (8, 2, 0):
                raise ValueError(
                    "expected 8-bit RGB non-interlaced, got depth %d colour %d "
                    "interlace %d" % (depth, colour, interlace))
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
        pos += 12 + length
    if width is None:
        raise ValueError("no IHDR")
    return width, height, _unfilter(zlib.decompress(b"".join(idat)),
                                    width, height, 3)


def flatness(path):
    """The share of the viewport taken by its single most common colour."""
    width, height, pixels = read_png(path)
    top, bottom = int(height * CROP_TOP), int(height * CROP_BOTTOM)
    counts = collections.Counter()
    for row in range(top, bottom):
        base = row * width * 3
        line = pixels[base:base + width * 3]
        for i in range(0, len(line), 3):
            counts[line[i:i + 3]] += 1
    total = sum(counts.values())
    return counts.most_common(1)[0][1] / total if total else 1.0


def main():
    show_all = "--list" in sys.argv
    shots = sorted(glob.glob(os.path.join(IMG_DIR, "*.png")))
    if not shots:
        print("no screenshots in %s — nothing to check "
              "(run tools/screenshots.sh first)" % IMG_DIR)
        return 0

    scored = []
    problems = []
    for path in shots:
        demo = os.path.basename(path)[:-4]
        try:
            share = flatness(path)
        except ValueError as error:
            problems.append("%s: cannot read (%s)" % (demo, error))
            continue
        scored.append((share, demo))
        if share > FLAT_LIMIT and demo not in FLAT_EXEMPT:
            problems.append(
                "%s: %.1f%% of the frame is one flat colour (over %.0f%%) — the "
                "demo rendered almost nothing. Point the camera at the subject, "
                "or add it to FLAT_EXEMPT with the reason."
                % (demo, share * 100, FLAT_LIMIT * 100))

    if show_all:
        for share, demo in sorted(scored, reverse=True):
            print("  %6.1f%%  %s" % (share * 100, demo))

    if problems:
        print("%d problem(s):\n" % len(problems))
        for problem in problems:
            print("  " + problem)
        return 1

    print("checked %d screenshot(s) — none of them empty" % len(scored))
    return 0


if __name__ == "__main__":
    sys.exit(main())
