---@omw-context player
-- DBV_settings.lua
--

local core    = require('openmw.core')
local ui      = require('openmw.ui')
local util    = require('openmw.util')
local storage = require('openmw.storage')
local async   = require('openmw.async')
local I       = require('openmw.interfaces')

local v2 = util.vector2

MODNAME = MODNAME or 'DBSVials'

--------------------------------------------------------------------------------
-- Renderer selection
--------------------------------------------------------------------------------
local RENDERER_SELECT = 'SuperSelect3'
local RENDERER_NUMBER = 'SuperSlider6'
local RENDERER_COLOR  = 'SuperColorPicker4'

local R_SLIDER = RENDERER_NUMBER
local R_SELECT = RENDERER_SELECT
local R_COLOR  = RENDERER_COLOR

local function sliderArg(min, max, step, unit, def, extra)
	local a = {
		min = min,
		max = max,
		step = step or 1,
		default = def,
		unit = unit or '',
		labelSize = 13,
		width = 120,
		thickness = 15,
		showDefaultMark = def ~= nil,
		showResetButton = false,
		bottomRow = true,
	}
	for k, v in pairs(extra or {}) do a[k] = v end
	return a
end

local function selectArg(items, extra)
	local a = { disabled = false, l10n = 'none', items = items, width = 170 }
	for k, v in pairs(extra or {}) do a[k] = v end
	return a
end

local COLOR_RENDERER = R_COLOR
local function colorDefault(hex)
	return (COLOR_RENDERER == 'textLine') and hex or util.color.hex(hex)
end

local layerId      = ui.layers.indexOf('HUD')
local hudLayerSize = ui.layers[layerId].size

local presetColors = { 'FFFFFF', 'C41C1C', '2EA83A', '4840F0', 'E0821E', '3C8BD9', 'caa560' }

local orderCounter = 0
local function getOrder() orderCounter = orderCounter + 1 return orderCounter end

local settingsTemplate = {}

--------------------------------------------------------------------------------
-- Built-in presets
--------------------------------------------------------------------------------




--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

settingsTemplate.GENERAL = {
	key = 'Settings' .. MODNAME .. 'General',
	l10n = 'none',
	name = 'General',
	description = 'Settings shared by both widgets. The vials and the runes are two\n'
		.. 'separate widgets with their own positions -- drag either one on its\n'
		.. 'own, or put them in opposite corners.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'HUD_LOCK',
			name = 'Lock Position',
			description = 'Locked puts the meters on the Scene layer, where they cannot be\n'
				.. 'dragged and never sit above a menu. Unlocked to move them.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'HUD_DISPLAY',
			name = 'When to Show',
			description = 'Always, only while an interface is open, or hidden while one is.',
			renderer = R_SELECT,
			default = 'Always',
			argument = selectArg { 'Always', 'Interface Only', 'Hide on Interface' },
		},
		{
			key = 'HUD_OPACITY',
			name = 'Opacity',
			description = 'Applies to the whole widget.',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0.1, 1, 0.05, '', 1.0),
		},
		{
			key = 'LAYOUT',
			name = 'Vial Arrangement',
			description = 'How the two vials sit next to each other. The runes are a\n'
				.. 'separate widget and are not affected.',
			renderer = R_SELECT,
			default = 'Horizontal',
			argument = selectArg { 'Horizontal', 'Vertical' },
		},
		{
			key = 'SPACING',
			name = 'Vial Spacing',
			description = 'Gap between the two vials.',
			renderer = R_SLIDER,
			default = 10,
			argument = sliderArg(0, 64, 1, 'px', 10),
		},
		{
			key = 'SHOW_HEALTH',
			name = 'Show Health Vial',
			description = '',
			renderer = 'checkbox',
			default = true,
		},
		{
			key = 'SHOW_STAMINA',
			name = 'Show Stamina Vial',
			description = 'Fatigue, in the engine\'s own terms.',
			renderer = 'checkbox',
			default = true,
		},
		{
			key = 'SHOW_RUNES',
			name = 'Show Magicka Runes',
			description = '',
			renderer = 'checkbox',
			default = true,
		},
	},
}

--------------------------------------------------------------------------------
-- Vials
--------------------------------------------------------------------------------

settingsTemplate.VIALS = {
	key = 'Settings' .. MODNAME .. 'Vials',
	l10n = 'none',
	name = 'Vials',
	description = 'The health and stamina tubes. Each is a block of colour that fills\n'
		.. 'from the bottom, with the glass drawn over the top of it.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'VIAL_X_POS',
			name = 'Horizontal Position',
			description = 'Pixels from the left. Click and drag a vial to move the pair.',
			renderer = R_SLIDER,
			default = 40,
			argument = sliderArg(-200, math.floor(hudLayerSize.x) + 200, 1, 'px', 40),
		},
		{
			key = 'VIAL_Y_POS',
			name = 'Vertical Position',
			description = 'Pixels from the top.',
			renderer = R_SLIDER,
			default = math.max(40, math.floor(hudLayerSize.y) - 260),
			argument = sliderArg(-50, math.floor(hudLayerSize.y), 1, 'px',
				math.max(40, math.floor(hudLayerSize.y) - 260)),
		},
		{
			key = 'VIAL_SIZE',
			name = 'Vial Size',
			description = 'Overall height of the whole assembly -- collar, tube, clasp and\n'
				.. 'bulb together. Width follows, so the fittings keep the\n'
				.. 'proportions they were drawn with. 190 is the art at 1:1.',
			renderer = R_SLIDER,
			default = 190,
			argument = sliderArg(24, 600, 1, 'px', 190),
		},
		{
			key = 'HEALTH_COLOR',
			name = 'Health Colour',
			description = 'Hex, no #. The liquid in the tube. The default is the colour of\n'
				.. 'the supplied red tube exactly.',
			renderer = R_COLOR,
			default = colorDefault('B60000'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'STAMINA_COLOR',
			name = 'Stamina Colour',
			description = 'Hex, no #. The default is the colour of the supplied green tube\n'
				.. 'exactly.',
			renderer = R_COLOR,
			default = colorDefault('349F00'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'GLASS_TEXTURE',
			name = 'Glass Texture',
			description = 'The overlay drawn in front of the fill. Blank for none --\n'
				.. 'the vial then reads as a plain bar.',
			renderer = 'textLine',
			default = 'textures/dbsvials/glass_tube.png',
		},
		{
			key = 'GLASS_TINT',
			name = 'Glass Tint',
			description = 'Multiplied over the glass. White leaves it untouched.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'BULB_TEXTURE',
			name = 'Bulb Backing',
			description = 'An extra glass reservoir drawn UNDER the liquid.\n'
				.. 'Off by default: the transparent clasp already carries the\n'
				.. 'bulb\'s glass, and a second copy behind the liquid thickens\n'
				.. 'the silhouette. VIAL_BOTT_EMPTY is the bulb as it looks empty,\n'
				.. 'with its dreg; VIAL_CLEAR_GLASS is the plain glass.',
			renderer = R_SELECT,
			default = '',
			argument = selectArg {
				'',
				'textures/dbsvials/VIAL_BOTT_EMPTY.png',
				'textures/dbsvials/VIAL_CLEAR_GLASS.png',
			},
		},
		{
			key = 'CLEAR_CLASP_TEXTURE',
			name = 'Clear Clasp',
			description = 'The fitted transparent clasp, drawn OVER the liquid.\n'
				.. 'Built from VIAL_CLEAR_GLASS + VIAL_CLASP_FRAME, which is what\n'
				.. 'gives the clasp a glass front the liquid shows through rather\n'
				.. 'than a solid one it hides behind. Blank for none.',
			renderer = 'textLine',
			default = 'textures/dbsvials/VIAL_CLEAR_CLASP.png',
		},
		{
			key = 'BULB_TINT',
			name = 'Bulb Tint',
			description = 'Multiplied over the bulb glass. White leaves it untouched.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'BULB_ALPHA',
			name = 'Bulb Opacity',
			description = '',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0, 1, 0.05, '', 1.0),
		},
		{
			key = 'SHOW_RESIDUE',
			name = 'Dreg',
			description = 'A settled residue in the bottom of the bulb, tinted with the\n'
				.. 'vial\'s own colour. Off by default: the liquid now runs into\n'
				.. 'the bulb itself, so a nearly-empty vial already shows a little\n'
				.. 'of its own colour pooled there and the dreg doubles it.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'RESIDUE_ALPHA',
			name = 'Dreg Opacity',
			description = '',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0, 1, 0.05, '', 1.0),
		},
		{
			key = 'SHOW_CLASP',
			name = 'Clasp',
			description = 'The diamond bracket where the tube meets the bulb. It is what\n'
				.. 'hides the join, so turning it off leaves the tube\'s end visible.',
			renderer = 'checkbox',
			default = true,
		},
		{
			key = 'SHOW_CAP',
			name = 'Collar',
			description = 'The pronged collar that caps the tube.',
			renderer = 'checkbox',
			default = true,
		},
		{
			key = 'FITTING_TINT',
			name = 'Fittings Tint',
			description = 'Multiplied over the clasp and the collar together.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
	},
}

--------------------------------------------------------------------------------
-- Runes
--------------------------------------------------------------------------------

settingsTemplate.RUNES = {
	key = 'Settings' .. MODNAME .. 'Runes',
	l10n = 'none',
	name = 'Magicka Runes',
	description = 'Eight runes, an eighth of your magicka each, in their own widget.\n'
		.. 'The runes are always drawn. Behind them, a full eighth wears the\n'
		.. 'thick halo and the one currently filling or emptying wears the thin\n'
		.. 'one; a spent eighth has none. The flair behind all of it is what\n'
		.. 'pulses.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'RUNE_X_POS',
			name = 'Horizontal Position',
			description = 'Pixels from the left. The runes are their own widget -- drag\n'
				.. 'them anywhere, independently of the vials.',
			renderer = R_SLIDER,
			default = 140,
			argument = sliderArg(-200, math.floor(hudLayerSize.x) + 200, 1, 'px', 140),
		},
		{
			key = 'RUNE_Y_POS',
			name = 'Vertical Position',
			description = 'Pixels from the top.',
			renderer = R_SLIDER,
			default = math.max(40, math.floor(hudLayerSize.y) - 260),
			argument = sliderArg(-50, math.floor(hudLayerSize.y), 1, 'px',
				math.max(40, math.floor(hudLayerSize.y) - 260)),
		},
		{
			key = 'RUNE_HEIGHT',
			name = 'Rune Column Height',
			description = 'The art is 276px of runes. Anything else stretches it.',
			renderer = R_SLIDER,
			default = 139,
			argument = sliderArg(32, 512, 1, 'px', 139),
		},
		{
			key = 'RUNE_WIDTH',
			name = 'Rune Column Width',
			description = 'The art is 70px wide.',
			renderer = R_SLIDER,
			default = 35,
			argument = sliderArg(8, 256, 1, 'px', 35),
		},
		{
			key = 'RUNE_FILL_FROM',
			name = 'Runes Fill From',
			description = 'Which end lights first as magicka returns.',
			renderer = R_SELECT,
			default = 'Bottom',
			argument = selectArg { 'Bottom', 'Top' },
		},
		{
			key = 'RUNE_TINT',
			name = 'Base Rune Tint',
			description = 'Multiplied over KainGameRUNES. White leaves it untouched.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'RUNE_BASE_ALPHA',
			name = 'Base Rune Opacity',
			description = 'The runes that are always drawn, spent or not.',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0, 1, 0.05, '', 1.0),
		},
		{
			key = 'GLOW_TINT',
			name = 'Glow Tint',
			description = 'Multiplied over both halo sheets, GLOW_UP1 and GLOW_UP2.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'GLOW_ALPHA',
			name = 'Glow Opacity',
			description = 'How bright a lit rune\'s glow is.',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0.05, 1, 0.05, '', 1.0),
		},
		{
			key = 'GLOW_PARTIAL',
			name = 'Fade the Partial Rune',
			description = 'The rune currently filling or emptying fades with what is left\n'
				.. 'of its eighth, instead of holding its thin halo at full\n'
				.. 'brightness until it empties. Costs nothing: the fade is\n'
				.. 'quantised to 16 steps.',
			renderer = 'checkbox',
			default = true,
		},
		{
			key = 'FLAIR_TINT',
			name = 'Flair Tint',
			description = 'The FLAIR sheet sits behind the runes and is what pulses. It is\n'
				.. 'invisible until something makes it flash, so this is the colour\n'
				.. 'of the flash rather than of anything normally on screen.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'FLAIR_ALPHA',
			name = 'Flair Brightness',
			description = 'How bright the flair gets at the top of a pulse.',
			renderer = R_SLIDER,
			default = 0.8,
			argument = sliderArg(0, 1, 0.05, '', 0.8),
		},
		{
			key = 'FLAIR_SPEED',
			name = 'Flair Pulse Speed',
			description = 'Full cycles per second. Kept under three, as with the vials:\n'
				.. 'faster than that is a seizure risk and this sits in the corner\n'
				.. 'of the eye all game.',
			renderer = R_SLIDER,
			default = 1.4,
			argument = sliderArg(0.2, 2.5, 0.1, '/s', 1.4),
		},
	},
}

--------------------------------------------------------------------------------
-- Readability
--------------------------------------------------------------------------------
-- Everything here exists so the meters can be read by someone who cannot rely
-- on the fill colour, or on a small fill at all.

settingsTemplate.ACCESS = {
	key = 'Settings' .. MODNAME .. 'Access',
	l10n = 'none',
	name = 'Readability',
	description = 'Reading the meters without relying on colour or on a small fill.\n'
		.. 'The Colour-blind safe preset sets several of these at once.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'SHOW_NUMBERS',
			name = 'Show Numbers',
			description = 'A readout under each meter. The surest way to read a level:\n'
				.. 'it does not depend on colour, size or the fill being visible.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'NUMBER_FORMAT',
			name = 'Number Format',
			description = 'Percent, the current value, or current of maximum.',
			renderer = R_SELECT,
			default = 'Percent',
			argument = selectArg { 'Percent', 'Current', 'Current / Max' },
		},
		{
			key = 'NUMBER_SIZE',
			name = 'Number Size',
			description = '',
			renderer = R_SLIDER,
			default = 13,
			argument = sliderArg(8, 32, 1, 'px', 13),
		},
		{
			key = 'NUMBER_COLOR',
			name = 'Number Colour',
			description = 'Hex, no #.',
			renderer = R_COLOR,
			default = colorDefault('FFFFFF'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'LOW_WARNING',
			name = 'Low Warning',
			description = 'Pulses a meter that has dropped below the threshold. A movement\n'
				.. 'cue rather than a colour one, so it reads for anyone who cannot\n'
				.. 'tell the fill colour from the empty tube.',
			renderer = R_SELECT,
			default = 'Off',
			argument = selectArg { 'Off', 'Health', 'Health and Stamina', 'All three' },
		},
		{
			key = 'LOW_THRESHOLD',
			name = 'Low Threshold',
			description = 'The fraction below which a meter counts as low.',
			renderer = R_SLIDER,
			default = 0.25,
			argument = sliderArg(0.05, 0.9, 0.05, '', 0.25),
		},
		{
			key = 'LOW_PULSE_SPEED',
			name = 'Pulse Speed',
			description = 'Full cycles per second. Kept well under three: faster than that\n'
				.. 'is a seizure risk and this sits in the corner of the eye all game.',
			renderer = R_SLIDER,
			default = 1.0,
			argument = sliderArg(0.2, 2.5, 0.1, '/s', 1.0),
		},
		{
			key = 'LOW_PULSE_DEPTH',
			name = 'Pulse Depth',
			description = 'How far the pulse dims. 0 disables the movement without\n'
				.. 'turning the warning off.',
			renderer = R_SLIDER,
			default = 0.45,
			argument = sliderArg(0, 0.9, 0.05, '', 0.45),
		},
	},
}

--------------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------------

settingsTemplate.FRAME = {
	key = 'Settings' .. MODNAME .. 'Frame',
	l10n = 'none',
	name = 'Frame',
	description = 'Background and border behind the meters.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'HUD_BACKGROUND',
			name = 'Background',
			description = 'A dark panel behind the meters. Helps the tubes read against a\n'
				.. 'bright sky or a pale wall.',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'BACKGROUND_ALPHA',
			name = 'Background Opacity',
			description = '',
			renderer = R_SLIDER,
			default = 0.5,
			argument = sliderArg(0, 1, 0.05, '', 0.5),
		},
		{
			key = 'HUD_BORDER',
			name = 'Border',
			description = '',
			renderer = 'checkbox',
			default = false,
		},
		{
			key = 'HUD_BORDER_STYLE',
			name = 'Border Style',
			description = '',
			renderer = R_SELECT,
			default = 'normal',
			argument = selectArg { 'thin', 'normal', 'thick', 'verythick' },
		},
		{
			key = 'HUD_BORDER_COLOR',
			name = 'Border Colour',
			description = 'Hex, no #.',
			renderer = R_COLOR,
			default = colorDefault('caa560'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'HUD_PADDING',
			name = 'Padding',
			description = 'Space between the border and the meters.',
			renderer = R_SLIDER,
			default = 6,
			argument = sliderArg(0, 48, 1, 'px', 6),
		},
	},
}


--------------------------------------------------------------------------------

for _, template in pairs(settingsTemplate) do
	I.Settings.registerGroup(template)
end

I.Settings.registerPage {
	key = MODNAME,
	l10n = 'none',
	name = 'dbsHUD - DBSVials',
	description = 'Health and stamina as filling glass vials, magicka as eight runes.\n'
}

--------------------------------------------------------------------------------
-- Mirror into globals
--------------------------------------------------------------------------------

local COLOR_KEYS = { HEALTH_COLOR = true, STAMINA_COLOR = true,
                     GLASS_TINT = true, RUNE_TINT = true, GLOW_TINT = true,
                     NUMBER_COLOR = true, HUD_BORDER_COLOR = true,
                     BULB_TINT = true, FITTING_TINT = true,
                     FLAIR_TINT = true }

local function normalise(k, v)
	if COLOR_KEYS[k] and type(v) == 'string' then
		local hex = v:gsub('^#', '')
		if hex:match('^%x%x%x%x%x%x$') then
			return util.color.hex(hex)
		end
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

--------------------------------------------------------------------------------
-- Change classes
--------------------------------------------------------------------------------

local REBUILD = {
	HUD_BORDER = true, HUD_BORDER_STYLE = true, HUD_BORDER_COLOR = true,
	HUD_PADDING = true, HUD_BACKGROUND = true, HUD_LOCK = true,
	LAYOUT = true, SPACING = true,
	SHOW_HEALTH = true, SHOW_STAMINA = true, SHOW_RUNES = true,
	VIAL_SIZE = true,
	RUNE_HEIGHT = true, RUNE_WIDTH = true, RUNE_FILL_FROM = true,
	GLASS_TEXTURE = true, BULB_TEXTURE = true, CLEAR_CLASP_TEXTURE = true,
	SHOW_RESIDUE = true, SHOW_CLASP = true, SHOW_CAP = true,
	SHOW_NUMBERS = true, NUMBER_SIZE = true, NUMBER_FORMAT = true,
}

for _, template in pairs(settingsTemplate) do
	local section = storage.playerSection(template.key)
	section:subscribe(async:callback(function(_, setting)
		if setting == nil then
			readAllSettings()
		else
			_G[setting] = normalise(setting, section:get(setting))
		end


		if setting == nil or REBUILD[setting] then
			if buildVialsHud then buildVialsHud() end
			return
		end
		if applyVialStyle then applyVialStyle() end
	end))
end
