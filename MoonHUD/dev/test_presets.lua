---@omw-context none
package.path = '/mnt/user-data/outputs/MoonHUD/?.lua;' .. package.path
local stubs = { ['openmw.core'] = { weather = { MOON_PHASE = {} } } }
local real = require
_G.require = function(n) if stubs[n] then return stubs[n] end return real(n) end
local C = require('scripts.moonhud.MH_constants')

local fails, checks = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: '..m) end end

-- mirrors resolveAtlasPath / resolveBackgroundPath in MH_hud.lua
local function atlasPath(preset, custom)
	local p = C.presetPath(preset)
	if p == nil then p = custom end
	if p == nil or p == '' then p = C.ATLAS_PATH end
	return p
end
local function bgPath(preset, custom)
	local p = C.presetPath(preset)
	if p == nil and preset == 'Custom' then p = custom end
	if p == nil or p == '' then p = 'black' end
	return p
end

print('=== atlas presets ===')
check(#C.ATLAS_PRESETS == 5, 'five atlas presets')
for _, n in ipairs(C.ATLAS_PRESETS) do
	local p = atlasPath(n, nil)
	print(string.format('  %-14s -> %s', n, p))
	check(p == 'textures/moonhud/' .. n .. '.png', n .. ' resolves')
end
print('  Custom (with path)  -> ' .. atlasPath('Custom', 'textures/mine/sheet.png'))
check(atlasPath('Custom', 'textures/mine/sheet.png') == 'textures/mine/sheet.png', 'custom honoured')
check(atlasPath('Custom', '') == C.ATLAS_PATH, 'empty custom falls back to default')
check(atlasPath(nil, nil) == C.ATLAS_PATH, 'nil preset falls back')

print('=== background presets ===')
check(#C.BACKGROUND_PRESETS == 3, 'three background presets')
for _, n in ipairs(C.BACKGROUND_PRESETS) do
	local p = bgPath(n, nil)
	print(string.format('  %-16s -> %s', n, p))
	check(p == 'textures/moonhud/' .. n .. '.png', n .. ' resolves')
end
check(bgPath('None', nil) == 'black', 'None gives flat black')
check(bgPath('Custom', 'textures/x.png') == 'textures/x.png', 'custom honoured')
check(bgPath('Custom', '') == 'black', 'empty custom falls back to black')

print('')
print(string.format('%d checks, %d failures', checks, fails))
os.exit(fails == 0 and 0 or 1)
