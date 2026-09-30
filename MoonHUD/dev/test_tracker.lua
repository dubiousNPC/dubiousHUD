---@omw-context none
-- Offline harness: stubs the OpenMW API and exercises MH_constants + MH_tracker.
package.path = '/home/claude/work/out/MoonHUD/?.lua;' .. package.path

local DAY, HOUR = 86400, 3600

-- ---------- simulated engine ----------
local RING = { 'Full','WaningGibbous','ThirdQuarter','WaningCrescent',
               'New','WaxingCrescent','FirstQuarter','WaxingGibbous' }
local MOON_PHASE = {}
for i, n in ipairs(RING) do MOON_PHASE[n] = i - 1 end
local PV = { Full=4, WaningGibbous=3, ThirdQuarter=2, WaningCrescent=1,
             New=0, WaxingCrescent=1, FirstQuarter=2, WaxingGibbous=3 }

-- The engine's own day counter differs from ours by DAY_OFFSET; the tracker has
-- to discover it. moonPhaseHour differs per moon, which is what makes them desync.
local DAY_OFFSET  = 7
local PHASE_HOUR  = { Masser = 5.0, Secunda = 9.0 }

local SIM = { gameTime = 0, cellActive = true }

local function engineIndex(moonName, gameDay, hour)
	local d = (hour < PHASE_HOUR[moonName]) and gameDay or (gameDay + 1)
	return math.floor(d / 3) % 8
end

-- ---------- stubs ----------
local function vec2(x, y) return { x = x, y = y } end

local stubs = {}
stubs['openmw.core'] = {
	weather = {
		MOON_PHASE = MOON_PHASE,
		getCurrentMoons = function(cell)
			if not SIM.cellActive then return nil end
			local day  = math.floor(SIM.gameTime / DAY) + DAY_OFFSET
			local hour = (SIM.gameTime % DAY) / HOUR
			local out = {}
			for _, name in ipairs({ 'Masser', 'Secunda' }) do
				local idx = engineIndex(name, day, hour)
				out[#out + 1] = { name = name, phase = MOON_PHASE[RING[idx + 1]],
				                  phaseValue = PV[RING[idx + 1]], alpha = 0.8 }
			end
			return out
		end,
	},
	getSimulationTime = function() return SIM.gameTime end,
}
stubs['openmw.self']   = { cell = { isExterior = true }, sendEvent = function() end }
stubs['openmw.types']  = {}
stubs['openmw.async']  = { callback = function(f) return f end }
stubs['openmw_aux.time'] = {
	day = DAY, hour = HOUR, minute = 60, second = 1, GameTime = 'GameTime',
	runRepeatedly = function() return function() end end,
}
-- Morrowind calendar: 365 days, fixed month lengths, no leap years.
local ML = { 31,28,31,30,31,30,31,31,30,31,30,31 }
local MCUM = {}; do local c=0; for i,l in ipairs(ML) do MCUM[i]=c; c=c+l end end
-- Our stub day 0 == 16 Last Seed 427 (day of year 228), matching a new game.
local START_DOY = MCUM[8] + 16
local function dateFromStubDay(n)
	local abs = START_DOY + n
	local year = 427 + math.floor((abs - 1) / 365)
	local doy = ((abs - 1) % 365) + 1
	for i = 1, 12 do
		if doy <= MCUM[i] + ML[i] then return year, i, doy - MCUM[i] end
	end
end
stubs['openmw_aux.calendar'] = {
	gameTime = function() return SIM.gameTime end,
	formatGameTime = function(fmt, t)
		local y, m, d = dateFromStubDay(math.floor((t or SIM.gameTime) / DAY))
		if fmt == '%d' then return tostring(d) end
		if fmt == '%m' then return tostring(m) end
		if fmt == '%Y' then return tostring(y) end
		return ''
	end,
}

local realRequire = require
_G.require = function(name)
	if stubs[name] then return stubs[name] end
	return realRequire(name)
end

-- ---------- load ----------
local C = require('scripts.moonhud.MH_constants')
local T = require('scripts.moonhud.MH_tracker')
local I = T.interface

local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then fails = fails + 1; print('  FAIL: ' .. msg) end
end

print('=== 1. constants sanity ===')
check(#C.RING == 8, 'ring has 8 entries')
check(C.indexOfName('New') == 4, 'New is index 4')
check(C.CONST_TO_INDEX[MOON_PHASE.ThirdQuarter] == 2, 'const->index bridge works')
check(C.PHASE_VALUE.WaningGibbous == 3, 'gibbous maps to MWScript 3')
print(string.format('  %d checks', checks))

print('=== 2. fixture matches the model ===')
-- The recorded 382 days should agree with the model on one of the two branches.
local BUCKET_OK = { [4]={Full=true}, [3]={WaningGibbous=true,WaxingGibbous=true},
                    [2]={ThirdQuarter=true,FirstQuarter=true},
                    [1]={WaningCrescent=true,WaxingCrescent=true}, [0]={New=true} }
local agree, total = 0, 0
for gameDay = 1, 382 do
	for _, moon in ipairs({ 'Masser', 'Secunda' }) do
		local v = C.fixtureValue(moon, gameDay)
		local a = C.RING[C.phaseIndexForDay(gameDay, false) + 1]
		local b = C.RING[C.phaseIndexForDay(gameDay, true) + 1]
		total = total + 1
		if BUCKET_OK[v][a] or BUCKET_OK[v][b] then agree = agree + 1 end
	end
end
print(string.format('  %d / %d moon-days agree (%.1f%%)', agree, total, agree / total * 100))
check(agree / total > 0.99, 'fixture agrees with model above 99%')

print('=== 3. tracker reads the engine and calibrates ===')
T.engineHandlers.onInit(nil)
SIM.gameTime = 100 * DAY + 12 * HOUR
local m = I.getMoon('Masser')
check(m ~= nil, 'got Masser')
check(m.source == 'engine', 'source is engine, got ' .. tostring(m and m.source))
local expected = C.RING[engineIndex('Masser', 100 + DAY_OFFSET, 12) + 1]
check(m.phaseName == expected, 'phase matches engine: ' .. tostring(m and m.phaseName) .. ' vs ' .. expected)

-- feed it a spread of days so calibration converges
for d = 100, 130 do
	-- alternate between an hour before and after both moons' phase hour, which is
	-- what resolves the two-candidate ambiguity
	local hour = (d % 2 == 0) and 2 or 14
	SIM.gameTime = d * DAY + hour * HOUR
	I.getMoons()
end
local st = I.getStatus()
print(string.format('  candidates left: %d, offset: %d (true offset %d)',
	st.candidatesLeft, st.calibrationOffset, DAY_OFFSET))
check(st.candidatesLeft == 1, 'varied-hour sampling collapses to a single candidate')
check(st.calibrationOffset == DAY_OFFSET, 'surviving offset is the true one')
check(I.getStatus().exact == true, 'status reports exact calibration')

print('=== 4. fallback tiers when the cell goes inactive ===')
local mismatch = 0
for d = 131, 260 do
	SIM.gameTime = d * DAY + 12 * HOUR
	SIM.cellActive = true
	local truth = {}
	for _, name in ipairs({ 'Masser', 'Secunda' }) do
		truth[name] = C.RING[engineIndex(name, d + DAY_OFFSET, 12) + 1]
	end
	I.getMoons()                      -- anchor from the engine
	SIM.cellActive = false            -- walk into an interior
	SIM.gameTime = d * DAY + 13 * HOUR
	local got = I.getMoons()
	for _, name in ipairs({ 'Masser', 'Secunda' }) do
		check(got[name] ~= nil, 'fallback returned ' .. name)
		if got[name] then
			check(got[name].source == 'projected', 'fallback source is projected')
			if got[name].phaseName ~= truth[name] then mismatch = mismatch + 1 end
		end
	end
end
print(string.format('  projected disagreed with engine on %d of 260 moon-days', mismatch))
check(mismatch == 0, 'projection is exact while anchored')

print('=== 5. long interior stretch (projection drift) ===')
SIM.cellActive = true
SIM.gameTime = 300 * DAY + 12 * HOUR
I.getMoons()
SIM.cellActive = false
local drift = 0
for d = 301, 360 do
	SIM.gameTime = d * DAY + 12 * HOUR
	local got = I.getMoons()
	for _, name in ipairs({ 'Masser', 'Secunda' }) do
		local truth = C.RING[engineIndex(name, d + DAY_OFFSET, 12) + 1]
		if got[name].phaseName ~= truth then drift = drift + 1 end
	end
end
print(string.format('  drift over a 60-day unbroken interior stay: %d of 120 moon-days', drift))
check(drift == 0, 'no drift over 60 days')

print('=== 6. helper functions ===')
SIM.cellActive = true
SIM.gameTime = 400 * DAY + 12 * HOUR
I.getMoons()
local cd = I.getCycleDay()
print('  cycle day: ' .. tostring(cd))
check(cd ~= nil and cd >= 0 and cd < 24, 'cycle day is known and in range')
local du = I.daysUntil('Masser', 'Full')
print('  days until Masser is Full: ' .. tostring(du))
check(du ~= nil and du >= 0 and du <= 24, 'daysUntil in range')
check(type(I.inSync()) == 'boolean', 'inSync returns a boolean')

-- verify daysUntil actually lands on Full
if du then
	SIM.gameTime = (400 + du) * DAY + 12 * HOUR
	local later = I.getMoon('Masser')
	print('  phase after waiting that many days: ' .. later.phaseName)
	check(later.phaseName == 'Full', 'daysUntil("Full") lands on Full')
end

print('=== 6b. daysUntil lands correctly across the whole cycle ===')
local badUntil, testedUntil = 0, 0
for d = 400, 447 do
	for _, target in ipairs({ 'Full', 'New', 'FirstQuarter', 'WaningCrescent' }) do
		SIM.cellActive = true
		SIM.gameTime = d * DAY + 12 * HOUR
		I.getMoons()
		local n = I.daysUntil('Masser', target)
		testedUntil = testedUntil + 1
		if n == nil then
			badUntil = badUntil + 1
		else
			SIM.gameTime = (d + n) * DAY + 12 * HOUR
			local arrived = I.getMoon('Masser').phaseName
			-- must be that phase, and n must be minimal (n-1 days earlier must not be)
			local minimal = true
			if n > 0 then
				SIM.gameTime = (d + n - 1) * DAY + 12 * HOUR
				minimal = I.getMoon('Masser').phaseName ~= target
			end
			if arrived ~= target or not minimal then badUntil = badUntil + 1 end
		end
	end
end
print(string.format('  %d of %d daysUntil answers wrong or non-minimal', badUntil, testedUntil))
check(badUntil == 0, 'daysUntil is exact and minimal')

print('=== 7. recovery from a day-counter jump ===')
DAY_OFFSET = 19                       -- simulate console time travel
SIM.gameTime = 500 * DAY + 12 * HOUR
for d = 500, 520 do
	local hour = (d % 2 == 0) and 2 or 14
	SIM.gameTime = d * DAY + hour * HOUR
	I.getMoons()
end
local st2 = I.getStatus()
print(string.format('  recalibrated: %d candidates, offset %d (true %d)',
	st2.candidatesLeft, st2.calibrationOffset, DAY_OFFSET))
check(st2.candidatesLeft == 1, 'recovered calibration')
check(st2.calibrationOffset == DAY_OFFSET, 'recovered the new true offset')
SIM.gameTime = 520 * DAY + 12 * HOUR
local mm = I.getMoon('Masser')
check(mm.phaseName == C.RING[engineIndex('Masser', 520 + DAY_OFFSET, 12) + 1],
	'still correct after the jump')

print('=== 8. cold start with no engine at all (old build, loaded in an interior) ===')
-- Wipe state and remove the binding entirely.
stubs['openmw.core'].weather.getCurrentMoons = nil
package.loaded['scripts.moonhud.MH_tracker'] = nil
local T2 = require('scripts.moonhud.MH_tracker')
local I2 = T2.interface
T2.engineHandlers.onInit(nil)
SIM.gameTime = 50 * DAY + 12 * HOUR
local cold = I2.getMoons()
check(cold.Masser ~= nil, 'cold start still returns Masser')
check(cold.Masser.source == 'formula', 'cold start uses the formula tier, got '
	.. tostring(cold.Masser and cold.Masser.source))
check(I2.getStatus().engineAvailable == false, 'engine correctly reported unavailable')
print('  cold-start phase: ' .. tostring(cold.Masser and cold.Masser.phaseName)
	.. ' (source ' .. tostring(cold.Masser and cold.Masser.source) .. ')')
-- it should still advance three days at a time
local seen = {}
for d = 50, 73 do
	SIM.gameTime = d * DAY + 12 * HOUR
	seen[#seen + 1] = I2.getMoon('Masser').index
end
local distinct = {}
for _, v in ipairs(seen) do distinct[v] = true end
local n = 0
for _ in pairs(distinct) do n = n + 1 end
check(n == 8, 'formula tier walks all 8 phases across 24 days, saw ' .. n)

print('=== 9. fixture tier ===')
check(C.fixtureValue('Masser', 1) == 4, 'day 1 is a full moon in the recording')
check(C.fixtureValue('Masser', 383) == nil, 'recording ends at day 382')
local fx = 0
for d = 1, 382 do if C.fixtureValue('Secunda', d) ~= nil then fx = fx + 1 end end
check(fx == 382, 'all 382 recorded days are readable')

print('=== 10. calendar arithmetic ===')
check(C.dayOfYear(8, 16) == 228, '16 Last Seed is day 228')
check(C.dayOfYear(12, 31) == 365, 'the year is 365 days')
local y, m, d = C.dateFromAbsoluteDay(C.absoluteDay(429, 3, 17))
check(y == 429 and m == 3 and d == 17, 'absoluteDay round-trips')
-- exhaustive round-trip over four years
local rt = 0
for a = 1, 365 * 4 do
	local yy, mm, dd = C.dateFromAbsoluteDay(a)
	if C.absoluteDay(yy, mm, dd) ~= a then rt = rt + 1 end
end
check(rt == 0, 'absoluteDay/dateFromAbsoluteDay round-trip over 4 years, ' .. rt .. ' bad')

print('=== 11. Shade of the Revenant ===')
-- The published sequence, from UESP's Oblivion days-passed table.
local EXPECTED = {
	{ 8, 27 }, { 9, 4 }, { 9, 12 }, { 9, 20 }, { 9, 28 },
	{ 10, 6 }, { 10, 14 }, { 10, 22 }, { 10, 30 },
}
for i, e in ipairs(EXPECTED) do
	check(C.isShadeDay(427, e[1], e[2]),
		string.format('%d %s 427 is a Shade day', e[2], C.MONTH_NAMES[e[1]]))
end
-- and the day either side of each is not
for _, e in ipairs(EXPECTED) do
	local a = C.absoluteDay(427, e[1], e[2])
	local y1, m1, d1 = C.dateFromAbsoluteDay(a + 1)
	check(not C.isShadeDay(y1, m1, d1), 'day after a Shade is not a Shade')
end
-- the common misremembering
check(not C.isShadeDay(427, 9, 5), '5 Hearthfire is NOT a Shade day (the 27/05/13 sequence is wrong)')
check(not C.isShadeDay(427, 9, 13), '13 Hearthfire is NOT a Shade day')

-- exactly one in eight days, over three years
local hits = 0
for a = C.absoluteDay(427, 1, 1), C.absoluteDay(429, 12, 31) do
	local yy, mm, dd = C.dateFromAbsoluteDay(a)
	if C.isShadeDay(yy, mm, dd) then hits = hits + 1 end
end
local span = C.absoluteDay(429, 12, 31) - C.absoluteDay(427, 1, 1) + 1
print(string.format('  %d Shade days in %d (1 in %.2f)', hits, span, span / hits))
check(math.abs(span / hits - 8) < 0.02, 'exactly one day in eight')

-- daysUntilShade and nextShadeDate agree with isShadeDay everywhere
local bad = 0
for a = C.absoluteDay(427, 1, 1), C.absoluteDay(428, 12, 31) do
	local yy, mm, dd = C.dateFromAbsoluteDay(a)
	local n = C.daysUntilShade(yy, mm, dd)
	local ny, nm, nd = C.nextShadeDate(yy, mm, dd)
	if n < 0 or n > 7 then bad = bad + 1 end
	if not C.isShadeDay(ny, nm, nd) then bad = bad + 1 end
	if C.absoluteDay(ny, nm, nd) ~= a + n then bad = bad + 1 end
	local y2, m2, d2 = C.dateFromAbsoluteDay(a + n)
	if n > 0 and C.isShadeDay(yy, mm, dd) then bad = bad + 1 end
end
check(bad == 0, 'daysUntilShade / nextShadeDate consistent over 2 years, ' .. bad .. ' bad')

-- year boundary really does slide by five days
local firstShadeIn = {}
for yr = 427, 430 do
	for a = C.absoluteDay(yr, 1, 1), C.absoluteDay(yr, 1, 31) do
		local yy, mm, dd = C.dateFromAbsoluteDay(a)
		if C.isShadeDay(yy, mm, dd) then firstShadeIn[yr] = dd break end
	end
end
print(string.format('  first Shade of Morning Star: 427=%d 428=%d 429=%d 430=%d',
	firstShadeIn[427], firstShadeIn[428], firstShadeIn[429], firstShadeIn[430]))
check(firstShadeIn[427] ~= firstShadeIn[428], 'dates do not repeat annually (365 mod 8 = 5)')

print('=== 12. tracker Shade interface ===')
stubs['openmw.core'].weather.getCurrentMoons = nil
package.loaded['scripts.moonhud.MH_tracker'] = nil
local T3 = require('scripts.moonhud.MH_tracker')
local I3 = T3.interface
T3.engineHandlers.onInit(nil)
-- stub day 11 == 27 Last Seed 427 (game starts on the 16th)
SIM.gameTime = 11 * DAY + 12 * HOUR
local sh = I3.getShade()
check(sh ~= nil, 'getShade returned something')
check(sh.active == true, '27 Last Seed is active, got ' .. tostring(sh and sh.active))
check(sh.daysUntil == 0, 'daysUntil is 0 on the day')
print('  on 27 Last Seed: active=' .. tostring(sh.active) .. ' next=' .. sh.dateString)

SIM.gameTime = 12 * DAY + 12 * HOUR
sh = I3.getShade()
check(sh.active == false and sh.daysUntil == 7, '28 Last Seed: 7 days to go, got ' .. sh.daysUntil)
check(sh.dateString == '4 Hearthfire', 'next Shade reads "4 Hearthfire", got ' .. sh.dateString)
print('  on 28 Last Seed: ' .. sh.daysUntil .. ' days, next ' .. sh.dateString)

local up = I3.upcomingShades(4)
print('  upcoming: ' .. table.concat(up, ', '))
check(#up == 4, 'upcomingShades returns 4')
check(up[1]:find('4 Hearthfire') ~= nil, 'first upcoming is 4 Hearthfire')

-- reconfiguring the anchor
I3.setShadeConfig { ANCHOR_DAY = 1, ANCHOR_MONTH = 1, INTERVAL_DAYS = 10 }
-- anchor 1 Morning Star 427, every 10 days -> abs must be 1 mod 10.
-- 6 Morning Star 428 is abs 371, and (371-1) %% 10 == 0.
SIM.gameTime = (C.absoluteDay(428, 1, 6) - (MCUM[8] + 16)) * DAY + 12 * HOUR
local rc = I3.getShade()
print('  reconfigured (anchor 1 Morning Star, every 10): 6 Morning Star 428 active=' .. tostring(rc.active))
check(rc.active == true, 'reconfigured anchor works')
SIM.gameTime = (C.absoluteDay(428, 1, 7) - (MCUM[8] + 16)) * DAY + 12 * HOUR
check(I3.getShade().active == false, 'the next day is not active under the new interval')
I3.setShadeConfig { ANCHOR_DAY = 27, ANCHOR_MONTH = 8, INTERVAL_DAYS = 8 }

print('')
print(string.format('%d checks, %d failures', checks, fails))
os.exit(fails == 0 and 0 or 1)
