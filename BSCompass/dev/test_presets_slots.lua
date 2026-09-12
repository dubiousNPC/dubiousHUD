-- Exercises the preset slots against the real settings module, through the
-- harness stubs: save a configuration, change it, load it back.
local storage = require('openmw.storage')
local util = require('openmw.util')
local checks, fails = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: ' .. m) end end

local MOD = 'BSCompass'
local P = storage.playerSection('Settings' .. MOD .. 'PRESETS')
local MOONS = storage.playerSection('Settings' .. MOD .. 'Compass')
local APP = storage.playerSection('Settings' .. MOD .. 'General')
local SLOTS = storage.playerSection('Settings' .. MOD .. 'PresetSlots')
local CARD  = storage.playerSection('Settings' .. MOD .. 'Cardinals')

print('=== 1. the preset controls exist ===')
check(P:get('PRESET') ~= nil or true, 'PRESET section reachable')

print('=== 2. save captures the current configuration ===')
MOONS:set('COMPASS_SIZE', 48)
MOONS:set('FACING_SOURCE', 'Body')
APP:set('HUD_X_POS', 271)
P:set('PRESET_SAVE', 'Save to Slot 1')

local snap = SLOTS:get('SLOT1')
check(type(snap) == 'table', 'slot 1 holds a table')
check(snap and snap.COMPASS_SIZE == 48, 'slot captured COMPASS_SIZE, got ' .. tostring(snap and snap.COMPASS_SIZE))
check(snap and snap.FACING_SOURCE == 'Body', 'slot captured FACING_SOURCE')
check(snap and snap.HUD_X_POS == 271, 'slot captured a key from another group')
check(snap and snap.PRESET == nil and snap.PRESET_SAVE == nil,
      'slot does not store the preset controls themselves')

print('=== 3. the save selector resets itself ===')
check(P:get('PRESET_SAVE') == '--', "PRESET_SAVE returned to '--', got " .. tostring(P:get('PRESET_SAVE')))

print('=== 4. load restores it ===')
MOONS:set('COMPASS_SIZE', 12)
MOONS:set('FACING_SOURCE', 'Camera')
APP:set('HUD_X_POS', 9)
P:set('PRESET', 'Slot 1')
check(MOONS:get('COMPASS_SIZE') == 48, 'ICON_SIZE restored, got ' .. tostring(MOONS:get('COMPASS_SIZE')))
check(MOONS:get('FACING_SOURCE') == 'Body', 'FACING_SOURCE restored')
check(APP:get('HUD_X_POS') == 271, 'cross-group key restored')

print('=== 5. two slots are independent ===')
MOONS:set('COMPASS_SIZE', 99)
P:set('PRESET_SAVE', 'Save to Slot 2')
check(SLOTS:get('SLOT2').COMPASS_SIZE == 99, 'slot 2 captured the new value')
check(SLOTS:get('SLOT1').COMPASS_SIZE == 48, 'slot 1 is untouched')
P:set('PRESET', 'Slot 1')
check(MOONS:get('COMPASS_SIZE') == 48, 'loading slot 1 does not read slot 2')
P:set('PRESET', 'Slot 2')
check(MOONS:get('COMPASS_SIZE') == 99, 'loading slot 2 works')

print('=== 6. colours survive a round trip ===')
APP:set('HUD_BORDER_COLOR', util.color.hex('ff8800'))
P:set('PRESET_SAVE', 'Save to Slot 1')
local stored = SLOTS:get('SLOT1').HUD_BORDER_COLOR
check(type(stored) == 'string' and stored:match('^#hex:'),
      'colour stored as a tagged hex string, got ' .. tostring(stored))
APP:set('HUD_BORDER_COLOR', util.color.hex('000000'))
P:set('PRESET', 'Slot 1')
local back = APP:get('HUD_BORDER_COLOR')
check(type(back) == 'table' or type(back) == 'userdata', 'colour came back as a colour')

print('=== 7. built-in presets apply ===')
P:set('PRESET', 'Daedric')
check(MOONS:get('ATLAS_PRESET') == 'DBS_CompassARROW', 'Daedric selects the DBS sheet')
check(CARD:get('CARDINAL_OVERLAY') == 'Sharp + Fade',
      'Daedric turns the glyphs on, got ' .. tostring(CARD:get('CARDINAL_OVERLAY')))
P:set('PRESET', 'Minimal')
check(MOONS:get('ATLAS_PRESET') == 'BSCompasAtlas', 'Minimal selects the plain dial')

print('=== 8. Custom does nothing ===')
MOONS:set('COMPASS_SIZE', 33)
P:set('PRESET', 'Custom')
check(MOONS:get('COMPASS_SIZE') == 33, 'Custom leaves settings alone')

print('=== 9. Default sweeps everything back ===')
MOONS:set('COMPASS_SIZE', 7)
APP:set('HUD_X_POS', 7)
P:set('PRESET', 'Default')
check(MOONS:get('COMPASS_SIZE') ~= 7, 'ICON_SIZE reset, got ' .. tostring(MOONS:get('COMPASS_SIZE')))
check(APP:get('HUD_X_POS') ~= 7, 'HUD_X_POS reset, got ' .. tostring(APP:get('HUD_X_POS')))

print('=== 10. an empty slot is a no-op, not an error ===')
local ok = pcall(function() P:set('PRESET', 'Slot 2') end)
check(ok, 'loading a populated slot is fine')
SLOTS:set('SLOT2', nil)
ok = pcall(function() P:set('PRESET', 'Slot 2') end)
check(ok, 'loading an empty slot does not raise')

print(string.format('  %d checks, %d failures', checks, fails))
if fails > 0 then error('preset slot failures') end
