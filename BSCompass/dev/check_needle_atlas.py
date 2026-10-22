#!/usr/bin/env python3
"""Checks a generated needle atlas against what the preset claims about it.

    MAGICK=/path/to/magick python3 dev/check_needle_atlas.py

Four properties, each of which has a failure mode you would otherwise only find
by turning around in game:

  size      the sheet is exactly cols x rows of cell, with nothing left over.
            A sheet one row short loses its last frames to transparent cells,
            and the compass blanks at those headings.

  turn      frame h is frame 0 turned anticlockwise by h. A needle that turns
            the wrong way still looks like a compass -- it moves when you move
            -- and points the wrong way at every heading but north and south.

            Measured by cross-correlating a ring histogram of the ink against
            frame 0's, NOT by the centroid: these needles are near enough
            symmetric that their centroid sits on the hub, and the angle of a
            vector a third of a pixel long is noise.

            Only the OUTER ring goes into the histogram. The RG star has eight
            points and seven of them are alike, so a histogram of the whole
            needle correlates just as well at every multiple of 45 degrees and
            the answer it gives is a coin toss. Beyond four fifths of the
            needle's reach only the long arrow survives, and one lobe has only
            one place it can line up.

  hub       the needle's hub sits in the same place in every frame. Rotating
            about the middle of the canvas instead of about the hub is the
            usual mistake, and it makes the needle wobble round a small circle
            rather than spin.

  clipped   every frame carries the same amount of ink, and reaches the same
            distance FROM THE HUB. A needle that reaches past the edge of its
            cell loses its tip at the diagonals, which is invisible at the four
            cardinals where you would think to check.

Everything angular is measured about the hub rather than about the middle of
the cell, because for one of these two they are seven pixels apart -- and a
rotation looks like anything but a rotation when measured from the wrong
centre.
"""
import math
import os
import subprocess
import sys

MAGICK = os.environ.get('MAGICK', 'magick')
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   '..', 'textures', 'bscompass')

ATLASES = [
    {'file': 'DBSpretty_needle_360.png', 'cell': 128, 'cols': 30, 'frames': 360},
    {'file': 'RG_needle_360.png', 'cell': 128, 'cols': 30, 'frames': 360},
]

SAMPLES = [0, 1, 23, 45, 90, 137, 180, 211, 270, 315, 359]
TOLERANCE_DEG = 2.0      # a 128px cell cannot place a thin needle finer
TOLERANCE_HUB = 1.2      # pixels
TOLERANCE_INK = 0.06     # fraction


def read_cells(path, cell, cols, frames):
    """The whole sheet once, sliced into frames in memory."""
    w, h = [int(x) for x in subprocess.run(
        [MAGICK, 'identify', '-format', '%w %h', path],
        check=True, stdout=subprocess.PIPE).stdout.split()]
    raw = subprocess.run([MAGICK, path, '-depth', '8', 'RGBA:-'],
                         check=True, stdout=subprocess.PIPE).stdout
    return w, h, raw


BINS = 360
OUTER_RING = 0.9     # only ink this far out counts towards the angle


def frame_stats(raw, sheetw, cell, cols, idx, hub=(0.0, 0.0)):
    """Centroid, total ink, furthest lit pixel, and a ring histogram.

    The histogram is ink per degree around the cell centre, weighted towards
    the red end of the needle so a two-ended spindle is not symmetric to it.
    Turning the needle turns the histogram, which is the whole point.
    """
    cx0, cy0 = (idx % cols) * cell, (idx // cols) * cell
    c = (cell - 1) / 2
    hx, hy = c + hub[0], c + hub[1]
    sx = sy = tot = 0.0
    far = 0.0
    lit = []
    for y in range(cell):
        row = (cy0 + y) * sheetw * 4
        for x in range(cell):
            o = row + (cx0 + x) * 4
            a = raw[o + 3]
            if not a:
                continue
            # the centroid stays relative to the cell, so the hub can be found
            # from it; everything else is measured about the hub
            sx += (x - c) * a
            sy += (y - c) * a
            tot += a
            dx, dy = x - hx, y - hy
            d2 = dx * dx + dy * dy
            if a > 60 and d2 > far:
                far = d2
            red = max(0, raw[o] - raw[o + 2]) / 255.0
            lit.append((d2, a * (1 + 2 * red),
                        int(math.degrees(math.atan2(dx, -dy)) % 360)))
    if tot == 0:
        return None
    far = math.sqrt(far)
    cut = (OUTER_RING * far) ** 2
    hist = [0.0] * BINS
    for d2, wgt, b in lit:
        if d2 >= cut:
            hist[b % BINS] += wgt
    return sx / tot, sy / tot, tot, far, hist


def best_shift(hist, ref):
    """Degrees frame 0 must turn CLOCKWISE to land on this frame."""
    best, bestk = None, 0
    for k in range(BINS):
        dot = 0.0
        for i in range(BINS):
            dot += hist[i] * ref[(i - k) % BINS]
        if best is None or dot > best:
            best, bestk = dot, k
    return bestk


def angdiff(a, b):
    return (a - b + 180) % 360 - 180


def check(job):
    path = os.path.join(TEX, job['file'])
    cell, cols, frames = job['cell'], job['cols'], job['frames']
    rows = frames // cols
    fails = []

    if not os.path.exists(path):
        return ['%s is missing' % job['file']]

    w, h, raw = read_cells(path, cell, cols, frames)
    print('%s  %dx%d' % (job['file'], w, h))
    if (w, h) != (cols * cell, rows * cell):
        fails.append('%s is %dx%d, the preset says %d cols x %d rows of %d = %dx%d'
                     % (job['file'], w, h, cols, rows, cell,
                        cols * cell, rows * cell))
        return fails

    # The hub first: frame h and frame h+180 are reflections of each other
    # through it, so their centroids average back to it. Everything after this
    # is measured about that point.
    est = []
    for idx in (0, 45, 90, 135):
        a = frame_stats(raw, w, cell, cols, idx)
        b = frame_stats(raw, w, cell, cols, (idx + 180) % frames)
        if a and b:
            est.append(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2))
    if not est:
        return ['%s has no frames to measure' % job['file']]
    hub = (sum(e[0] for e in est) / len(est), sum(e[1] for e in est) / len(est))
    spread = max(math.hypot(e[0] - hub[0], e[1] - hub[1]) for e in est)
    print('   hub  (%.2f, %.2f) px from the cell centre, '
          'steady to %.2fpx across four pairs' % (hub[0], hub[1], spread))
    if spread > TOLERANCE_HUB:
        fails.append('the hub moves %.2fpx between frames -- the needle wobbles '
                     'rather than spinning' % spread)

    base = frame_stats(raw, w, cell, cols, 0, hub)
    if base is None:
        return ['%s frame 0 is empty' % job['file']]
    bx, by, bink, bfar, bhist = base

    for idx in SAMPLES:
        st = frame_stats(raw, w, cell, cols, idx, hub)
        if st is None:
            fails.append('frame %d is empty' % idx)
            continue
        x, y, ink, far, hist = st
        # anticlockwise by idx: the needle keeps pointing north as you turn
        ang = best_shift(hist, bhist)
        want = (-idx) % 360
        off = angdiff(ang, want)
        ok_turn = abs(off) <= TOLERANCE_DEG
        ok_ink = abs(ink - bink) <= bink * TOLERANCE_INK
        ok_far = abs(far - bfar) <= 1.5
        if not ok_turn:
            fails.append('frame %d is frame 0 turned %d deg clockwise, expected %d'
                         % (idx, ang, want))
        if not ok_ink:
            fails.append('frame %d carries %.1f%% of frame 0\'s ink -- clipped?'
                         % (idx, 100 * ink / bink))
        if not ok_far:
            fails.append('frame %d reaches %.1fpx, frame 0 reaches %.1f -- clipped?'
                         % (idx, far, bfar))
        print('   frame %3d  turned %3d (want %3d)  ink %5.1f%%  reach %5.1f  %s'
              % (idx, ang, want, 100 * ink / bink, far,
                 'ok' if (ok_turn and ok_ink and ok_far) else 'FAIL'))

    return fails


if __name__ == '__main__':
    bad = []
    for job in ATLASES:
        bad += check(job)
        print('')
    if bad:
        for b in bad:
            print('FAIL: ' + b)
        sys.exit(1)
    print('needle atlases OK')
