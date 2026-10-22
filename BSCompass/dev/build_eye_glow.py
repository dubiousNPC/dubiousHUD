#!/usr/bin/env python3
"""Builds the glowing-eyes overlay for the demon frame.

    MAGICK=/path/to/magick python3 dev/build_eye_glow.py

`PANEL_detail.png` is a source sheet, not an overlay. It carries the eye
positions as FOUR SINGLE PIXELS -- two per gargoyle -- alongside a '?' button
that belongs to the original Battlespire panel and has no business on a compass.
Pointed at the overlay machinery as it stands it would draw the button and
nothing you could see of the eyes, so the positions are read out of it and the
glow is drawn here.

Rendered at four times the frame's resolution: a glow is all gradient, and one
source pixel blown up to HUD size is a square.

The output is white, so the overlay tint decides the colour -- the same
arrangement the DBS_CompassEYES overlays use.
"""
import math
import os
import struct
import subprocess
import sys
import zlib

MAGICK = os.environ.get('MAGICK', 'magick')
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   '..', 'textures', 'bscompass')

SRC = 'PANEL_detail.png'
FRAME = 'PANEL_demons.png'
OUT = 'PANEL_demons_eyes.png'

SCALE = 4          # output resolution relative to the frame
RADIUS = 2.3       # glow radius in SOURCE pixels
CORE = 0.3         # fraction of the radius that stays at full brightness

# The two eyes of one gargoyle are about four pixels apart, so a radius much
# over two merges them into one blob and the creature looks cycloptic.

# The '?' button is a cluster of hundreds of pixels; an eye is one pixel. Any
# threshold between the two separates them, and this one is nowhere near either.
MAX_EYE_PIXELS = 8


def read_rgba(path):
    w, h = [int(x) for x in subprocess.run(
        [MAGICK, 'identify', '-format', '%w %h', path],
        check=True, stdout=subprocess.PIPE).stdout.split()]
    raw = subprocess.run([MAGICK, path, '-depth', '8', 'RGBA:-'],
                         check=True, stdout=subprocess.PIPE).stdout
    return w, h, raw


def write_png(path, w, h, px):
    rows = b''.join(b'\x00' + bytes(b for p in px[y * w:(y + 1) * w] for b in p)
                    for y in range(h))

    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c))

    open(path, 'wb').write(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(rows, 9))
        + chunk(b'IEND', b''))


def clusters(w, h, raw, thr=10):
    """Connected runs of opaque pixels, largest first."""
    seen = bytearray(w * h)
    out = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if seen[i] or raw[i * 4 + 3] <= thr:
                continue
            stack = [(x, y)]
            seen[i] = 1
            pts = []
            while stack:
                cx, cy = stack.pop()
                pts.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                               (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and raw[j * 4 + 3] > thr:
                            seen[j] = 1
                            stack.append((nx, ny))
            out.append(pts)
    return sorted(out, key=len, reverse=True)


def main():
    sw, sh, raw = read_rgba(os.path.join(TEX, SRC))
    fw, fh, _ = read_rgba(os.path.join(TEX, FRAME))
    if (sw, sh) != (fw, fh):
        raise SystemExit('%s is %dx%d but %s is %dx%d -- the eyes would not '
                         'land on the heads' % (SRC, sw, sh, FRAME, fw, fh))

    eyes = [c for c in clusters(sw, sh, raw) if len(c) <= MAX_EYE_PIXELS]
    eyes = [(sum(x for x, _ in c) / len(c) + 0.5,
             sum(y for _, y in c) / len(c) + 0.5) for c in eyes]
    print('%s: %d eye marks at %s' % (SRC, len(eyes),
          ', '.join('(%.1f, %.1f)' % e for e in eyes)))
    if len(eyes) != 4:
        raise SystemExit('expected four eyes, two per gargoyle')

    w, h = sw * SCALE, sh * SCALE
    r = RADIUS * SCALE
    px = [(255, 255, 255, 0)] * (w * h)
    for ex, ey in eyes:
        cx, cy = ex * SCALE, ey * SCALE
        x0, x1 = max(0, int(cx - r) - 1), min(w, int(cx + r) + 2)
        y0, y1 = max(0, int(cy - r) - 1), min(h, int(cy + r) + 2)
        for y in range(y0, y1):
            for x in range(x0, x1):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
                if d >= 1:
                    continue
                # flat core, then a squared falloff, so it reads as a lit eye
                # rather than as a soft blob with no centre
                a = 1.0 if d <= CORE else (1 - (d - CORE) / (1 - CORE)) ** 2
                i = y * w + x
                prev = px[i][3]
                px[i] = (255, 255, 255, max(prev, int(a * 255 + 0.5)))

    write_png(os.path.join(TEX, OUT), w, h, px)
    lit = sum(1 for p in px if p[3] > 0)
    print('   wrote %s  %dx%d  %d lit pixels' % (OUT, w, h, lit))


if __name__ == '__main__':
    main()
