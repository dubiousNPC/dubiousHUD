#!/usr/bin/env python3
"""
Generates the alternate MoonHUD atlases and the star panel background.

Atlas layout is fixed by MH_constants.ATLAS_ROW: 8 columns x 3 rows of 64px.
Columns are the engine phase index, row 0 Masser, row 1 Secunda, row 2 the Shade
indicator (cell 0 lit, cells 1-7 dim).

    moon_atlas    soft shaded discs        (already shipped, not regenerated here)
    moon_atlas_1  woodcut, flat two-tone, hard outline
    moon_atlas_2  cratered, mottled surface
    moon_atlas_3  celestial, outer halo and thin ring
    moon_atlas_4  engraved, outline with hatched shadow

Phase geometry is shared with generate_hud_atlases.sh: the terminator is a
half-ellipse with x semi-axis r*cos(index * 45 deg). Indices 1-3 are lit on the
left, 5-7 on the right.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = "/mnt/user-data/outputs/MoonHUD/textures/moonhud"
CELL = 64
COLS = 8
ROWS = 3
SS = 4  # supersample factor

os.makedirs(OUT, exist_ok=True)
random.seed(20427)


def lit_mask(size, index, waxing_right=True):
    """Grayscale mask, white where the moon is illuminated."""
    m = Image.new("L", (size, size), 0)
    if index == 4:
        return m
    d = ImageDraw.Draw(m)
    c = size / 2.0
    r = size / 2.0 - 2 * SS
    if index == 0:
        d.ellipse([c - r, c - r, c + r, c + r], fill=255)
        return m

    theta = math.radians(index * 45)
    a = r * math.cos(theta)
    waning = index < 4  # lit on the left

    px = m.load()
    for y in range(size):
        dy = y - c
        if abs(dy) > r:
            continue
        w = math.sqrt(max(0.0, r * r - dy * dy))
        for x in range(size):
            dx = x - c
            if dx * dx + dy * dy > r * r:
                continue
            lit = (dx <= w * math.cos(theta)) if waning else (dx >= -w * math.cos(theta))
            if lit:
                px[x, y] = 255
    return m


def disc_mask(size, inset=2 * SS):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([inset, inset, size - inset, size - inset], fill=255)
    return m


def radial_shade(size, strength=0.28):
    """Subtle volume: brighter at centre, falling off to the limb."""
    m = Image.new("L", (size, size), 255)
    px = m.load()
    c = size / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            dd = math.sqrt((x - c) ** 2 + (y - c) ** 2) / r
            px[x, y] = max(0, min(255, int(255 * (1.0 - strength * dd * dd))))
    return m


def crater_field(size, count=26):
    """Mottled surface, drawn once and reused across every phase of a moon."""
    m = Image.new("L", (size, size), 128)
    d = ImageDraw.Draw(m)
    c = size / 2.0
    r = size / 2.0 - 4 * SS
    for _ in range(count):
        while True:
            cx = random.uniform(-r, r)
            cy = random.uniform(-r, r)
            if cx * cx + cy * cy < r * r * 0.82:
                break
        rad = random.uniform(size * 0.03, size * 0.11)
        tone = random.choice([96, 104, 112, 150, 158])
        d.ellipse([c + cx - rad, c + cy - rad, c + cx + rad, c + cy + rad], fill=tone)
    return m.filter(ImageFilter.GaussianBlur(size * 0.012))


def flat(size, colour):
    return Image.new("RGBA", (size, size), colour)


def compose(size, lit_rgb, dark_rgb, index, style, craters=None):
    """One phase cell at supersampled size, returned RGBA."""
    lit_m = lit_mask(size, index)
    disc = disc_mask(size)
    dark_m = Image.new("L", (size, size))
    dark_m.paste(disc, (0, 0))
    # dark = disc minus lit
    dark_px, lit_px = dark_m.load(), lit_m.load()
    for y in range(size):
        for x in range(size):
            if lit_px[x, y]:
                dark_px[x, y] = 0

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    if style == "woodcut":
        out.paste(flat(size, dark_rgb), (0, 0), dark_m)
        out.paste(flat(size, lit_rgb), (0, 0), lit_m)
        # hard outline ring
        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(ring)
        w = max(3, int(size * 0.055))
        d.ellipse([2 * SS, 2 * SS, size - 2 * SS, size - 2 * SS],
                  outline=(lit_rgb[0] // 4, lit_rgb[1] // 4, lit_rgb[2] // 4, 255), width=w)
        out.alpha_composite(ring)

    elif style == "cratered":
        shade = radial_shade(size, 0.30)
        litl = flat(size, lit_rgb)
        darkl = flat(size, dark_rgb)
        for layer in (litl, darkl):
            layer.putalpha(255)
        # modulate both layers by craters and radial shading
        for layer, mask in ((darkl, dark_m), (litl, lit_m)):
            base = layer.load()
            cr = craters.load()
            sh = shade.load()
            for y in range(size):
                for x in range(size):
                    if not mask.getpixel((x, y)):
                        continue
                    f = (cr[x, y] / 128.0) * (sh[x, y] / 255.0)
                    r0, g0, b0, a0 = base[x, y]
                    base[x, y] = (min(255, int(r0 * f)), min(255, int(g0 * f)),
                                  min(255, int(b0 * f)), a0)
            out.paste(layer, (0, 0), mask)

    elif style == "celestial":
        # Halo well outside the disc, so the cell silhouette itself differs.
        halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        for k, alpha in ((0.02, 95), (0.08, 70), (0.15, 45)):
            inset = int(size * k)
            hd.ellipse([inset, inset, size - inset, size - inset],
                       fill=(lit_rgb[0], lit_rgb[1], lit_rgb[2], alpha))
        halo = halo.filter(ImageFilter.GaussianBlur(size * 0.075))
        out.alpha_composite(halo)

        inner = int(size * 0.16)
        body_disc = Image.new("L", (size, size), 0)
        ImageDraw.Draw(body_disc).ellipse([inner, inner, size - inner, size - inner], fill=255)
        lm = lit_mask(size, index)
        dm = Image.new("L", (size, size), 0)
        bd, lm_px, dm_px = body_disc.load(), lm.load(), dm.load()
        for y in range(size):
            for x in range(size):
                if bd[x, y] and not lm_px[x, y]:
                    dm_px[x, y] = 255
        lit_in = Image.new("L", (size, size), 0)
        li = lit_in.load()
        for y in range(size):
            for x in range(size):
                if bd[x, y] and lm_px[x, y]:
                    li[x, y] = 255
        out.paste(flat(size, (dark_rgb[0], dark_rgb[1], dark_rgb[2], 240)), (0, 0), dm)
        out.paste(flat(size, lit_rgb), (0, 0), lit_in)

        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(ring)
        d.ellipse([inner, inner, size - inner, size - inner],
                  outline=(255, 255, 255, 225), width=max(3, int(size * 0.030)))
        # four cardinal ticks on the outer edge
        # Kept clear of the cell edge: ticks that touch it chain the moons
        # together into one dashed line across the strip.
        c = size / 2.0
        r_out = size * 0.425
        r_in = r_out - size * 0.055
        for ang in (0, 90, 180, 270):
            a = math.radians(ang)
            d.line([c + r_in * math.cos(a), c + r_in * math.sin(a),
                    c + r_out * math.cos(a), c + r_out * math.sin(a)],
                   fill=(255, 255, 255, 210), width=max(2, int(size * 0.022)))
        out.alpha_composite(ring)

    elif style == "engraved":
        # Hatched shadow, open lit side, strong outline.
        hatch = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hatch)
        step = max(3, int(size * 0.055))
        for i in range(-size, size * 2, step):
            hd.line([(i, 0), (i - size, size)],
                    fill=(lit_rgb[0], lit_rgb[1], lit_rgb[2], 165),
                    width=max(1, int(size * 0.012)))
        out.paste(hatch, (0, 0), dark_m)
        faint = flat(size, (lit_rgb[0], lit_rgb[1], lit_rgb[2], 46))
        out.paste(faint, (0, 0), lit_m)
        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(ring)
        d.ellipse([2 * SS, 2 * SS, size - 2 * SS, size - 2 * SS],
                  outline=lit_rgb, width=max(2, int(size * 0.026)))
        out.alpha_composite(ring)
        # terminator line
        if index not in (0, 4):
            theta = math.radians(index * 45)
            a = abs(size / 2.0 - 2 * SS) * abs(math.cos(theta))
            c = size / 2.0
            r = size / 2.0 - 2 * SS
            td = ImageDraw.Draw(out)
            td.arc([c - a, c - r, c + a, c + r], 0, 360,
                   fill=lit_rgb, width=max(1, int(size * 0.018)))

    else:  # soft, matches the shipped default
        shade = radial_shade(size, 0.28)
        for layer_rgb, mask in ((dark_rgb, dark_m), (lit_rgb, lit_m)):
            layer = flat(size, layer_rgb)
            base = layer.load()
            sh = shade.load()
            for y in range(size):
                for x in range(size):
                    if not mask.getpixel((x, y)):
                        continue
                    f = sh[x, y] / 255.0
                    r0, g0, b0, a0 = base[x, y]
                    base[x, y] = (int(r0 * f), int(g0 * f), int(b0 * f), a0)
            out.paste(layer, (0, 0), mask)

    return out


def shade_cell(size, active, style, lit_rgb, dark_rgb):
    disc = disc_mask(size)
    if active:
        core, rim = (214, 150, 236, 255), (246, 228, 255, 255)
    else:
        core, rim = (58, 55, 66, 255), (96, 92, 104, 255)

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if style == "celestial" and active:
        halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([1 * SS, 1 * SS, size - 1 * SS, size - 1 * SS],
                                     fill=(core[0], core[1], core[2], 90))
        out.alpha_composite(halo.filter(ImageFilter.GaussianBlur(size * 0.05)))

    body = flat(size, core)
    if style != "engraved":
        shade = radial_shade(size, 0.25)
        b = body.load()
        sh = shade.load()
        for y in range(size):
            for x in range(size):
                f = sh[x, y] / 255.0
                r0, g0, b0, a0 = b[x, y]
                b[x, y] = (int(r0 * f), int(g0 * f), int(b0 * f), a0)
    out.paste(body, (0, 0), disc)

    # vertical beam
    beam = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bw = int(size * 0.11)
    ImageDraw.Draw(beam).rectangle([size // 2 - bw, 0, size // 2 + bw, size],
                                   fill=(255, 240, 255, 150 if active else 45))
    beam = beam.filter(ImageFilter.GaussianBlur(size * 0.02))
    out.alpha_composite(Image.composite(beam, Image.new("RGBA", (size, size), (0, 0, 0, 0)), disc))

    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([2 * SS, 2 * SS, size - 2 * SS, size - 2 * SS],
                                 outline=rim, width=max(2, int(size * 0.022)))
    out.alpha_composite(ring)
    return out


STYLES = {
    "moon_atlas_1": "woodcut",
    "moon_atlas_2": "cratered",
    "moon_atlas_3": "celestial",
    "moon_atlas_4": "engraved",
}

MOONS = [
    ("masser", (224, 186, 152, 255), (58, 42, 36, 255)),
    ("secunda", (240, 243, 250, 255), (44, 48, 58, 255)),
]


def build_atlas(name, style):
    n = CELL * SS
    atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for row, (moon, lit_rgb, dark_rgb) in enumerate(MOONS):
        craters = crater_field(n) if style == "cratered" else None
        for i in range(COLS):
            cell = compose(n, lit_rgb, dark_rgb, i, style, craters)
            atlas.paste(cell.resize((CELL, CELL), Image.LANCZOS),
                        (i * CELL, row * CELL))
    on = shade_cell(n, True, style, *MOONS[0][1:]).resize((CELL, CELL), Image.LANCZOS)
    off = shade_cell(n, False, style, *MOONS[0][1:]).resize((CELL, CELL), Image.LANCZOS)
    for i in range(COLS):
        atlas.paste(on if i == 0 else off, (i * CELL, 2 * CELL))
    atlas.save(f"{OUT}/{name}.png")
    return atlas.size


def build_stars(size=256):
    """Tileable star field. Stars are drawn with wraparound so the edges match."""
    img = Image.new("RGBA", (size, size), (10, 12, 22, 255))

    # faint nebula wash
    neb = Image.new("L", (size, size), 0)
    nd = ImageDraw.Draw(neb)
    for _ in range(14):
        cx, cy = random.uniform(0, size), random.uniform(0, size)
        r = random.uniform(size * 0.12, size * 0.3)
        nd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=random.randint(20, 55))
    neb = neb.filter(ImageFilter.GaussianBlur(size * 0.07))
    wash = Image.new("RGBA", (size, size), (52, 44, 96, 255))
    img.paste(wash, (0, 0), neb)

    d = ImageDraw.Draw(img)

    def star(cx, cy, r, tone):
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.ellipse([cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r], fill=tone)

    for _ in range(260):
        star(random.uniform(0, size), random.uniform(0, size),
             random.uniform(0.4, 1.0), (200, 205, 225, random.randint(90, 190)))
    for _ in range(46):
        star(random.uniform(0, size), random.uniform(0, size),
             random.uniform(1.1, 1.9), (240, 244, 255, random.randint(190, 255)))
    # a handful of bright ones with a soft bloom
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for _ in range(9):
        cx, cy = random.uniform(0, size), random.uniform(0, size)
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                gd.ellipse([cx + ox - 3.4, cy + oy - 3.4, cx + ox + 3.4, cy + oy + 3.4],
                           fill=(255, 250, 235, 150))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2.2)))
    for _ in range(9):
        star(random.uniform(0, size), random.uniform(0, size), 1.5, (255, 253, 245, 255))

    img.save(f"{OUT}/panel_bg_stars.png")
    return img.size


if __name__ == "__main__":
    for name, style in STYLES.items():
        print(f"{name}.png  {build_atlas(name, style)}  ({style})")
    print(f"panel_bg_stars.png  {build_stars()}")
