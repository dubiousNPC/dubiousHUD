# Morrowind / OpenMW Lunar Phases — collated findings

Everything below is derived from the five sources you supplied, cross-checked against
the OpenMW engine source. Where a source disagrees with the engine, the engine wins
and the disagreement is explained rather than averaged away.

---

## 1. The engine model (authoritative)

From OpenMW master, `apps/openmw/mwworld/weather.cpp`, `MWWorld::MoonModel::phase()`:

```cpp
// Morrowind starts with a full moon on 16 Last Seed and then begins to wane
// 17 Last Seed, working on 3 day phase cycle.
// If the moon didn't rise yet today, use yesterday's moon phase.
if (gameTime.getHour() < moonPhaseHour(gameTime.getDay()))
    return static_cast<Phase>( (gameTime.getDay()     / 3) % 8 );
else
    return static_cast<Phase>( ((gameTime.getDay() + 1) / 3) % 8 );
```

That is the whole algorithm. Integer division, modulo 8, and an hour-of-day branch.

### Phase enum order

`MWRender::MoonState::Phase`, in numeric order:

| Index | Phase | MWScript `phaseValue` | 5-bucket name | Direction |
|---|---|---|---|---|
| 0 | Full | 4 | Full | — |
| 1 | WaningGibbous | 3 | Gibbous | waning |
| 2 | ThirdQuarter | 2 | Half | waning |
| 3 | WaningCrescent | 1 | Crescent | waning |
| 4 | New | 0 | New | — |
| 5 | WaxingCrescent | 1 | Crescent | waxing |
| 6 | FirstQuarter | 2 | Half | waxing |
| 7 | WaxingGibbous | 3 | Gibbous | waxing |

Order confirmed two ways: the source comment ("starts with a full moon… then begins
to wane"), and empirically — 761 of 764 observed moon-days fit this ordering and no
other rotation of it fits as well.

### What follows from it

1. **Both moons run the identical sequence.** There is no separate Masser cycle and
   no separate Secunda cycle. They differ *only* in `moonPhaseHour()`.
2. **Phase is a function of day AND hour.** `moonPhaseHour()` is driven by
   `Moons_<name>_Daily_Increment` (Masser `1.0`, Secunda `0.75`), so the two moons
   cross their rollover point at different times of day.
3. **The period is exactly 24 days.** 8 phases × 3 days. It never varies.
4. **A new game starts on 16 Last Seed 427, day 1, phase Full.**

---

## 2. Reconciling the sources

### `moontracker_explain.txt` — the community research

Genuinely correct:

- 3-day phases.
- Game starts mid-full-moon, so you only get two days of it.
- Roughly 20 days between the end of one full moon and the start of the next.
  (Exactly: 21 days from the last day of Full to the first day of the next Full.)
- Desyncs last exactly one day.

Incorrect, and worth correcting because it has shaped a lot of mods:

| Claim | Reality |
|---|---|
| "there is no pattern… extremely unpredictable" | Fully deterministic. `(day/3) % 8`. |
| "sometimes a phase takes 4 or 2 days" | Never. That is an artefact of checking at a fixed wall-clock hour on either side of a moon's rollover. |
| "USUALLY Secunda changes first when waning… but sometimes they swap" | Not random. Whichever moon's `moonPhaseHour` you have passed at the moment you look has rolled over. |
| "the game does not natively track waning vs waxing" | It does. The 8-value enum encodes direction, exposed as `MOON_PHASE.Waxing*` / `MOON_PHASE.Waning*`. |
| "day 83–119 always in sync, then 176–305 nothing happens" | Artefact of observing at one time of day. Those stretches are where the observation hour sat away from both rollover points. |

The long quiet stretches are the giveaway. A genuinely stochastic process does not go
129 days without an event and then resume.

### `mwscript_moontracker.txt` — the MWScript implementation

Superseded. The one-second delay after day change existed because MWScript polled
`GetMasserPhase` before the engine had recomputed. Lua reads `MoonModel` state live,
so no delay is needed. `core.weather.getCurrentMoons(cell)` returns name, phase,
`phaseValue` and alpha in one call.

### `Moon Phases.zip` — the 382-day manual log

**761 / 764 moon-days (99.6%) reproduced by the engine formula.** A row counts as
matching if the observed 5-bucket phase equals *either* the pre- or post-rollover
engine phase, which is exactly the ambiguity a human observer faces.

All 3 mismatches fall inside one week:

| Day | Date | Moon | Logged | Engine says |
|---|---|---|---|---|
| 121 | 14 Evening Star | Masser | Gibbous | Full |
| 124 | 17 Evening Star | Secunda | Half | Waning Gibbous |
| 127 | 20 Evening Star | Secunda | Crescent | Third Quarter |

Three errors, all one phase early, all three days apart, all in the same week. That
is the signature of a single row-shift while transcribing, not engine variance.

**Verdict: trustworthy.** Shipped in `MH_constants.lua` as a regression fixture, not
as a runtime lookup table.

### `Lunar Calendar_Shared.csv` — ⚠️ not OpenMW

This describes a completely different lunar system:

| | This CSV | OpenMW |
|---|---|---|
| Moons | Jode / Jone (Ta'agra names) | Masser / Secunda |
| Jode / Masser cycle | 30 days | 24 days |
| Jone / Secunda cycle | 8 days (one day per phase) | 24 days |
| Year length | 360 days | 365 days |
| Moons independent? | Yes, different periods | No, identical sequence |

Both cycles are perfectly regular here, which OpenMW's are not in appearance. It also
carries `provinceName` placeholders and Daggerfall summoning days — this is
**Daggerfall-era / Khajiit lore**, most likely for furstock determination (which
breed a kitten is born as depends on the moons).

**Do not drive gameplay checks from it.** It is genuinely useful for: the 64 Tamrielic
holidays and their descriptions, the 16 furstocks, and any in-world almanac item.

---

## 3. The 24-day cycle, in full

| Cycle day | Phase | `phaseValue` | Bucket |
|---|---|---|---|
| 0–2 | Full | 4 | Full |
| 3–5 | Waning Gibbous | 3 | Gibbous |
| 6–8 | Third Quarter | 2 | Half |
| 9–11 | Waning Crescent | 1 | Crescent |
| 12–14 | New | 0 | New |
| 15–17 | Waxing Crescent | 1 | Crescent |
| 18–20 | First Quarter | 2 | Half |
| 21–23 | Waxing Gibbous | 3 | Gibbous |

Cycle day = `(DaysPassed + 1) % 24`.

Useful intervals:

- Full → next Full: **24 days**
- Last day of Full → first day of next Full: **21 days**
- Full → New: **12 days**
- Any phase lasts **3 days**, always

---

## 4. Practical guidance for mods

**Just read the engine.** In an active exterior cell:

```lua
local core = require('openmw.core')
local moons = core.weather.getCurrentMoons(self.cell)   -- nil in interiors
for _, m in ipairs(moons or {}) do
    print(m.name, m.phase, m.phaseValue, m.alpha)
end
```

**Do not poll on day change.** Phase changes at each moon's `moonPhaseHour`, not at
midnight. If you need an event, watch for the value changing.

**Do not assume the moons agree.** Check each one. They disagree on roughly 8% of
days (32 of 382 in the log), always for exactly one day.

**Handle `nil`.** `getCurrentMoons` returns nil in interiors and inactive cells. That
is the entire reason `MH_tracker.lua` exists.

**"Full moon tonight" needs care.** A moon can be in phase Full while being invisible
(`alpha == 0`) because it is below the horizon. Check `alpha` if visibility matters
to your effect.

---

## 5. Files

| File | What it is |
|---|---|
| `Morrowind_Lunar_Reference.xlsx` | 7 sheets: engine model, 24-day cycle, all 382 observed days vs engine prediction, desync days, Morrowind calendar, lore calendar, reconciliation |
| `MoonHUD/scripts/moonhud/MH_constants.lua` | Constants, phase model, 382-day fixture, atlas layout |
| `MoonHUD/scripts/moonhud/MH_tracker.lua` | The tracker, 4 fallback tiers |
| `MoonHUD/scripts/moonhud/MH_hud.lua` | The on-screen widget |
| `MoonHUD/dev/test_tracker.lua` | Offline harness, 548 assertions |

---

## 6. Shade of the Revenant

Every eighth day, anchored on **27 Last Seed**:

```
27 Last Seed → 4 Hearthfire → 12 → 20 → 28 → 6 Frostfall → 14 → 22 → 30 Frostfall
```

**It is 27 → 4 → 12, not 27 → 5 → 13.** Last Seed has 31 days, so 27 + 8 lands on
4 Hearthfire. The 27 → 5 → 13 sequence only works if you assume 30-day months, which
is the *lore* calendar's structure, not Morrowind's.

Confirmed against UESP's Oblivion days-passed table, which lists exactly:
1 → Last Seed 27, 9 → Heartfire 4, 17 → Heartfire 12, 25 → Heartfire 20,
33 → Heartfire 28, 41 → Frostfall 6, 49 → Frostfall 14, 57 → Frostfall 22,
65 → Frostfall 30.

Two things worth knowing:

- **This is an Oblivion mechanic, not a Morrowind one.** The anchor date is 27 Last
  Seed because that is when Oblivion begins; the event there is just
  `DaysPassed % 8 == 1`. Morrowind starts on 16 Last Seed, so in a Morrowind game the
  first Shade falls eleven days in.
- **The dates do not repeat annually.** 365 is not divisible by 8 (365 mod 8 = 5), so
  the sequence slides five days each year. First Shade of Morning Star: the 7th in
  3E 427, the 2nd in 428, the 5th in 429, the 8th in 430.

The implementation anchors to a calendar date rather than to `DaysPassed`, which
survives save transplants and console time travel, and does not care when the game
began. Anchor and interval are both configurable.

---

## 7. Lore calendar vs engine, measured

The lore calendar's Jode phase agrees with the OpenMW phase for the same date on
**39 of 360 days — 10.8%**. Random guessing among 8 phases would score 12.5%.

The lore calendar is not an inaccurate description of OpenMW's moons. It is a
description of something else entirely.

| | Lore calendar | OpenMW |
|---|---|---|
| Moons | Jode / Jone | Masser / Secunda |
| Masser cycle | 30 days | 24 days |
| Secunda cycle | 8 days | 24 days |
| Moons independent? | Yes | No — identical sequence |
| Year | 360 days | 365 days |
| Repeats annually? | Yes | No — slides 5 cycle-days a year |
| Phase duration | 1–5 days | Always 3 |

See `Lore_vs_Engine_Calendar.xlsx` for the day-by-day working, and
`TAMRIELIC_HOLIDAYS.md` for the 64 holidays, which are the part of that file worth
keeping.
