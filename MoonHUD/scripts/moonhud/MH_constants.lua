---@omw-context player
-- MH_constants.lua
-- Static lunar data for OpenMW / Morrowind, and the verified engine phase model.
--
-- SOURCES
--   * Engine model taken from OpenMW master:
--       apps/openmw/mwworld/weather.cpp  ::  MWWorld::MoonModel::phase()
--   * Cross-checked against 382 in-game days of manual observation ("Moon Phases" sheet):
--       761 / 764 moon-days agree (99.6%). The 3 outliers all fall inside one week
--       (Evening Star, days 121-127) and look like a single row-shift logging slip.
--   * "Lunar Calendar (Shared)" (Jode/Jone, 30- and 8-day cycles, 360-day year) is
--       Daggerfall-era / Khajiit LORE. It does not describe OpenMW and is deliberately
--       not used for any gameplay logic here. Lore constants live at the bottom.

local core = require('openmw.core')

local M = {}

M.VERSION = 1

--------------------------------------------------------------------------------
-- THE ENGINE MODEL
--------------------------------------------------------------------------------
-- MoonModel::phase(gameTime):
--     if (gameTime.getHour() < moonPhaseHour(gameTime.getDay()))
--         return Phase(  (gameTime.getDay()    / 3) mod 8 )   -- not yet rolled over today
--     else
--         return Phase( ((gameTime.getDay()+1) / 3) mod 8 )   -- rolled over
--
-- Consequences that matter for modding:
--   1. BOTH moons run the identical sequence. There is no separate Masser cycle.
--   2. Phase depends on day AND hour. The moons only ever look "out of sync"
--      because moonPhaseHour() differs between them (driven by the fallback setting
--      Moons_<name>_Daily_Increment: Masser 1.0, Secunda 0.75). One has rolled over,
--      the other has not. It always resolves within a day and is fully deterministic.
--   3. Period is exactly 24 days: 8 phases x 3 days. Never 2, never 4.
--   4. A new game starts on 16 Last Seed 427 at day 1, phase Full.

M.PHASE_LENGTH_DAYS = 3
M.CYCLE_LENGTH_DAYS = 24

-- MWRender::MoonState::Phase, in numeric order.
-- RING[i + 1] is engine phase index i (Lua is 1-based).
M.RING = {
	'Full', 'WaningGibbous', 'ThirdQuarter', 'WaningCrescent',
	'New',  'WaxingCrescent', 'FirstQuarter', 'WaxingGibbous',
}

-- MWScript-compatible value, as returned by Moon.phaseValue
-- (0 new, 1 crescent, 2 quarter, 3 gibbous, 4 full)
M.PHASE_VALUE = {
	Full = 4, WaningGibbous = 3, ThirdQuarter = 2, WaningCrescent = 1,
	New  = 0, WaxingCrescent = 1, FirstQuarter = 2, WaxingGibbous = 3,
}

-- The 5 buckets GetMasserPhase / GetSecundaPhase could see
M.BUCKET = {
	Full = 'Full', WaningGibbous = 'Gibbous', ThirdQuarter = 'Half',
	WaningCrescent = 'Crescent', New = 'New', WaxingCrescent = 'Crescent',
	FirstQuarter = 'Half', WaxingGibbous = 'Gibbous',
}

-- 'waning' | 'waxing' | 'full' | 'new'
M.DIRECTION = {
	Full = 'full', WaningGibbous = 'waning', ThirdQuarter = 'waning',
	WaningCrescent = 'waning', New = 'new', WaxingCrescent = 'waxing',
	FirstQuarter = 'waxing', WaxingGibbous = 'waxing',
}

M.DISPLAY_NAME = {
	Full = 'Full', WaningGibbous = 'Waning Gibbous', ThirdQuarter = 'Third Quarter',
	WaningCrescent = 'Waning Crescent', New = 'New', WaxingCrescent = 'Waxing Crescent',
	FirstQuarter = 'First Quarter', WaxingGibbous = 'Waxing Gibbous',
}

M.MOON_NAMES = { 'Masser', 'Secunda' }

--------------------------------------------------------------------------------
-- Bridge to core.weather.MOON_PHASE constants
--------------------------------------------------------------------------------
-- The numeric values of MOON_PHASE are never hardcoded. They are looked up by name
-- so this keeps working if the engine ever renumbers the enum.

M.PHASE_CONST = {}      -- 'Full' -> core.weather.MOON_PHASE.Full
M.CONST_TO_NAME = {}    -- MOON_PHASE value -> 'Full'
M.CONST_TO_INDEX = {}   -- MOON_PHASE value -> 0..7 ring index

do
	local MP = core.weather and core.weather.MOON_PHASE
	if MP then
		for i, name in ipairs(M.RING) do
			local v = MP[name]
			if v ~= nil then
				M.PHASE_CONST[name] = v
				M.CONST_TO_NAME[v] = name
				M.CONST_TO_INDEX[v] = i - 1
			end
		end
	end
end

--- Ring index (0..7) for a phase name, or nil.
function M.indexOfName(name)
	for i, n in ipairs(M.RING) do
		if n == name then return i - 1 end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Morrowind calendar
--------------------------------------------------------------------------------
M.MONTHS = {
	{ 'Morning Star', 31 }, { "Sun's Dawn",  28 }, { 'First Seed',   31 },
	{ "Rain's Hand",  30 }, { 'Second Seed', 31 }, { 'Mid Year',     30 },
	{ "Sun's Height", 31 }, { 'Last Seed',   31 }, { 'Hearthfire',   30 },
	{ 'Frost Fall',   31 }, { "Sun's Dusk",  30 }, { 'Evening Star', 31 },
}
M.YEAR_LENGTH_DAYS   = 365
M.START_MONTH        = 8    -- Last Seed
M.START_DAY_OF_MONTH = 16
M.START_YEAR         = 427

--------------------------------------------------------------------------------
-- OBSERVATION FIXTURE (tier-4 fallback + regression test)
--------------------------------------------------------------------------------
-- 382 consecutive in-game days starting at day 1 (16 Last Seed 427).
-- Digits are the 5-bucket MWScript phase value: 0 new, 1 crescent, 2 quarter,
-- 3 gibbous, 4 full. This is a *recording*, not the model - prefer phaseIndexForDay().

M.FIXTURE_FIRST_DAY = 1
M.FIXTURE_MASSER =
		"44333222110001112222333444333222110001112223333444333222110001112223334444333222110001112223334" ..
		"44433322211100111222333443333222111000111222333444333222211000111222333444333222211000111222333" ..
		"44433322211100011122223334443332221110001112223334443332221110011122223334443332221110001112223" ..
		"33444333222111000111222333444333222110000111222333444333222110000111222333444333221110000111222" ..
		"33"

M.FIXTURE_SECUNDA =
		"44332221110000111222333443332221111000111222334443332222111000112223334443333222111001112223334" ..
		"44433322211100111222333344332221111000111222333344333222111000111222233444333222111000111222333" ..
		"44433322211100011122223334443332221110001112223334443332221110011122223334443332221110001112223" ..
		"33444333222111000112222333444333222111001111222333444333222110000111222333444332222111000111222" ..
		"33"

--- 5-bucket phase value (0..4) recorded for a game day, or nil if out of range.
function M.fixtureValue(moonName, gameDay)
	local s = (moonName == 'Secunda') and M.FIXTURE_SECUNDA or M.FIXTURE_MASSER
	local i = gameDay - M.FIXTURE_FIRST_DAY + 1
	if i < 1 or i > #s then return nil end
	return tonumber(s:sub(i, i))
end

--------------------------------------------------------------------------------
-- The model itself
--------------------------------------------------------------------------------

--- Engine phase index (0..7) for a game day.
-- @param gameDay number    engine day counter (TimeStamp::getDay / DaysPassed)
-- @param rolledOver boolean true once the moon has passed its moonPhaseHour today
function M.phaseIndexForDay(gameDay, rolledOver)
	local d = rolledOver and (gameDay + 1) or gameDay
	return math.floor(d / 3) % 8
end

--- Position within the 24-day cycle, 0..23, using the post-rollover branch.
function M.cycleDay(gameDay)
	return (gameDay + 1) % M.CYCLE_LENGTH_DAYS
end

--- Whole days from `gameDay` until ring index `targetIndex` (0..7) next begins.
-- Returns 0 if that phase is already current.
function M.daysUntilIndex(gameDay, targetIndex)
	local t = (gameDay + 1) % M.CYCLE_LENGTH_DAYS
	local current = math.floor(t / 3)
	local steps = (targetIndex - current) % 8
	if steps == 0 then return 0 end
	local daysLeftInPhase = 3 - (t % 3)
	return daysLeftInPhase + (steps - 1) * 3
end

--------------------------------------------------------------------------------
-- Texture atlas layout
--------------------------------------------------------------------------------
-- textures/moonhud/moon_atlas.png is 512 x 128:
--   8 columns of 64px, one per ring index (Full .. WaxingGibbous, left to right)
--   row 0 = Masser, row 1 = Secunda
-- Swap in your own sheet by matching this layout, or point ATLAS_PATH elsewhere
-- and adjust ATLAS_CELL / ATLAS_ROW.
M.TEXTURE_DIR = 'textures/moonhud/'

-- Bundled atlases. All share the 8 x 3 layout above; they differ only in style.
--   moon_atlas    soft shaded discs
--   moon_atlas_1  woodcut, flat two-tone with a hard outline
--   moon_atlas_2  cratered, mottled surface
--   moon_atlas_3  celestial, outer halo with a ringed chart face
--   moon_atlas_4  engraved, line art with a hatched shadow
M.ATLAS_PRESETS = {
	'moon_atlas', 'moon_atlas_1', 'moon_atlas_2', 'moon_atlas_3', 'moon_atlas_4',
}

-- Bundled panel fills for the rectangular and circular panels.
M.BACKGROUND_PRESETS = { 'panel_bg_stars', 'panel_bg_stone', 'panel_bg_linen' }

--- Turn a preset name into a VFS path. Returns nil for 'Custom' or 'None'.
function M.presetPath(name)
	if name == nil or name == '' or name == 'Custom' or name == 'None' then
		return nil
	end
	return M.TEXTURE_DIR .. name .. '.png'
end

M.ATLAS_PATH = 'textures/moonhud/moon_atlas.png'
M.ATLAS_CELL = 64
M.ATLAS_ROW  = { Masser = 0, Secunda = 1, Shade = 2 }
-- Row 2 holds the Shade indicator: cell 0 is lit, cells 1-7 are all the dim state,
-- so indexing it with anything is safe.
M.ATLAS_SHADE_ACTIVE   = 0
M.ATLAS_SHADE_INACTIVE = 1

--------------------------------------------------------------------------------
-- Calendar arithmetic
--------------------------------------------------------------------------------

M.MONTH_LENGTHS = {}
M.MONTH_NAMES = {}
M.MONTH_CUMULATIVE = {}   -- days before the start of month n
do
	local c = 0
	for i, m in ipairs(M.MONTHS) do
		M.MONTH_NAMES[i] = m[1]
		M.MONTH_LENGTHS[i] = m[2]
		M.MONTH_CUMULATIVE[i] = c
		c = c + m[2]
	end
end

--- Day of year, 1..365. month is 1..12.
function M.dayOfYear(month, day)
	return M.MONTH_CUMULATIVE[month] + day
end

--- A single monotonic day number across years. There are no leap years in Tamriel.
function M.absoluteDay(year, month, day)
	return (year - M.START_YEAR) * M.YEAR_LENGTH_DAYS + M.dayOfYear(month, day)
end

--- Inverse of absoluteDay. Returns year, month, day.
function M.dateFromAbsoluteDay(abs)
	local year = M.START_YEAR + math.floor((abs - 1) / M.YEAR_LENGTH_DAYS)
	local doy = ((abs - 1) % M.YEAR_LENGTH_DAYS) + 1
	for i = 1, 12 do
		if doy <= M.MONTH_CUMULATIVE[i] + M.MONTH_LENGTHS[i] then
			return year, i, doy - M.MONTH_CUMULATIVE[i]
		end
	end
	return year, 12, M.MONTH_LENGTHS[12]
end

function M.formatDate(year, month, day, withYear)
	local s = day .. ' ' .. (M.MONTH_NAMES[month] or '?')
	if withYear then s = s .. ' 3E ' .. year end
	return s
end

--------------------------------------------------------------------------------
-- Shade of the Revenant
--------------------------------------------------------------------------------
-- Every eighth day, anchored on 27 Last Seed.
--
-- Worth being precise about the sequence, because it is commonly misremembered as
-- 27 -> 5 -> 13. Last Seed has 31 days, so 27 + 8 lands on 4 Hearthfire:
--
--     27 Last Seed, 4 Hearthfire, 12, 20, 28, 6 Frostfall, 14, 22, 30 Frostfall...
--
-- That matches UESP's Oblivion "days passed" table exactly (Oblivion begins on
-- 27 Last Seed, which is where the anchor date comes from; the event there is
-- simply DaysPassed % 8 == 1).
--
-- Anchoring to a calendar date rather than to DaysPassed is deliberate: it survives
-- save transplants and console time travel, and it does not care when the game began.
--
-- The 365-day year is not divisible by 8, so the calendar dates do NOT repeat
-- year to year. 365 mod 8 = 5, so each year the sequence slides by five days.

M.SHADE = {
	ANCHOR_YEAR   = 427,
	ANCHOR_MONTH  = 8,     -- Last Seed
	ANCHOR_DAY    = 27,
	INTERVAL_DAYS = 8,
}

local function shadeAnchorAbs(cfg)
	cfg = cfg or M.SHADE
	return M.absoluteDay(cfg.ANCHOR_YEAR or 427, cfg.ANCHOR_MONTH or 8, cfg.ANCHOR_DAY or 27)
end

--- True if the given date is a Shade of the Revenant day.
function M.isShadeDay(year, month, day, cfg)
	local n = (cfg and cfg.INTERVAL_DAYS) or M.SHADE.INTERVAL_DAYS
	return (M.absoluteDay(year, month, day) - shadeAnchorAbs(cfg)) % n == 0
end

--- Whole days until the next Shade. 0 means today is one.
function M.daysUntilShade(year, month, day, cfg)
	local n = (cfg and cfg.INTERVAL_DAYS) or M.SHADE.INTERVAL_DAYS
	local delta = (M.absoluteDay(year, month, day) - shadeAnchorAbs(cfg)) % n
	if delta == 0 then return 0 end
	return n - delta
end

--- Date of the next Shade on or after the given date. Returns year, month, day.
function M.nextShadeDate(year, month, day, cfg)
	local d = M.daysUntilShade(year, month, day, cfg)
	return M.dateFromAbsoluteDay(M.absoluteDay(year, month, day) + d)
end

--------------------------------------------------------------------------------
-- LORE ONLY - not used for any gameplay logic
--------------------------------------------------------------------------------
-- From "Lunar Calendar (Shared)". Jode = Masser, Jone = Secunda in Ta'agra.
-- That calendar puts Jode on a 30-day cycle and Jone on an 8-day cycle across a
-- 360-day year. OpenMW uses 24 days for both across 365. Almanac flavour only.
M.LORE = {
	JODE_CYCLE_DAYS = 30,
	JONE_CYCLE_DAYS = 8,
	YEAR_DAYS = 360,
	FURSTOCKS = {
		'Alfiq', 'Alfiq-raht', 'Cathay', 'Cathay-raht', 'Dagi', 'Dagi-raht',
		'Ohmes', 'Ohmes-raht', 'Pahmar', 'Pahmar-raht', 'Senche', 'Senche-raht',
		'Suthay', 'Suthay-raht', 'Tojay', 'Tojay-raht',
	},
	NOTE = 'Lore reference only. Does not match OpenMW engine behaviour.',
}

return M
