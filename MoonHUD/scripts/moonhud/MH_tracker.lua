---@omw-context player
-- MH_tracker.lua  (PLAYER script)
--
-- Lunar phase tracking for OpenMW, primary source core.weather.getCurrentMoons(),
-- with three progressively weaker fallbacks so callers always get an answer.
--
--   tier 1  "engine"     core.weather.getCurrentMoons(self.cell)          exact
--   tier 2  "projected"  last good engine read, advanced by the 3-day step  exact while calibrated
--   tier 3  "formula"    ((day + K) / 3) mod 8 with a default K             good
--   tier 4  "fixture"    the recorded 382-day observation table             last resort
--
-- Tier 1 is unavailable in interiors, in inactive cells, and on engine builds
-- predating the moon bindings. Tiers 2-4 cover those cases.
--
-- Exposes interface `MoonTracker`. See the bottom of this file.

local core     = require('openmw.core')
local self     = require('openmw.self')
local types    = require('openmw.types')
local async    = require('openmw.async')
local time     = require('openmw_aux.time')
local calendar = require('openmw_aux.calendar')

local C = require('scripts.moonhud.MH_constants')

local CYCLE = C.CYCLE_LENGTH_DAYS

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local saveData = {
	-- surviving calibration offsets K (0..23) mapping our day index onto the
	-- engine's DaysPassed counter. Starts as every candidate and narrows.
	kCandidates = nil,
	-- last confirmed engine reading, per moon: { day = n, index = 0..7 }
	anchors     = {},
	-- last phase index seen, per moon, for change events
	lastIndex   = {},
}

local engineAvailable = nil   -- nil = untested, then true/false
local lastShadeActive = nil
local shadeConfig = {
	ANCHOR_YEAR   = C.SHADE.ANCHOR_YEAR,
	ANCHOR_MONTH  = C.SHADE.ANCHOR_MONTH,
	ANCHOR_DAY    = C.SHADE.ANCHOR_DAY,
	INTERVAL_DAYS = C.SHADE.INTERVAL_DAYS,
}
local lastResult      = nil   -- cached per-frame result
local lastResultDay   = nil
local lastResultHour  = nil

--------------------------------------------------------------------------------
-- Day index
--------------------------------------------------------------------------------

-- Our own day counter. It differs from the engine's DaysPassed by an unknown but
-- CONSTANT offset, which the calibration step below solves for.
local function currentDayIndex()
	local t = calendar.gameTime()
	if type(t) ~= 'number' then return nil end
	return math.floor(t / time.day)
end

local function currentHour()
	local t = calendar.gameTime()
	if type(t) ~= 'number' then return 0 end
	return (t % time.day) / time.hour
end

--- Current in-game calendar date as year, month (1-12), day (1-31), or nil.
local function currentDate()
	local t = calendar.gameTime()
	if type(t) ~= 'number' then return nil end
	local d = tonumber(calendar.formatGameTime('%d', t))
	local m = tonumber(calendar.formatGameTime('%m', t))
	local y = tonumber(calendar.formatGameTime('%Y', t))
	if not (d and m and y) then return nil end
	return y, m, d
end

--------------------------------------------------------------------------------
-- Tier 1: the engine
--------------------------------------------------------------------------------

-- Returns { Masser = index, Secunda = index, alphas = {...} } or nil.
local function readEngine()
	if engineAvailable == false then return nil end
	if not (core.weather and core.weather.getCurrentMoons) then
		engineAvailable = false
		return nil
	end

	-- self.cell is nil while a save is loading, and passing nil is the one call
	-- shape that could reasonably raise. Checked explicitly rather than wrapped
	-- in pcall: a genuine engine fault should surface, not be mistaken for
	-- "the binding is broken, stop trying" and silently demote the mod to its
	-- fallback tier for the rest of the session.
	local cell = self.cell
	if cell == nil then return nil end

	local moons = core.weather.getCurrentMoons(cell)
	engineAvailable = true
	if not moons then return nil end   -- inactive cell / no sky. Normal in interiors.

	local out, alphas = {}, {}
	for _, moon in ipairs(moons) do
		local idx = C.CONST_TO_INDEX[moon.phase]
		if idx == nil and moon.phase ~= nil then
			-- Unknown enum value. Fall back to the 5-bucket value, which cannot
			-- distinguish waxing from waning, so pick the waning representative.
			for name, v in pairs(C.PHASE_VALUE) do
				if v == moon.phaseValue then idx = C.indexOfName(name) break end
			end
		end
		if idx ~= nil then
			out[moon.name] = idx
			alphas[moon.name] = moon.alpha
		end
	end
	if next(out) == nil then return nil end
	out.alphas = alphas
	return out
end

--------------------------------------------------------------------------------
-- Calibration
--------------------------------------------------------------------------------
-- On any given day the engine reports either floor((D+K)/3) mod 8 or
-- floor((D+K+1)/3) mod 8, depending on whether that moon has passed its
-- moonPhaseHour yet. So a reading is consistent with K if EITHER branch matches.
-- Intersecting candidate sets across days converges within a couple of days.

local function freshCandidates()
	local t = {}
	for k = 0, CYCLE - 1 do t[k] = true end
	return t
end

local function narrowCalibration(day, index)
	if not saveData.kCandidates then saveData.kCandidates = freshCandidates() end
	local kept, count = {}, 0
	for k in pairs(saveData.kCandidates) do
		local a = math.floor((day + k) / 3) % 8
		local b = math.floor((day + k + 1) / 3) % 8
		if a == index or b == index then
			kept[k] = true
			count = count + 1
		end
	end
	if count == 0 then
		-- Contradiction: the day counter jumped (console, mod, save transplant).
		-- Restart calibration from this reading rather than serve stale data.
		saveData.kCandidates = freshCandidates()
		return narrowCalibration(day, index)
	end
	saveData.kCandidates = kept
	return count
end

local function calibrationOffset()
	if not saveData.kCandidates then return 0 end
	local best
	for k in pairs(saveData.kCandidates) do
		if best == nil or k < best then best = k end
	end
	return best or 0
end

local function calibrationCount()
	if not saveData.kCandidates then return CYCLE end
	local n = 0
	for _ in pairs(saveData.kCandidates) do n = n + 1 end
	return n
end

-- Sampling only ever at, say, midday leaves TWO adjacent candidates standing:
-- "K, having rolled over" and "K+1, not yet rolled over" predict identical phases
-- for every day. That is not a bug, it is the limit of the information available -
-- you cannot tell the two apart without a reading from the other side of the
-- moon's phase hour. Two candidates is therefore the normal converged state, and
-- costs at most one day of precision on boundary predictions. It collapses to one
-- as soon as the player is outdoors both before and after moonrise.
local function calibrationConverged() return calibrationCount() <= 2 end
local function calibrationExact()     return calibrationCount() == 1 end

--------------------------------------------------------------------------------
-- Tiers 2-4
--------------------------------------------------------------------------------

-- Tier 2: advance the last confirmed reading by however many 3-day steps have
-- elapsed. Inherits the correct rollover branch from that reading, so it stays
-- exact for as long as the calibration holds.
local function projectFromAnchor(moonName, day)
	local a = saveData.anchors[moonName]
	if not a then return nil end
	local k = calibrationOffset()
	local stepsNow  = math.floor((day   + k + 1) / 3)
	local stepsThen = math.floor((a.day + k + 1) / 3)
	return (a.index + (stepsNow - stepsThen)) % 8
end

-- Tier 3: the raw formula.
local function formulaIndex(day)
	return math.floor((day + calibrationOffset() + 1) / 3) % 8
end

-- Tier 4: the recorded observation table, keyed by day since game start.
-- Only gives a 5-bucket value, so direction is inferred from the neighbouring days.
local function fixtureIndex(moonName, gameDay)
	local v = C.fixtureValue(moonName, gameDay)
	if v == nil then return nil end
	if v == 4 then return C.indexOfName('Full') end
	if v == 0 then return C.indexOfName('New') end
	-- Look ahead to work out whether we are waxing or waning.
	local nxt = C.fixtureValue(moonName, gameDay + 1) or v
	local prv = C.fixtureValue(moonName, gameDay - 1) or v
	local waning = (nxt < v) or (prv > v)
	local byBucket = {
		[3] = waning and 'WaningGibbous'  or 'WaxingGibbous',
		[2] = waning and 'ThirdQuarter'   or 'FirstQuarter',
		[1] = waning and 'WaningCrescent' or 'WaxingCrescent',
	}
	return C.indexOfName(byBucket[v])
end

--------------------------------------------------------------------------------
-- Assembly
--------------------------------------------------------------------------------

local function describe(moonName, index, source, alpha)
	local phaseName = C.RING[index + 1]
	return {
		name        = moonName,
		index       = index,                          -- 0..7 engine phase index
		phase       = C.PHASE_CONST[phaseName],       -- core.weather.MOON_PHASE.*
		phaseName   = phaseName,                      -- 'WaningGibbous'
		displayName = C.DISPLAY_NAME[phaseName],      -- 'Waning Gibbous'
		phaseValue  = C.PHASE_VALUE[phaseName],       -- MWScript 0..4
		bucket      = C.BUCKET[phaseName],            -- 'Gibbous'
		direction   = C.DIRECTION[phaseName],         -- 'waning'
		alpha       = alpha,                          -- sky alpha, nil when unknown
		source      = source,
	}
end

local function compute()
	local day = currentDayIndex()
	if day == nil then return nil end

	local engine = readEngine()
	local result = { day = day, moons = {} }

	for _, moonName in ipairs(C.MOON_NAMES) do
		local index, source, alpha

		if engine and engine[moonName] then
			index  = engine[moonName]
			alpha  = engine.alphas and engine.alphas[moonName]
			source = 'engine'
			narrowCalibration(day, index)
			saveData.anchors[moonName] = { day = day, index = index }
		else
			index = projectFromAnchor(moonName, day)
			source = 'projected'
			if index == nil then
				index = formulaIndex(day)
				source = 'formula'
			end
			if index == nil then
				index = fixtureIndex(moonName, day)
				source = 'fixture'
			end
		end

		if index ~= nil then
			result.moons[moonName] = describe(moonName, index, source, alpha)
		end
	end

	return result
end

local function current()
	local day  = currentDayIndex()
	local hour = math.floor(currentHour() * 4)   -- quarter-hour granularity
	if lastResult and lastResultDay == day and lastResultHour == hour then
		return lastResult
	end
	local r = compute()
	-- Only cache a reading taken with a live cell. During a load self.cell is
	-- nil, so the result comes from a fallback tier; caching that would keep the
	-- fallback in place for the rest of the quarter-hour bucket even once the
	-- cell is back and the engine could answer exactly.
	if r and self.cell ~= nil then
		lastResult, lastResultDay, lastResultHour = r, day, hour
	end
	return r
end

--------------------------------------------------------------------------------
-- Phase change events
--------------------------------------------------------------------------------

local function checkForChanges()
	local r = current()
	if not r then return end
	for name, moon in pairs(r.moons) do
		local prev = saveData.lastIndex[name]
		if prev ~= nil and prev ~= moon.index then
			self:sendEvent('MoonTracker_PhaseChanged', {
				moon = name,
				from = C.RING[prev + 1],
				to   = moon.phaseName,
				info = moon,
			})
		end
		saveData.lastIndex[name] = moon.index
	end

	-- Shade of the Revenant is date-driven, so check it independently of the moons.
	local shade = interface.getShade()
	if shade then
		if lastShadeActive == false and shade.active then
			self:sendEvent('MoonTracker_ShadeOfTheRevenant', { shade = shade })
		end
		lastShadeActive = shade.active
	end
end

--------------------------------------------------------------------------------
-- Interface
--------------------------------------------------------------------------------

-- Forward declaration: the methods below call each other, and a local is only in
-- scope *after* its declaring statement finishes.
local interface

interface = {
	version = C.VERSION,

	--- All moons: { Masser = info, Secunda = info }, or an empty table.
	getMoons = function()
		local r = current()
		return r and r.moons or {}
	end,

	--- One moon by name ('Masser' / 'Secunda'), or nil.
	getMoon = function(moonName)
		local r = current()
		return r and r.moons[moonName] or nil
	end,

	--- Whole days until `moonName` next enters `phaseName` (e.g. 'Full').
	--- 0 means it is in that phase now. nil if unknown.
	daysUntil = function(moonName, phaseName)
		local moon = interface.getMoon(moonName)
		if not moon then return nil end
		local target = C.indexOfName(phaseName)
		if target == nil then return nil end
		local steps = (target - moon.index) % 8
		if steps == 0 then return 0 end
		local day = currentDayIndex()
		if day and calibrationConverged() then
			-- Exact once calibrated, give or take the one-day ambiguity described
			-- above. getStatus().exact tells you which you are getting.
			return C.daysUntilIndex(day + calibrationOffset(), target)
		end
		-- Uncalibrated: we know the phase but not where inside it we are, so
		-- assume a whole phase remains. Over-estimates by at most two days.
		return steps * C.PHASE_LENGTH_DAYS
	end,

	isFull = function(moonName)
		local m = interface.getMoon(moonName)
		return m ~= nil and m.phaseName == 'Full'
	end,

	isNew = function(moonName)
		local m = interface.getMoon(moonName)
		return m ~= nil and m.phaseName == 'New'
	end,

	--- True when both moons show the same phase.
	inSync = function()
		local r = current()
		if not r then return nil end
		local a, b = r.moons.Masser, r.moons.Secunda
		if not (a and b) then return nil end
		return a.index == b.index
	end,

	--- Position in the 24-day cycle (0..23), or nil while uncalibrated.
	--- May be one out until calibration is exact; see getStatus().exact.
	getCycleDay = function()
		local day = currentDayIndex()
		if not day or not calibrationConverged() then return nil end
		return C.cycleDay(day + calibrationOffset())
	end,

	--- Diagnostics.
	getStatus = function()
		local r = current()
		return {
			engineAvailable   = engineAvailable,
			calibrationOffset = calibrationOffset(),
			candidatesLeft    = calibrationCount(),
			calibrated        = calibrationConverged(),
			exact             = calibrationExact(),
			dayIndex          = currentDayIndex(),
			source            = r and r.moons.Masser and r.moons.Masser.source or 'none',
		}
	end,

	--- Re-run calibration from scratch. Useful after console time travel.
	resetCalibration = function()
		saveData.kCandidates = nil
		saveData.anchors = {}
		lastResult = nil
	end,

	--------------------------------------------------------------------------
	-- Shade of the Revenant
	--------------------------------------------------------------------------
	-- Every eighth day from 27 Last Seed. Independent of the moons, so it works
	-- indoors and on engine builds with no moon bindings at all.
	--
	--   27 Last Seed, 4 Hearthfire, 12, 20, 28, 6 Frostfall, 14, 22, 30 Frostfall
	--
	-- Note 27 -> 4 -> 12, not 27 -> 5 -> 13. Last Seed has 31 days.

	--- { active, daysUntil, date = {year, month, day}, dateString, todayString }
	--- or nil if the calendar is unreadable.
	getShade = function()
		local y, m, d = currentDate()
		if not y then return nil end
		local cfg = shadeConfig
		local until_ = C.daysUntilShade(y, m, d, cfg)
		local ny, nm, nd = C.nextShadeDate(y, m, d, cfg)
		return {
			active      = (until_ == 0),
			daysUntil   = until_,
			date        = { year = ny, month = nm, day = nd },
			dateString  = C.formatDate(ny, nm, nd, ny ~= y),
			todayString = C.formatDate(y, m, d, false),
			interval    = cfg.INTERVAL_DAYS,
		}
	end,

	--- True if today is a Shade day.
	isShadeDay = function()
		local s = interface.getShade()
		return s ~= nil and s.active
	end,

	--- Override the anchor date or interval, e.g. from settings.
	--- Pass { ANCHOR_YEAR, ANCHOR_MONTH, ANCHOR_DAY, INTERVAL_DAYS }.
	setShadeConfig = function(cfg)
		for k, v in pairs(cfg or {}) do
			if v ~= nil then shadeConfig[k] = v end
		end
		lastShadeActive = nil
	end,

	getShadeConfig = function()
		return {
			ANCHOR_YEAR   = shadeConfig.ANCHOR_YEAR,
			ANCHOR_MONTH  = shadeConfig.ANCHOR_MONTH,
			ANCHOR_DAY    = shadeConfig.ANCHOR_DAY,
			INTERVAL_DAYS = shadeConfig.INTERVAL_DAYS,
		}
	end,

	--- The next `count` Shade dates as formatted strings. Handy for almanac items.
	upcomingShades = function(count)
		local y, m, d = currentDate()
		if not y then return {} end
		local out = {}
		local abs = C.absoluteDay(y, m, d) + C.daysUntilShade(y, m, d, shadeConfig)
		for i = 1, (count or 8) do
			local yy, mm, dd = C.dateFromAbsoluteDay(abs)
			out[i] = C.formatDate(yy, mm, dd, true)
			abs = abs + shadeConfig.INTERVAL_DAYS
		end
		return out
	end,

	constants = C,
}

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

local stopTimer

local function onLoad(data)
	saveData = data or saveData
	saveData.anchors   = saveData.anchors or {}
	saveData.lastIndex = saveData.lastIndex or {}
	lastResult = nil
	if stopTimer then stopTimer() end
	-- Poll on game time so it pauses with the game and keeps up during Rest.
	stopTimer = time.runRepeatedly(checkForChanges, 30 * time.minute, {
		type = time.GameTime,
		initialDelay = 0,
	})
end

return {
	interfaceName = 'MoonTracker',
	interface = interface,
	engineHandlers = {
		onInit = onLoad,
		onLoad = onLoad,
		onSave = function() return saveData end,
	},
}
