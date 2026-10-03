#!/usr/bin/env python3
"""
Builds glass_tube_lengths.png -- one tube per height, 63 to 139 rows, so the
vial's length can be a setting.

The three supplied pieces fit the original exactly (mean diff 0.000):

    glass_tube_x_top.png      9x19, at x3, original rows  0..18
    glass_tube_x_middle.png   9x47, at x3, original rows  9..55
    glass_tube_x_bottom.png  13x50, at x0, original rows 89..138

They are what settles WHERE the tube divides. They are not used as the pixel
source, though, because between them they do not cover rows 56..88 -- a third of
the tube -- so a sheet tiled from them cannot reproduce the original at full
height, and the longest setting would not match the classic vial. Measured:
mean 10.3 off, which shows.

So each frame is cut from glass_tube.png itself: its own top 19 rows, its own
bottom 50, and as much of its own middle as the height leaves room for. Full
height is then bit-identical to glass_tube.png, and shortening drops rows from
just above the foot, where the tube is plainest.

The short end is 63 because that is glass_tube_short.png, which is the top at y0
and the bottom at y13 overlapping by six rows -- the same art, so the range runs
continuously from it.
"""
from PIL import Image
import numpy as np

T = '/mnt/user-data/outputs/DBSVials/textures/dbsvials/'
orig = Image.open(T + 'glass_tube.png').convert('RGBA')
W, FULL = orig.width, orig.height            # 13 x 139
TOP_H, BOT_H = 19, 50                        # from x_top and x_bottom
H_MIN, H_MAX = 63, FULL
FRAMES = H_MAX - H_MIN + 1                   # 77

def build(H):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    gap = H - TOP_H - BOT_H
    if gap > 0:
        im.alpha_composite(orig.crop((0, TOP_H, W, TOP_H + gap)), (0, TOP_H))
    im.alpha_composite(orig.crop((0, 0, W, TOP_H)), (0, 0))
    im.alpha_composite(orig.crop((0, FULL - BOT_H, W, FULL)), (0, H - BOT_H))
    return im

# Every frame is H_MAX tall and the tube is bottom-aligned inside it, so the
# widget can draw any frame at one fixed rect and the foot never moves.
sheet = Image.new('RGBA', (W, H_MAX * FRAMES), (0, 0, 0, 0))
for i in range(FRAMES):
    H = H_MIN + i
    sheet.paste(build(H), (0, i * H_MAX + (H_MAX - H)))
sheet.save(T + 'glass_tube_lengths.png')
print(f'wrote glass_tube_lengths.png  {W}x{H_MAX*FRAMES}  '
      f'{FRAMES} frames of {W}x{H_MAX}, tube heights {H_MIN}..{H_MAX}, bottom-aligned')

# --- checks -----------------------------------------------------------------
s = np.asarray(Image.open(T + 'glass_tube_lengths.png')).astype(int)
on = np.asarray(orig).astype(int)
last = s[(FRAMES - 1) * H_MAX:FRAMES * H_MAX]
print(f'  longest frame vs glass_tube.png      : max diff {int(np.abs(last - on).max())}')
short = np.asarray(Image.open(T + 'glass_tube_short.png').convert('RGBA')).astype(int)
first = s[0:H_MAX][H_MAX - H_MIN:]
m = (short[:, :, 3] > 40) | (first[:, :, 3] > 40)
print(f'  shortest frame vs glass_tube_short   : mean {np.abs(short-first).max(axis=2)[m].mean():.2f}')
bad = 0
for i in range(FRAMES):
    H = H_MIN + i
    f = s[i * H_MAX:(i + 1) * H_MAX]
    rows = np.nonzero((f[:, :, 3] > 40).any(axis=1))[0]
    if rows.max() != H_MAX - 1 or rows.min() != H_MAX - H:
        bad += 1
print(f'  frames whose foot is not on the last row: {bad} of {FRAMES}')
