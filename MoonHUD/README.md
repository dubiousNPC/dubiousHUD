# MoonHUD

Tracks Masser and Secunda, and shows their phases on screen.

Two independent pieces — use either on its own:

- **`MH_tracker.lua`** — a `MoonTracker` interface other mods can call. Reads the
  engine where it can, falls back gracefully where it can't.
- **`MH_hud.lua`** — the widget. Built to match TimeHUD and LocationHUD, with the
  same settings, the same drag/scroll gestures and the same border styles.

Requires OpenMW with the Lua `core.weather` moon bindings (API revision ~62+, so
0.49 and later). Degrades to a calculated phase on older builds rather than failing.

---

## Install

Copy the `MoonHUD` folder into your data directories, then in the launcher:

1. **Data Files → Data Directories** → add the folder containing `MoonHUD`
2. **Data Files → Content Files** → tick `moonhud.omwscripts`

Settings live under **Options → Scripts → MoonHUD**.

---

## Settings

Everything TimeHUD and LocationHUD expose is here, plus a **Moons** group.

### General

| Setting | Default | Notes |
|---|---|---|
| HUD Display | Always | Always / Interface Only / Hide on Interface / Hide on Dialogue Only / Never |
| Lock Position | off | Disables click-and-drag |
| X Position / Y Position | 12 / bottom-left | Also set by dragging the widget |
| Only display outdoors | off | Tracker keeps running regardless |
| Only display when a moon is up | off | Uses real sky alpha; needs an active exterior |
| Visibility Mode | Persistent | Or "On Phase Change" — appears, holds, fades |
| Hold Duration | 5 s | "On Phase Change" only |
| Fade Duration | 2 s | "On Phase Change" only |

### Appearance

| Setting | Default |
|---|---|
| Font Size | 20 |
| Text Color | game's `FontColor_color_normal` |
| Background Opacity | 0.5 |
| Alignment | Left |

### Moons

| Setting | Default | Notes |
|---|---|---|
| **Display Mode** | Icons + Text | **Text / Icons / Icons + Text** |
| Layout | Vertical | Or Horizontal |
| Icon Size | 32 px | Atlas cell is 64, so 64 is 1:1 |
| Icon Spacing | 6 px | |
| **Moon Artwork** | `moon_atlas` | Five bundled sheets, or Custom — see below |
| Atlas Path (Custom) | `textures/moonhud/moon_atlas.png` | Only read when Moon Artwork is Custom |
| **Atlas Cell Size** | 64 | Cell width/height in your sheet |
| Show Masser / Show Secunda | on / on | |
| Show Moon Names | on | |
| Phase Names | Descriptive | Descriptive (`Waning Gibbous`) / Simple (`Gibbous`) / Value (`3`) |
| Dim with sky visibility | off | Fades each icon with that moon's real alpha |
| Show data source | off | Debug: appends `engine` / `projected` / `formula` / `fixture` |
| **Show Shade of the Revenant** | on | Adds a third line — see below |
| Shade Display | Always | Always / Only When Active / Countdown Only |
| Shade Anchor Month | Last Seed | |
| Shade Anchor Day | 27 | |
| Shade Interval | 8 | Days between occurrences |
| Update Interval | 30 in-game min | Phases move once every 3 days, so this can be lazy |

### Border

Border on/off, style (thin / normal / thick / verythick), colour, padding — the same
four options and the same textures as TimeHUD, LocationHUD and Quickloot.

> **Colour pickers.** MoonHUD ships with no dependencies, so colours are plain hex
> text fields. If you have TimeHUD or LocationHUD installed you already have their
> `SuperColorPicker2` renderer — set `COLOR_RENDERER = 'SuperColorPicker2'` at the
> top of `MH_settings.lua` for a colour wheel.

---

## Shade of the Revenant

The third data point. Every eighth day, anchored on **27 Last Seed**:

```
27 Last Seed → 4 Hearthfire → 12 → 20 → 28 → 6 Frostfall → 14 → 22 → 30 Frostfall
```

**Note it is 27 → 4 → 12, not 27 → 5 → 13.** Last Seed has 31 days, so 27 + 8 lands
on the 4th of Hearthfire. This matches UESP's Oblivion "days passed" table exactly —
Oblivion begins on 27 Last Seed, which is where the anchor date comes from, and the
event there is simply `DaysPassed % 8 == 1`.

Anchoring to a **calendar date** rather than to `DaysPassed` is deliberate: it
survives save transplants and console time travel, and it doesn't care when your game
began. Both the anchor and the interval are settings if you want a different cadence.

Because 365 isn't divisible by 8, **the dates don't repeat year to year** — the
sequence slides by five days each year (365 mod 8 = 5). The first Shade of Morning
Star falls on the 7th in 3E 427, the 2nd in 428, the 5th in 429, the 8th in 430.

It's pure calendar arithmetic, so it works indoors, in inactive cells, and on engine
builds with no moon bindings at all.

```lua
local shade = I.MoonTracker.getShade()
-- { active = false, daysUntil = 3, date = { year = 427, month = 9, day = 4 },
--   dateString = '4 Hearthfire', interval = 8 }

I.MoonTracker.isShadeDay()          -- boolean
I.MoonTracker.upcomingShades(8)     -- next 8 dates as strings
I.MoonTracker.setShadeConfig{ ANCHOR_DAY = 1, INTERVAL_DAYS = 10 }
```

Fires `MoonTracker_ShadeOfTheRevenant` on the player when a Shade day begins.

---

## Artwork presets

Five bundled phase sheets, chosen under **Moons → Moon Artwork**. All share the
same 8 × 3 layout, so switching is instant and needs nothing else changed.

| Preset | Style |
|---|---|
| `moon_atlas` | soft shaded discs — the default |
| `moon_atlas_1` | woodcut: flat two-tone with a hard outline |
| `moon_atlas_2` | cratered: mottled surface |
| `moon_atlas_3` | celestial: outer halo with a ringed chart face and cardinal ticks |
| `moon_atlas_4` | engraved: line art with a hatched shadow side |
| `Custom` | use **Atlas Path (Custom)** instead |

Three panel fills, under **Panel → Background Fill**:

| Preset | Style |
|---|---|
| `None` | flat black, tinted and faded by the settings below it |
| `panel_bg_stars` | night sky — verified seamless, so it tiles at any panel size |
| `panel_bg_stone` | mottled stone |
| `panel_bg_linen` | fine woven crosshatch |
| `Custom` | use **Background Path (Custom)** instead |

`moon_atlas_3` over `panel_bg_stars` is the strongest pairing if you want the
widget to read as an orrery rather than a HUD.

All five atlases and the star field are regenerated by
`dev/make_atlas_variants.py`, which shares its phase geometry with
`generate_hud_atlases.sh` — the terminator is a half-ellipse with x semi-axis
`r·cos(index × 45°)`.

## The texture atlas

`textures/moonhud/moon_atlas.png` is **512 × 192**:

```
        Full  WanGib  ThirdQ  WanCres   New   WaxCres  FirstQ  WaxGib
row 0   [64]   [64]    [64]    [64]    [64]    [64]    [64]    [64]   ← Masser
row 1   [64]   [64]    [64]    [64]    [64]    [64]    [64]    [64]   ← Secunda
row 2   [lit]  [dim]   [dim]   [dim]   [dim]   [dim]   [dim]   [dim]  ← Shade
```

Row 2 holds the Shade indicator: cell 0 lit, cell 1 dim. Cells 2–7 repeat the dim
state so indexing that row with anything is safe.

Column order is the engine phase index (0–7). Cells are cut out with
`ui.texture{ path, offset, size }`, which is OpenMW's documented atlas mechanism, and
cached — one texture resource per moon/phase pair, created once.

To use your own art, match that layout and change **Atlas Path**. Different cell size
is fine, just set **Atlas Cell Size** to match. Row assignment lives in
`MH_constants.lua` under `ATLAS_ROW` if you want more than two moons.

---

## Using the tracker from your own mod

```lua
local I = require('openmw.interfaces')

local masser = I.MoonTracker.getMoon('Masser')
-- {
--   name        = 'Masser',
--   index       = 1,                                -- 0..7 engine phase index
--   phase       = core.weather.MOON_PHASE.WaningGibbous,
--   phaseName   = 'WaningGibbous',
--   displayName = 'Waning Gibbous',
--   phaseValue  = 3,                                -- MWScript-compatible 0..4
--   bucket      = 'Gibbous',
--   direction   = 'waning',
--   alpha       = 0.83,                             -- sky visibility, nil indoors
--   source      = 'engine',
-- }
```

| Call | Returns |
|---|---|
| `getMoons()` | `{ Masser = info, Secunda = info }` |
| `getMoon(name)` | one info table, or nil |
| `daysUntil(name, phaseName)` | whole days until that phase begins; `0` if current |
| `isFull(name)` / `isNew(name)` | boolean |
| `inSync()` | true when both moons show the same phase |
| `getCycleDay()` | 0–23 position in the cycle, or nil while uncalibrated |
| `getShade()` | Shade state — see below |
| `isShadeDay()` | boolean |
| `upcomingShades(n)` | next `n` Shade dates as strings |
| `setShadeConfig(cfg)` / `getShadeConfig()` | change or read the anchor and interval |
| `getStatus()` | diagnostics — see below |
| `resetCalibration()` | wipe and recalibrate, e.g. after console time travel |
| `constants` | the `MH_constants` table |

Phase changes fire an event on the player:

```lua
eventHandlers = {
    MoonTracker_PhaseChanged = function(data)
        -- data.moon = 'Masser', data.from = 'Full', data.to = 'WaningGibbous'
        -- data.info = the full info table
    end,
    MoonTracker_ShadeOfTheRevenant = function(data)
        -- data.shade = the getShade() table, fired when a Shade day begins
    end,
}
```

---

## How the fallbacks work

`core.weather.getCurrentMoons()` returns `nil` in interiors and inactive cells, which
is most of the time in practice. Four tiers cover it:

| Tier | `source` | When | Accuracy |
|---|---|---|---|
| 1 | `engine` | Active exterior cell | Exact |
| 2 | `projected` | Interior, with a prior engine reading | Exact — verified over a 60-day unbroken interior stay |
| 3 | `formula` | No reading yet (fresh save loaded indoors) | Correct phase, day boundary may be off by one until calibrated |
| 4 | `fixture` | Day index unavailable | The recorded 382-day log |

**Calibration.** Our day counter (`calendar.gameTime() / time.day`) differs from the
engine's `DaysPassed` by an unknown but constant offset. The tracker maintains a
candidate set of all 24 possible offsets and intersects it against every engine
reading. It narrows within a day or two of outdoor play and is persisted in the save.

Sampling only ever at one time of day leaves **two** adjacent candidates standing —
"offset K, rolled over" and "offset K+1, not yet rolled over" predict identical
phases for every day, and no amount of same-hour observation separates them. That is
the information limit, not a bug; it costs at most one day of precision on boundary
predictions and collapses to one candidate as soon as you're outdoors both before and
after moonrise. `getStatus().exact` tells you which you have.

If the day counter jumps (console, another mod, a transplanted save), the candidate
set empties, calibration restarts from that reading, and it re-converges rather than
serving stale data.

---

## Tests

`dev/test_tracker.lua` stubs the OpenMW API and exercises the tracker offline —
**584 assertions**, covering:

- the 382-day fixture against the model (761/764 = 99.6%)
- calibration convergence, including the two-candidate floor
- tier-2 projection against ground truth over 260 moon-days (0 disagreements)
- 60-day interior drift (0 of 120 moon-days)
- `daysUntil` exact *and* minimal for 4 target phases across 48 start days (192 cases)
- recovery from a day-counter jump
- cold start with the engine binding absent entirely
- calendar round-trip over four years (1460 dates)
- the Shade sequence against UESP's published dates, and that 5 and 13 Hearthfire
  are explicitly *not* Shade days
- exactly one day in eight over three years, and the annual five-day slide
- a reconfigured anchor and interval

Run with any Lua 5.3+:

```bash
lua dev/test_tracker.lua
```

`dev/` is not loaded by the game and can be deleted.

---

## Credits

- Border template module is TimeHUD's / LocationHUD's `makeborder`, reused unchanged
  so the border styles match.
- Phase model reverse-engineered from OpenMW `apps/openmw/mwworld/weather.cpp`.
- The 382-day observation log came from the "Moon Phases" research sheet.

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

**Sizes being ignored.** Images now set `tileH = false, tileV = false`. Without
them MyGUI draws a texture at its native size and repeats it to fill the widget,
which looks exactly like the size setting doing nothing. Atlas sub-rect textures
are the usual victims.

**Triangle layouts.** The Layout dropdown only listed Vertical and Horizontal, so
the triangle modes the widget already supported could not be selected.

---

## On `pcall`

There is none in this mod's code. The audit that removed the last of it is worth
recording, because most of it was guarding conditions that do not occur.

| Site | Was catching | Now |
|---|---|---|
| `ui.texture` × 3 | nothing | direct call, path validated by type |
| `util.color.hex` | malformed settings input | pattern match on the input |
| `core.weather.getCurrentMoons` | a nil cell during load | explicit `self.cell` check |

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

**The tracker one was the worst of them.** It treated *any* error from
`getCurrentMoons` as "the binding is broken" and permanently demoted the mod to
its fallback tier for the rest of the session. The one call shape that could
plausibly raise is a nil cell, which happens while a save loads, so that is now
checked directly.

Removing it exposed a bug the `pcall` had been hiding: a reading taken with a nil
cell was being cached, so the fallback stayed in place for up to fifteen in-game
minutes after the cell came back. Readings are now only cached when the cell is
live.

`dev/check_all.sh` covers both replacements — 24 checks on the colour validator
including eight malformed inputs, and 7 on the nil-cell guard including that the
engine tier recovers afterwards.
