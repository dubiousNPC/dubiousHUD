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
  Each notch is a fixed *proportion*, so it moves at the same apparent speed at
  every size; hold Shift for single-pixel steps.

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

The two ramps are not interchangeable sets to pick between — one is the health
liquid and one is the stamina liquid, and that is what tells the tubes apart.
`ENGY01` runs yellow to red, `ENGY02` blue to red. Nothing is tinted; the
artwork carries its own colour.

**Liquid Colour** offers the other way round:

| | |
|---|---|
| **Classic** | The artwork as supplied. The liquid shifts through its ramp as it drains. |
| **Vanilla** | One flat colour that does not shift, taking the same **Health Liquid** and **Stamina Liquid** colours the LOK vials use, so the two sets read alike. Tint it to anything. |

Vanilla needs two things the supplied art does not contain, so
`dev/build_engy_masks.py` generates them — both white, so they tint to anything:

```
dbs_ENGY_liquid.png    32 frames, the liquid region of each ENGY frame
dbs_ENGY_backing.png   1 frame, the area the outline encloses
```

The liquid region is found by **difference against the atlas's own last frame**,
which is the empty tube: whatever differs from the empty tube is liquid. Picking
it out by colour instead would have to separate a saturated liquid from the
glass highlights over it, and the near-empty frames are white and red — exactly
where that fails. The glass for Vanilla is that same last frame, drawn over the
flat liquid, so the highlights still fall where they were drawn to fall.

The backing is a *row-span* fill, not a flood fill: the outline is not closed.
Rows 3 and 4 of `dbs_ENGY_frame.png` have no outline at all and row 5 only has
its left side, so a flood leaks out through the neck and fills the canvas. Each
row takes the span between its leftmost and rightmost outline pixel instead, and
a row with none inherits the one above — right for this art, because those rows
are the straight part of the collar.

**Tube Backing** then draws that shape behind the glass, which is what a
background for this set should be: a rectangle behind a round-ended tube reads
as a mistake. `dbs_ENGY_frame.png` goes over the top as the **Outline**.

### The fortified part

A Fortify Maximum genuinely gives you more capacity, so the vessel grows and the
liquid you had is a smaller share of it. That is honest, but on its own it reads
as a loss. So the part of the liquid above your *unfortified* maximum is drawn
in its own colour (**Fortified Colour**, gold by default), and the smaller share
reads as the vessel growing rather than as damage.

It is not drawn as a band. A band would need a sub-rect cut from the middle of
the tube art and there are 140 × 140 possible middles — far too many to cut and
keep. The fortified layer is a **full** column in its own colour with the
ordinary liquid drawn on top of it, so only the part above shows: two draws from
the 140 cuts that already exist, and the taper at the foot stays correct in both.

A drain is the opposite case and is handled by the scale rather than the colour.
The vessel is scaled against `max(base, base + modifier)`, so a Drain Maximum
does *not* lower the scale — scaling to `base + modifier` there would make the
liquid jump **up** as your maximum is taken away. The vessel keeps its size and
the headroom above the liquid is what has gone.

Works on the Classic vials and on Battlespire Vanilla. Not on the Battlespire
Classic ramp, which is one image carrying its own colour.

### Smoothing, and the idle flag that pays for it

**Fill Smoothing** eases the drawn level towards the real one instead of jumping,
so a hit reads as the vial draining. The form is `1 - exp(-k·dt)`, which is
frame-rate independent — a plain `d * 0.1` per frame moves at a speed that
depends on the frame rate, which is why a mod tuned at 60fps looks wrong at 144.
The test asserts that a quarter of a second gets to the same place at 30fps and
at 144. Set it to 0 and the level is exact.

The ease snaps once it is within a hair of its target, and that snap is what
makes the whole thing affordable: an exponential approach never arrives on its
own, so without it the HUD would work every frame forever. Once everything has
settled, `onUpdate` returns after reading the three stats once and comparing
them. That is the state the HUD is in for most of the game.

Both are borrowed from PixelHUD, which arrived at the same discipline from the
other direction.

### Vial length

**Vial Length** draws between 63 and 139 rows of tube. Everything below it —
the clasp, the bulb, the foot of the liquid, the assembly height — moves up by
the same amount, so the vessel stays one object and the liquid still fills it
end to end. At 63 with the clasp switched off you get the short standalone vial.

It is a **separate setting from Vial Size**, and the two do not interact. Size is
how big the glass is drawn; length is how much of it there is. The scale is taken
from the full 190-row art height, never from the shortened height, so the width
and every fitting stay exactly as Size set them and a shorter vial is simply
shorter on screen:

| Vial Size 190 | 139 rows | 120 | 100 | 80 | 63 |
|---|---|---|---|---|---|
| widget | 40 x 190 | 40 x 171 | 40 x 151 | 40 x 131 | 40 x 114 |

Scaling by the shortened height instead would make Size mean "fill this many
pixels whatever the length", which is the same setting wearing two labels: the
vial would hold 190px at every length and reach 66 wide at 63 rows — a 65%
fattening nobody asked for. Width is the tell, so width is what the tests read.

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

## The settings page

Eleven small groups rather than five large ones. A group *is* a storage section,
so the grouping is the layout: anything you would change in one sitting sits
together, and each of the three subjects gets a leading group that reads as its
banner.

```
General                     show/hide, lock, opacity, arrangement, spacing
Vials                       which set, size, position
  Vials: Classic (LOK)      length, liquid colours, the tube
  Vials: Classic Fittings   clasp, collar, bulb, dreg, metal tint
  Vials: Battlespire (BS)   ramp, a tint per tube, frame
Runes                       style, size, count, fill direction, position
  Runes: Pips               everything that only applies to pips
  Runes: Colour and Glow    rune, glow and flair tints and opacities
Numbers                     the figures under each meter
Low Warning                 the pulse
Frame                       background and border
```

Nothing is in a group it is not about. The old page had twenty-three settings
under Vials and twenty-one under Runes, with pip settings, flair settings and
Battlespire settings in among them; most of any screenful did not apply to what
you were actually looking at.

Defaults are the author's own working configuration rather than the art's 1:1
figures, so a fresh install looks like the screenshots. The two position
defaults are stored as a distance from the right and bottom edges, so they land
in the same corner on any resolution rather than off the side of a smaller one.

Regrouping moves settings between storage sections, which would ordinarily put
an existing install back on the defaults. It does not: anything a new section
has not got yet is taken from wherever it used to live, once, before anything
subscribes. **Rune Size** is computed from the old **Rune Column Height**.

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

#### Rune size, and one aspect ratio

There used to be a **Rune Column Height** and a **Rune Column Width**, and the
mousewheel drove the width from the width it had just rounded:

```lua
local scale = h / math.max(1, RUNE_HEIGHT or 139)
runeSection:set('RUNE_WIDTH', math.floor((RUNE_WIDTH or 35) * scale + 0.5))
```

That compounds. Twenty notches up and twenty back does not return the column to
where it started, and because the default pair (35 x 139) was measured off the
*Classic* sheet, the xs runes — whose cells are 27 x 30 — were being stretched
**2.2x wider than they were drawn** before anyone touched the wheel.

Now there is one **Rune Size**: the height of a single rune. The width is
derived from the artwork of whichever style is in use (27:30 a rune for Runes,
70:292 for the eight bands of Classic) and is never read back, so it cannot
drift. The column is `size x count` tall, which is what makes Rune Size and
Rune Count independent in the same way Vial Size and Vial Length are.

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
case. There are two size settings and no more: **Vial Size** (24–600px) and
**Rune Size** (4–64px per rune). Both drive their widget's width as well as its
height, from the artwork's own proportions, so nothing can be stretched out of
shape on the way to a size you can read — and the mousewheel gesture reaches
both.

---

## Performance

`onUpdate` reads three stats, divides, and quantises. If nothing quantised has
moved it returns without touching the UI. It allocates nothing in the common
path: no tables, no textures, no vectors beyond the two the engine needs when a
value has genuinely changed.

Textures are cut once. A `ui.texture` is decided entirely by its path and its
sub-rect, so the same three numbers always give the same resource; they are
memoised on those. This matters because *every settings change rebuilds the
tree*, and the resize wheel is a settings change per notch — the whole set,
around 250 cuts including a 140-frame fill ramp, used to be cut again on each
one. Ten notches of the wheel cut **2,570** textures before and fewer than
**40** now; the test asserts it.

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

- **354 behavioural checks** against the real module and the real widget tree.
  `dev/test_vials.lua` deliberately re-implements none of the module's logic — a
  test that mirrors the code only ever proves the mirror is faithful. It drives
  `onUpdate` and reads the tree that was actually built.
- Every settings branch that changes the shape of the tree, loaded for real.
- The six vial pieces checked for register at five sizes, and the rune slices
  for gaps and overlaps at four column heights. Both are read off the tree the
  module builds, not asserted against a copy of the arithmetic.
- Vial width and fitting sizes checked against Vial Length at three scales, so
  the two settings cannot quietly become one.
- Both Battlespire colourings read off the tree: each tube draws its own ramp,
  Classic tints nothing, Vanilla's flat colour does not shift as it drains, and
  the backing sits under the liquid which sits under the glass.
- A fortify and a drain driven through the real accessors, checking the vessel
  grows for one and holds its scale for the other.
- Smoothing checked for frame-rate independence (a quarter second at 30fps and
  at 144 land within two pixels), for arriving rather than approaching forever,
  and for going idle afterwards — measured by counting stat reads, because the
  picture is identical whether onUpdate returns early or works and finds
  nothing.
- The resize wheel driven for real: the step scales with the size, up-then-down
  returns to the start, Shift is a single pixel, both ends clamp, and the grab
  survives the rebuild its own first notch causes.
- A rebuild counted against the texture cuts it makes, so the cache cannot
  quietly stop working.
- The rune column's aspect read off the tree at five sizes in both styles.
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
height, tinting both dregs the same, taking the vial's
scale from its shortened height instead of the full art, putting the drag flag
back on the widget where a rebuild wipes it, dropping the texture cache,
stepping the wheel by a fixed number of pixels, giving both Battlespire tubes
one ramp, letting the Vanilla colour shift as it drains, drawing the fortified
layer over the liquid instead of under it, scaling the vessel to base + modifier
so a drain makes the liquid rise, easing by a fixed fraction per frame instead
of by elapsed time, dropping the snap so the ease never arrives, subdividing the rune column instead of extending it, putting both halos on one rune,
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
