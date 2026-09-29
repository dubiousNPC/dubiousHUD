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

- Click and drag to move the meters.
- Click and mousewheel to resize them. The vials and the rune column scale
  together, so the set keeps its proportions.

---

## The vials

`glass_tube.png` is 13 × 139 and almost entirely transparent — mean alpha 118 at
its brightest column, nothing at all down either edge. It is a highlight streak
and a foot, not a container.

So the vial is two layers: a block of colour behind, the glass in front. The
colour spans the full width, because there is no rim for it to stay inside of.
It fills from the bottom by moving its top edge down as it shrinks — position
`y = 1 − fraction` against size `y = fraction`. Leaving the position at zero
would drain it from the bottom up, which is the wrong way round for a tube.

Health is red and stamina green by default, as specified. Both are configurable,
and there is a reason you might want to change them — see **Readability** below.

`Empty Portion` puts a faint wash of the same colour above the fill line. At the
default of 0 the empty part of the tube is bare glass; raise it if you want the
tube to stay readable as a shape when it is nearly drained.

---

## The runes

`KainGameRUNES.png` and `KainGame_RUNES_GLOW.png` are both 70 × 328 and
registered pixel-for-pixel: every glow shape sits behind its own rune.

The base runes are always drawn. The glow is eight separate slices, one per
rune, each cut from the sheet by texture offset and drawn *behind* the base.
A rune's glow goes out when its eighth of your magicka is fully spent, and comes
back the moment that eighth starts to refill — the boundary is at *any* fill,
not at half of one. By default the bottom rune is the first to light and the
last to go out; **Runes Fill From** flips that.

**Fade the Partial Rune** (on by default) fades the rune currently being spent
with what is left of its eighth, rather than holding it at full glow until it
empties. It costs nothing: the fade is quantised to 16 steps.

### About the sheets

Only the top **276** rows of the 328 carry art. The remaining 52 are empty
padding. The textures ship exactly as supplied rather than cropped — the widget
reads rows 0–275 and never looks at the tail, so there is no dead space under
the bottom rune and nothing was destroyed to get that.

The eight runes are hand-drawn and their heights differ by up to 17px, so the
boundaries are measured rather than assumed even:

```
rune 1   0– 33      rune 5  139–170
rune 2  33– 70      rune 6  170–205
rune 3  70–110      rune 7  205–232
rune 4 110–139      rune 8  232–276
```

Seven of those eight cuts fall in rows where both sheets are empty. The
exception is between runes 6 and 7: the glow bridges rows 203–206 while the base
runes are already apart, so that cut sits at 205, the narrowest point of the
bridge. `dev/check_all.sh` asserts the eight slices tile the column with no gap
and no overlap, at four different column heights — a gap shows as a dead stripe,
an overlap double-draws the glow and reads as a brighter seam.

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
- A **rune** is redrawn only when it lights or goes out — eight states, or 16
  alpha steps with the partial fade on.
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

- **78 behavioural checks** against the real module and the real widget tree.
  `dev/test_vials.lua` deliberately re-implements none of the module's logic — a
  test that mirrors the code only ever proves the mirror is faithful. It drives
  `onUpdate` and reads the tree that was actually built.
- Every settings branch that changes the shape of the tree, loaded for real.
- The rune slices checked for gaps and overlaps at four column heights.
- Stat extremes, including all three at zero and magicka at 0.1%.
- A `pcall` audit over the shipped scripts.

The behavioural tests are mutation-checked. Flipping the rune fill order,
dropping the bottom-anchor on the fill, removing the stat clamp, or drawing the
glow over the base runes instead of behind them each make the suite fail.

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
I.DBSVials.setVisible(false)
I.DBSVials.isVisible()
```

From a script that cannot see the interface — a global script, or a mod that
loads earlier — the same is reachable by event:

```lua
player:sendEvent('DBSVialsSetVisible', { show = false })
```

---

## Credits

- Vial, rune and glow art: **Dubious**.
- `glass_tube.png`, `KainGameRUNES.png`, `KainGame_RUNES_GLOW.png` ship
  unmodified.
- Stat-tracking approach and the discipline of not redrawing a HUD that has not
  changed: [ErnMMUI](https://github.com/erinpentecost/ErnMMUI) by Erin
  Pentecost, AGPL-3.0. No ErnMMUI code is included here.
- SuperSettingsRenderers, bundled unaltered.
- Settings page style follows Sun's Dusk, as do MoonHUD and BSCompass.
