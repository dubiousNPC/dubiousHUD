# BSCompass

A dial compass HUD for OpenMW, driven by a vertical texture atlas.

Built to sit alongside TimeHUD and LocationHUD — same settings layout, same
drag-and-scroll gestures, same border textures.

---

## Install

Copy the `BSCompass` folder into your data directories, then in the launcher:

1. **Data Files → Data Directories** → add the folder containing `BSCompass`
2. **Data Files → Content Files** → tick `bscompass.omwscripts`

Settings live under **Options → Scripts → BSCompass**.

### Dependencies

**SuperSettingsRenderers** — for the sliders, selects and colour wheel on the
settings page. If you don't have it, open `scripts/bscompass/BSC_settings.lua` and
change one line near the top:

```lua
local SUPER = false
```

That falls the page back to OpenMW's built-in renderers. Nothing else changes.

Nothing else is required.

---

## A note on ErnCompass

You asked for ErnCompass as a dependency. It can't be one in the literal sense —
`compass_p.lua` returns only `engineHandlers` and `eventHandlers`, with no
`interfaceName` and no `interface` table, so there is nothing for another script to
`require` or call. It's a self-contained widget, not a library.

So BSCompass is standalone. What it does take from ErnCompass:

- the same heading convention, so the two always agree on which way you're facing
- the same drag-to-move and scroll-to-resize gestures
- the same `HUDTransparencyChange` event handling, so both fade together
- the same "outdoors only" default

**They coexist happily.** ErnCompass gives you the 16-wind text (`NNE`), BSCompass
gives you the dial. Run both if you want both, or just this one.

One deliberate difference: ErnCompass reads the heading with
`camera.viewportToWorldVector()`, which does a matrix transform and degenerates when
you look straight up or down. BSCompass uses `camera.getYaw()`, a scalar read that is
both cheaper and well-defined at every pitch.

---

## Performance

This was the brief, so here's exactly what it does per frame.

**Cost when hidden** — indoors, HUD toggled off, or in a menu — is one boolean test
and a return. No heading read, no arithmetic, no allocation.

**Cost when visible**, per frame:

1. Decrement a counter. If it hasn't hit zero, return. (`Sample Every N Frames`,
   default 2.)
2. One `camera.getYaw()`, one modulo, one floor. All scalar.
3. Compare against the current frame index. **If unchanged, return** — this is the
   common case.
4. Only on change: assign a texture reference and call `:update()`.

With a 36-frame atlas each frame covers 10°, so step 4 fires once per 10° of turn.
Standing still it never fires at all.

**What is not done per frame:**

- `ui.texture` is never called. All 36 textures are built once at load and cached in
  a flat array. Rebuilt only if you change an atlas setting.
- No table is allocated in `onFrame`. No `util.vector2`, no closures, no string
  concatenation.
- Settings are read from Lua globals, not from `storage`, because a storage lookup
  per frame is far more expensive than a global read. The settings module mirrors
  them into globals on change.
- The element tree is never rebuilt while running. Style changes poke `props`
  directly; only structural changes (border, padding, lock) rebuild.

If you want it cheaper still, raise `Sample Every N Frames`. At 3 the compass is
still visually smooth and does a third of the sampling work.

---

## The atlas

`textures/bscompass/BSCompasAtlas.png` is **88 × 3168** — a vertical strip of 36
frames, 88 × 88 each, top to bottom, starting at north.

Each frame is 10° of heading. The needle rotates clockwise by exactly 10° per frame
index; measured across all 36 frames the mean is **−10.00°** and the loop closes at
exactly −360°.

To use your own strip, set **Atlas Path**, **Atlas Tile Count** and **Atlas Tile
Size**. Any frame count works — 8, 16, 64, 360 — as long as the frames are evenly
spaced and frame 0 is north.

### Which way does it turn?

The mapping is:

```lua
frame = (tileCount - round(headingDegrees / step)) % tileCount
```

Note the **subtraction**. A world-fixed marker has to rotate *counter*-clockwise on
screen as you turn clockwise. Since this artwork's needle rotates clockwise with
increasing frame index, the index has to advance as the heading *decreases*.

Sanity check in game: **face north, then turn right. The needle should swing left.**
If it swings right, tick **Invert Rotation** and it's fixed.

For what it's worth, the artwork's long arm points **south**, not north — frame 0
(facing north) has it pointing down, frame 18 (facing south) has it pointing up.
That's consistent at all four cardinals and across the full sweep, so it's the
design, not an indexing error. If you expected the long arm to be the north head,
that's the thing to look at first.

---

## Settings

### General

| Setting | Default | Notes |
|---|---|---|
| HUD Display | Always | Always / Interface Only / Hide on Interface / Hide on Dialogue Only / Never |
| Lock Position | off | Disables click-and-drag |
| X / Y Position | top right | Also set by dragging |
| Only display outdoors | **on** | Also means zero per-frame work indoors |

### Compass

| Setting | Default | Notes |
|---|---|---|
| Size | 88 px | Atlas tile is 88, so 88 is 1:1 |
| Opacity | 1.0 | |
| Tint | white | Multiplied over the artwork |
| Facing Source | Camera | Camera follows the view (incl. third person); Body follows the character |
| Invert Rotation | off | Flip if the needle turns the wrong way |
| Heading Offset | 0° | Rotates the artwork, for atlases that don't start at north |
| **Sample Every N Frames** | 2 | Raise to do less work |
| Atlas Path / Tile Count / Tile Size | bundled / 36 / 88 | |

### Frame

Background on/off and opacity, border on/off, style (thin / normal / thick /
verythick), colour, padding. Border textures and styles are shared with TimeHUD,
LocationHUD and Quickloot. Both background and border default **off**, since the
artwork already has its own bezel.

---

## Tests

`dev/test_heading.lua` verifies the heading maths offline — **120 assertions**, no
game needed:

- the atlas rotates −10.00° per frame and closes a full −360°
- every frame is reachable and covers exactly 10° of heading
- a world-fixed marker counter-rotates correctly at all 36 headings
- the four cardinals, and that the needle tracks south to within 1.8° across the
  full sweep
- inverted mapping is an exact mirror
- heading offset shifts the right way
- 4-, 8-, 16-, 32-, 64- and 360-frame atlases all use every frame
- row-major grid indexing, and that all 360 cells of a 30×12 sheet are distinct
  and in bounds
- the 36- and 360-frame sheets agree on where north is at every cardinal
- the texture-size arithmetic that forces a grid above ~180 frames

Run with any Lua 5.3+:

```bash
lua dev/test_heading.lua
```

`dev/` is not loaded by the game and can be deleted.

---

## Credits

- Border template module reused unchanged from TimeHUD / LocationHUD
  (`TH_makeborder.lua`).
- Structure and gesture handling follow TimeHUD and ErnCompass.
- The pre-built-texture-array approach is the one Talk To The Hand uses for its own
  compass, which is the right way to do this.
- `BSCompasAtlas.png` is yours; it ships here unmodified.

---

## If the settings page is missing

A Lua error while a script loads takes out **both** the settings page and the
widget, because the whole file stops executing. If neither appears, that is the
first thing to check.

**SuperSettingsRenderers is bundled**, unaltered, under
`scripts/SuperSettingsRenderers`, and registered by the `MENU:` lines at the top
of the `.omwscripts` file. Those lines must come before the `PLAYER:` entries:
a renderer has to exist by the time a settings group names it. Nothing needs to
be downloaded separately, and `local SUPER = true` in the settings file is safe.

If you also run another mod that bundles the same renderers, both copies get
registered. That is harmless — a duplicate `registerRenderer` is logged and
ignored, unlike a duplicate settings *group*, which is fatal.

`dev/check_all.sh` catches load-time breakage without launching the game:

```bash
./dev/check_all.sh
```

It stubs the OpenMW API, executes the scripts for real, runs `onInit` and
`onFrame`, loads the bundled renderers, and cross-checks that every renderer a
setting names is both **present on disk** and **listed as a MENU script**.
Shipping the file without the manifest entry is silent breakage, so those are
verified separately. Run it after editing anything under `scripts/`.

---

## Fixes in this revision

**360-frame wobble.** The expansion picked the nearest source frame and rotated by
the remainder. Each of the 36 source frames carries its own small positional
error, so the chosen source changing every ten frames switched those errors in and
out — a wobble with period 10. Measured needle centroid jitter was 0.63px mean,
4.53px worst. `expand_compass_atlas` now defaults to `--mode single`: every output
frame is one source frame rotated, so the motion is continuous. Jitter drops to
0.29px mean, 0.98px worst, and the rotation rate tightens from -0.980 ± 0.332 to
-1.002 ± 0.201 degrees per frame. `--mode nearest` keeps the old behaviour where
per-frame art detail matters more than smoothness.

The rotation pivot was also `cell / 2`, which is 44 for an 88px cell where the
pixel centre is 43.5. Now `(cell - 1) / 2`.

**East/west and north/south.** The frame index used to be subtracted from the
frame count, on the reasoning that a world-fixed marker counter-rotates as you
turn. In game that put east and west the wrong way round on the BSCompass sheets,
and north and south the wrong way round on the DBS sheet. A mirror about the
north-south axis is a sign flip on the heading; a mirror about the east-west axis
is that same flip plus 180. Both sheets needing the same flip is what identifies
it as a handedness problem rather than an artwork one. The index now advances with
the heading, and the DBS preset carries `headingOffset = 180`.

**Backdrop resizing.** The static art used to be pinned to the arrow's size, so a
1785px housing could not be made larger than the needle, and the Size slider
capped at 320. There are now three layers — backdrop, face, arrow — all sized from
one figure, with the inner two placed as percentages of the backdrop. Size goes up
to 1024. The face layer is unused by the bundled DBS preset, whose corner art
includes its dial; it is there for when that art is split.

**Sizes being ignored.** Images now set `tileH = false, tileV = false`. Without
them MyGUI draws a texture at its native size and repeats it to fill the widget,
which looks exactly like the size setting doing nothing. Atlas sub-rect textures
are the usual victims.


---

## Cardinal glyphs

Artwork that provides them can light the N/E/S/W glyph on the dial as you come
round to face it. The bundled DBS preset does; the plain dial sheets do not, and
the setting simply has no effect there.

Two bands, both configurable under **Cardinals**:

| Setting | Default | Meaning |
|---|---|---|
| Cardinal Glyphs | Sharp + Fade | Off / Sharp / Sharp + Fade |
| Sharp Arc | 15° | either side of a cardinal, solid glyph |
| Fade Arc | 45° | either side, fade glyph ramping off with distance |
| Glyph Opacity | 1.0 | ceiling on the ramp |
| Glyph Tint | white | multiplied over the glyph art |

Cardinals are 90° apart, so at the default fade arc of 45° the bands meet exactly
at the midpoint and tile the whole circle — there is always a glyph on screen
except at the four exact midpoints, where the ramp reaches zero. Narrow the fade
arc below 45° if you want a genuine dead band between them.

The opacity ramp is quantised to 16 steps, so a slow turn produces at most 129
element updates across a full 360° rather than one per frame.

## Named overlays

Layers that nothing raises by itself, for another mod, a quest or an enchantment
to switch on. The DBS artwork defines `eyes` and `dragoneyes`.

From a script that can see the interface:

```lua
local I = require('openmw.interfaces')

I.BSCompass.setOverlay('eyes', { duration = 8 })   -- clears itself after 8s
I.BSCompass.setOverlay('dragoneyes', { alpha = 0.6, tint = someColour })
I.BSCompass.clearOverlay('eyes')
I.BSCompass.clearAllOverlays()

I.BSCompass.isOverlayActive('eyes')   -- boolean
I.BSCompass.getOverlayNames()         -- what this artwork defines
I.BSCompass.getHeading()              -- degrees, and the glyph lit if any
```

From anywhere that would rather not hard-depend — a global script, another mod —
send the player an event instead:

```lua
player:sendEvent('BSCompass_SetOverlay', { name = 'eyes', duration = 8 })
player:sendEvent('BSCompass_ClearOverlay', { name = 'eyes' })
player:sendEvent('BSCompass_ClearAllOverlays')
```

`setOverlay` returns false for a name the current artwork does not define rather
than raising, so a mod can offer to light something without checking first. Omit
`duration` to leave an overlay up until it is cleared.

### Adding your own

Both sets are declared per preset in `BSC_p.lua`, as full-canvas layers drawn at
the backdrop rect. They need no placement figures because they are authored on
the same canvas as the corner art and simply line up:

```lua
cardinals = { N = '...', E = '...', S = '...', W = '...',
              Nfade = '...', Efade = '...', Sfade = '...', Wfade = '...' },
overlays  = { eyes = '...', dragoneyes = '...' },
```

Add a key to `overlays` and it becomes callable by that name immediately.

Every one of these is built once at load, hidden, and toggled by visibility and
alpha. Elements are never created or destroyed while playing, which is what keeps
this inside the per-frame budget.

---

## On `pcall`

There is none in this mod's code. The audit that removed the last of it is worth
recording, because most of it was guarding conditions that do not occur.

| Site | Was catching | Now |
|---|---|---|
| `ui.texture` × 2 | nothing | direct call, path validated by type |
| `util.color.hex` | malformed settings input | pattern match on the input |

**The texture ones were guarding a condition that never happens.** A missing file
is not a Lua error in OpenMW — it logs `Failed to open image: Resource ... not
found` and carries on. `ui.texture` raises only on a malformed argument, which is
a bug in this script. Catching it turned a loud, findable failure into a silently
blank widget, and would have hidden any future change to the binding, which is
the opposite of compatibility.

**The colour one was guarding something real** — whatever was typed into a text
field — but a pattern match does the job without also swallowing a genuine fault
in `util.color`. It now accepts three-digit shorthand as a bonus, and falls back
to white on anything it cannot parse.

`dev/check_all.sh` covers the replacement: 24 checks on the colour validator,
including eight malformed inputs.

