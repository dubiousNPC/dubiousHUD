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
		'BSCompasAtlas_360.png', 'PANEL_demons.png',
		'PANEL_demons_eyes.png', 'PANEL_demons_orb.png',
	},
	BSCompas_Demons_Wide = {
		'BSCompasAtlas_360.png', 'PANEL_demons_WIDE_R.png',
		'PANEL_demons_wide_eyes.png', 'PANEL_demons_wide_orb.png',
	},
	Redguard_Classic = { 'RG_ring_360.png', 'RG_compass_needle.png' },
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
-- Where the author's own examples put the dial, in each frame's own pixels.
-- PANEL_demons_EXAMPLE101 and PANEL_demons_WIDE_EXAMPLE1/2 are shipped beside
-- the frames, so these figures can be checked by looking rather than measured
-- again.
-- Where the author's own examples put the dial, as a CENTRE and a SIZE in the
-- frame's own pixels. PANEL_demons_EXAMPLE101 and PANEL_demons_WIDE_EXAMPLE1/2
-- are shipped beside the frames, so these can be checked by looking.
--
-- Centre and size rather than four edges, because that is what the preset
-- actually controls -- two anchors and a scale. Comparing edges invites an
-- off-by-one over whether 172 is the last pixel or the right edge, and makes a
-- one-pixel difference look like a placement error.
--
-- The examples' dials are 126 wide and 127 tall at every alpha threshold. The
-- preset's rect is square, so it takes the width: one pixel in 127, against a
-- dial the author drew a pixel out of square.
local PLACED = {
	BSCompas_Demons = { cx = 110, cy = 63.5, size = 126, w = 191, h = 128 },
	BSCompas_Demons_Wide = { cx = 190, cy = 63.5, size = 126, w = 300, h = 128 },
}

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
	BSCompas_Demons = 191 / 128,
	BSCompas_Demons_Wide = 300 / 128,
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

print('=== 4. the demon frames put the dial where the examples put it ===')
for name, want in pairs(PLACED) do
	for _, size in ipairs(SIZES) do
		local stack, img = geometryAt(name, size)
		local sw, sh = stack.props.size.x, stack.props.size.y
		-- back into the artwork's own pixels, where the example was read
		local kx, ky = want.w / sw, want.h / sh
		local cx = (img.props.position.x + img.props.size.x / 2) * kx
		local cy = (img.props.position.y + img.props.size.y / 2) * ky
		local dw = img.props.size.x * kx
		-- Slack in WIDGET pixels, converted back. At 48 across, one widget
		-- pixel is four of the artwork's, so a flat figure in art pixels asks
		-- for sub-pixel placement at the small end and lets the dial wander
		-- at the large one.
		local slack = 1.5 * math.max(kx, ky)
		check(math.abs(cx - want.cx) <= slack, string.format(
			'%s at %d: dial centred at x%.1f, the example has %.1f (slack %.1f)',
			name, size, cx, want.cx, slack))
		check(math.abs(cy - want.cy) <= slack, string.format(
			'%s at %d: dial centred at y%.1f, the example has %.1f (slack %.1f)',
			name, size, cy, want.cy, slack))
		check(math.abs(dw - want.size) <= slack, string.format(
			'%s at %d: dial is %.1f across, the example has %d (slack %.1f)',
			name, size, dw, want.size, slack))
	end
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

print('=== the dial lands where the example puts it ===')
-- The examples ARE the specification: they are the author's own placement, and
-- they say where the dial was MEANT to go rather than where it would fit. So
-- the check is equality against the example's own pixels, at the artwork's own
-- size, not "somewhere inside the opening".
for _, ex in ipairs {
	{ preset = 'BSCompas_Demons', size = 191,
	  file = 'textures/bscompass/PANEL_demons_EXAMPLE101.png', x = 47, w = 126 },
	{ preset = 'BSCompas_Demons_Wide', size = 300,
	  file = 'textures/bscompass/PANEL_demons_WIDE_EXAMPLE2.png', x = 127, w = 126 },
} do
	local _, img = geometryAt(ex.preset, ex.size)
	check(img.props.position.x == ex.x, string.format(
		'%s at %d: the dial starts at x%d, the example has it at x%d',
		ex.preset, ex.size, img.props.position.x, ex.x))
	check(img.props.size.x == ex.w, string.format(
		'%s at %d: the dial is %d wide, the example has it %d',
		ex.preset, ex.size, img.props.size.x, ex.w))
	local f = io.open(ex.file, 'rb')
	check(f ~= nil, ex.file .. ' is shipped, so the placement can be re-derived')
	if f then f:close() end
end

print('=== the demon frame draws over the dial, under its own eyes ===')
-- The frame is the backdrop because that is what gives the widget its aspect
-- and the dial its rect. It is drawn LAST because the gargoyles grip the rim
-- of the opening, and hands behind the thing they are holding look wrong.
for _, name in ipairs { 'BSCompas_Demons', 'BSCompas_Demons_Wide' } do
	geometryAt(name, 320)
	local stack = findNode('compassStack')
	local pos = {}
	for i, ch in ipairs(stack.content._items) do pos[ch.name] = i end
	check(pos.compassImage ~= nil and pos.compassBackdrop ~= nil,
		name .. ' draws both a dial and a frame')
	check(pos.compassImage < pos.compassBackdrop,
		name .. ': the frame is drawn over the dial')
	check(pos.overlayeyes > pos.compassBackdrop,
		name .. ': the eyes are drawn over the frame, which is where the heads are')
	check(pos.overlayorb == nil or pos.overlayorb > pos.compassBackdrop,
		name .. ': and so is the orb')
end
-- and that this is the exception, not the new rule
do
	geometryAt('DBS_CompassARROW', 320)
	local stack = findNode('compassStack')
	local pos = {}
	for i, ch in ipairs(stack.content._items) do pos[ch.name] = i end
	check(pos.compassBackdrop < pos.compassImage,
		'a preset without frameOnTop still draws its backdrop behind the needle')
end

print('=== the compass sits on a layer below every other HUD ===')
-- Inside one layer, what draws on top is whatever was created last, which comes
-- down to script load order. A layer of its own is the only way to say "below
-- the vials" and mean it.
do
	local ui = require('openmw.ui')
	local general = storage.playerSection('SettingsBSCompassGeneral')
	general:set('HUD_UNDERLAY', true)
	general:set('HUD_LOCK', true)
	local root = findNode('compassHud')
	check(root.layer ~= 'Scene', 'locked, the compass is not on the stock Scene layer')
	check(ui.layers.indexOf(root.layer) ~= nil, 'and the layer it is on exists')
	check(ui.layers.indexOf(root.layer) < ui.layers.indexOf('Scene'),
		'and sits below it, so anything on Scene draws over the compass')

	general:set('HUD_LOCK', false)
	root = findNode('compassHud')
	check(ui.layers.indexOf(root.layer) < ui.layers.indexOf('Modal'),
		'unlocked, the same holds against Modal')

	-- inserting the same layer twice is not a thing to find out about in
	-- someone else's save
	local before = #ui.layers._names
	for _ = 1, 5 do
		general:set('HUD_LOCK', true)
		general:set('HUD_LOCK', false)
	end
	check(#ui.layers._names == before,
		'rebuilding does not insert the layer again (' .. #ui.layers._names
			.. ' layers vs ' .. before .. ')')

	general:set('HUD_UNDERLAY', false)
	root = findNode('compassHud')
	check(root.layer == 'Modal', 'switched off, it goes back to the stock layer')
	general:set('HUD_UNDERLAY', true)
	general:set('HUD_LOCK', false)
end

print('')
print(string.format('%d checks, %d failures', checks, fails))
SCRIPT_FAILURES = fails
