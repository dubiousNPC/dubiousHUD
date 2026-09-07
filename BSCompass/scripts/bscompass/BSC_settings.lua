---@omw-context player
-- BSC_settings.lua
--
-- Settings for BSCompass. Group layout and key naming follow TimeHUD and
-- LocationHUD so the page sits consistently alongside them.
--
-- Each setting is mirrored into a global of the same name (COMPASS_SIZE,
-- HUD_X_POS, ...) which the main script reads directly. Reading a global in
-- onFrame is a lot cheaper than a storage lookup, which matters here because
-- this HUD samples every frame.

local core    = require('openmw.core')
local ui      = require('openmw.ui')
local util    = require('openmw.util')
local storage = require('openmw.storage')
local async   = require('openmw.async')
local I       = require('openmw.interfaces')

local v2 = util.vector2

MODNAME = MODNAME or 'BSCompass'

--------------------------------------------------------------------------------
-- Renderer selection
--------------------------------------------------------------------------------
-- SuperSettingsRenderers is bundled with this mod, under
-- scripts/SuperSettingsRenderers, and registered by the MENU entries in the
-- .omwscripts file. It is therefore always present and this can stay on.
--
-- Set it to false only if you have stripped the bundled copy out. Naming a
-- renderer that is not registered makes I.Settings.registerGroup fail, which
-- kills the whole script: no settings page and no widget.
local SUPER = true

local R_SLIDER = SUPER and 'SuperSlider6'      or 'number'
local R_SELECT = SUPER and 'SuperSelect3'      or 'select'
local R_COLOR  = SUPER and 'SuperColorPicker4' or 'textLine'

local function sliderArg(min, max, step, unit)
	if SUPER then
		return { min = min, max = max, step = step or 1, unit = unit or '',
		         showResetButton = true, tinyReset = true, width = 200 }
	end
	return { min = min, max = max }
end

local function selectArg(items)
	if SUPER then return { items = items, l10n = 'none', width = 170 } end
	return { disabled = false, l10n = 'none', items = items }
end

local function colorDefault(hex)
	if SUPER then return util.color.hex(hex) end
	return hex
end

--------------------------------------------------------------------------------

local layerId      = ui.layers.indexOf('HUD')
local hudLayerSize = ui.layers[layerId].size

local presetColors = { 'FFFFFF', 'caa560', 'dfc99f', 'eee2c9', 'd4b77f', '81cded', 'c8a2c8' }

local orderCounter = 0
local function getOrder() orderCounter = orderCounter + 1 return orderCounter end

local settingsTemplate = {}
local key

--------------------------------------------------------------------------------
key = 'General'
settingsTemplate[key] = {
	key = 'Settings' .. MODNAME .. key,
	page = MODNAME,
	l10n = 'none',
	name = 'General',
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'HUD_DISPLAY',
			name = 'HUD Display',
			description = 'When to show the compass.',
			renderer = R_SELECT,
			default = 'Always',
			argument = selectArg { 'Always', 'Interface Only', 'Hide on Interface', 'Hide on Dialogue Only', 'Never' },
		},
		{
			key = 'HUD_LOCK',
			name = 'Lock Position',
			description = 'Stops click-and-drag repositioning.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'HUD_X_POS',
			name = 'X Position',
			description = '',
			renderer = R_SLIDER,
			integer = true,
			default = math.floor(hudLayerSize.x - 120),
			argument = sliderArg(-200, math.floor(hudLayerSize.x) + 200, 1, 'px'),
		},
		{
			key = 'HUD_Y_POS',
			name = 'Y Position',
			description = '',
			renderer = R_SLIDER,
			integer = true,
			default = 40,
			argument = sliderArg(-50, math.floor(hudLayerSize.y), 1, 'px'),
		},
		{
			key = 'HUD_EXTERIOR',
			name = 'Only display outdoors',
			description = 'A compass is not much use in a tomb. Leaving this on also means\nzero per-frame work while you are inside.',
			renderer = 'checkbox',
			default = true,
		},
	},
}

--------------------------------------------------------------------------------
key = 'Compass'
settingsTemplate[key] = {
	key = 'Settings' .. MODNAME .. key,
	page = MODNAME,
	l10n = 'none',
	name = 'Compass',
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'COMPASS_SIZE',
			name = 'Size',
			description = 'Pixels. The atlas tile is 88, so 88 is 1:1 and anything larger will soften.',
			renderer = R_SLIDER,
			integer = true,
			default = 88,
			argument = sliderArg(24, 320, 1, 'px'),
		},
		{
			key = 'COMPASS_ALPHA',
			name = 'Opacity',
			description = '',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0, 1, 0.05),
		},
		{
			key = 'COMPASS_TINT',
			name = 'Tint',
			description = 'Multiplied over the artwork. White leaves it untouched.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'FACING_SOURCE',
			name = 'Facing Source',
			description = 'Camera follows where you are looking, including in third person and vanity mode.\nBody follows the character, ignoring the camera.',
			renderer = R_SELECT,
			default = 'Camera',
			argument = selectArg { 'Camera', 'Body' },
		},
		{
			key = 'INVERT_ROTATION',
			name = 'Invert Rotation',
			description = 'Flip if the needle turns the wrong way. Sanity check: face north, then\nturn right. A world-fixed needle should swing LEFT.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'HEADING_OFFSET',
			name = 'Heading Offset',
			description = 'Rotates the artwork. Use if your atlas does not start at north.',
			renderer = R_SLIDER,
			default = 0,
			argument = sliderArg(-180, 180, 1, ' deg'),
		},
		{
			key = 'SAMPLE_EVERY',
			name = 'Sample Every N Frames',
			description = 'How often to check your heading. 1 is every frame.\n2 or 3 is imperceptible while turning and does proportionally less work.\nThis only gates the check; the texture still swaps only when the tile changes.',
			renderer = R_SLIDER,
			integer = true,
			default = 2,
			argument = sliderArg(1, 10, 1, ' frames'),
		},
		{
			key = 'ATLAS_PRESET',
			name = 'Compass Artwork',
			description = 'Which bundled sheet to use. Each preset carries its own\n'
				.. 'frame count, column count and cell size, so they cannot be mismatched.\n\n'
				.. 'BSCompasAtlas       36 steps, 10 degrees apart, vertical strip\n'
				.. 'BSCompasAtlas_360   360 steps, 1 degree apart, 30-column grid\n'
				.. 'DBS_CompassARROW    360 steps, arrow over the DBS corner frame\n'
				.. 'Custom              use the manual settings below',
			renderer = R_SELECT,
			default = 'BSCompasAtlas',
			argument = selectArg { 'BSCompasAtlas', 'BSCompasAtlas_360',
			                       'DBS_CompassARROW', 'Custom' },
		},
		{
			key = 'ATLAS_PATH',
			name = 'Atlas Path (Custom)',
			description = 'Only used when Compass Artwork is Custom.\n'
				.. 'Frames are read row-major: index = row * columns + column,\n'
				.. 'starting at north.',
			renderer = 'textLine',
			default = 'textures/bscompass/BSCompasAtlas.png',
		},
		{
			key = 'ATLAS_COLUMNS',
			name = 'Atlas Columns (Custom)',
			description = 'Columns in your sheet. 1 is a vertical strip.\n'
				.. 'Above roughly 180 frames a strip exceeds the maximum texture size,\n'
				.. 'so a grid is required: 360 frames at 88px is 31680px tall as a strip.',
			renderer = R_SLIDER,
			integer = true,
			default = 1,
			argument = sliderArg(1, 60, 1),
		},
		{
			key = 'ATLAS_TILES',
			name = 'Atlas Frame Count (Custom)',
			description = 'Frames in the strip. 36 gives one frame per 10 degrees.',
			renderer = R_SLIDER,
			integer = true,
			default = 36,
			argument = sliderArg(4, 360, 1),
		},
		{
			key = 'ATLAS_CELL',
			name = 'Atlas Tile Size (Custom)',
			description = 'Width and height of one frame, in pixels.',
			renderer = R_SLIDER,
			integer = true,
			default = 88,
			argument = sliderArg(8, 512, 1, 'px'),
		},
	},
}

--------------------------------------------------------------------------------
key = 'Overlay'
settingsTemplate[key] = {
	key = 'Settings' .. MODNAME .. key,
	page = MODNAME,
	l10n = 'none',
	name = 'Overlay',
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'BACKDROP_TEXTURE',
			name = 'Backdrop Texture (Custom)',
			description = 'Bottom layer: the frame or housing. Fills the widget.\n'
				.. 'Leave empty for none. The DBS preset sets this for you.',
			renderer = 'textLine',
			default = '',
		},
		{
			key = 'FACE_TEXTURE',
			name = 'Face Texture (Custom)',
			description = 'Middle layer: static dial art, drawn over the backdrop and\n'
				.. 'under the rotating arrow. Leave empty for none.',
			renderer = 'textLine',
			default = '',
		},
		{
			key = 'FACE_ANCHOR_X',
			name = 'Face Pivot X (Custom)',
			description = 'Face centre across the backdrop, as a percentage of its width.',
			renderer = R_SLIDER,
			default = 50,
			argument = sliderArg(0, 100, 0.1, '%'),
		},
		{
			key = 'FACE_ANCHOR_Y',
			name = 'Face Pivot Y (Custom)',
			description = 'As above, down the backdrop height.',
			renderer = R_SLIDER,
			default = 50,
			argument = sliderArg(0, 100, 0.1, '%'),
		},
		{
			key = 'FACE_SCALE',
			name = 'Face Scale (Custom)',
			description = 'Face size as a percentage of the backdrop width.',
			renderer = R_SLIDER,
			default = 60,
			argument = sliderArg(1, 100, 0.1, '%'),
		},
		{
			key = 'FACE_TINT',
			name = 'Face Tint',
			description = 'Multiplied over the face art. White leaves it untouched.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'FACE_ALPHA',
			name = 'Face Opacity',
			description = '',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0, 1, 0.05),
		},
		{
			key = 'OVERLAY_LAYER',
			name = 'Backdrop Layer',
			description = 'Behind: backdrop, then face, then arrow. The usual order.\n'
				.. 'In front: the backdrop is drawn last, for housings with a glass\n'
				.. 'or bezel that should occlude the needle.',
			renderer = R_SELECT,
			default = 'Behind',
			argument = selectArg { 'Behind', 'In front' },
		},
		{
			key = 'OVERLAY_ANCHOR_X',
			name = 'Pivot X (Custom)',
			description = 'Where the rotating frame sits on the overlay, as a percentage\n'
				.. 'of its width. 50 is centred.',
			renderer = R_SLIDER,
			default = 50,
			argument = sliderArg(0, 100, 0.1, '%'),
		},
		{
			key = 'OVERLAY_ANCHOR_Y',
			name = 'Pivot Y (Custom)',
			description = 'As above, down the overlay height.',
			renderer = R_SLIDER,
			default = 50,
			argument = sliderArg(0, 100, 0.1, '%'),
		},
		{
			key = 'OVERLAY_SCALE',
			name = 'Frame Scale (Custom)',
			description = 'Size of the rotating frame as a percentage of the overlay width.',
			renderer = R_SLIDER,
			default = 20,
			argument = sliderArg(1, 100, 0.1, '%'),
		},
		{
			key = 'OVERLAY_TINT',
			name = 'Backdrop Tint',
			description = 'Multiplied over the backdrop. White leaves it untouched.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'OVERLAY_ALPHA',
			name = 'Backdrop Opacity',
			description = '',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0, 1, 0.05),
		},
	},
}

--------------------------------------------------------------------------------
key = 'Cardinals'
settingsTemplate[key] = {
	key = 'Settings' .. MODNAME .. key,
	page = MODNAME,
	l10n = 'none',
	name = 'Cardinals',
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'CARDINAL_OVERLAY',
			name = 'Cardinal Glyphs',
			description = 'Lights the N/E/S/W glyph on the dial as you come round to\n'
				.. 'face it. Needs artwork that provides them; the DBS preset does.\n\n'
				.. 'Off           never shown\n'
				.. 'Sharp         only inside the sharp arc, no approach\n'
				.. 'Sharp + Fade  fades in across the wider arc first',
			renderer = R_SELECT,
			default = 'Sharp + Fade',
			argument = selectArg { 'Off', 'Sharp', 'Sharp + Fade' },
		},
		{
			key = 'CARDINAL_ARC',
			name = 'Sharp Arc',
			description = 'Degrees either side of a cardinal within which the solid\n'
				.. 'glyph is drawn. 15 lights it for a 30 degree window.',
			renderer = R_SLIDER,
			default = 15,
			argument = sliderArg(1, 45, 1, ' deg'),
		},
		{
			key = 'CARDINAL_FADE_ARC',
			name = 'Fade Arc',
			description = 'Degrees either side within which the fade glyph is drawn,\n'
				.. 'ramping off with distance. Must be at least the sharp arc.',
			renderer = R_SLIDER,
			default = 45,
			argument = sliderArg(1, 90, 1, ' deg'),
		},
		{
			key = 'CARDINAL_ALPHA',
			name = 'Glyph Opacity',
			description = 'Ceiling on the glyph opacity.',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0, 1, 0.05),
		},
		{
			key = 'CARDINAL_TINT',
			name = 'Glyph Tint',
			description = 'Multiplied over the glyph art. White leaves it untouched.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
	},
}

--------------------------------------------------------------------------------
key = 'Frame'
settingsTemplate[key] = {
	key = 'Settings' .. MODNAME .. key,
	page = MODNAME,
	l10n = 'none',
	name = 'Frame',
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'HUD_BACKGROUND',
			name = 'Background',
			description = 'Draw a panel behind the compass. Off by default: the artwork already\nhas its own bezel.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'BACKGROUND_ALPHA',
			name = 'Background Opacity',
			description = '',
			renderer = R_SLIDER,
			default = 0.5,
			argument = sliderArg(0, 1, 0.05),
		},
		{
			key = 'HUD_BORDER',
			name = 'Border',
			description = 'Same border styles as TimeHUD, LocationHUD and Quickloot.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'HUD_BORDER_STYLE',
			name = 'Border Style',
			description = '',
			renderer = R_SELECT,
			default = 'thin',
			argument = selectArg { 'thin', 'normal', 'thick', 'verythick' },
		},
		{
			key = 'HUD_BORDER_COLOR',
			name = 'Border Color',
			description = '',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'HUD_PADDING',
			name = 'Padding',
			description = 'Inner spacing in pixels, both axes.',
			renderer = R_SLIDER,
			integer = true,
			default = 4,
			argument = sliderArg(0, 50, 1, 'px'),
		},
	},
}

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

for _, template in pairs(settingsTemplate) do
	I.Settings.registerGroup(template)
end

I.Settings.registerPage {
	key = MODNAME,
	l10n = 'none',
	name = 'BSCompass',
	description = 'A dial compass driven by a vertical texture atlas.\n'
		.. '- Click and drag to move it.\n'
		.. '- Click and mousewheel to resize.\n'
		.. '- Every frame of the atlas is built once at load, and the texture is only\n'
		.. '  swapped when the heading crosses into a new frame.',
}

--------------------------------------------------------------------------------
-- Mirror into globals
--------------------------------------------------------------------------------

local COLOR_KEYS = { COMPASS_TINT = true, HUD_BORDER_COLOR = true,
                     OVERLAY_TINT = true, FACE_TINT = true,
                     CARDINAL_TINT = true }
local function normalise(k, v)
	if COLOR_KEYS[k] and type(v) == 'string' then
		-- Validated by pattern rather than caught with pcall. util.color.hex
		-- raises on anything that is not six hex digits, and this is genuinely
		-- untrusted -- it is whatever was typed into a text field. But a pcall
		-- here would also swallow a real fault in util.color, so the input is
		-- checked directly and the call is left to raise if it ever should.
		local hex = v:gsub('^#', '')
		if hex:match('^%x%x%x%x%x%x$') then
			return util.color.hex(hex)
		end
		-- Three-digit shorthand, since the settings text says "hex, no #".
		local short = hex:match('^(%x%x%x)$')
		if short then
			return util.color.hex(short:gsub('(%x)', '%1%1'))
		end
		return util.color.rgb(1, 1, 1)
	end
	return v
end

local function readAllSettings()
	for _, template in pairs(settingsTemplate) do
		local section = storage.playerSection(template.key)
		for _, entry in pairs(template.settings) do
			local val = section:get(entry.key)
			if val == nil then val = entry.default end
			_G[entry.key] = normalise(entry.key, val)
		end
	end
end

readAllSettings()

-- Anything that changes the widget tree, or the atlas itself, needs a rebuild.
-- Everything else can be poked straight into the live element.
local REBUILD = {
	HUD_BORDER = true, HUD_BORDER_STYLE = true, HUD_BORDER_COLOR = true,
	HUD_PADDING = true, HUD_BACKGROUND = true, HUD_LOCK = true,
}
local RETILE = {
	ATLAS_PRESET = true, ATLAS_PATH = true, ATLAS_TILES = true,
	ATLAS_CELL = true, ATLAS_COLUMNS = true,
	BACKDROP_TEXTURE = true, FACE_TEXTURE = true,
	OVERLAY_LAYER = true, OVERLAY_ANCHOR_X = true,
	OVERLAY_ANCHOR_Y = true, OVERLAY_SCALE = true,
	FACE_ANCHOR_X = true, FACE_ANCHOR_Y = true, FACE_SCALE = true,
	COMPASS_SIZE = true,
	CARDINAL_OVERLAY = true,
}

for _, template in pairs(settingsTemplate) do
	local section = storage.playerSection(template.key)
	section:subscribe(async:callback(function(_, setting)
		if setting == nil then
			readAllSettings()
		else
			_G[setting] = normalise(setting, section:get(setting))
		end

		if setting == nil or RETILE[setting] then
			if rebuildTiles then rebuildTiles() end
			if createCompassHud then createCompassHud() end
			return
		end
		if REBUILD[setting] then
			if createCompassHud then createCompassHud() end
			return
		end
		if applyCompassStyle then applyCompassStyle() end
	end))
end

return settingsTemplate
