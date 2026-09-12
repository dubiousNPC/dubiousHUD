---@omw-context player
-- self.cell is nil while a save loads. That was the one call shape the old
-- pcall could plausibly have been catching, so it now has an explicit guard.
local mod = _G.LOADED['scripts.moonhud.MH_tracker']
local I = mod.interface
local self_ = require('openmw.self')
local core = require('openmw.core')
local checks, fails = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: '..m) end end

-- 1. nil cell must not raise, and must not permanently demote the tracker
local realCell = self_.cell
self_.cell = nil
local ok, err = pcall(I.getMoons)
check(ok, 'nil cell does not raise: ' .. tostring(err))
check(I.getStatus().engineAvailable ~= false,
      'nil cell does not mark the engine unavailable')

-- 2. once the cell is back, the engine tier is used again
self_.cell = realCell
core.weather.getCurrentMoons = function()
	return { { name = 'Masser',  phase = 1, phaseValue = 3, alpha = 0.8 },
	         { name = 'Secunda', phase = 1, phaseValue = 3, alpha = 0.8 } }
end
local m = I.getMoons()
check(m.Masser ~= nil, 'Masser read back')
check(m.Masser.source == 'engine',
      'engine tier recovered after the nil-cell gap, got ' .. tostring(m.Masser and m.Masser.source))

-- 3. a genuinely absent binding still demotes, as before
core.weather.getCurrentMoons = nil
package.loaded['scripts.moonhud.MH_tracker'] = nil
local T2 = require('scripts.moonhud.MH_tracker')
T2.engineHandlers.onInit(nil)
local m2 = T2.interface.getMoons()
check(m2.Masser ~= nil, 'still answers with no binding at all')
check(m2.Masser.source ~= 'engine', 'falls back rather than claiming engine')
check(T2.interface.getStatus().engineAvailable == false, 'absent binding reported')

print(string.format('  %d checks, %d failures', checks, fails))
if fails > 0 then error('tracker failures') end
