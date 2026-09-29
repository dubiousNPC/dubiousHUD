---@omw-context player
-- DBV_settings.lua
--
-- Settings for DBSVials. Group layout, key naming and the preset machinery
-- follow BSCompass and MoonHUD so the page sits consistently alongside them.
--
-- Each setting is mirrored into a global of the same name (VIAL_HEIGHT,
-- HUD_X_POS, ...) which the main script reads directly. Reading a global in
-- onUpdate is a lot cheaper than a storage lookup, which matters because this
-- HUD samples the player's stats every frame.

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
-- SuperSettingsRenderers is bundled with this mod, under
-- scripts/SuperSettingsRenderers, and registered by the MENU entries in the
-- .omwscripts file. It is therefore always present and this can stay on.
--
-- Set it to false only if you have stripped the bundled copy out. Naming a
-- renderer that is not registered makes I.Settings.registerGroup fail, which
-- kills the whole script: no settings page and no widget.
local RENDERER_SELECT = 'SuperSelect3'
local RENDERER_NUMBER = 'SuperSlider6'
local RENDERER_COLOR  = 'SuperColorPicker4'

local R_SLIDER = RENDERER_NUMBER
local R_SELECT = RENDERER_SELECT
local R_COLOR  = RENDERER_COLOR

-- Slider argument in the Sun's Dusk house style: a labelled track with the
-- default marked, the value and reset on a second row. `def` must be the
-- setting's own default or showDefaultMark puts the tick at the minimum.
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
-- Sparse: only the keys that differ from the shipped defaults. Anything not
-- listed is left alone, so a preset is a nudge rather than a reset. 'Default'
-- is handled separately and does sweep everything.
BuiltInPresets = {
	-- Red and green sit on the one axis that protanopia and deuteranopia
	-- collapse, and between them that is most colour-blind people. This preset
	-- moves health and stamina onto the blue/orange axis, which survives all
	-- three common types, and turns the numbers on so the level can be read
	-- without relying on the fill at all.
	['Colour-blind safe'] = {
		HEALTH_COLOR  = colorDefault('3C8BD9'),
		STAMINA_COLOR = colorDefault('E0821E'),
		SHOW_NUMBERS  = true,
		EMPTY_ALPHA   = 0.55,
	},
	['Large'] = {
		VIAL_HEIGHT  = 208,
		VIAL_WIDTH   = 26,
		RUNE_HEIGHT  = 276,
		SHOW_NUMBERS = true,
		NUMBER_SIZE  = 18,
	},
	['Minimal'] = {
		SHOW_RUNES     = false,
		HUD_BACKGROUND = false,
		HUD_BORDER     = false,
		VIAL_HEIGHT    = 96,
	},
	['Runes only'] = {
		SHOW_HEALTH  = false,
		SHOW_STAMINA = false,
		SHOW_RUNES   = true,
	},
}

local PRESET_ITEMS = { 'Custom', 'Default', 'Colour-blind safe', 'Large',
                       'Minimal', 'Runes only', 'Slot 1', 'Slot 2' }

--------------------------------------------------------------------------------
-- Presets group
--------------------------------------------------------------------------------

settingsTemplate.PRESETS = {
	key = 'Settings' .. MODNAME .. 'PRESETS',
	l10n = 'none',
	name = 'Presets',
	description = 'Pick a preset to apply it. Changing anything afterwards puts\n'
		.. 'this back to Custom -- the preset is a starting point, not a lock.\n'
		.. 'The two slots hold whatever you have set up now.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'PRESET',
			name = 'Preset',
			description = 'Applies at once. Slot 1 and Slot 2 load what you saved there.',
			renderer = R_SELECT,
			default = 'Custom',
			argument = selectArg(PRESET_ITEMS),
		},
		{
			key = 'PRESET_SAVE',
			name = 'Save current settings to',
			description = 'Writes every setting on this page into the slot, then\n'
				.. 'returns to "--" so the same slot can be written again.',
			renderer = R_SELECT,
			default = '--',
			argument = selectArg { '--', 'Save to Slot 1', 'Save to Slot 2' },
		},
	},
}

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

settingsTemplate.GENERAL = {
	key = 'Settings' .. MODNAME .. 'General',
	l10n = 'none',
	name = 'General',
	description = 'Placement and visibility.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
		{
			key = 'HUD_X_POS',
			name = 'Horizontal Position',
			description = 'Pixels from the left. Click and drag the meters to move them.',
			renderer = R_SLIDER,
			default = 40,
			argument = sliderArg(-200, math.floor(hudLayerSize.x) + 200, 1, 'px', 40),
		},
		{
			key = 'HUD_Y_POS',
			name = 'Vertical Position',
			description = 'Pixels from the top.',
			renderer = R_SLIDER,
			default = math.max(40, math.floor(hudLayerSize.y) - 260),
			argument = sliderArg(-50, math.floor(hudLayerSize.y), 1, 'px',
				math.max(40, math.floor(hudLayerSize.y) - 260)),
		},
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
			name = 'Arrangement',
			description = 'How the three meters are laid out next to each other.',
			renderer = R_SELECT,
			default = 'Horizontal',
			argument = selectArg { 'Horizontal', 'Vertical' },
		},
		{
			key = 'SPACING',
			name = 'Spacing',
			description = 'Gap between meters.',
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
			key = 'VIAL_HEIGHT',
			name = 'Vial Height',
			description = 'The tube art is 139px tall. Anything taller or shorter stretches it.',
			renderer = R_SLIDER,
			default = 139,
			argument = sliderArg(32, 512, 1, 'px', 139),
		},
		{
			key = 'VIAL_WIDTH',
			name = 'Vial Width',
			description = 'The tube art is 13px wide.',
			renderer = R_SLIDER,
			default = 13,
			argument = sliderArg(4, 96, 1, 'px', 13),
		},
		{
			key = 'HEALTH_COLOR',
			name = 'Health Colour',
			description = 'Hex, no #. The block behind the glass.',
			renderer = R_COLOR,
			default = colorDefault('C41C1C'),
			argument = { presetColors = presetColors },
		},
		{
			key = 'STAMINA_COLOR',
			name = 'Stamina Colour',
			description = 'Hex, no #.',
			renderer = R_COLOR,
			default = colorDefault('2EA83A'),
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
			key = 'EMPTY_ALPHA',
			name = 'Empty Portion',
			description = 'Opacity of the colour above the fill line. At 0 the empty part of\n'
				.. 'the tube is bare glass. Raise it to keep the tube readable as a\n'
				.. 'shape when it is nearly drained.',
			renderer = R_SLIDER,
			default = 0.0,
			argument = sliderArg(0, 1, 0.05, '', 0.0),
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
	description = 'Eight runes, an eighth of your magicka each. The base runes are always\n'
		.. 'drawn; the glow behind a rune goes out when its eighth is spent and\n'
		.. 'comes back the moment it starts to refill.',
	page = MODNAME,
	permanentStorage = true,
	order = getOrder(),
	settings = {
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
			description = 'Multiplied over KainGame_RUNES_GLOW.',
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
			description = 'The rune currently being spent fades with what is left of its\n'
				.. 'eighth, instead of staying at full glow until it empties.\n'
				.. 'Costs nothing: the fade is quantised to 16 steps.',
			renderer = 'checkbox',
			default = true,
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
-- Preset slots
--------------------------------------------------------------------------------
-- Same approach as BSCompass: the settings interface has no "button" renderer
-- whose extra buttons do not send a GLOBAL event, and this mod ships no global
-- script. A select that resets itself needs no second script.

local SLOT_SECTION = 'Settings' .. MODNAME .. 'PresetSlots'
local SLOT_FOR     = { ['Slot 1'] = 'SLOT1', ['Slot 2'] = 'SLOT2' }
local SAVE_TO      = { ['Save to Slot 1'] = 'SLOT1', ['Save to Slot 2'] = 'SLOT2' }
local PRESET_KEYS  = { PRESET = true, PRESET_SAVE = true }

-- key -> { section, default }, so a preset can reach any setting on the page.
local settingIndex = {}

-- Set while a preset is writing, so the subscribe handler below does not treat
-- each write as a fresh user edit and knock the selector back to Custom.
local applyingPreset = false

-- util.color is userdata and does not survive being nested in a stored table,
-- so colours go in and out of a slot as a tagged hex string.
local function toStorable(v)
	local t = type(v)
	if (t == 'userdata' or t == 'table') and type(v.asHex) == 'function' then
		return '#hex:' .. v:asHex()
	end
	return v
end

local function fromStorable(v)
	if type(v) == 'string' then
		local h = v:match('^#hex:(%x%x%x%x%x%x)$')
		if h then return util.color.hex(h) end
	end
	return v
end

local function writeValues(values)
	if type(values) ~= 'table' then return false end
	local wrote = 0
	applyingPreset = true
	for k, v in pairs(values) do
		local d = settingIndex[k]
		if d and not PRESET_KEYS[k] then
			storage.playerSection(d.section):set(k, fromStorable(v))
			wrote = wrote + 1
		end
	end
	applyingPreset = false
	return wrote > 0
end

local function resetToDefaults()
	local values = {}
	for k, d in pairs(settingIndex) do
		if not PRESET_KEYS[k] then values[k] = d.default end
	end
	return writeValues(values)
end

local function saveSlot(slotKey)
	local snap = {}
	for k, d in pairs(settingIndex) do
		if not PRESET_KEYS[k] then
			local v = storage.playerSection(d.section):get(k)
			if v == nil then v = d.default end
			snap[k] = toStorable(v)
		end
	end
	storage.playerSection(SLOT_SECTION):set(slotKey, snap)
	return snap
end

local function loadSlot(slotKey)
	return writeValues(storage.playerSection(SLOT_SECTION):get(slotKey))
end

--- Returns true if the setting was a preset control and has been dealt with.
local function handlePresetSetting(setting)
	if not PRESET_KEYS[setting] then return false end
	if applyingPreset then return true end
	local section = storage.playerSection(settingsTemplate.PRESETS.key)

	if setting == 'PRESET' then
		local choice = section:get('PRESET')
		if choice == nil or choice == 'Custom' then return true end
		if choice == 'Default' then
			resetToDefaults()
		elseif SLOT_FOR[choice] then
			loadSlot(SLOT_FOR[choice])
		elseif BuiltInPresets[choice] then
			writeValues(BuiltInPresets[choice])
		end
		return true
	end

	-- PRESET_SAVE: act, then put the selector back so the same slot can be
	-- written twice in a row.
	local slot = SAVE_TO[section:get('PRESET_SAVE') or '']
	if slot then
		saveSlot(slot)
		applyingPreset = true
		section:set('PRESET_SAVE', '--')
		applyingPreset = false
	end
	return true
end

--------------------------------------------------------------------------------

for _, template in pairs(settingsTemplate) do
	I.Settings.registerGroup(template)
end

I.Settings.registerPage {
	key = MODNAME,
	l10n = 'none',
	name = 'dbsHUD - DBSVials',
	description = 'Health and stamina as filling glass vials, magicka as eight runes.\n'
		.. '- Click and drag to move them.\n'
		.. '- Click and mousewheel to resize.\n'
		.. '- Readability holds the settings for reading the meters without\n'
		.. '  relying on colour.',
}

--------------------------------------------------------------------------------
-- Mirror into globals
--------------------------------------------------------------------------------

local COLOR_KEYS = { HEALTH_COLOR = true, STAMINA_COLOR = true,
                     GLASS_TINT = true, RUNE_TINT = true, GLOW_TINT = true,
                     NUMBER_COLOR = true, HUD_BORDER_COLOR = true }

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
			settingIndex[entry.key] = { section = template.key, default = entry.default }
		end
	end
end

readAllSettings()

--------------------------------------------------------------------------------
-- Change classes
--------------------------------------------------------------------------------
-- REBUILD  anything that changes the shape of the widget tree or a texture.
-- Everything else is a poke into the live element.
--
-- There is no third class here the way BSCompass has retile: nothing in this
-- mod cuts an atlas, so the only two costs are "rebuild the tree" and "set a
-- prop". Colours and opacities are pokes because they are dragged.

local REBUILD = {
	HUD_BORDER = true, HUD_BORDER_STYLE = true, HUD_BORDER_COLOR = true,
	HUD_PADDING = true, HUD_BACKGROUND = true, HUD_LOCK = true,
	LAYOUT = true, SPACING = true,
	SHOW_HEALTH = true, SHOW_STAMINA = true, SHOW_RUNES = true,
	VIAL_HEIGHT = true, VIAL_WIDTH = true,
	RUNE_HEIGHT = true, RUNE_WIDTH = true, RUNE_FILL_FROM = true,
	GLASS_TEXTURE = true,
	SHOW_NUMBERS = true, NUMBER_SIZE = true, NUMBER_FORMAT = true,
}

for _, template in pairs(settingsTemplate) do
	local section = storage.playerSection(template.key)
	section:subscribe(async:callback(function(_, setting)
		if setting ~= nil and handlePresetSetting(setting) then return end

		if setting == nil then
			readAllSettings()
		else
			_G[setting] = normalise(setting, section:get(setting))
		end

		-- Any edit that is not a preset being applied means the user has moved
		-- off whatever preset was selected.
		if setting ~= nil and not applyingPreset and not PRESET_KEYS[setting] then
			local psection = storage.playerSection(settingsTemplate.PRESETS.key)
			if (psection:get('PRESET') or 'Custom') ~= 'Custom' then
				applyingPreset = true
				psection:set('PRESET', 'Custom')
				applyingPreset = false
			end
		end

		if setting == nil or REBUILD[setting] then
			if buildVialsHud then buildVialsHud() end
			return
		end
		if applyVialStyle then applyVialStyle() end
	end))
end
