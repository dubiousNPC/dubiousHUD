#!/usr/bin/env python3
"""Builds the lit overlays for the demon frames from their detail sheets.

    MAGICK=/path/to/magick python3 dev/build_eye_glow.py

A `PANEL_detail` sheet is a source, not an overlay. It holds two different
things on one canvas:

  marks   one pixel each, where a gargoyle's eye is. Blown up to HUD size a
          single pixel is a square, so the glow is drawn here rather than
          scaled up from the sheet.

  orb     a few hundred pixels, already drawn, sitting over the socket in the
          frame. That one is finished art and is taken as it is.

Telling them apart by size is not a heuristic that might go wrong: an eye is
ONE pixel and an orb is several hundred, with nothing in between.

Positions are read as FRACTIONS of the sheet, so a detail sheet and the frame
it belongs to need not be the same size -- the narrow pair are 149x100 and
191x128, drawn at different times. What they do have to share is their aspect,
which is checked, because a mark placed by fraction onto a differently
proportioned canvas lands somewhere else entirely.

Output is white for the eyes, so the overlay tint decides their colour, and
untouched for the orb, which is already the colour it should be.
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

JOBS = [
    {
        'detail': 'PANEL_detail.png',
        'frame': 'PANEL_demons.png',
        'eyes': 'PANEL_demons_eyes.png',
        'orb': 'PANEL_demons_orb.png',
    },
    {
        'detail': 'PANEL_detail_WIDE.png',
        'frame': 'PANEL_demons_WIDE_R.png',
        'eyes': 'PANEL_demons_wide_eyes.png',
        'orb': 'PANEL_demons_wide_orb.png',
    },
]

SCALE = 4          # eye-glow resolution relative to the frame
RADIUS = 0.018     # glow radius as a fraction of the frame's WIDTH
CORE = 0.3         # fraction of the radius that stays at full brightness

# An eye is one pixel and an orb is hundreds. Anything in between would be
# something nobody has drawn yet, so it is reported rather than guessed at.
MARK_MAX = 8
ORB_MIN = 50
ASPECT_TOLERANCE = 0.02


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


def build_eyes(marks, fw, fh, out):
    """Soft glows at each mark, white, at SCALE times the frame's size."""
    w, h = fw * SCALE, fh * SCALE
    r = RADIUS * w
    px = [(255, 255, 255, 0)] * (w * h)
    for fx, fy in marks:
        cx, cy = fx * w, fy * h
        x0, x1 = max(0, int(cx - r) - 1), min(w, int(cx + r) + 2)
        y0, y1 = max(0, int(cy - r) - 1), min(h, int(cy + r) + 2)
        for y in range(y0, y1):
            for x in range(x0, x1):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
                if d >= 1:
                    continue
                # flat core, then a squared falloff, so it reads as a lit eye
                # rather than a soft blob with no centre
                a = 1.0 if d <= CORE else (1 - (d - CORE) / (1 - CORE)) ** 2
                i = y * w + x
                px[i] = (255, 255, 255, max(px[i][3], int(a * 255 + 0.5)))
    write_png(out, w, h, px)
    return w, h, sum(1 for p in px if p[3] > 0)


def build_orb(pts, sw, sh, raw, fw, fh, out):
    """The orb as drawn, on a canvas the shape of the frame.

    Copied pixel for pixel and placed by fraction, so it keeps its own art and
    still lands on the socket when the frame is a different size.
    """
    px = [(0, 0, 0, 0)] * (fw * fh)
    kx, ky = fw / sw, fh / sh
    for sx, sy in pts:
        o = (sy * sw + sx) * 4
        fx, fy = int(sx * kx), int(sy * ky)
        for dy in range(max(1, int(math.ceil(ky)))):
            for dx in range(max(1, int(math.ceil(kx)))):
                x, y = fx + dx, fy + dy
                if 0 <= x < fw and 0 <= y < fh:
                    px[y * fw + x] = tuple(raw[o:o + 4])
    write_png(out, fw, fh, px)
    return sum(1 for p in px if p[3] > 0)


def main():
    for job in JOBS:
        sw, sh, raw = read_rgba(os.path.join(TEX, job['detail']))
        fw, fh, _ = read_rgba(os.path.join(TEX, job['frame']))
        a1, a2 = sw / sh, fw / fh
        if abs(a1 - a2) > ASPECT_TOLERANCE * a2:
            raise SystemExit(
                '%s is %dx%d (aspect %.3f) and %s is %dx%d (aspect %.3f) -- a '
                'mark placed by fraction would land somewhere else'
                % (job['detail'], sw, sh, a1, job['frame'], fw, fh, a2))

        cl = clusters(sw, sh, raw)
        marks = [c for c in cl if len(c) <= MARK_MAX]
        orbs = [c for c in cl if len(c) >= ORB_MIN]
        odd = [c for c in cl if MARK_MAX < len(c) < ORB_MIN]
        if odd:
            raise SystemExit('%s has a %d-pixel cluster, which is neither an '
                             'eye nor an orb' % (job['detail'], len(odd[0])))

        frac = [((sum(x for x, _ in c) / len(c) + 0.5) / sw,
                 (sum(y for _, y in c) / len(c) + 0.5) / sh) for c in marks]
        print('%s: %d eye marks at %s' % (job['detail'], len(frac),
              ', '.join('(%.1f%%, %.1f%%)' % (100 * a, 100 * b) for a, b in frac)))

        # Eyes come in pairs, and a frame with two gargoyles wants four marks.
        # An odd count means the sheet is missing one -- which looks exactly
        # like a deliberately one-eyed creature until you put the two heads
        # side by side, so it is said out loud rather than left to be noticed.
        if len(frac) % 2 == 1:
            left = [f for f in frac if f[0] < 0.5]
            right = [f for f in frac if f[0] >= 0.5]
            short = 'left' if len(left) < len(right) else 'right'
            print('   WARNING: %d marks, so one head has fewer than the other '
                  '(%d on the left, %d on the right). The %s gargoyle is a mark '
                  'short in %s.' % (len(frac), len(left), len(right), short,
                                    job['detail']))

        w, h, n = build_eyes(frac, fw, fh, os.path.join(TEX, job['eyes']))
        print('   %s  %dx%d  %d lit pixels' % (job['eyes'], w, h, n))

        if orbs:
            n = build_orb(orbs[0], sw, sh, raw, fw, fh,
                          os.path.join(TEX, job['orb']))
            cx = sum(x for x, _ in orbs[0]) / len(orbs[0]) / sw
            cy = sum(y for _, y in orbs[0]) / len(orbs[0]) / sh
            print('   %s  %dx%d  %d px at (%.1f%%, %.1f%%)'
                  % (job['orb'], fw, fh, n, 100 * cx, 100 * cy))


if __name__ == '__main__':
    main()
