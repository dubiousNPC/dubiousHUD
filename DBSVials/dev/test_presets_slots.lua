---@omw-context none
-- Exercises the preset slots and the built-in presets against the real settings
-- module, through the harness stubs: save a configuration, change it, load it
-- back. Run as API_SCRIPT.

local storage = require('openmw.storage')
local checks, fails = 0, 0
local function check(c, m)
	checks = checks + 1
	if not c then fails = fails + 1; print('  FAIL: ' .. m) end
end

local MOD    = 'DBSVials'
local P      = storage.playerSection('Settings' .. MOD .. 'PRESETS')
local VIALS  = storage.playerSection('Settings' .. MOD .. 'Vials')
local GEN    = storage.playerSection('Settings' .. MOD .. 'General')
local RUNES  = storage.playerSection('Settings' .. MOD .. 'Runes')
local ACCESS = storage.playerSection('Settings' .. MOD .. 'Access')
local SLOTS  = storage.playerSection('Settings' .. MOD .. 'PresetSlots')

print('=== 1. save captures the current configuration ===')
VIALS:set('VIAL_SIZE', 208)
VIALS:set('VIAL_X_POS', 271)
RUNES:set('RUNE_FILL_FROM', 'Top')
P:set('PRESET_SAVE', 'Save to Slot 1')

local snap = SLOTS:get('SLOT1')
check(type(snap) == 'table', 'slot 1 holds a table')
check(snap and snap.VIAL_SIZE == 208,
	'slot captured VIAL_SIZE, got ' .. tostring(snap and snap.VIAL_SIZE))
check(snap and snap.VIAL_X_POS == 271, 'slot captured the vials\' own position')
check(snap and snap.RUNE_FILL_FROM == 'Top', 'slot captured a third group')
check(snap and snap.PRESET == nil and snap.PRESET_SAVE == nil,
	'slot does not store the preset controls themselves')

print('=== 2. the save selector resets itself ===')
check(P:get('PRESET_SAVE') == '--',
	"PRESET_SAVE returned to '--', got " .. tostring(P:get('PRESET_SAVE')))

print('=== 3. load restores it ===')
VIALS:set('VIAL_SIZE', 40)
VIALS:set('VIAL_X_POS', 9)
RUNES:set('RUNE_FILL_FROM', 'Bottom')
P:set('PRESET', 'Slot 1')
check(VIALS:get('VIAL_SIZE') == 208,
	'VIAL_SIZE restored, got ' .. tostring(VIALS:get('VIAL_SIZE')))
check(VIALS:get('VIAL_X_POS') == 271, 'position restored')
check(RUNES:get('RUNE_FILL_FROM') == 'Top', 'select restored')

print('=== 4. two slots are independent ===')
VIALS:set('VIAL_SIZE', 99)
P:set('PRESET_SAVE', 'Save to Slot 2')
check(SLOTS:get('SLOT2').VIAL_SIZE == 99, 'slot 2 captured the new value')
check(SLOTS:get('SLOT1').VIAL_SIZE == 208, 'slot 1 is untouched')
P:set('PRESET', 'Slot 1')
check(VIALS:get('VIAL_SIZE') == 208, 'loading slot 1 does not read slot 2')

print('=== 5. colours survive a round trip ===')
-- util.color is userdata and does not survive being nested in a stored table,
-- so the slot machinery tags it as hex on the way in. This is the check that
-- the tag is read back rather than left as a string.
local util = require('openmw.util')
VIALS:set('HEALTH_COLOR', util.color.hex('3C8BD9'))
P:set('PRESET_SAVE', 'Save to Slot 2')
VIALS:set('HEALTH_COLOR', util.color.hex('FFFFFF'))
P:set('PRESET', 'Slot 2')
local c = VIALS:get('HEALTH_COLOR')
check(type(c) ~= 'string', 'colour came back as a colour, not the stored tag')
check(c and c.asHex and c:asHex():lower() == '3c8bd9',
	'colour round-tripped, got ' .. tostring(c and c.asHex and c:asHex()))

print('=== 6. the built-in presets only touch what they name ===')
-- A preset is meant to be a nudge, not a reset: anything it does not list must
-- be left exactly as the user had it.
GEN:set('SPACING', 27)
VIALS:set('VIAL_SIZE', 150)
P:set('PRESET', 'Colour-blind safe')
check(GEN:get('SPACING') == 27,
	'a preset left an unrelated setting alone, got ' .. tostring(GEN:get('SPACING')))
check(ACCESS:get('SHOW_NUMBERS') == true, 'Colour-blind safe turned the numbers on')
local hc = VIALS:get('HEALTH_COLOR')
check(hc and hc.asHex and hc:asHex():lower() == '3c8bd9',
	'Colour-blind safe moved health off red, got ' .. tostring(hc and hc.asHex and hc:asHex()))
local sc = VIALS:get('STAMINA_COLOR')
check(sc and sc.asHex and sc:asHex():lower() == 'e0821e',
	'Colour-blind safe moved stamina off green')

print('=== 7. Default sweeps everything back ===')
P:set('PRESET', 'Default')
check(VIALS:get('VIAL_SIZE') == 172,
	'VIAL_SIZE back to default, got ' .. tostring(VIALS:get('VIAL_SIZE')))
check(ACCESS:get('SHOW_NUMBERS') == false, 'SHOW_NUMBERS back to default')
local dh = VIALS:get('HEALTH_COLOR')
check(dh and dh.asHex and dh:asHex():lower() == 'b60000',
	'health colour back to the art\'s own red, got ' .. tostring(dh and dh.asHex and dh:asHex()))

print('=== 8. editing a setting drops the selector back to Custom ===')
-- Otherwise the page keeps claiming a preset is active after it has been
-- edited out from under it.
P:set('PRESET', 'Minimal')
check(P:get('PRESET') == 'Minimal', 'preset selected')
VIALS:set('VIAL_SIZE', 123)
check(P:get('PRESET') == 'Custom',
	'a manual edit put the selector back to Custom, got ' .. tostring(P:get('PRESET')))

print('=== 9. the two widgets keep separate positions through a slot ===')
-- They are separate widgets now, so a slot has to carry both pairs of
-- coordinates or loading one flattens them onto each other.
VIALS:set('VIAL_X_POS', 100); VIALS:set('VIAL_Y_POS', 200)
RUNES:set('RUNE_X_POS', 700); RUNES:set('RUNE_Y_POS', 300)
P:set('PRESET_SAVE', 'Save to Slot 1')
VIALS:set('VIAL_X_POS', 1); VIALS:set('VIAL_Y_POS', 2)
RUNES:set('RUNE_X_POS', 3); RUNES:set('RUNE_Y_POS', 4)
P:set('PRESET', 'Slot 1')
check(VIALS:get('VIAL_X_POS') == 100 and VIALS:get('VIAL_Y_POS') == 200,
	'the vials came back to their own spot')
check(RUNES:get('RUNE_X_POS') == 700 and RUNES:get('RUNE_Y_POS') == 300,
	'the runes came back to theirs, not the vials\'')

print('')
print(string.format('%d checks, %d failures', checks, fails))
SCRIPT_FAILURES = fails
