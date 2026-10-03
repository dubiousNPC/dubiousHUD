# DBSVials — dbsHUD

Health and stamina as glass vials that fill from the bottom. Magicka as a column
of eight runes whose glow goes out an eighth at a time.

Built after [ErnMMUI](https://github.com/erinpentecost/ErnMMUI), which is the
reference for reading the player's dynamic stats and for keeping a stats HUD
honest about when it actually needs to redraw.

By **Dubious**.

---

## Install

Drop the folder in your mods directory and add it to `openmw.cfg`:

```
data="path/to/DBSVials"
content=dbsvials.omwscripts
```

No dependencies. SuperSettingsRenderers is bundled, unaltered, under
`scripts/SuperSettingsRenderers`, so the settings page never relies on a
separate download.

Settings live under **dbsHUD - DBSVials**.

- Click and drag either widget to move it. They move independently.
- Click and mousewheel while dragging to resize whichever one you are holding.

---

## Two widgets, not one

The vials and the rune column are separate widgets with separate positions.
Drag either one on its own; each remembers where you put it, and each resizes on
its own when you click-and-scroll it. Put them in opposite corners if you like.

They share the stat-reading pass and the frame styling, and nothing else.

---

## The vials

Each vial is one vessel — collar, tube, clasp and bulb — with a single column of
liquid running the whole height of it. Drawn lowest first:

```
VIAL_CLASP.png         the metal, behind everything
VIAL_FILL.png          the liquid
VIAL_CLEAR_CLASP.png   the fitted transparent clasp, over the liquid
glass_tube.png         the tube's glass, cut to end at the clasp
VIAL_TOP.png           the collar
```

The clasp being *under* the liquid is the point. Drawn on top it covers the
liquid where it passes through, and the vessel reads as a tube sitting on a
separate bulb rather than one thing.

### The transparent clasp

`VIAL_CLEAR_CLASP.png` is built from two pieces:

```
VIAL_CLEAR_GLASS.png  +  VIAL_CLASP_FRAME.png
```

the clear bulb glass with the clasp frame fitted over it. That is what gives the
clasp a glass front the liquid shows *through*, rather than a solid one it
disappears behind. The build is in the repo's history rather than done at
runtime — it is one static texture — and it matches the supplied combination to
a mean of **0.04** on a 0–255 scale, with 18 pixels of 470 differing by more
than 8.

Both source pieces ship too, so the composite can be rebuilt if either changes.

### The tube's glass is cut

`glass_tube.png` is 139 rows and carries a flared foot at the bottom, but in
this vessel the clasp is the termination. The tube is drawn as **125 rows**,
ending at y140 where the clasp begins; its own foot is never shown. Drawn whole
it runs on to y154 and clips through the clasp.

It is *cut*, not squeezed — handing the widget the whole 139-row texture in a
125-row rect would squash it instead of ending it. The suite checks the texture
that was cut matches the rect it is drawn in.

### The liquid is one column

It runs the full height: down the tube, through the clasp, and into the bulb. So
a nearly-empty vial shows a little liquid pooled in the bulb, and draining past
the clasp is continuous rather than the tube emptying and the bulb staying put.

Nothing is hidden at either end, so all 139 rows of the travel are on screen. An
empty vessel draws no liquid at all rather than a sliver in the foot. The liquid
is cut per height the same way the tube glass is, so the taper at the bottom
keeps its shape at every level.

### Placement

The assembly is **40 × 190**, and every offset was found by *searching* against
the supplied example flasks rather than reasoned about:

```
VIAL_TOP          (8,   4)    fits the examples bit-exactly
glass_tube        (8,  15)    125 rows, ending at the clasp
VIAL_FILL         (9,  30)    full; its 7px column lands on x12-18
VIAL_CLASP        (1, 112)
VIAL_CLEAR_CLASP  (0,   0)    authored on the whole canvas
liquid foot         y169
```

The tube's glass and the liquid it covers **do not share a left edge** — the
glass sits one pixel to the left of its own column. Reasoning from "they are
both the tube" puts them together and gets it wrong; the search found it.

Against the supplied flasks the assembly matches at a silhouette IoU of
**0.998–0.999**. By region, the fittings and glass differ by a mean of **15.6**
on 0–255; the liquid column by **43.1**, because the examples carry more of the
glass highlight through the liquid than `glass_tube.png` produces over a flat
colour. That is the one part still not exact.

### Optional extras, both off by default

**Bulb Backing** draws a second reservoir under the liquid, and **Dreg** a
tinted residue in its foot. Both are off: the transparent clasp already carries
the bulb's glass, so a backing behind the liquid thickens the silhouette
(measured: IoU drops from 0.998 to 0.883), and the liquid now pools in the bulb
itself, so a dreg doubles what is already there.

### Colours

`VIAL_FILL.png` is a white master cut to the shape the TUBE pngs define, so the
colour setting tints it. The shipped defaults — `B60000` and `349F00` — are the
supplied tubes' own colours exactly.

**Vial Size** scales the whole assembly by one factor; 190 is the art at 1:1.
**Vial Spacing** reaches a full screen width, so the two vials can sit in
opposite corners while still being one draggable widget.

---

### Battlespire Vials

**Vial Style** switches the pair to a plain test tube that drains through a
colour ramp of its own: `ENGY01.png` runs green to red, `ENGY02.png` blue to
red. Each is a 32-frame atlas, 28 x 82 a frame, frame 0 full and frame 31
empty, so the fill is quantised to 32 states and the texture is only swapped
when a different frame would be drawn.

The colour is in the artwork, so the health and stamina colour settings do not
apply to this style. `dbs_ENGY_frame.png` is an outline that can go over the
tube (**Battlespire Frame**) for when it has to read against a bright sky.

### Vial length

**Vial Length** draws between 63 and 139 rows of tube. Everything below it —
the clasp, the bulb, the foot of the liquid, the assembly height — moves up by
the same amount, so the vessel stays one object and the liquid still fills it
end to end. At 63 with the clasp switched off you get the short standalone vial.

The tube comes from `glass_tube_lengths.png`, one frame per height, each
bottom-aligned in a 139-row cell so any frame draws at one rect and the foot
never moves. `dev/build_tube_atlas.py` rebuilds it.

The three supplied pieces — `glass_tube_x_top` (rows 0–18 at x3),
`glass_tube_x_middle` (rows 9–55 at x3), `glass_tube_x_bottom` (rows 89–138 at
x0) — fit the original exactly and are what settle **where** the tube divides.
They are not the pixel source: between them they miss rows 56–88, a third of the
tube, so a sheet tiled from them lands about 10 off at full height and the
longest setting would not match the classic vial. Each frame is cut from
`glass_tube.png` itself instead, which makes full length bit-identical and puts
the shortening just above the foot where the tube is plainest.

`glass_tube_short.png` is the top at y0 and the bottom at y13 overlapping by six
rows — the same art — which is why the range starts at 63 and runs continuously.

---

## The runes

Three styles, set by **Rune Style**.

### Runes (the default)

`KainGameRUNES_xs.png` — the same eight runes redrawn separated and ordered on
an even grid: 27 x 240, eight cells of exactly 30 rows, so the cells need no
measuring. Two layers and only two:

```
KainGameRUNES_xs_empty.png   the outline, always drawn, one cell per rune
KainGameRUNES_xs.png         the blue, over it, one cell per rune
```

A rune empties by losing its blue and leaving its outline. Outline + blue
reproduces `KainGameRUNES_xs_full.png` exactly — zero difference — so the two
layers are the full sheet, and `_xs_full` and `_xs_ARRAY` are reference art
rather than anything the mod loads.

Both layers are cut per cell rather than drawn as one image. That is what lets
the column be lengthened.

#### Rune length

**Rune Length** draws between 8 and 32 runes, the same gesture as the vial's
length and for the same reason: the column grows by *gaining* runes, not by
subdividing the same space smaller. A rune keeps the height it has at eight —
**Rune Height** stays the height of eight of them — and the eight shapes repeat
upward the way the pips do, so at 8 the column is pixel-identical to a fixed
eight and at 16 it is twice as tall.

One thing it does that the vial's length does not: it changes what a rune
*means*. The liquid still reads 0–100% whatever length the tube is, but a rune
is one *N*th of your magicka, so a longer column is a **finer readout** — at 32
a rune goes out every 3% rather than every 12.5%. Multiples of eight keep the
pattern whole; other lengths work and simply cut the repeat short at the top.

Runes only. The Classic sheet's eight are measured bands of one specific image
(`RUNE_CUTS`), not an even grid, so there is nothing there to repeat — the
setting is ignored on Classic and on Pips, which has **Pips per Column** instead.

### Pips

One rune per casting, the way MMUI counts them, so the row shortens as a spell
gets dearer. **A Pip Is** chooses between a casting of your selected spell and a
fixed amount of magicka; with nothing selected it falls back to the fixed amount
rather than showing an empty row.

The eight shapes repeat upward in the sheet's order. **Pips per Column** sets how
many stack before a new column starts and **New Column Goes** which side it goes
— set to Left, the main column sits at the right edge so later columns grow away
from it and nothing already drawn moves. All 64 elements are built once and
hidden; counting up and down is a visibility flag.

### Classic

The original sheet, with its two halos and the flair behind them, unchanged.

---

### The three states

Each rune owns an eighth of your magicka and is in one of three states:

| | |
|---|---|
| **spent** | no halo |
| **filling or emptying** | the thin halo, `GLOW_UP1` |
| **full** | the thick halo, `GLOW_UP2` |

Only ever one rune is in the middle state: the eighth the level is currently
passing through. At an exact eighth nothing is in motion and every lit rune
wears the thick halo. The suite checks that no rune ever wears both.

By default the bottom rune is the first to fill and the last to empty;
**Runes Fill From** flips that. **Fade the Partial Rune** (on by default) fades
the thin halo with what is left of its eighth rather than holding it at full
brightness — quantised to 16 steps, so it costs nothing.

### The flair

`FLAIR.png` sits behind everything and is invisible until something pulses it.
Two things do:

- **The magicka low warning.** This used to dim the runes themselves, which was
  the wrong cue — going darker is what running out already *looks* like. Now it
  lights the flair behind whatever is left.
- **Another mod**, through `flashRunes()` — see below.

It shows only under lit runes, so what pulses is what you have left.
**Flair Tint**, **Flair Brightness** and **Flair Pulse Speed** control it; the
speed is capped at 2.5 cycles/second for the same reason as the vials'.

### About the sheets

Only the top **292** rows carry art; the rest is empty padding the widget never
looks at, so the sheets ship uncropped.

The eight runes are hand-drawn and their heights differ, so the boundaries are
measured rather than assumed even:

```
rune 1   0– 33      rune 5  143–178
rune 2  33– 69      rune 6  178–216
rune 3  69–111      rune 7  216–249
rune 4 111–143      rune 8  249–292
```

Those cuts come from the **front runes**, which are the only sheet whose eight
shapes are cleanly separated — the FLAIR is fat enough to bridge them. Each cut
then sits at the narrowest point of the FLAIR across that gap, so at most **7
pixels** of art fall on any boundary.

`dev/check_all.sh` asserts the eight slices tile the column with no gap and no
overlap at four different column heights — a gap shows as a dead stripe, an
overlap double-draws the halo and reads as a brighter seam — and that all three
back layers take the same band of their respective sheets, since a mismatch
there would land a halo on its neighbour.

---

## Readability

Red and green sit on the one axis that protanopia and deuteranopia collapse, and
between them that is most colour-blind people. Two vials side by side,
distinguished only by that pair, is the worst case. The defaults are as
specified, but the settings to fix it are on the page and the
**Colour-blind safe** preset applies them in one go:

- health moves to blue, stamina to orange — an axis that survives all three
  common types
- the numbers come on
- the empty portion gets a wash, so each tube reads as a shape as well as a
  colour

The other settings in that group:

| Setting | What it is for |
|---|---|
| **Show Numbers** | A readout under each meter. The surest way to read a level: it does not depend on colour, on size, or on the fill being visible at all. Percent, current value, or current of maximum. |
| **Number Size / Colour** | For when the default 13px is too small to be worth having. |
| **Low Warning** | Pulses a meter that has dropped below the threshold. A *movement* cue rather than a colour one, so it reads for anyone who cannot tell the fill from the empty tube. |
| **Pulse Speed** | Capped at 2.5 cycles/second and defaulted to 1. Above about three is a recognised seizure risk, and this sits in the corner of the eye for the whole game. |
| **Pulse Depth** | How far the pulse dims. Set it to 0 to keep the warning without the movement. |

Sizing is not buried in an accessibility section because it is not a special
case: **Vial Height**, **Vial Width**, **Rune Column Height** and **Rune Column
Width** go from tiny to 512px, and the mousewheel gesture scales the whole set.

---

## Performance

`onUpdate` reads three stats, divides, and quantises. If nothing quantised has
moved it returns without touching the UI. It allocates nothing in the common
path: no tables, no textures, no vectors beyond the two the engine needs when a
value has genuinely changed.

The quantisation is the whole trick:

- A **vial** is redrawn only when the fill crosses a whole *pixel row of its own
  height*. A 139px vial has at most 139 distinct states however smoothly health
  regenerates. Without this, regenerating fatigue would rebuild the widget every
  frame for a change nobody can see.
- A **rune** is redrawn only when it changes state — spent, filling, full —
  or when the partial fade crosses one of its 16 steps.
- The **flair** is quantised to the same 16 steps, so a pulse pokes the UI at
  most 16 times a cycle rather than once a frame.
- The two widgets are updated **separately**: a health tick that changes nothing
  in the rune column does not touch the rune column.
- The **pulse** is quantised to the same 16 steps, so a warning can poke the UI
  at most 16 times a cycle rather than once a frame.
- The **numbers** are compared as the rendered string, so a stat drifting within
  the same displayed value costs one comparison and nothing else.

Every texture is built once at load. The eight glow slices are cut by offset and
size and are never rebuilt — not even on resize, because a `ui.texture`'s offset
and size are in texture pixels and have nothing to do with how large the widget
is drawn.

UI elements are created once and hidden. Lighting a rune is a visibility flag,
not a tree edit; nothing is added to or removed from the tree while playing.

Settings changes split into two classes. `REBUILD` is anything that changes the
shape of the tree or a texture path. Everything else — colours, opacities,
position — is poked straight into the live layout. Colours are pokes because
they are *dragged*: a colour picker fires on every tick of the drag, and
rebuilding the tree on each one would stutter the menu.

---

## Tests

```sh
dev/check_all.sh          # needs any Lua 5.3+ as `lua`
LUA=texlua dev/check_all.sh   # a LuaTeX install already carries one
```

`dev/load_check.lua` stubs enough of the OpenMW API to load the mod offline,
including live dynamic-stat accessors the tests can drive. The suite:

- **233 behavioural checks** against the real module and the real widget tree.
  `dev/test_vials.lua` deliberately re-implements none of the module's logic — a
  test that mirrors the code only ever proves the mirror is faithful. It drives
  `onUpdate` and reads the tree that was actually built.
- Every settings branch that changes the shape of the tree, loaded for real.
- The six vial pieces checked for register at five sizes, and the rune slices
  for gaps and overlaps at four column heights. Both are read off the tree the
  module builds, not asserted against a copy of the arithmetic.
- The xs column checked at five lengths for cell count, contiguity, a rune
  keeping its height, the eight shapes repeating, and the readout stepping in
  *N*ths.
- Stat extremes, including all three at zero and magicka at 0.1%.
- A `pcall` audit over the shipped scripts.

The behavioural tests are mutation-checked. Flipping the rune fill order,
removing the stat clamp, drawing the glow over the base runes instead of behind
them, setting the clasp overlap to zero, letting the fill travel run under the
collar, floating the collar off the tube, rounding the rune slices so they open
a one-pixel gap, shrinking the runes to fit a longer column into the same
height, tinting both dregs the same, putting both halos on one rune,
swapping the thin and thick halos, showing the flair under spent runes,
stopping the flash from decaying, and interleaving the flair with the halos
instead of keeping it behind them all each make the suite fail.

---

## On `pcall`

There is none in `scripts/dbsvials/`, and `dev/check_all.sh` fails the run if any
appears. Two places where it would have been the reflex, and what is there
instead:

- **Texture paths.** An empty glass path is a legitimate setting — it means "no
  glass" — so it is a value to test, not a fault to catch. `validPath` checks it.
- **Colour parsing.** `util.color.hex` raises on anything that is not six hex
  digits, and the input is genuinely untrusted: it is whatever was typed into a
  text field. But wrapping it would also swallow a real fault inside
  `util.color`, so the input is validated by pattern and the call is left to
  raise if it ever should.

The test harness does use `pcall`. That is a test runner reporting failures, not
shipped code, and the audit only looks at `scripts/dbsvials/`.

---

## For other mods

```lua
local I = require('openmw.interfaces')

I.DBSVials.getFractions()   -- { health = , stamina = , magicka = }  0..1
I.DBSVials.getLitRunes()    -- how many of the eight are lit, and the total
I.DBSVials.setVisible(false)           -- both
I.DBSVials.setVisible(false, 'runes')  -- or just one: 'vials' / 'runes'
I.DBSVials.isVisible()
I.DBSVials.flashRunes(1.5)             -- pulse the flair behind the lit runes
```

From a script that cannot see the interface — a global script, or a mod that
loads earlier — the same is reachable by event:

```lua
player:sendEvent('DBSVialsSetVisible', { show = false, which = 'runes' })
player:sendEvent('DBSVialsFlashRunes', { seconds = 1.5 })
```

---

## Credits

- Vial, rune and glow art: **Dubious**.
- All supplied art ships unmodified: `glass_tube.png`, `VIAL_TOP.png`,
  `VIAL_CLASP.png`, `VIAL_BOTT_EMPTY.png`, `VIAL_CLEAR_GLASS.png`,
  `VIAL_RESIDUE.png`, `VIAL_CLASP_FRAME.png`, `VIAL_CLEAR_GLASS.png`,
  `RUNES_x.png`, `GLOW_UP1.png`, `GLOW_UP2.png`, `FLAIR.png`.
  Two files are derived: `VIAL_FILL.png`, a white master cut to the shape the
  TUBE pngs define so the colour setting can tint it, and
  `VIAL_CLEAR_CLASP.png`, the clear glass with the clasp frame fitted over it.
  `VIAL_FILL.png` is the one derived file: a white master cut to the shape the
  TUBE pngs define, so the colour setting can tint it.
- Stat-tracking approach and the discipline of not redrawing a HUD that has not
  changed: [ErnMMUI](https://github.com/erinpentecost/ErnMMUI) by Erin
  Pentecost, AGPL-3.0. No ErnMMUI code is included here.
- SuperSettingsRenderers, bundled unaltered.
- Settings page style follows Sun's Dusk, as do MoonHUD and BSCompass.

---

## A note on storage handlers

OpenMW refuses a storage write made from inside that section's own subscribe
handler:

```
Storage handler shouldn't change the storage section it handles
(leads to an infinite recursion)
```

The preset machinery trips over this in one place: the "Save current settings
to" selector puts itself back to `--` after saving, so the same slot can be
written twice in a row, and that write lands in the section the handler is
subscribed to. It is deferred to the next simulation tick instead, where it is
an ordinary write.

`dev/load_check.lua` enforces the same rule, so a mod that breaks it fails
offline rather than on the first settings change in play.
