#!/usr/bin/env python3
"""Builds a 360-frame needle atlas from a single drawing of a needle.

    MAGICK=/path/to/magick python3 dev/build_needle_atlas.py

Frame *h* holds the needle as it should look while the player faces heading *h*.
A needle that points north has to turn ANTICLOCKWISE as the heading increases:
face east (heading 90) and north is ninety degrees to your left, so the needle
points left, which is 270 clockwise from up. So frame h is the artwork rotated
anticlockwise by h, and the preset needs neither `headingOffset` nor `invert`.

ImageMagick's SRT angle turns clockwise, hence the negated angle below.

Each frame is rotated about the needle's HUB rather than the centre of its
canvas, and lands back on a canvas the same size as the source. Two things fall
out of that, both wanted:

  * the hub does not move between frames, so the needle spins rather than
    wobbling -- the usual bug when a needle is drawn off-centre;
  * the frame stays registered against the backdrop it was drawn on, so the
    preset is `overlayScale = 100` with the anchors at the middle and the hub
    lands wherever the artwork puts it, with nothing to line up by hand.

The hubs below were measured, not chosen: see `measure_hub` at the bottom, which
is how each one was found and is worth re-running if the artwork changes.
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

FRAMES = 360
COLS = 30
ROWS = FRAMES // COLS

# source, output, cell size, hub in SOURCE pixels
JOBS = [
    {
        'src': 'DBSpretty_compass_needle.png',
        'out': 'DBSpretty_needle_360.png',
        'cell': 128,
        # the ball is x56..70, y59..69; its alpha-weighted centre is the canvas
        # centre to within half a pixel, which is what the artwork intends, and
        # the shaft reaches forty pixels either side of it
        'hub': (63.5, 64.0),
    },
    {
        'src': 'RG_compass_needle.png',
        'out': 'RG_needle_360.png',
        'cell': 128,
        # the blue gem, which is NOT the centre of the canvas: the star sits
        # about seven pixels high in its 128 square, exactly as the supplied
        # RG_compass.png composes it. The artwork is 128 now, so the cell is
        # 1:1 and nothing is resampled on the way into the sheet.
        'hub': (63.0, 56.1),
    },
]


def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL)


def size_of(path):
    out = subprocess.run([MAGICK, 'identify', '-format', '%w %h', path],
                         check=True, stdout=subprocess.PIPE).stdout
    return [int(x) for x in out.split()]


def read_rgba(path):
    w, h = size_of(path)
    raw = subprocess.run([MAGICK, path, '-depth', '8', 'RGBA:-'],
                         check=True, stdout=subprocess.PIPE).stdout
    return w, h, raw


def write_png(path, w, h, raw):
    """RGBA8 straight out, without a PNG library."""
    rows = b''.join(b'\x00' + raw[y * w * 4:(y + 1) * w * 4] for y in range(h))

    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c))

    open(path, 'wb').write(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(rows, 9))
        + chunk(b'IEND', b''))


def clearance(src, hub):
    """Furthest any opaque pixel sits from the hub, in source pixels.

    If that exceeds half the canvas the needle would be clipped as it turns,
    and the atlas would quietly lose its tip at some headings.
    """
    w, h, raw = read_rgba(src)
    hx, hy = hub
    worst = 0.0
    for y in range(h):
        row = y * w * 4
        for x in range(w):
            if raw[row + x * 4 + 3] > 10:
                d = math.hypot(x - hx, y - hy)
                if d > worst:
                    worst = d
    return worst, w, h


def build(job):
    src = os.path.join(TEX, job['src'])
    out = os.path.join(TEX, job['out'])
    cell = job['cell']
    hx, hy = job['hub']

    reach, sw, sh = clearance(src, (hx, hy))
    room = min(hx, hy, sw - 1 - hx, sh - 1 - hy)
    print('%s: %dx%d, hub (%.1f, %.1f), reach %.1f, room %.1f'
          % (job['src'], sw, sh, hx, hy, reach, room))
    if reach > room + 0.5:
        raise SystemExit(
            '  the needle reaches %.1fpx from its hub but only %.1fpx of canvas '
            'is available -- it would be clipped as it turns' % (reach, room))

    tmp = os.path.join(os.path.dirname(out), '_frame_tmp.png')
    atlas = bytearray(COLS * cell * ROWS * cell * 4)
    stride = COLS * cell * 4

    for i in range(FRAMES):
        # negated: SRT turns clockwise and the needle has to turn the other way
        run([MAGICK, src, '-virtual-pixel', 'none',
             '-distort', 'SRT', '%f,%f 1 %f' % (hx, hy, -i),
             '-filter', 'Lanczos', '-resize', '%dx%d!' % (cell, cell),
             '-depth', '8', 'PNG32:' + tmp])
        _, _, raw = read_rgba(tmp)
        cx, cy = (i % COLS) * cell, (i // COLS) * cell
        for y in range(cell):
            a = (cy + y) * stride + cx * 4
            b = y * cell * 4
            atlas[a:a + cell * 4] = raw[b:b + cell * 4]
        if i % 60 == 0:
            print('   frame %3d' % i)

    os.remove(tmp)
    write_png(out, COLS * cell, ROWS * cell, bytes(atlas))
    print('   wrote %s  %dx%d  %d frames, %d cols, cell %d'
          % (job['out'], COLS * cell, ROWS * cell, FRAMES, COLS, cell))


def measure_hub(path, test):
    """Centroid of the pixels `test` accepts -- how the hubs above were found."""
    w, h, raw = read_rgba(path)
    sx = sy = n = 0
    for y in range(h):
        row = y * w * 4
        for x in range(w):
            p = raw[row + x * 4: row + x * 4 + 4]
            if p[3] > 10 and test(p):
                sx += x
                sy += y
                n += 1
    return (sx / n, sy / n, n) if n else (None, None, 0)


if __name__ == '__main__':
    # Name one or more sources to rebuild just those. Each atlas takes a few
    # minutes, and redrawing one needle is no reason to redraw the other.
    want = [a.lower() for a in sys.argv[1:]]
    todo = [j for j in JOBS
            if not want or any(a in j['src'].lower() or a in j['out'].lower()
                               for a in want)]
    if not todo:
        raise SystemExit('nothing matches %s; known sources: %s'
                         % (', '.join(want), ', '.join(j['src'] for j in JOBS)))
    for job in todo:
        build(job)
