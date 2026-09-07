#!/usr/bin/env python3
"""
Offline preview of MoonHUD layouts.

Mirrors the geometry in MH_hud.lua exactly -- buildTriangle, buildVertex and the
Circle branch of createMoonHud -- so what this renders is what the widget builds.
Nothing here is shipped; it exists to compare display options side by side.
"""
import os
from PIL import Image, ImageDraw, ImageFont

TEX = "/mnt/user-data/outputs/MoonHUD/textures/moonhud"
FONT = "/mnt/user-data/uploads/MysticCards.ttf"
OUT = "/home/claude/preview"
os.makedirs(OUT, exist_ok=True)

ATLAS = Image.open(f"{TEX}/moon_atlas.png").convert("RGBA")
ATLAS_NAME = "moon_atlas"
CELL = 64
ROW = {"Masser": 0, "Secunda": 1, "Shade": 2}
RING_NAMES = ["Full", "WaningGibbous", "ThirdQuarter", "WaningCrescent",
              "New", "WaxingCrescent", "FirstQuarter", "WaxingGibbous"]
DISPLAY = {"Full": "Full", "WaningGibbous": "Waning Gibbous",
           "ThirdQuarter": "Third Quarter", "WaningCrescent": "Waning Crescent",
           "New": "New", "WaxingCrescent": "Waxing Crescent",
           "FirstQuarter": "First Quarter", "WaxingGibbous": "Waxing Gibbous"}

TEXT_COLOR = (202, 165, 96, 255)
RING_COLOR = (202, 165, 96, 255)
BG_TINT = (255, 255, 255, 255)


_ATLAS_CACHE = {}


def use_atlas(name):
    global ATLAS
    if name not in _ATLAS_CACHE:
        _ATLAS_CACHE[name] = Image.open(f"{TEX}/{name}.png").convert("RGBA")
    ATLAS = _ATLAS_CACHE[name]


def tile(name, idx, size):
    row = ROW[name]
    t = ATLAS.crop((idx * CELL, row * CELL, (idx + 1) * CELL, (row + 1) * CELL))
    return t.resize((size, size), Image.LANCZOS)


def tint(img, colour, alpha=1.0):
    r, g, b, _a = colour[0], colour[1], colour[2], 255
    out = Image.new("RGBA", img.size)
    px, op = img.load(), out.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            pr, pg, pb, pa = px[x, y]
            op[x, y] = (pr * r // 255, pg * g // 255, pb * b // 255,
                        int(pa * alpha))
    return out


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except Exception:
        return ImageFont.load_default()


def build_vertex(canvas, name, phase, x, y, cellW, cellH, icon_size,
                 show_icon, show_text, font_size, label_fn):
    """buildVertex: icon centred in the cell, label centred underneath."""
    if show_icon:
        ic = tile(name, phase, icon_size)
        canvas.alpha_composite(ic, (x + (cellW - icon_size) // 2, y))
    if show_text:
        d = ImageDraw.Draw(canvas)
        f = font(font_size)
        txt = label_fn(name, phase)
        ty = y + (icon_size + 2 if show_icon else 0)
        bbox = d.textbbox((0, 0), txt, font=f)
        tw = bbox[2] - bbox[0]
        d.text((x + (cellW - tw) // 2, ty), txt, font=f, fill=TEXT_COLOR)


def label_full(name, phase):
    return f"{name}: {DISPLAY[RING_NAMES[phase]]}"


def label_short(name, phase):
    return DISPLAY[RING_NAMES[phase]]


def render(layout="Triangle", panel="Circle", mode="Icons",
           icon_size=32, font_size=20, spread=10, padding=4,
           bg_texture=None, ring=True, phases=(1, 4, 0), label_fn=label_short,
           circle_size=0):
    show_icon = mode != "Text"
    show_text = mode != "Icons"
    names = ["Masser", "Secunda", "Shade"]

    # --- buildTriangle / flex sizing, straight from MH_hud.lua -------------
    # matches labelWidth() in MH_hud.lua
    longest = {"Icons + Text": 15, "Text": 15}.get(mode, 0)
    if label_fn is label_full:
        longest += 9
    label_w = int(-(-longest * font_size * 58 // 100))

    if layout.startswith("Triangle"):
        cellW = icon_size
        if show_text:
            cellW = max(cellW, label_w)
        cellH = (icon_size if show_icon else 0) + ((font_size + 2) if show_text else 0)
        w = cellW * 2 + spread
        h = cellH * 2 + spread
        inverted = layout == "Triangle Inverted"
        if inverted:
            slots = [(0, 0), (w - cellW, 0), ((w - cellW) // 2, cellH + spread)]
        else:
            slots = [((w - cellW) // 2, 0), (0, cellH + spread), (w - cellW, cellH + spread)]
    else:
        cellW = icon_size + (6 + label_w if show_text else 0)
        cellH = icon_size
        if layout == "Horizontal":
            w, h = cellW * 3 + spread * 2, cellH
            slots = [(i * (cellW + spread), 0) for i in range(3)]
        else:
            w, h = cellW, cellH * 3 + 2 * 2
            slots = [(0, i * (cellH + 2)) for i in range(3)]

    # --- panel -------------------------------------------------------------
    if panel == "Circle":
        import math as _m
        diameter = circle_size or (
            -(-int(_m.sqrt(w * w + h * h) * 106) // 100) + padding * 2)
        canvas = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
        plate = Image.open(f"{TEX}/panel_circle.png").convert("RGBA").resize(
            (diameter, diameter), Image.LANCZOS)
        if bg_texture:
            bg = Image.open(f"{TEX}/{bg_texture}").convert("RGBA").resize(
                (diameter, diameter), Image.LANCZOS)
            bg.putalpha(plate.getchannel("A"))
            plate = bg
        canvas.alpha_composite(tint(plate, BG_TINT, 0.5))
        if ring:
            rg = Image.open(f"{TEX}/panel_circle_border.png").convert("RGBA").resize(
                (diameter, diameter), Image.LANCZOS)
            canvas.alpha_composite(tint(rg, RING_COLOR, 1.0))
        ox, oy = (diameter - w) // 2, (diameter - h) // 2
    else:
        W, H = w + padding * 2, h + padding * 2
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        if panel != "None":
            if bg_texture:
                bg = Image.open(f"{TEX}/{bg_texture}").convert("RGBA").resize((W, H), Image.LANCZOS)
            else:
                bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
            canvas.alpha_composite(tint(bg, BG_TINT, 0.5))
            if ring:  # reuse the flag as "rectangle border"
                d = ImageDraw.Draw(canvas)
                d.rectangle([0, 0, W - 1, H - 1], outline=RING_COLOR, width=1)
        ox, oy = padding, padding

    for i, name in enumerate(names):
        x, y = slots[i]
        if layout.startswith("Triangle"):
            build_vertex(canvas, name, phases[i], ox + x, oy + y, cellW, cellH,
                         icon_size, show_icon, show_text, font_size, label_fn)
        else:
            if show_icon:
                canvas.alpha_composite(tile(name, phases[i], icon_size), (ox + x, oy + y))
            if show_text:
                d = ImageDraw.Draw(canvas)
                d.text((ox + x + (icon_size + 6 if show_icon else 0),
                        oy + y + icon_size // 2 - font_size // 2),
                       label_fn(name, phases[i]), font=font(font_size), fill=TEXT_COLOR)
    return canvas


def board(items, cols, pad=18, bg=(38, 38, 42, 255), caption_h=20):
    f = font(15)
    rendered = [(cap, im) for cap, im in items]
    cw = max(im.width for _, im in rendered) + pad * 2
    ch = max(im.height for _, im in rendered) + pad * 2 + caption_h
    rows = (len(rendered) + cols - 1) // cols
    sheet = Image.new("RGBA", (cw * cols, ch * rows), bg)
    d = ImageDraw.Draw(sheet)
    for i, (cap, im) in enumerate(rendered):
        cx, cy = (i % cols) * cw, (i // cols) * ch
        sheet.alpha_composite(im, (cx + (cw - im.width) // 2,
                                   cy + caption_h + (ch - caption_h - im.height) // 2))
        bb = d.textbbox((0, 0), cap, font=f)
        d.text((cx + (cw - (bb[2] - bb[0])) // 2, cy + 4), cap, font=f,
               fill=(220, 220, 225, 255))
    return sheet


if __name__ == "__main__":
    P = (1, 4, 0)  # Masser waning gibbous, Secunda new, Shade lit

    layouts = [
        ("Triangle + Circle",          render("Triangle", "Circle", "Icons", icon_size=40)),
        ("Triangle Inv + Circle",      render("Triangle Inverted", "Circle", "Icons", icon_size=40)),
        ("Vertical + Circle",          render("Vertical", "Circle", "Icons", icon_size=40)),
        ("Horizontal + Circle",        render("Horizontal", "Circle", "Icons", icon_size=40)),
        ("Triangle + Rectangle",       render("Triangle", "Rectangle", "Icons", icon_size=40)),
        ("Triangle + None",            render("Triangle", "None", "Icons", icon_size=40)),
        ("Triangle + stone bg",        render("Triangle", "Circle", "Icons", icon_size=40,
                                              bg_texture="panel_bg_stone.png")),
        ("Triangle + linen bg",        render("Triangle", "Circle", "Icons", icon_size=40,
                                              bg_texture="panel_bg_linen.png")),
    ]
    board(layouts, 4).save(f"{OUT}/layouts.png")

    texty = [
        ("Triangle, Icons+Text",   render("Triangle", "Circle", "Icons + Text",
                                          icon_size=32, font_size=16)),
        ("Tri Inv, Icons+Text",    render("Triangle Inverted", "Rectangle", "Icons + Text",
                                          icon_size=32, font_size=16)),
        ("Vertical, Icons+Text",   render("Vertical", "Rectangle", "Icons + Text",
                                          icon_size=32, font_size=16, label_fn=label_full)),
    ]
    board(texty, 3).save(f"{OUT}/with_text.png")

    print("wrote layouts.png and with_text.png")
