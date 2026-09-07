# Tamrielic Holidays and Festivals

All 64 holiday entries from `Lunar Calendar_ Shared.csv`.

---

## Contents


**Morning Star**  
- [1 Morning Star — New Life Festival](#1-morning-star) 
- [2 Morning Star — Scour Day](#2-morning-star) 
- [12 Morning Star — Ovank'a](#12-morning-star) 
- [13 Morning Star — Meridia's Summoning Day](#13-morning-star) 
- [15 Morning Star — South Winds Prayer](#15-morning-star) 
- [16 Morning Star — Day of Lights](#16-morning-star) 
- [18 Morning Star — Waking Day](#18-morning-star) 

**Sun's Dawn**  
- [2 Sun's Dawn — Mad Pelagius](#2-suns-dawn) 
- [5 Sun's Dawn — Othroktide](#5-suns-dawn) 
- [8 Sun's Dawn — Day of Release](#8-suns-dawn) 
- [13 Sun's Dawn — Feast of the Dead](#13-suns-dawn) 
- [16 Sun's Dawn — Heart's Day](#16-suns-dawn) 
- [27 Sun's Dawn — Perserverance Day](#27-suns-dawn) 
- [28 Sun's Dawn — Aduros Nau](#28-suns-dawn) 

**First Seed**  
- [5 First Seed — Hermaeus Mora's Summoning Day](#5-first-seed) 
- [7 First Seed — First Planting](#7-first-seed) 
- [9 First Seed — Day of Waiting](#9-first-seed) 
- [21 First Seed — Hogithum](#21-first-seed) 
- [25 First Seed — Flower Day](#25-first-seed) 
- [26 First Seed — Festival of Blades](#26-first-seed) 

**Rain's Hand**  
- [1 Rain's Hand — Gardtide](#1-rains-hand) 
- [9 Rain's Hand — Peryite's Summoning Day](#9-rains-hand) 
- [13 Rain's Hand — Day of the Dead](#13-rains-hand) 
- [20 Rain's Hand — Day of Shame](#20-rains-hand) 
- [28 Rain's Hand — Jester's Day](#28-rains-hand) 

**Second Seed**  
- [7 Second Seed — Second Planting](#7-second-seed) 
- [9 Second Seed — Marukh's Day](#9-second-seed) 
- [20 Second Seed — Fire Festival](#20-second-seed) 
- [30 Second Seed — Fishing Day](#30-second-seed) 

**Mid Year**  
- [1 Mid Year — Drigh R'Zimb](#1-mid-year) 
- [5 Mid Year — Hircine's Summoning Day](#5-mid-year) 
- [16 Mid Year — Mid Year Celebration](#16-mid-year) 
- [23 Mid Year — Dancing Day](#23-mid-year) 
- [24 Mid Year — Tibedetha](#24-mid-year) 

**Sun's Height**  
- [10 Sun's Height — Merchants Festival](#10-suns-height) 
- [12 Sun's Height — Divad Etep't](#12-suns-height) 
- [20 Sun's Height — Sun's Rest](#20-suns-height) 
- [29 Sun's Height — Fiery Night](#29-suns-height) 

**Last Seed**  
- [2 Last Seed — Maiden Katrica](#2-last-seed) 
- [11 Last Seed — Koomu Alezer'i](#11-last-seed) 
- [14 Last Seed — Feast of the Tiger](#14-last-seed) 
- [21 Last Seed — Appreciation Day](#21-last-seed) 
- [27 Last Seed — Harvest's End](#27-last-seed) 

**Hearthfire**  
- [3 Hearthfire — Tales and Tallows](#3-hearthfire) 
- [6 Hearthfire — Khurat](#6-hearthfire) 
- [8 Hearthfire — Nocturnal's Summoning Day](#8-hearthfire) 
- [12 Hearthfire — Riglametha](#12-hearthfire) 
- [19 Hearthfire — Children's Day](#19-hearthfire) 

**Frostfall**  
- [5 Frostfall — Dirij Tereur](#5-frostfall) 
- [8 Frostfall — Malacath's Summoning Day](#8-frostfall) 
- [13 Frostfall — Witches Festival](#13-frostfall) 
- [23 Frostfall — Broken Diamonds](#23-frostfall) 
- [30 Frostfall — Emperor's Day](#30-frostfall) 

**Sun's Dusk**  
- [2 Sun's Dusk — Gauntlet](#2-suns-dusk) 
- [3 Sun's Dusk — Serpent's Dance](#3-suns-dusk) 
- [8 Sun's Dusk — Moon Festival](#8-suns-dusk) 
- [18 Sun's Dusk — Hel Anseilak](#18-suns-dusk) 
- [20 Sun's Dusk — Warriors Festival](#20-suns-dusk) 

**Evening Star**  
- [15 Evening Star — North Winds Prayer](#15-evening-star) 
- [18 Evening Star — Baranth Do](#18-evening-star) 
- [20 Evening Star — Chil'a](#20-evening-star) 
- [24 Evening Star — Chil'a](#24-evening-star) 
- [25 Evening Star — Saturalia](#25-evening-star) 
- [30 Evening Star — Old Life Festival](#30-evening-star) 

---

## Morning Star

### 1 Morning Star — New Life Festival / Winter Solstice / Clavicus Vile's Summoning Day

*The source lists 3 observances sharing this date.*

> Today the people of provinceName are having the New Life Festival in celebration of a new year. The Emperor has ordered yet another tax increase in his New Life Address, and there is much grumbling about this. Still, despite financial difficulties, the New Life tradition of free ale at all the taverns in the cities continues. The people of provinceName certainly know how to hold a celebration. In Daggerfall, this is the Summoning Day for Clavicus Vile.

```yaml
date:            1 Morning Star
day_of_year:     1          # in the 360-day lore calendar
observances:
  - "New Life Festival"
  - "Winter Solstice"
  - "Clavicus Vile's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  New
  furstock:      Suthay     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           1 Morning Star 3E 428
  masser_secunda: First Quarter
  days_passed:    139
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Clavicus Vile
  summoning_day:   true
  provinces:       Daggerfall
  templated_text:  true   # contains Daggerfall's provinceName variable
  valid_in_morrowind_calendar: true
```

### 2 Morning Star — Scour Day

> Scour Day is a celebration held in most High Rock villages on the day after New Life. It was once the day one cleans up after New Life, but has changed into a party of its own.

```yaml
date:            2 Morning Star
day_of_year:     2          # in the 360-day lore calendar
observances:
  - "Scour Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  Waxing Crescent
  furstock:      Ohmes-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           2 Morning Star 3E 428
  masser_secunda: Waxing Gibbous
  days_passed:    140
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       High Rock
  valid_in_morrowind_calendar: true
```

### 12 Morning Star — Ovank'a

> Ovank'a is the day the people of the Alik'r Desert offer prayers to Stendarr in the hopes of a mild and merciful year. It is considered very holy.

```yaml
date:            12 Morning Star
day_of_year:     12          # in the 360-day lore calendar
observances:
  - "Ovank'a"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Waxing Gibbous
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           12 Morning Star 3E 428
  masser_secunda: Third Quarter
  days_passed:    150
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Alik'r
  valid_in_morrowind_calendar: true
```

### 13 Morning Star — Meridia's Summoning Day

> In Daggerfall, this is the Summoning Day for Meridia.

```yaml
date:            13 Morning Star
day_of_year:     13          # in the 360-day lore calendar
observances:
  - "Meridia's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Full
  furstock:      Cathay     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           13 Morning Star 3E 428
  masser_secunda: Third Quarter
  days_passed:    151
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Meridia
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 15 Morning Star — South Winds Prayer

> The 15th of Morning Star is a holiday taken very seriously in provinceName, where they call it South Wind's Prayer, a plea by all the religions of Tamriel for a good planting season. Citizens with every affliction known in Tamriel flock to services in the cities's temples, as the clergy is known to perform free healings on this day. Only some will be judged worthy of this service, but few can afford the temples usual price...

```yaml
date:            15 Morning Star
day_of_year:     15          # in the 360-day lore calendar
observances:
  - "South Winds Prayer"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Second Quarter
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           15 Morning Star 3E 428
  masser_secunda: Waning Crescent
  days_passed:    153
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Tamriel
  templated_text:  true   # contains Daggerfall's provinceName variable
  valid_in_morrowind_calendar: true
```

### 16 Morning Star — Day of Lights

> The Day of Lights is celebrated as a holy day by most villages in Hammerfell on the Iliac Bay. It is a prayer for a good farming and fishing year, and is taken very seriously.

```yaml
date:            16 Morning Star
day_of_year:     16          # in the 360-day lore calendar
observances:
  - "Day of Lights"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Full
  jone_secunda:  Waning Crescent
  furstock:      Pahmar-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           16 Morning Star 3E 428
  masser_secunda: Waning Crescent
  days_passed:    154
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Hammerfell, Iliac Bay
  valid_in_morrowind_calendar: true
```

### 18 Morning Star — Waking Day

> The people in Yeorth Burrowland invented Waking Day in prehistoric times to wake the spirits of nature after a long, cold winter. It has evolved into a sort of orgiastic celebration of the end of winter.

```yaml
date:            18 Morning Star
day_of_year:     18          # in the 360-day lore calendar
observances:
  - "Waking Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Full
  jone_secunda:  Waxing Crescent
  furstock:      Senche-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           18 Morning Star 3E 428
  masser_secunda: New
  days_passed:    156
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Yeorth Burrowland
  valid_in_morrowind_calendar: true
```

## Sun's Dawn

### 2 Sun's Dawn — Mad Pelagius / Sheogorath's Summoning Day

*The source lists 2 observances sharing this date.*

> Mad Pelagius is a silly little tradition in High Rock in a mock memorial to Pelagius Septim III, one of the maddest emperors in recent history. He died about 350 years ago, so the Septims since have taken it with good humor. In Daggerfall this is the Summoning Day for Sheogorath.

```yaml
date:            2 Sun's Dawn
day_of_year:     32          # in the 360-day lore calendar
observances:
  - "Mad Pelagius"
  - "Sheogorath's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  Waning Crescent
  furstock:      Suthay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           2 Sun's Dawn 3E 428
  masser_secunda: Waning Gibbous
  days_passed:    171
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Sheogorath
  summoning_day:   true
  provinces:       Daggerfall, High Rock
  valid_in_morrowind_calendar: true
```

### 5 Sun's Dawn — Othroktide

> The people of Dwynnen have a huge party to celebrate Othroktide, the day when Baron Othrok took Dwynnen from the undead forces who claimed it in the Battle of Wightmoor.

```yaml
date:            5 Sun's Dawn
day_of_year:     35          # in the 360-day lore calendar
observances:
  - "Othroktide"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  First Quarter
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           5 Sun's Dawn 3E 428
  masser_secunda: Third Quarter
  days_passed:    174
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 8 Sun's Dawn — Day of Release

> The people of Glenumbra may be the only people to remember or care about the battle between Aiden Direnni and the Alessian Army in the first era. They celebrate it vigorously on the Day of Release.

```yaml
date:            8 Sun's Dawn
day_of_year:     38          # in the 360-day lore calendar
observances:
  - "Day of Release"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  Waning Gibbous
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           8 Sun's Dawn 3E 428
  masser_secunda: Waning Crescent
  days_passed:    177
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 13 Sun's Dawn — Feast of the Dead

> Celebrated in the Skyrim city of Windhelm. During the feast, the names of the Five Hundred Companions of Ysgramor are recited.[3]

```yaml
date:            13 Sun's Dawn
day_of_year:     43          # in the 360-day lore calendar
observances:
  - "Feast of the Dead"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  First Quarter
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           13 Sun's Dawn 3E 428
  masser_secunda: Waxing Crescent
  days_passed:    182
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Skyrim
  valid_in_morrowind_calendar: true
```

### 16 Sun's Dawn — Heart's Day / Sanguine's Summoning Day

*The source lists 2 observances sharing this date.*

> Today is the 16th of Sun's Dawn, a holiday celebrated all over Tamriel as Heart's Day. It seems that in every house, the Legend of the Lovers is being sung for the younger generation. In honor of these Lovers, Polydor and Eloisa, the inns of the city offer a free room for visitors. If such kindness had been given the Lovers, it is said, it would always be springtime in the world. In Daggerfall, this is the Summoning Day for Sanguine.

```yaml
date:            16 Sun's Dawn
day_of_year:     46          # in the 360-day lore calendar
observances:
  - "Heart's Day"
  - "Sanguine's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Full
  jone_secunda:  Waning Gibbous
  furstock:      Pahmar-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           16 Sun's Dawn 3E 428
  masser_secunda: First Quarter
  days_passed:    185
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Sanguine
  summoning_day:   true
  provinces:       Daggerfall, Tamriel
  valid_in_morrowind_calendar: true
```

### 27 Sun's Dawn — Perserverance Day

> Perserverance [sic] Day is quite a party in Ykalon. It was originally held as a solemn memorial to those killed in battle while resisting the Camoran Usurper, but has since become a boisterous festival.

```yaml
date:            27 Sun's Dawn
day_of_year:     57          # in the 360-day lore calendar
observances:
  - "Perserverance Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  New
  furstock:      Dagi     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           27 Sun's Dawn 3E 428
  masser_secunda: Waning Gibbous
  days_passed:    196
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 28 Sun's Dawn — Aduros Nau

> The villages in the Bantha celebrate the baser urges that come with Springtide on Aduros Nau. The traditions vary from village to village, but none of them are for the overly virtuous.

```yaml
date:            28 Sun's Dawn
day_of_year:     58          # in the 360-day lore calendar
observances:
  - "Aduros Nau"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  Waxing Crescent
  furstock:      Alfiq-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           28 Sun's Dawn 3E 428
  masser_secunda: Third Quarter
  days_passed:    197
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

## First Seed

### 5 First Seed — Hermaeus Mora's Summoning Day

> In Daggerfall, this is the Summoning Day for Hermaeus Mora.

```yaml
date:            5 First Seed
day_of_year:     65          # in the 360-day lore calendar
observances:
  - "Hermaeus Mora's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  New
  furstock:      Tojay     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           5 First Seed 3E 428
  masser_secunda: Waning Crescent
  days_passed:    202
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Hermaeus Mora
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 7 First Seed — First Planting

> On the 7th of First Seed every year, the people of provinceName celebrate First Planting, symbolically sowing the seeds for the autumn harvest. It is a festival of fresh beginnings, both for the crops and for the men and women of the city. Neighbors are reconciled in their disputes, resolutions are formed, bad habits dropped, the diseased cured. The clerics at the temples run a free clinic all day long to cure people of poisoning, different diseases, paralysis, and the other banes found in the world of Tamriel.

```yaml
date:            7 First Seed
day_of_year:     67          # in the 360-day lore calendar
observances:
  - "First Planting"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  First Quarter
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           7 First Seed 3E 428
  masser_secunda: New
  days_passed:    204
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Tamriel
  templated_text:  true   # contains Daggerfall's provinceName variable
  valid_in_morrowind_calendar: true
```

### 9 First Seed — Day of Waiting

> The Day of Waiting is a very old holy day among certain settlements in the Dragontail Mountains. Every year at that time, a dragon is supposed to come out of the desert and devour the wicked, so everyone locks themselves up inside.

```yaml
date:            9 First Seed
day_of_year:     69          # in the 360-day lore calendar
observances:
  - "Day of Waiting"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   First Quarter
  jone_secunda:  Full
  furstock:      Cathay     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           9 First Seed 3E 428
  masser_secunda: Waxing Crescent
  days_passed:    206
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 21 First Seed — Hogithum / Azura's Summoning Day

*The source lists 2 observances sharing this date.*

> In Daggerfall, this is the Summoning Day for Azura.

```yaml
date:            21 First Seed
day_of_year:     81          # in the 360-day lore calendar
observances:
  - "Hogithum"
  - "Azura's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  New
  furstock:      Dagi     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           21 First Seed 3E 428
  masser_secunda: Waning Gibbous
  days_passed:    218
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Azura
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 25 First Seed — Flower Day

> Flower Day is another of the frivolous celebrations of High Rock. Children pick the new flowers of spring while older Bretons, cooped up all winter, come out to welcome the season with dancing and singing.

```yaml
date:            25 First Seed
day_of_year:     85          # in the 360-day lore calendar
observances:
  - "Flower Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Second Quarter
  jone_secunda:  Full
  furstock:      Alfiq     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           25 First Seed 3E 428
  masser_secunda: Third Quarter
  days_passed:    222
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       High Rock
  valid_in_morrowind_calendar: true
```

### 26 First Seed — Festival of Blades

> During the Festival of Blades, the people of the Alik'r Desert celebrate the victor of the first Redguard over a race of giant goblins. The story is considered a myth by most scholars, but the holiday is still very popular in the desert.

```yaml
date:            26 First Seed
day_of_year:     86          # in the 360-day lore calendar
observances:
  - "Festival of Blades"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  Waning Gibbous
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           26 First Seed 3E 428
  masser_secunda: Third Quarter
  days_passed:    223
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Alik'r
  valid_in_morrowind_calendar: true
```

## Rain's Hand

### 1 Rain's Hand — Gardtide

> On Gardtide, the people of Tamarilyn Point hold a festival to honor Druagaa, the old goddess of flowers. Worship of the goddess is all but dead, but the celebration is always a great success.

```yaml
date:            1 Rain's Hand
day_of_year:     91          # in the 360-day lore calendar
observances:
  - "Gardtide"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  First Quarter
  furstock:      Ohmes-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           1 Rain's Hand 3E 428
  masser_secunda: New
  days_passed:    229
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 9 Rain's Hand — Peryite's Summoning Day

> In Daggerfall, this is the Summoning Day for Peryite.

```yaml
date:            9 Rain's Hand
day_of_year:     99          # in the 360-day lore calendar
observances:
  - "Peryite's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   First Quarter
  jone_secunda:  First Quarter
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           9 Rain's Hand 3E 428
  masser_secunda: Waxing Gibbous
  days_passed:    237
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Peryite
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 13 Rain's Hand — Day of the Dead

> The Day of the Dead is one of the more peculiar holidays of Daggerfall. The superstitious say that the dead rise on this holiday to wreak vengeance on the living. It is a fact that King Lysandus' spectre began its haunting on the Day of the Dead, 3E 404.

```yaml
date:            13 Rain's Hand
day_of_year:     103          # in the 360-day lore calendar
observances:
  - "Day of the Dead"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Second Quarter
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           13 Rain's Hand 3E 428
  masser_secunda: Full
  days_passed:    241
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 20 Rain's Hand — Day of Shame

> All along the seaside of Hammerfell, no one leaves their houses on the Day of Shame. It is said that the Crimson Ship, a vessel filled with victims of the Knahaten Plague who were refused refuge hundreds of years ago, will return on this day.

```yaml
date:            20 Rain's Hand
day_of_year:     110          # in the 360-day lore calendar
observances:
  - "Day of Shame"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Waning Gibbous
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           20 Rain's Hand 3E 428
  masser_secunda: Waning Crescent
  days_passed:    248
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Hammerfell
  valid_in_morrowind_calendar: true
```

### 28 Rain's Hand — Jester's Day

> Be warned that today is Jester's Day in the city of provinceName, and pranks are being set up from one end of town to the other. It is as if a spell has been cast over the community, for even the most taciturn and dignified councilman might attempt to play a joke on his relative. The Thieves Guild finds particular attention as everyone looks for pickpockets in particular.

```yaml
date:            28 Rain's Hand
day_of_year:     118          # in the 360-day lore calendar
observances:
  - "Jester's Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  Waning Gibbous
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           28 Rain's Hand 3E 428
  masser_secunda: Waxing Crescent
  days_passed:    256
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  templated_text:  true   # contains Daggerfall's provinceName variable
  valid_in_morrowind_calendar: true
```

## Second Seed

### 7 Second Seed — Second Planting

> The celebration of Second Planting is in full glory this day. It is a holiday with traditions similar to First Planting, improvements on the first seeding symbolically to suggest improvements on the soul. The free clinics of the temples are open for the second and last time this year, offering cures for those suffering from any kind of disease or affliction. Because peace and not conflict is stressed at this time, battle injuries are healed only at full price.

```yaml
date:            7 Second Seed
day_of_year:     127          # in the 360-day lore calendar
observances:
  - "Second Planting"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  Second Quarter
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           7 Second Seed 3E 428
  masser_secunda: Full
  days_passed:    265
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 9 Second Seed — Marukh's Day / Namira's Summoning Day

*The source lists 2 observances sharing this date.*

> Marukh's Day is only observed by certain communities in Skeffington Wood. By comparing themselves to the virtuous prophet Marukh, the people of Skeffington Wood pray for the strength to resist temptation. In Daggerfall, this is the Summoning Day for Namira.

```yaml
date:            9 Second Seed
day_of_year:     129          # in the 360-day lore calendar
observances:
  - "Marukh's Day"
  - "Namira's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   First Quarter
  jone_secunda:  New
  furstock:      Tojay     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           9 Second Seed 3E 428
  masser_secunda: Waning Gibbous
  days_passed:    267
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Namira
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 20 Second Seed — Fire Festival

> The Fire Festival in Northmoor is one of the most attended celebrations in High Rock. It began as a pompous display of magic and military strength in ancient days and has become quite a festival.

```yaml
date:            20 Second Seed
day_of_year:     140          # in the 360-day lore calendar
observances:
  - "Fire Festival"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Waxing Gibbous
  furstock:      Alfiq-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           20 Second Seed 3E 428
  masser_secunda: Waxing Crescent
  days_passed:    278
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       High Rock
  valid_in_morrowind_calendar: true
```

### 30 Second Seed — Fishing Day

> Fishing Day is a big celebration for the Bretons who live off the bounty of the Iliac Bay. They are not a usually flamboyant people, but on Fishing Day, they make so much noise, fish have been scared away for weeks.

```yaml
date:            30 Second Seed
day_of_year:     150          # in the 360-day lore calendar
observances:
  - "Fishing Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  Waning Gibbous
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           30 Second Seed 3E 428
  masser_secunda: Full
  days_passed:    288
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Iliac Bay
  valid_in_morrowind_calendar: true
```

## Mid Year

### 1 Mid Year — Drigh R'Zimb

> The festival of Drigh R'Zimb, held in the hottest time of year in Abibon-Gora, is a jubilation held for the sun Daibethe itself. Scholars do not know how long Drigh R'Zimb has been held, but it is possible the Redguards brought the festival with them when they came in the first era.

```yaml
date:            1 Mid Year
day_of_year:     151          # in the 360-day lore calendar
observances:
  - "Drigh R'Zimb"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  Second Quarter
  furstock:      Suthay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           1 Mid Year 3E 428
  masser_secunda: Waning Gibbous
  days_passed:    290
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 5 Mid Year — Hircine's Summoning Day

> In Daggerfall, this is the Summoning Day for Hircine.

```yaml
date:            5 Mid Year
day_of_year:     155          # in the 360-day lore calendar
observances:
  - "Hircine's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  First Quarter
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           5 Mid Year 3E 428
  masser_secunda: Third Quarter
  days_passed:    294
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Hircine
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 16 Mid Year — Mid Year Celebration

> Today is the 16th of Mid Year, the traditional day for the Mid Year Celebration. Perhaps to alleviate the annual news of the Emperor's latest tax increase, the cities temples offer blessings for only half the donation they usually suggest. Many so blessed feel confident enough to enter the (dangerous) dungeons when they are not fully prepared, so this joyous festival has often been known to turn suddenly into a day of defeat and tragedy.

```yaml
date:            16 Mid Year
day_of_year:     166          # in the 360-day lore calendar
observances:
  - "Mid Year Celebration"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Full
  jone_secunda:  Waning Gibbous
  furstock:      Pahmar-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           16 Mid Year 3E 428
  masser_secunda: First Quarter
  days_passed:    305
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 23 Mid Year — Dancing Day

> Dancing Day is a time-honored holiday in Daggerfall. Who started it is questionable, but the Red Prince Atryck popularized it in the second era. It is an occasion of great pomp and merriment for all the people of Daggerfall, from the nobles down.

```yaml
date:            23 Mid Year
day_of_year:     173          # in the 360-day lore calendar
observances:
  - "Dancing Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Full
  furstock:      Alfiq     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           23 Mid Year 3E 428
  masser_secunda: Full
  days_passed:    312
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 24 Mid Year — Tibedetha

> Tibedetha is middle Tamrielic for "Tibers Day." It is not surprising that the lorddom of Alcaire celebrates its most famous native with a great party. Historically, Tiber Septim never returned once to his beloved birthplace.

```yaml
date:            24 Mid Year
day_of_year:     174          # in the 360-day lore calendar
observances:
  - "Tibedetha"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Second Quarter
  jone_secunda:  Waning Gibbous
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           24 Mid Year 3E 428
  masser_secunda: Full
  days_passed:    313
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Tamriel
  valid_in_morrowind_calendar: true
```

## Sun's Height

### 10 Sun's Height — Merchants Festival / Vaermina's Summoning Day

*The source lists 2 observances sharing this date.*

> The bargain shoppers of the known world are out in force today and it is little wonder, for the 10th of Sun's Height is a holiday called the Merchants' Festival. Every marketplace and equipment store has dropped their prices to at least half. The only shop not being patronized today is the Mages Guild, where prices are as exorbitant as usual. Most citizens in need of a magical item are waiting two months for the celebration of Tales and Tallows when prices will be more reasonable... In Daggerfall, this is the Summoning day for Vaernima.

```yaml
date:            10 Sun's Height
day_of_year:     190          # in the 360-day lore calendar
observances:
  - "Merchants Festival"
  - "Vaermina's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   First Quarter
  jone_secunda:  Waning Gibbous
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           10 Sun's Height 3E 428
  masser_secunda: First Quarter
  days_passed:    329
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Vaermina
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 12 Sun's Height — Divad Etep't

> During Divat Etep't, the people of Antiphyllos mourn the death of one of the greatest of the early Redguard heroes, Divat, son of Frandar of the Hel Ansei. His deeds are questioned by historians, but his tomb in Antiphyllos is almost certainly genuine.

```yaml
date:            12 Sun's Height
day_of_year:     192          # in the 360-day lore calendar
observances:
  - "Divad Etep't"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Waning Crescent
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           12 Sun's Height 3E 428
  masser_secunda: First Quarter
  days_passed:    331
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 20 Sun's Height — Sun's Rest

> You will have to wait until tomorrow if you are planning on making any equipment purchases, for all stores are closed in observance of Sun's Rest. Of course, the temples, taverns, and Mages Guild in the (city) are still open their regular hours, but most citizens chose to devote this day to relaxation, not commerce or prayer. This is not a convenient arrangement for all, but the Merchants' Guild heavily fines any shop that stays open, so everyone complies.

```yaml
date:            20 Sun's Height
day_of_year:     200          # in the 360-day lore calendar
observances:
  - "Sun's Rest"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Waning Crescent
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           20 Sun's Height 3E 428
  masser_secunda: Waning Gibbous
  days_passed:    339
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 29 Sun's Height — Fiery Night

> Few besides the natives of the Alik'r Desert would venture out on the hottest day of the year, Fiery Night. It's a lively celebration with a meaning lost in antiquity.

```yaml
date:            29 Sun's Height
day_of_year:     209          # in the 360-day lore calendar
observances:
  - "Fiery Night"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  New
  furstock:      Dagi     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           29 Sun's Height 3E 428
  masser_secunda: New
  days_passed:    348
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Alik'r
  valid_in_morrowind_calendar: true
```

## Last Seed

### 2 Last Seed — Maiden Katrica

> On the day of Maiden Katrica, the people of Ayasofya show their appreciation for the warrior that saved their county with the biggest party of the year.

```yaml
date:            2 Last Seed
day_of_year:     212          # in the 360-day lore calendar
observances:
  - "Maiden Katrica"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  Waxing Gibbous
  furstock:      Ohmes-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           2 Last Seed 3E 428
  masser_secunda: Waxing Crescent
  days_passed:    352
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 11 Last Seed — Koomu Alezer'i

> Koomu Alezer'i means simply "We Acknowledge" in old Redguard, and it has been a tradition in Sentinel for thousands of years. No matter the harvest, the people of Sentinel solemnly thank the gods for their bounty, and pray to be worthy of the graces of the gods.

```yaml
date:            11 Last Seed
day_of_year:     221          # in the 360-day lore calendar
observances:
  - "Koomu Alezer'i"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Full
  furstock:      Cathay     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           11 Last Seed 3E 428
  masser_secunda: Full
  days_passed:    361
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Sentinel
  valid_in_morrowind_calendar: true
```

### 14 Last Seed — Feast of the Tiger

> The Feast of the Tiger in the Bantha rainforest is like other holidays in praise of a bountiful harvest. It is not, however, a solemn occasion for introspection and thanksgiving, but a great celebration and festival from village to village.

```yaml
date:            14 Last Seed
day_of_year:     224          # in the 360-day lore calendar
observances:
  - "Feast of the Tiger"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Waning Crescent
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           14 Last Seed 3E 428
  masser_secunda: Waning Gibbous
  days_passed:    364
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 21 Last Seed — Appreciation Day

> Appreciation Day in Anticlere is an ancient holiday of thanksgiving for a bountiful harvest for the people of Anticlere. It is considered a holy and contemplative day, devoted to Mara, the goddess-protector of Anticlere.

```yaml
date:            21 Last Seed
day_of_year:     231          # in the 360-day lore calendar
observances:
  - "Appreciation Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Second Quarter
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           21 Last Seed 3E 427
  masser_secunda: Third Quarter
  days_passed:    6
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 27 Last Seed — Harvest's End

> Perhaps no other festival fires the spirit of cityName as much as the one held today, Harvest's End. The work of the year is over, the seeding, sowing, and reaping. Now is the time to celebrate and enjoy the fruits of the harvest, and even visitors to regionName are invited to join the farmers. The taverns offer free drinks all day long, an extravagance before the economy of the coming winter months. Underfed farm hands gorging themselves and then getting sick in the town square are the most common sights of the celebration of Harvest's End.  This day in 3E 433 marked the beginning of the Oblivion Crisis.

```yaml
date:            27 Last Seed
day_of_year:     237          # in the 360-day lore calendar
observances:
  - "Harvest's End"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  Full
  furstock:      Alfiq     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           27 Last Seed 3E 427
  masser_secunda: New
  days_passed:    12
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

## Hearthfire

### 3 Hearthfire — Tales and Tallows

> No other holiday divides the people of cityName like the 3rd of Hearth Fire. A few of the oldest, more superstitious men and women do not speak all day long for fear that the evil spirits of the dead will enter their bodies. Most citizens enjoy the holiday, calling it Tales and Tallows, but even the most lighthearted avoid the dark streets of cityName, for everyone knows the dead do walk tonight. Only the Mages Guild completely thrives on this day. In celebration of the oldest magical science, necromancy, all magical items are half price today. NOTE: A number of in game sources say this is the day one may summon Nocturnal, but that is actually the 8th — see below.

```yaml
date:            3 Hearthfire
day_of_year:     243          # in the 360-day lore calendar
observances:
  - "Tales and Tallows"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  First Quarter
  furstock:      Ohmes-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           3 Hearthfire 3E 427
  masser_secunda: First Quarter
  days_passed:    19
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Nocturnal
  valid_in_morrowind_calendar: true
```

### 6 Hearthfire — Khurat

> Every town and fellowship in the Wrothgarian Mountains celebrates Khurat, the day when the finest young scholars are accepted into the various priesthoods. Even those people without children of age go to pray for the wisdom and benevolence of the clergy.

```yaml
date:            6 Hearthfire
day_of_year:     246          # in the 360-day lore calendar
observances:
  - "Khurat"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  Waning Gibbous
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           6 Hearthfire 3E 427
  masser_secunda: Waxing Gibbous
  days_passed:    22
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Wrothgarian
  valid_in_morrowind_calendar: true
```

### 8 Hearthfire — Nocturnal's Summoning Day

> In Daggerfall, this is the Summoning Day for Nocturnal.

```yaml
date:            8 Hearthfire
day_of_year:     248          # in the 360-day lore calendar
observances:
  - "Nocturnal's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  Waning Crescent
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           8 Hearthfire 3E 427
  masser_secunda: Full
  days_passed:    24
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Nocturnal
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 12 Hearthfire — Riglametha

> Riglametha is celebrated on the twelfth of Hearth Fire every year in Lainlyn as a celebration of Lainlyns many blessings. Pageants are held on such themes as the Ghraewaj, when the daedra worshippers in Lainlyn were changed to harpies for their blasphemy.

```yaml
date:            12 Hearthfire
day_of_year:     252          # in the 360-day lore calendar
observances:
  - "Riglametha"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  Waxing Gibbous
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           12 Hearthfire 3E 427
  masser_secunda: Waning Gibbous
  days_passed:    28
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 19 Hearthfire — Children's Day

> Children's Day in Betony is a festive occasion with a grim history. All know though few choose to recall that Children's Day began as a memorial to the dozens of children in Betony who were stolen from their homes by vampires one night never to be seen again. This happened over a hundred years ago, and the holiday has since become a celebration of youth.

```yaml
date:            19 Hearthfire
day_of_year:     259          # in the 360-day lore calendar
observances:
  - "Children's Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  First Quarter
  furstock:      Alfiq-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           19 Hearthfire 3E 427
  masser_secunda: New
  days_passed:    35
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

## Frostfall

### 5 Frostfall — Dirij Tereur

> The fifth of Frost Fall marks Dirij Tereur for the people of the Alik'r Desert. It is a sacred day honoring Frandar Hund, the traditional spiritual leader of the Redguards who led them to Hammerfell in the first era. Stories are read from Hund's Book of Circles, and the temples in the region are filled to capacity.

```yaml
date:            5 Frostfall
day_of_year:     275          # in the 360-day lore calendar
observances:
  - "Dirij Tereur"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  First Quarter
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           5 Frostfall 3E 427
  masser_secunda: Waning Gibbous
  days_passed:    51
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Alik'r, Hammerfell
  valid_in_morrowind_calendar: true
```

### 8 Frostfall — Malacath's Summoning Day

> In Daggerfall, this is the Summoning Day for Malacath.

```yaml
date:            8 Frostfall
day_of_year:     278          # in the 360-day lore calendar
observances:
  - "Malacath's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  Waning Gibbous
  furstock:      Tojay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           8 Frostfall 3E 427
  masser_secunda: Third Quarter
  days_passed:    54
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Malacath
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 13 Frostfall — Witches Festival / Mephala's Summoning Day

*The source lists 2 observances sharing this date.*

> Today is the 13th of Frostfall, known throughout Tamriel as the Witches' Festival when the forces of sorcery and religion clash. The Mages Guild gets most of the business since weapons and items are evaluated for their mystic potential free of charge and magic spells are one half their usual price. Demonologists, conjurors, lamias, warlocks, and thaumaturgists meet in the wilderness outside (the city), and the creatures created or summoned there may plague Tamriel for eons. Most wise men choose not to wander this night. In Daggerfall, this is the Summoning Day for Mephala.

```yaml
date:            13 Frostfall
day_of_year:     283          # in the 360-day lore calendar
observances:
  - "Witches Festival"
  - "Mephala's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  First Quarter
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           13 Frostfall 3E 427
  masser_secunda: New
  days_passed:    59
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Mephala
  summoning_day:   true
  provinces:       Daggerfall, Tamriel
  valid_in_morrowind_calendar: true
```

### 23 Frostfall — Broken Diamonds

> On the 23rd of Frost Fall in the 121st year of the third era, the empress Kintyra Septim II met her death in the imperial dungeons in Glenpoint on the orders of her cousin and usurper Uriel III. Her death is remembered in Glenpoint as the day called Broken Diamonds. It is a day of silent prayer for the wisdom and benevolence of the imperial family of Tamriel. [Editor's note: It is Uriel III who killed Kintyra, not Cephorus. This is a scribe's error in Daggerfall].

```yaml
date:            23 Frostfall
day_of_year:     293          # in the 360-day lore calendar
observances:
  - "Broken Diamonds"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Full
  furstock:      Alfiq     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           23 Frostfall 3E 427
  masser_secunda: Waxing Gibbous
  days_passed:    69
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Daggerfall, Tamriel
  valid_in_morrowind_calendar: true
```

### 30 Frostfall — Emperor's Day

> Once the 30th of Frostfall, the Emperor's Birthday, was the most popular holiday of the year. Great traveling carnivals entertained the masses, while the aristocracy of cityName enjoyed the annual Goblin Chase on horseback. Recently, these traditions have fallen into neglect. It has been decades since there was a big carnival in cityName and longer still since a regentTitle of the cityName sponsered a Goblin Chase.

```yaml
date:            30 Frostfall
day_of_year:     300          # in the 360-day lore calendar
observances:
  - "Emperor's Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  Waxing Gibbous
  furstock:      Alfiq-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           30 Frostfall 3E 427
  masser_secunda: Waning Gibbous
  days_passed:    76
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

## Sun's Dusk

### 2 Sun's Dusk — Gauntlet / Boethiah's Summoning Day

*The source lists 2 observances sharing this date.*

> In Daggerfall, this is the Summoning Day for Boethiah.

```yaml
date:            2 Sun's Dusk
day_of_year:     302          # in the 360-day lore calendar
observances:
  - "Gauntlet"
  - "Boethiah's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  Waning Gibbous
  furstock:      Suthay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           2 Sun's Dusk 3E 427
  masser_secunda: Third Quarter
  days_passed:    79
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Boethiah
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 3 Sun's Dusk — Serpent's Dance

> The Serpents Dance in Satakalaam may or may not have begun as a serious religious holiday dedicated to a snake god, but in this day, it is a reason for a great street festival.

```yaml
date:            3 Sun's Dusk
day_of_year:     303          # in the 360-day lore calendar
observances:
  - "Serpent's Dance"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   New
  jone_secunda:  Second Quarter
  furstock:      Suthay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           3 Sun's Dusk 3E 427
  masser_secunda: Waning Crescent
  days_passed:    80
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 8 Sun's Dusk — Moon Festival

> On the 8th of Sun's Dusk, the Bretons of Glenumbra Moors hold the Moon Festival, a joyous holiday in honor of Secunda, goddess of the moon. Although the goddess has no active worshippers, the traditional celebration has continued through the ages as a time of feasting and merriment.

```yaml
date:            8 Sun's Dusk
day_of_year:     308          # in the 360-day lore calendar
observances:
  - "Moon Festival"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Crescent
  jone_secunda:  Waxing Gibbous
  furstock:      Cathay-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           8 Sun's Dusk 3E 427
  masser_secunda: New
  days_passed:    85
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 18 Sun's Dusk — Hel Anseilak

> Hel Anseilak, which means "Communion with the Saints of the Sword" in Old Redguard is the most serious of holy days for the people of Pothago. The ancient way of Hel Ansei is never practiced by modern Redguards, but its rich heritage is remembered and honored on this day.

```yaml
date:            18 Sun's Dusk
day_of_year:     318          # in the 360-day lore calendar
observances:
  - "Hel Anseilak"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Full
  jone_secunda:  Waning Gibbous
  furstock:      Pahmar-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           18 Sun's Dusk 3E 427
  masser_secunda: Full
  days_passed:    95
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  valid_in_morrowind_calendar: true
```

### 20 Sun's Dusk — Warriors Festival / Mehrunes Dagon's Summoning Day

*The source lists 2 observances sharing this date.*

> Today is the 20th of Sun's Dusk, the Warriors Festival in cityName. Most all the local warriors, spellswords, and rogues come to the equipment stores and blacksmiths where all weapons are half price. Unfortunately, the low prices also tempt many an untrained boy to buy his first sword and the normally quiet cityName streets ring with amateur skirmishes. The regentTitle has pardoned most of these ruffians in the past, but has promised to be less merciful this year. In Daggerfall, this is the Summoning Day for Mehrunes Dagon.

```yaml
date:            20 Sun's Dusk
day_of_year:     320          # in the 360-day lore calendar
observances:
  - "Warriors Festival"
  - "Mehrunes Dagon's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Waning Crescent
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           20 Sun's Dusk 3E 427
  masser_secunda: Full
  days_passed:    97
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Mehrunes Dagon
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

## Evening Star

### 15 Evening Star — North Winds Prayer

> Today is the 15th of Evening Star, a holiday reverently observed by the temples as North Wind's Prayer. It is a thanksgiving to the Gods for a good harvest and a mild winter. Some years, like this one, the harvest was not particularly good and the winter unseasonally harsh in provinceName, but as the regentTitle is fond of saying, "It could be much worse." The temples offer all their services blessing, curing, healing for half the donation usually requested.

```yaml
date:            15 Evening Star
day_of_year:     345          # in the 360-day lore calendar
observances:
  - "North Winds Prayer"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waxing Gibbous
  jone_secunda:  New
  furstock:      Tojay     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           15 Evening Star 3E 427
  masser_secunda: Waning Gibbous
  days_passed:    122
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  templated_text:  true   # contains Daggerfall's provinceName variable
  valid_in_morrowind_calendar: true
```

### 18 Evening Star — Baranth Do

> Baranth Do is celebrated on the 18th of Evening Star by the Redguards of the Alik'r Desert. Its meaning is "Goodbye to the Beast of Last Year." Pageants featuring demonic representations of the old year are popular, and revelry to honor the new year is everywhere.

```yaml
date:            18 Evening Star
day_of_year:     348          # in the 360-day lore calendar
observances:
  - "Baranth Do"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Full
  jone_secunda:  Waxing Gibbous
  furstock:      Senche-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           18 Evening Star 3E 427
  masser_secunda: Third Quarter
  days_passed:    125
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Alik'r
  valid_in_morrowind_calendar: true
```

### 20 Evening Star — Chil'a / Molag Bal's Summoning Day

*The source lists 2 observances sharing this date.*

> Chil'a, the blessing of the new year in the barony of Kairou, is both a sacred day and a festival. The archpriest and the baroness each consecrate the ashes of the old year in solemn ceremony, then street parades, balls, and tournaments conclude the event. In Daggerfall, this is the Summoning Day for Molag Bal.

```yaml
date:            20 Evening Star
day_of_year:     350          # in the 360-day lore calendar
observances:
  - "Chil'a"
  - "Molag Bal's Summoning Day"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Gibbous
  jone_secunda:  Waning Gibbous
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           20 Evening Star 3E 427
  masser_secunda: Third Quarter
  days_passed:    127
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  daedric_prince:  Molag Bal
  summoning_day:   true
  provinces:       Daggerfall
  valid_in_morrowind_calendar: true
```

### 24 Evening Star — Chil'a

> Local Iliac Bay New Year's festival on the 24th of Evening Star. It was probably moved from its original date to correspond with the notion of the year defined in Tamriel.

```yaml
date:            24 Evening Star
day_of_year:     354          # in the 360-day lore calendar
observances:
  - "Chil'a"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Second Quarter
  jone_secunda:  Waxing Crescent
  furstock:      Alfiq-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           24 Evening Star 3E 427
  masser_secunda: New
  days_passed:    131
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Iliac Bay, Tamriel
  valid_in_morrowind_calendar: true
```

### 25 Evening Star — Saturalia

> The New Life festival comes a few days early in Wayrest with Saturalia, traditionally held on the 25th of Evening Star. Originally a holiday for a long forgotten god of debauchery, it has become a time of gift giving, parties, and parading. Visitors are encouraged to participate.

```yaml
date:            25 Evening Star
day_of_year:     355          # in the 360-day lore calendar
observances:
  - "Saturalia"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Second Quarter
  jone_secunda:  First Quarter
  furstock:      Alfiq-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           25 Evening Star 3E 427
  masser_secunda: New
  days_passed:    132
  shade_of_the_revenant: true
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Wayrest
  valid_in_morrowind_calendar: true
```

### 30 Evening Star — Old Life Festival

> On the last day of the year the Empire celebrates the holiday called Old Life. Many go to the temples to reflect on their past. Some go for more than this, for it is rumored that priests will as the last act of the year perform resurrections on beloved friends and family members free of the usual charge. Worshippers know better than to expect this philanthropy, but they arrive in a macabre procession with the recently deceased nevertheless. When ale flows free in all the taverns in all the cities of Tamriel.

```yaml
date:            30 Evening Star
day_of_year:     360          # in the 360-day lore calendar
observances:
  - "Old Life Festival"
lore_calendar:                       # from the source CSV. Not OpenMW.
  jode_masser:   Waning Crescent
  jone_secunda:  Waning Crescent
  furstock:      Dagi-raht     # Khajiit form for a kitten born today
openmw_first_occurrence:             # engine truth, first time this date
  date:           30 Evening Star 3E 427
  masser_secunda: First Quarter
  days_passed:    137
  shade_of_the_revenant: false
  note: "shifts 5 cycle-days each following year; 365 mod 24 = 5"
supplementary:
  provinces:       Tamriel
  valid_in_morrowind_calendar: true
```

---

## Appendix A — Daedric Summoning Days

Sixteen of the 64 entries are Summoning Days.

| Date | Prince |
|---|---|
| 1 Morning Star | Clavicus Vile |
| 13 Morning Star | Meridia |
| 2 Sun's Dawn | Sheogorath |
| 16 Sun's Dawn | Sanguine |
| 5 First Seed | Hermaeus Mora |
| 21 First Seed | Azura |
| 9 Rain's Hand | Peryite |
| 9 Second Seed | Namira |
| 5 Mid Year | Hircine |
| 10 Sun's Height | Vaermina |
| 8 Hearthfire | Nocturnal |
| 8 Frostfall | Malacath |
| 13 Frostfall | Mephala |
| 2 Sun's Dusk | Boethiah |
| 20 Sun's Dusk | Mehrunes Dagon |
| 20 Evening Star | Molag Bal |

## Appendix B — Furstock by date

In Khajiit lore the form a kitten takes is set by the moons at its birth.

| Date | Furstock | Jode | Jone |
|---|---|---|---|
| 1 Morning Star | Suthay | New | New |
| 2 Morning Star | Ohmes-raht | New | Waxing Crescent |
| 12 Morning Star | Cathay-raht | Waxing Gibbous | Waxing Gibbous |
| 13 Morning Star | Cathay | Waxing Gibbous | Full |
| 15 Morning Star | Tojay-raht | Waxing Gibbous | Second Quarter |
| 16 Morning Star | Pahmar-raht | Full | Waning Crescent |
| 18 Morning Star | Senche-raht | Full | Waxing Crescent |
| 2 Sun's Dawn | Suthay-raht | New | Waning Crescent |
| 5 Sun's Dawn | Cathay-raht | Waxing Crescent | First Quarter |
| 8 Sun's Dawn | Tojay-raht | Waxing Crescent | Waning Gibbous |
| 13 Sun's Dawn | Cathay-raht | Waxing Gibbous | First Quarter |
| 16 Sun's Dawn | Pahmar-raht | Full | Waning Gibbous |
| 27 Sun's Dawn | Dagi | Waning Crescent | New |
| 28 Sun's Dawn | Alfiq-raht | Waning Crescent | Waxing Crescent |
| 5 First Seed | Tojay | Waxing Crescent | New |
| 7 First Seed | Cathay-raht | Waxing Crescent | First Quarter |
| 9 First Seed | Cathay | First Quarter | Full |
| 21 First Seed | Dagi | Waning Gibbous | New |
| 25 First Seed | Alfiq | Second Quarter | Full |
| 26 First Seed | Dagi-raht | Waning Crescent | Waning Gibbous |
| 1 Rain's Hand | Ohmes-raht | New | First Quarter |
| 9 Rain's Hand | Cathay-raht | First Quarter | First Quarter |
| 13 Rain's Hand | Tojay-raht | Waxing Gibbous | Second Quarter |
| 20 Rain's Hand | Dagi-raht | Waning Gibbous | Waning Gibbous |
| 28 Rain's Hand | Dagi-raht | Waning Crescent | Waning Gibbous |
| 7 Second Seed | Tojay-raht | Waxing Crescent | Second Quarter |
| 9 Second Seed | Tojay | First Quarter | New |
| 20 Second Seed | Alfiq-raht | Waning Gibbous | Waxing Gibbous |
| 30 Second Seed | Dagi-raht | Waning Crescent | Waning Gibbous |
| 1 Mid Year | Suthay-raht | New | Second Quarter |
| 5 Mid Year | Cathay-raht | Waxing Crescent | First Quarter |
| 16 Mid Year | Pahmar-raht | Full | Waning Gibbous |
| 23 Mid Year | Alfiq | Waning Gibbous | Full |
| 24 Mid Year | Dagi-raht | Second Quarter | Waning Gibbous |
| 10 Sun's Height | Tojay-raht | First Quarter | Waning Gibbous |
| 12 Sun's Height | Tojay-raht | Waxing Gibbous | Waning Crescent |
| 20 Sun's Height | Dagi-raht | Waning Gibbous | Waning Crescent |
| 29 Sun's Height | Dagi | Waning Crescent | New |
| 2 Last Seed | Ohmes-raht | New | Waxing Gibbous |
| 11 Last Seed | Cathay | Waxing Gibbous | Full |
| 14 Last Seed | Tojay-raht | Waxing Gibbous | Waning Crescent |
| 21 Last Seed | Dagi-raht | Waning Gibbous | Second Quarter |
| 27 Last Seed | Alfiq | Waning Crescent | Full |
| 3 Hearthfire | Ohmes-raht | New | First Quarter |
| 6 Hearthfire | Tojay-raht | Waxing Crescent | Waning Gibbous |
| 8 Hearthfire | Tojay-raht | Waxing Crescent | Waning Crescent |
| 12 Hearthfire | Cathay-raht | Waxing Gibbous | Waxing Gibbous |
| 19 Hearthfire | Alfiq-raht | Waning Gibbous | First Quarter |
| 5 Frostfall | Cathay-raht | Waxing Crescent | First Quarter |
| 8 Frostfall | Tojay-raht | Waxing Crescent | Waning Gibbous |
| 13 Frostfall | Cathay-raht | Waxing Gibbous | First Quarter |
| 23 Frostfall | Alfiq | Waning Gibbous | Full |
| 30 Frostfall | Alfiq-raht | Waning Crescent | Waxing Gibbous |
| 2 Sun's Dusk | Suthay-raht | New | Waning Gibbous |
| 3 Sun's Dusk | Suthay-raht | New | Second Quarter |
| 8 Sun's Dusk | Cathay-raht | Waxing Crescent | Waxing Gibbous |
| 18 Sun's Dusk | Pahmar-raht | Full | Waning Gibbous |
| 20 Sun's Dusk | Dagi-raht | Waning Gibbous | Waning Crescent |
| 15 Evening Star | Tojay | Waxing Gibbous | New |
| 18 Evening Star | Senche-raht | Full | Waxing Gibbous |
| 20 Evening Star | Dagi-raht | Waning Gibbous | Waning Gibbous |
| 24 Evening Star | Alfiq-raht | Second Quarter | Waxing Crescent |
| 25 Evening Star | Alfiq-raht | Second Quarter | First Quarter |
| 30 Evening Star | Dagi-raht | Waning Crescent | Waning Crescent |

## Appendix C — On `provinceName`

Five descriptions contain the literal string `provinceName`. That is a Daggerfall
text-template variable which the engine substituted at runtime with whichever
province the player was in.

- **1 Morning Star** — New Life Festival
- **15 Morning Star** — South Winds Prayer
- **7 First Seed** — First Planting
- **28 Rain's Hand** — Jester's Day
- **15 Evening Star** — North Winds Prayer
