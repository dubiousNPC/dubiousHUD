---@omw-context player
-- Every preset, at every size, drawn where it says it will be.
--
-- Run as API_SCRIPT. Three things are checked, and each of them is something
-- that goes wrong quietly:
--
--   1. Every texture a preset names is on disk. A missing one draws nothing at
--      all, and the compass simply does not appear -- with no error, because an
--      absent texture is not an error to MyGUI.
--
--   2. The needle stays inside the widget at every size. The needle's rect is
--      derived from percentages, so a rounding error at one size and not
--      another is exactly the kind of thing that survives a single spot check.
--
--   3. The widget keeps the backdrop's aspect. A backdrop drawn into the wrong
--      aspect stretches, and a stretched frame is the one thing that makes
--      pixel artwork look broken rather than small.
--
-- The demon frame gets a fourth: its opening was MEASURED off the artwork, so
-- the dial has to land inside it, not merely inside the widget.

local storage = require('openmw.storage')
local checks, fails = 0, 0
local function check(c, m)
	checks = checks + 1
	if not c then fails = fails + 1; print('  FAIL: ' .. m) end
end

local SIZES = { 48, 64, 88, 128, 200, 320, 512, 1024 }

-- Presets and the textures each one needs. Listed here rather than read out of
-- the module on purpose: if the two disagree, one of them is wrong, and this
-- file is where the disagreement shows up.
local PRESETS = {
	BSCompasAtlas = { 'BSCompasAtlas.png' },
	BSCompasAtlas_360 = { 'BSCompasAtlas_360.png' },
	BSCompas_Layered_360 = { 'BSC_Arrow_360.png', 'BSC_Plate.png', 'BSC_Glass.png' },
	BSCompas_Demons = {
		'BSCompasAtlas_360.png', 'PANEL_demons.png', 'PANEL_demons_eyes.png',
	},
	DBS_CompassARROW = {
		'DBS_CompassARROWAtlas.png', 'DBS_CompassCORNER.png',
		'NEWS_N.png', 'NEWS_E.png', 'NEWS_S.png', 'NEWS_W.png',
		'NEWS_Nfade.png', 'NEWS_Efade.png', 'NEWS_S_fade.png', 'NEWS_W_fade.png',
		'DBS_CompassEYES.png', 'DBS_CompassDragonEYES.png',
	},
	DBSpretty = { 'DBSpretty_needle_360.png', 'DBSpretty_compass.png' },
	Redguard_Compass = { 'RG_needle_360.png', 'RG_compass_frame.png' },
}

-- The arch in PANEL_demons, in the artwork's own 149x100 pixels. Read off the
-- alpha, not guessed: the sides close in above y30 and the gargoyles' hands
-- come in at x38 and x135.
local ARCH = { x0 = 38, x1 = 135, y0 = 30, y1 = 100, w = 149, h = 100 }

print('=== 1. every preset names textures that are on disk ===')
for name, files in pairs(PRESETS) do
	for _, f in ipairs(files) do
		local path = 'textures/bscompass/' .. f
		local fh = io.open(path, 'rb')
		check(fh ~= nil, name .. ' needs ' .. f .. ', which is not there')
		if fh then fh:close() end
	end
end

print('=== 2. the needle stays inside the widget at every size ===')
local section = storage.playerSection('SettingsBSCompassCompass')
local general = storage.playerSection('SettingsBSCompassGeneral')

--- Widget rect, needle rect and backdrop for one preset at one size.
---
--- A preset with no backdrop has no stack to put one in: the needle IS the
--- widget and is the compass root's only child. So the widget rect comes from
--- the needle in that case, which is the same thing said two ways.
local function geometryAt(preset, size)
	section:set('ATLAS_PRESET', preset)
	section:set('COMPASS_SIZE', size)
	local img = findNode('compassImage')
	local stack = findNode('compassStack') or img
	return stack, img, findNode('compassBackdrop')
end

for name in pairs(PRESETS) do
	for _, size in ipairs(SIZES) do
		local stack, img, back = geometryAt(name, size)
		if stack == nil or img == nil then
			check(false, name .. ' at ' .. size .. ' did not build')
		else
			local sw, sh = stack.props.size.x, stack.props.size.y
			local ix, iy = img.props.position.x, img.props.position.y
			local iw, ih = img.props.size.x, img.props.size.y
			check(ix >= 0 and iy >= 0 and ix + iw <= sw and iy + ih <= sh,
				string.format('%s at %d: the needle is %dx%d at (%d,%d) in a %dx%d widget',
					name, size, iw, ih, ix, iy, sw, sh))
			check(iw > 0 and ih > 0,
				string.format('%s at %d: the needle has size %dx%d', name, size, iw, ih))
			if back then
				check(back.props.size.x == sw and back.props.size.y == sh,
					string.format('%s at %d: the backdrop is %dx%d in a %dx%d widget',
						name, size, back.props.size.x, back.props.size.y, sw, sh))
			end
		end
	end
end

print('=== 3. the widget keeps the backdrop aspect ===')
-- Width is the size setting; height follows from the artwork's own aspect.
local ASPECT = {
	BSCompas_Demons = 149 / 100,
	DBSpretty = 1,
	Redguard_Compass = 1,
	BSCompas_Layered_360 = 1,
	DBS_CompassARROW = 1785 / 1610,
}
for name, aspect in pairs(ASPECT) do
	for _, size in ipairs { 64, 320, 1024 } do
		local stack = geometryAt(name, size)
		local sw, sh = stack.props.size.x, stack.props.size.y
		check(sw == size, string.format('%s at %d is %d wide', name, size, sw))
		check(math.abs(sh - size / aspect) <= 1, string.format(
			'%s at %d is %d tall, the artwork wants %.1f', name, size, sh, size / aspect))
	end
end

print('=== 4. the demon frame holds the dial inside its arch ===')
for _, size in ipairs(SIZES) do
	local stack, img = geometryAt('BSCompas_Demons', size)
	local sw, sh = stack.props.size.x, stack.props.size.y
	-- back into the artwork's own pixels, where the arch was measured
	local kx, ky = ARCH.w / sw, ARCH.h / sh
	local x0 = img.props.position.x * kx
	local y0 = img.props.position.y * ky
	local x1 = (img.props.position.x + img.props.size.x) * kx
	local y1 = (img.props.position.y + img.props.size.y) * ky
	-- no slack: the preset is sized to leave margin, so a figure outside the
	-- arch means the preset is wrong rather than the arithmetic being tight
	check(x0 >= ARCH.x0 and x1 <= ARCH.x1, string.format(
		'at %d the dial spans x%.1f..%.1f, the arch is x%d..%d',
		size, x0, x1, ARCH.x0, ARCH.x1))
	check(y0 >= ARCH.y0 and y1 <= ARCH.y1, string.format(
		'at %d the dial spans y%.1f..%.1f, the arch is y%d..%d',
		size, y0, y1, ARCH.y0, ARCH.y1))
end

print('=== 5. the old preset name still resolves ===')
-- A preset name is stored in the save. Renaming one without an alias drops
-- anyone who had it selected back to the default, with nothing to tell them
-- why, so the alias is worth a test of its own.
do
	local new = geometryAt('Redguard_Compass', 320)
	local old = geometryAt('RG_Compass', 320)
	check(old ~= nil, 'the old name builds something')
	check(old.props.size.x == new.props.size.x
		and old.props.size.y == new.props.size.y,
		'and builds the same compass as the new name')
	local img = findNode('compassImage')
	check(img ~= nil and img.props.resource ~= nil
		and tostring(img.props.resource._texture):find('RG_needle_360') ~= nil,
		'from the same sheet')
end

print('=== 6. the eyes overlay covers the whole frame ===')
do
	geometryAt('BSCompas_Demons', 320)
	local stack = findNode('compassStack')
	local eyes = findNode('overlayeyes')
	check(eyes ~= nil, 'the demon frame has an eyes overlay')
	if eyes then
		check(eyes.props.size.x == stack.props.size.x
			and eyes.props.size.y == stack.props.size.y,
			'and it is drawn over the whole frame, so the glows land on the heads')
		check(eyes.props.visible == false, 'but it is off until something lights it')
	end
end

section:set('ATLAS_PRESET', 'BSCompasAtlas')
section:set('COMPASS_SIZE', 88)

print('')
print(string.format('%d checks, %d failures', checks, fails))
SCRIPT_FAILURES = fails
