-- Run with a legacy string seeded into storage, as check_all.sh does:
--   SEED=TEXT_COLOR=caa560 API_SCRIPT=dev/test_legacy_colour.lua lua dev/load_check.lua . \
--       scripts/moonhud/MH_tracker.lua scripts/moonhud/MH_hud.lua
-- An older build stored TEXT_COLOR as a hex string (textLine renderer). The
-- SuperColorPicker4 menu renderer calls value:asHex() on whatever is stored,
-- so the string made that setting unrenderable in the settings menu.
local storage = require('openmw.storage')
local checks, fails = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: ' .. m) end end

local APP = storage.playerSection('SettingsMoonHUDAppearance')
local v = APP:get('TEXT_COLOR')
check(type(v) ~= 'string', 'stored TEXT_COLOR is no longer a string, got ' .. tostring(v))
check(v ~= nil and type(v.asHex) == 'function', 'stored TEXT_COLOR answers asHex, as the renderer requires')
check(v ~= nil and type(v.asHex) == 'function' and v:asHex():lower() == 'caa560',
      'the colour itself is preserved, got ' .. tostring(v and v.asHex and v:asHex()))
print(string.format('  %d checks, %d failures', checks, fails))
if fails > 0 then error('legacy colour failures') end
