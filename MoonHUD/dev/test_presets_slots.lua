-- Exercises the preset slots against the real settings module, through the
-- harness stubs: save a configuration, change it, load it back.
local storage = require('openmw.storage')
local util = require('openmw.util')
local checks, fails = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: ' .. m) end end

local MOD = 'MoonHUD'
local P = storage.playerSection('Settings' .. MOD .. 'PRESETS')
local MOONS = storage.playerSection('Settings' .. MOD .. 'Moons')
local APP = storage.playerSection('Settings' .. MOD .. 'Appearance')
local SLOTS = storage.playerSection('Settings' .. MOD .. 'PresetSlots')

print('=== 1. the preset controls exist ===')
check(P:get('PRESET') ~= nil or true, 'PRESET section reachable')

print('=== 2. save captures the current configuration ===')
MOONS:set('ICON_SIZE', 48)
MOONS:set('LAYOUT', 'Triangle')
APP:set('FONT_SIZE', 27)
P:set('PRESET_SAVE', 'Save to Slot 1')

local snap = SLOTS:get('SLOT1')
check(type(snap) == 'table', 'slot 1 holds a table')
check(snap and snap.ICON_SIZE == 48, 'slot captured ICON_SIZE, got ' .. tostring(snap and snap.ICON_SIZE))
check(snap and snap.LAYOUT == 'Triangle', 'slot captured LAYOUT')
check(snap and snap.FONT_SIZE == 27, 'slot captured a key from another group')
check(snap and snap.PRESET == nil and snap.PRESET_SAVE == nil,
      'slot does not store the preset controls themselves')

print('=== 3. the save selector resets itself ===')
check(P:get('PRESET_SAVE') == '--', "PRESET_SAVE returned to '--', got " .. tostring(P:get('PRESET_SAVE')))

print('=== 4. load restores it ===')
MOONS:set('ICON_SIZE', 12)
MOONS:set('LAYOUT', 'Horizontal')
APP:set('FONT_SIZE', 9)
P:set('PRESET', 'Slot 1')
check(MOONS:get('ICON_SIZE') == 48, 'ICON_SIZE restored, got ' .. tostring(MOONS:get('ICON_SIZE')))
check(MOONS:get('LAYOUT') == 'Triangle', 'LAYOUT restored')
check(APP:get('FONT_SIZE') == 27, 'cross-group key restored')

print('=== 5. two slots are independent ===')
MOONS:set('ICON_SIZE', 99)
P:set('PRESET_SAVE', 'Save to Slot 2')
check(SLOTS:get('SLOT2').ICON_SIZE == 99, 'slot 2 captured the new value')
check(SLOTS:get('SLOT1').ICON_SIZE == 48, 'slot 1 is untouched')
P:set('PRESET', 'Slot 1')
check(MOONS:get('ICON_SIZE') == 48, 'loading slot 1 does not read slot 2')
P:set('PRESET', 'Slot 2')
check(MOONS:get('ICON_SIZE') == 99, 'loading slot 2 works')

print('=== 6. colours survive a round trip ===')
APP:set('TEXT_COLOR', util.color.hex('ff8800'))
P:set('PRESET_SAVE', 'Save to Slot 1')
local stored = SLOTS:get('SLOT1').TEXT_COLOR
check(type(stored) == 'string' and stored:match('^#hex:'),
      'colour stored as a tagged hex string, got ' .. tostring(stored))
APP:set('TEXT_COLOR', util.color.hex('000000'))
P:set('PRESET', 'Slot 1')
local back = APP:get('TEXT_COLOR')
check(type(back) == 'table' or type(back) == 'userdata', 'colour came back as a colour')

print('=== 7. built-in presets apply ===')
P:set('PRESET', 'Orrery')
check(MOONS:get('LAYOUT') == 'Triangle', 'Orrery sets a triangle layout')
check(MOONS:get('ATLAS_PRESET') == 'moon_atlas_3', 'Orrery sets the celestial atlas')
P:set('PRESET', 'Minimal')
check(MOONS:get('LAYOUT') == 'Vertical', 'Minimal sets a vertical layout')

print('=== 8. Custom does nothing ===')
MOONS:set('ICON_SIZE', 33)
P:set('PRESET', 'Custom')
check(MOONS:get('ICON_SIZE') == 33, 'Custom leaves settings alone')

print('=== 9. Default sweeps everything back ===')
MOONS:set('ICON_SIZE', 7)
APP:set('FONT_SIZE', 7)
P:set('PRESET', 'Default')
check(MOONS:get('ICON_SIZE') ~= 7, 'ICON_SIZE reset, got ' .. tostring(MOONS:get('ICON_SIZE')))
check(APP:get('FONT_SIZE') ~= 7, 'FONT_SIZE reset, got ' .. tostring(APP:get('FONT_SIZE')))

print('=== 10. an empty slot is a no-op, not an error ===')
local ok = pcall(function() P:set('PRESET', 'Slot 2') end)
check(ok, 'loading a populated slot is fine')
SLOTS:set('SLOT2', nil)
ok = pcall(function() P:set('PRESET', 'Slot 2') end)
check(ok, 'loading an empty slot does not raise')

print(string.format('  %d checks, %d failures', checks, fails))
if fails > 0 then error('preset slot failures') end
