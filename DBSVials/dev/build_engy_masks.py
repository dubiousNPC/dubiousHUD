#!/usr/bin/env python3
"""Builds the two Battlespire masks from the supplied art.

Both are white-with-alpha so they can be tinted to any colour at runtime.

  dbs_ENGY_liquid.png    32 frames, the liquid region of each ENGY frame
  dbs_ENGY_backing.png   1 frame, the area enclosed by the frame's outline

The liquid region is found by DIFFERENCE against the atlas's own last frame,
which is the empty tube: whatever differs from the empty tube is liquid. Picking
it out by colour instead would have to separate a saturated liquid from the
glass highlights over it, and the near-empty frames are white and red, which is
exactly where that would fail.

Needs the ImageMagick 7 binary on PATH as `magick`, or at $MAGICK.
"""
import os, subprocess, sys, struct, zlib

W, H, FRAMES = 28, 82, 32
SRC   = 'textures/dbsvials/ENGY01.png'
FRAME = 'textures/dbsvials/dbs_ENGY_frame.png'
OUT_LIQUID  = 'textures/dbsvials/dbs_ENGY_liquid.png'
OUT_BACKING = 'textures/dbsvials/dbs_ENGY_backing.png'
MAGICK = os.environ.get('MAGICK', 'magick')
THRESHOLD = 28          # per-channel difference that counts as liquid, of 255

def rgba(path, crop=None):
    """Read a PNG as a flat list of (r,g,b,a) via magick's raw RGBA output."""
    args = [MAGICK, path]
    if crop:
        args += ['-crop', crop, '+repage']
    args += ['-depth', '8', 'RGBA:-']
    raw = subprocess.run(args, check=True, stdout=subprocess.PIPE).stdout
    return [tuple(raw[i:i+4]) for i in range(0, len(raw), 4)]

def write_png(path, w, h, px):
    """Write RGBA8 without a PNG library."""
    rows = b''.join(b'\x00' + bytes(b for p in px[y*w:(y+1)*w] for b in p)
                    for y in range(h))
    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c))
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(rows, 9))
           + chunk(b'IEND', b''))
    open(path, 'wb').write(png)

def build_liquid():
    empty = rgba(SRC, f'{W}x{H}+0+{(FRAMES-1)*H}')
    out = []
    for f in range(FRAMES):
        frame = rgba(SRC, f'{W}x{H}+0+{f*H}')
        for i, (p, e) in enumerate(zip(frame, empty)):
            differs = (abs(p[0]-e[0]) > THRESHOLD or abs(p[1]-e[1]) > THRESHOLD
                       or abs(p[2]-e[2]) > THRESHOLD)
            # keep the source's own alpha so the edges stay anti-aliased
            out.append((255, 255, 255, p[3]) if (differs and p[3] > 0)
                       else (255, 255, 255, 0))
    write_png(OUT_LIQUID, W, H * FRAMES, out)
    lit = sum(1 for p in out if p[3] > 0)
    print(f'{OUT_LIQUID}: {FRAMES} frames, {lit} lit pixels')

def build_backing():
    """The tube's interior, row by row.

    A flood fill is the obvious way and the wrong one here: the outline is not
    closed. Rows 3 and 4 have no outline at all and row 5 only has its left
    side, so a flood leaks out through the neck and fills the whole canvas.

    Each row's interior is taken as the span between its leftmost and rightmost
    outline pixel instead. A row with no outline, or with the outline on one
    side only, inherits the row above -- which is right for this art, because
    those rows are the straight part of the collar.
    """
    px = rgba(FRAME, f'{W}x{H}+0+0')
    wall = [p[3] > 100 for p in px]
    out = [(255, 255, 255, 0)] * (W * H)
    span = None
    for y in range(H):
        xs = [x for x in range(W) if wall[y * W + x]]
        if xs and xs[-1] - xs[0] >= 4:
            span = (xs[0], xs[-1])
        if span is None:
            continue
        for x in range(span[0] + 1, span[1]):
            if not wall[y * W + x]:
                out[y * W + x] = (255, 255, 255, 255)
    write_png(OUT_BACKING, W, H, out)
    print(f'{OUT_BACKING}: {sum(1 for p in out if p[3] > 0)} pixels enclosed')

if __name__ == '__main__':
    build_liquid()
    build_backing()
