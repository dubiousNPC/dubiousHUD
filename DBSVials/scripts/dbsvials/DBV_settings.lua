---@omw-context player
--------------------------------------------------------------------------------
-- DBSVials -- settings
--------------------------------------------------------------------------------
-- Eleven small groups rather than five large ones. A group is a section on the
-- page, so the grouping IS the layout: anything you would change in one sitting
-- sits together, and the three subjects -- the vials, the runes, the frame they
-- share -- are separated by their own leading group.
--
-- Defaults are the author's own working configuration, so a fresh install looks
-- like the screenshots rather than like a developer's test bench.
--------------------------------------------------------------------------------

local core    = require('openmw.core')
local ui      = require('openmw.ui')
local util    = require('openmw.util')
local storage = require('openmw.storage')
local async   = require('openmw.async')
local I       = require('openmw.interfaces')

local v2 = util.vector2

MODNAME = MODNAME or 'DBSVials'

--------------------------------------------------------------------------------
-- Renderers
--------------------------------------------------------------------------------
-- Named once so swapping the renderer set is a single line, not a sweep.

local R_SLIDER = 'SuperSlider6'
local R_SELECT = 'SuperSelect3'
local R_COLOR  = 'SuperColorPicker4'
local R_CHECK  = 'checkbox'

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

local function colorDefault(hex) return util.color.hex(hex) end

local layerId      = ui.layers.indexOf('HUD')
local hudLayerSize = ui.layers[layerId].size
local SCREEN_W     = math.floor(hudLayerSize.x)
local SCREEN_H     = math.floor(hudLayerSize.y)

local presetColors = { 'FFFFFF', 'C41C1C', '2EA83A', '4840F0',
                       'E0821E', '3C8BD9', 'caa560' }

--- A position default that keeps its corner at any resolution. The author's own
--- placement was measured on a 1920x1080 screen; stored as a distance from the
--- right and bottom edges it lands in the same place on every other one.
local function fromRight(px) return math.max(0, SCREEN_W - px) end
local function fromBottom(px) return math.max(0, SCREEN_H - px) end

--- Groups appear in the order they are declared. A leading group is padded so
--- it reads as the banner for the ones under it -- the trick SDsettings uses,
--- and the only one the settings API gives us for a visual break.
local BANNER = string.rep(' ', 40)

local orderCounter = 0
local function getOrder() orderCounter = orderCounter + 1 return orderCounter end

local settingsTemplate = {}

local function group(id, name, description, settings)
	settingsTemplate[id] = {
		key = 'Settings' .. MODNAME .. id,
		l10n = 'none',
		name = name,
		description = description,
		page = MODNAME,
		permanentStorage = true,
		order = getOrder(),
		settings = settings,
	}
end

--------------------------------------------------------------------------------
-- 1. General
--------------------------------------------------------------------------------

group('General', 'General',
	'Whether the meters are shown, where they sit relative to each other,\n'
	.. 'and how solid they are.', {
	{
		key = 'HUD_DISPLAY',
		name = 'When to Show',
		description = 'Always, only while a menu or the inventory is open, or\n'
			.. 'everywhere except there.',
		renderer = R_SELECT,
		default = 'Always',
		argument = selectArg { 'Always', 'Interface Only', 'Hide on Interface' },
	},
	{
		key = 'HUD_LOCK',
		name = 'Lock Position',
		description = 'Locked, the meters ignore the mouse entirely. Unlock to drag\n'
			.. 'them, then lock again so they cannot be nudged in play.',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'HUD_OPACITY',
		name = 'Opacity',
		description = 'Applies to everything at once, over the top of each piece\'s\n'
			.. 'own opacity.',
		renderer = R_SLIDER,
		default = 1.0,
		argument = sliderArg(0.1, 1, 0.05, '', 1.0),
	},
	{
		key = 'LAYOUT',
		name = 'Vial Arrangement',
		description = 'Whether the two vials sit side by side or stacked. The runes\n'
			.. 'are a separate widget and are placed on their own.',
		renderer = R_SELECT,
		default = 'Horizontal',
		argument = selectArg { 'Horizontal', 'Vertical' },
	},
	{
		key = 'SPACING',
		name = 'Vial Spacing',
		description = 'Gap between the two vials. The range runs the full width of\n'
			.. 'the screen, so they can be split to opposite corners.',
		renderer = R_SLIDER,
		default = 0,
		argument = sliderArg(0, math.max(640, SCREEN_W), 1, 'px', 0),
	},
	{
		key = 'SHOW_HEALTH',
		name = 'Show Health Vial',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'SHOW_STAMINA',
		name = 'Show Stamina Vial',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'SHOW_RUNES',
		name = 'Show Magicka Runes',
		renderer = R_CHECK,
		default = true,
	},
})

--------------------------------------------------------------------------------
-- 2. The vials
--------------------------------------------------------------------------------

group('Vials', 'Vials' .. BANNER,
	'Health and stamina. Two sets to choose from: Classic is the assembled\n'
	.. 'LOK vessel -- collar, tube, clasp and bulb, with the liquid tinted by\n'
	.. 'the colours you pick. Battlespire is a plain test tube that drains\n'
	.. 'through a colour ramp of its own.\n\n'
	.. 'The settings for each set are in their own group below.', {
	{
		key = 'VIAL_STYLE',
		name = 'Vial Set',
		description = 'Which of the two sets is drawn. Each has its own group below;\n'
			.. 'the other one\'s settings simply do nothing while it is not in use.',
		renderer = R_SELECT,
		default = 'Classic',
		argument = selectArg { 'Classic', 'Battlespire' },
	},
	{
		key = 'VIAL_SIZE',
		name = 'Vial Size',
		description = 'How big the glass is drawn. Width and every fitting follow it,\n'
			.. 'so the vessel keeps the proportions it was drawn with.\n'
			.. 'Separate from Vial Length: a shorter vial is shorter on screen,\n'
			.. 'never thicker. 190 is the art at 1:1.\n\n'
			.. 'Drag a vial and roll the wheel to set this by eye.',
		renderer = R_SLIDER,
		default = 278,
		argument = sliderArg(24, 600, 1, 'px', 278),
	},
	{
		key = 'HEALTH_COLOR',
		name = 'Health Liquid',
		description = 'The colour of the liquid in the health vial. Used by the\n'
			.. 'Classic vials always, and by the Battlespire ones when their\n'
			.. 'Liquid Colour is set to Vanilla.',
		renderer = R_COLOR,
		default = colorDefault('B60000'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'STAMINA_COLOR',
		name = 'Stamina Liquid',
		description = 'The colour of the liquid in the stamina vial.',
		renderer = R_COLOR,
		default = colorDefault('349F00'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'FILL_SMOOTHING',
		name = 'Fill Smoothing',
		description = 'How fast the liquid chases the real value. The level eases\n'
			.. 'towards it rather than jumping, so a hit reads as the vial\n'
			.. 'draining rather than as the picture changing.\n'
			.. 'Higher is snappier; 0 turns it off and the level is exact.',
		renderer = R_SLIDER,
		default = 12,
		argument = sliderArg(0, 40, 1, '', 12),
	},
	{
		key = 'SHOW_FORTIFY',
		name = 'Show Fortified',
		description = 'Draws the part of the liquid an active Fortify effect has\n'
			.. 'added in its own colour.\n\n'
			.. 'The vessel is scaled against the larger of your base and your\n'
			.. 'fortified maximum either way, so a Fortify Maximum no longer\n'
			.. 'makes the liquid FALL at the moment you gain the headroom.\n'
			.. 'Not available on the Battlespire Classic ramp, which is one\n'
			.. 'image carrying its own colour.',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'FORTIFY_TINT',
		name = 'Fortified Colour',
		description = 'The colour of the added part.',
		renderer = R_COLOR,
		default = colorDefault('FAD778'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'VIAL_X_POS',
		name = 'Horizontal Position',
		description = 'Pixels from the left. Click and drag a vial to move the pair.',
		renderer = R_SLIDER,
		default = fromRight(176),
		argument = sliderArg(-200, SCREEN_W + 200, 1, 'px', fromRight(176)),
	},
	{
		key = 'VIAL_Y_POS',
		name = 'Vertical Position',
		description = 'Pixels from the top.',
		renderer = R_SLIDER,
		default = fromBottom(384),
		argument = sliderArg(-50, SCREEN_H, 1, 'px', fromBottom(384)),
	},
})

--------------------------------------------------------------------------------
-- 3. Classic vials: the liquid and the glass
--------------------------------------------------------------------------------

group('Classic', 'Vials: Classic (LOK)',
	'The assembled vessel. This group is the liquid and the tube it is in;\n'
	.. 'the metal and the glassware are in the group after it.', {
	{
		key = 'VIAL_LENGTH',
		name = 'Vial Length',
		description = 'How much tube there is, in rows of the original art.\n'
			.. '139 is the full vial; 63 is the short one. The clasp, the bulb\n'
			.. 'and the foot of the liquid all move up together, so the vessel\n'
			.. 'stays one object and the liquid still fills it end to end.',
		renderer = R_SLIDER,
		default = 109,
		argument = sliderArg(63, 139, 1, 'px', 109),
	},
	{
		key = 'GLASS_TEXTURE',
		name = 'Glass Texture',
		description = 'Leave this alone to use the supplied tube, which is what the\n'
			.. 'Vial Length setting cuts from. Point it at your own 13-wide\n'
			.. 'texture to replace it -- a custom tube is drawn whole, so Vial\n'
			.. 'Length stops applying.',
		renderer = 'textLine',
		default = 'textures/dbsvials/glass_tube.png',
	},
	{
		key = 'GLASS_TINT',
		name = 'Glass Tint',
		description = 'Tints the tube itself, not the liquid in it.',
		renderer = R_COLOR,
		default = colorDefault('FFFFFF'),
		argument = { presetColors = presetColors },
	},
})

--------------------------------------------------------------------------------
-- 4. Classic vials: the fittings
--------------------------------------------------------------------------------

group('Fittings', 'Vials: Classic Fittings',
	'The metal and the glassware around the liquid. All of it is optional --\n'
	.. 'switching the lot off leaves a bare tube.', {
	{
		key = 'SHOW_CLASP',
		name = 'Clasp',
		description = 'The metal diamond the vessel hangs in. It is drawn UNDER the\n'
			.. 'liquid, so the liquid reads as being inside the glass.',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'SHOW_CAP',
		name = 'Collar',
		description = 'The fitting that caps the top of the tube.',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'FITTING_TINT',
		name = 'Metal Tint',
		description = 'Clasp and collar together, and the Battlespire frame.',
		renderer = R_COLOR,
		default = colorDefault('FFFFFF'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'CLEAR_CLASP_TEXTURE',
		name = 'Clear Clasp',
		description = 'The transparent front of the clasp, drawn over the liquid so\n'
			.. 'the liquid passes behind the metal rather than across it.\n'
			.. 'Clear this box to drop that piece.',
		renderer = 'textLine',
		default = 'textures/dbsvials/VIAL_CLEAR_CLASP.png',
	},
	{
		key = 'BULB_TEXTURE',
		name = 'Bulb Backing',
		description = 'An optional plate behind the bulb at the foot. Off by default;\n'
			.. 'the clear glass version reads best over a busy scene.',
		renderer = R_SELECT,
		default = '',
		argument = selectArg {
			'',
			'textures/dbsvials/VIAL_CLEAR_GLASS.png',
			'textures/dbsvials/VIAL_BOTT_EMPTY.png',
		},
	},
	{
		key = 'BULB_TINT',
		name = 'Bulb Tint',
		renderer = R_COLOR,
		default = colorDefault('FFFFFF'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'BULB_ALPHA',
		name = 'Bulb Opacity',
		renderer = R_SLIDER,
		default = 1.0,
		argument = sliderArg(0, 1, 0.05, '', 1.0),
	},
	{
		key = 'SHOW_RESIDUE',
		name = 'Dreg',
		description = 'A little of the liquid left in the bulb, in that vial\'s own\n'
			.. 'colour, so an empty vessel still reads as a health or a stamina\n'
			.. 'one rather than going blank.',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'RESIDUE_ALPHA',
		name = 'Dreg Opacity',
		renderer = R_SLIDER,
		default = 1.0,
		argument = sliderArg(0, 1, 0.05, '', 1.0),
	},
})

--------------------------------------------------------------------------------
-- 5. Battlespire vials
--------------------------------------------------------------------------------

group('Battlespire', 'Vials: Battlespire (BS)',
	'A plain test tube that drains through a 32-frame ramp. Health gets the\n'
	.. 'warm artwork and stamina the cool one, which is what tells the two\n'
	.. 'tubes apart -- they are otherwise the same tube.', {
	{
		key = 'ENGY_COLOUR',
		name = 'Liquid Colour',
		description = 'Classic is the artwork as supplied: the liquid shifts through\n'
			.. 'its own ramp as it drains, yellow to red for health and blue to\n'
			.. 'red for stamina, and nothing is tinted.\n\n'
			.. 'Vanilla replaces it with one flat colour that does not shift,\n'
			.. 'taking the same two Liquid colours the Classic vials use, so the\n'
			.. 'two sets read alike. The glass is unchanged either way.',
		renderer = R_SELECT,
		default = 'Classic',
		argument = selectArg { 'Classic', 'Vanilla' },
	},
	{
		key = 'ENGY_SHOW_BACKING',
		name = 'Tube Backing',
		description = 'A panel behind the glass, cut to what the outline encloses\n'
			.. 'rather than drawn as a rectangle -- a square backing behind a\n'
			.. 'round-ended tube reads as a mistake. Gives the flat Vanilla\n'
			.. 'liquid something to sit against over a busy scene.',
		renderer = R_CHECK,
		default = false,
	},
	{
		key = 'ENGY_BACKING_TINT',
		name = 'Backing Tint',
		renderer = R_COLOR,
		default = colorDefault('101018'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'ENGY_BACKING_ALPHA',
		name = 'Backing Opacity',
		renderer = R_SLIDER,
		default = 0.7,
		argument = sliderArg(0, 1, 0.05, '', 0.7),
	},
	{
		key = 'ENGY_SHOW_FRAME',
		name = 'Outline',
		description = 'The dark outline over the tube, which helps it hold its shape\n'
			.. 'against a bright scene. Takes the Metal Tint from the Fittings\n'
			.. 'group.',
		renderer = R_CHECK,
		default = false,
	},
	{
		key = 'ENGY_FRAME_ALPHA',
		name = 'Outline Opacity',
		renderer = R_SLIDER,
		default = 1.0,
		argument = sliderArg(0, 1, 0.05, '', 1.0),
	},
})

--------------------------------------------------------------------------------
-- 6. The runes
--------------------------------------------------------------------------------

group('Runes', 'Runes' .. BANNER,
	'Magicka, in its own widget, placed on its own. Three styles: Runes is\n'
	.. 'the separated set on an even grid, Classic the original sheet with its\n'
	.. 'halos and flair, and Pips counts castings the way MMUI does.\n\n'
	.. 'Pips have their own group; colour and glow have another.', {
	{
		key = 'RUNE_STYLE',
		name = 'Rune Style',
		description = 'Runes: the eight runes separated, each emptying by losing its\n'
			.. 'blue and leaving its outline.\n'
			.. 'Classic: the original sheet, with the two halos behind it.\n'
			.. 'Pips: one rune per casting rather than a share of your magicka.',
		renderer = R_SELECT,
		default = 'Runes',
		argument = selectArg { 'Runes', 'Classic', 'Pips' },
	},
	{
		key = 'RUNE_SIZE',
		name = 'Rune Size',
		description = 'The height of one rune. The width follows from the artwork, so\n'
			.. 'the runes keep their shape at every size -- there is no separate\n'
			.. 'width to drift out of proportion.\n\n'
			.. 'Drag the column and roll the wheel to set this by eye.',
		renderer = R_SLIDER,
		default = 24,
		argument = sliderArg(4, 64, 1, 'px', 24),
	},
	{
		key = 'RUNE_LENGTH',
		name = 'Rune Count',
		description = 'How many runes the column is drawn with. Each keeps the size\n'
			.. 'above, so the column grows by gaining runes and the eight shapes\n'
			.. 'repeat upward.\n\n'
			.. 'This is a finer readout, not just a taller one: a rune is one\n'
			.. 'Nth of your magicka, so at 32 one goes out every 3% rather than\n'
			.. 'every 12.5%. Multiples of eight keep the pattern whole.\n'
			.. 'Runes only -- the Classic sheet is eight measured bands of one\n'
			.. 'image and cannot be extended.',
		renderer = R_SLIDER,
		default = 8,
		argument = sliderArg(8, 32, 1, '', 8),
	},
	{
		key = 'RUNE_FILL_FROM',
		name = 'Runes Fill From',
		description = 'Which end of the column empties last.',
		renderer = R_SELECT,
		default = 'Bottom',
		argument = selectArg { 'Bottom', 'Top' },
	},
	{
		key = 'RUNE_X_POS',
		name = 'Horizontal Position',
		description = 'Pixels from the left. Click and drag the column to move it.',
		renderer = R_SLIDER,
		default = fromRight(60),
		argument = sliderArg(-200, SCREEN_W + 200, 1, 'px', fromRight(60)),
	},
	{
		key = 'RUNE_Y_POS',
		name = 'Vertical Position',
		description = 'Pixels from the top.',
		renderer = R_SLIDER,
		default = fromBottom(374),
		argument = sliderArg(-50, SCREEN_H, 1, 'px', fromBottom(374)),
	},
})

--------------------------------------------------------------------------------
-- 7. Pips
--------------------------------------------------------------------------------

group('Pips', 'Runes: Pips',
	'One rune per casting rather than a share of your magicka, so the row\n'
	.. 'shortens as a spell gets dearer. Nothing here applies to the other\n'
	.. 'two styles.', {
	{
		key = 'PIP_SOURCE',
		name = 'A Pip Is',
		description = 'A casting of your selected spell, or a fixed amount of\n'
			.. 'magicka. With no spell selected it falls back to the fixed\n'
			.. 'amount rather than showing an empty row.',
		renderer = R_SELECT,
		default = 'One casting of the selected spell',
		argument = selectArg {
			'One casting of the selected spell',
			'A fixed amount of magicka',
		},
	},
	{
		key = 'PIP_MAGICKA',
		name = 'Magicka per Pip',
		description = 'Used when A Pip Is is set to the fixed amount.',
		renderer = R_SLIDER,
		default = 10,
		argument = sliderArg(1, 100, 1, '', 10),
	},
	{
		key = 'PIP_SIZE',
		name = 'Pip Size',
		description = 'The artwork is 45px square.',
		renderer = R_SLIDER,
		default = 22,
		argument = sliderArg(6, 96, 1, 'px', 22),
	},
	{
		key = 'PIP_GAP',
		name = 'Pip Spacing',
		description = 'Negative values overlap them, which is how the supplied set\n'
			.. 'is meant to sit.',
		renderer = R_SLIDER,
		default = -4,
		argument = sliderArg(-24, 24, 1, 'px', -4),
	},
	{
		key = 'PIP_COLUMN',
		name = 'Pips per Column',
		description = 'How many stack before a new column starts.',
		renderer = R_SLIDER,
		default = 8,
		argument = sliderArg(1, 32, 1, '', 8),
	},
	{
		key = 'PIP_WRAP',
		name = 'New Column Goes',
		description = 'Which side of the main column the next one is added to. Set\n'
			.. 'to Left, the main column sits at the right edge so later ones\n'
			.. 'grow away from it and nothing already drawn moves.',
		renderer = R_SELECT,
		default = 'Right',
		argument = selectArg { 'Right', 'Left' },
	},
})

--------------------------------------------------------------------------------
-- 8. Rune colour
--------------------------------------------------------------------------------

group('RuneColour', 'Runes: Colour and Glow',
	'The runes themselves are always drawn. What changes as magicka moves is\n'
	.. 'what sits behind and over them.', {
	{
		key = 'RUNE_TINT',
		name = 'Rune Tint',
		description = 'The runes themselves -- on the Runes style, the outline that\n'
			.. 'is left behind when one empties.',
		renderer = R_COLOR,
		default = colorDefault('FFFFFF'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'RUNE_BASE_ALPHA',
		name = 'Rune Opacity',
		renderer = R_SLIDER,
		default = 1.0,
		argument = sliderArg(0, 1, 0.05, '', 1.0),
	},
	{
		key = 'GLOW_TINT',
		name = 'Glow Tint',
		description = 'The blue that fills a rune on the Runes style, and the halos\n'
			.. 'behind one on Classic.',
		renderer = R_COLOR,
		default = colorDefault('FFFFFF'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'GLOW_ALPHA',
		name = 'Glow Opacity',
		renderer = R_SLIDER,
		default = 1.0,
		argument = sliderArg(0.05, 1, 0.05, '', 1.0),
	},
	{
		key = 'GLOW_PARTIAL',
		name = 'Fade the Partial Rune',
		description = 'The rune currently filling or emptying fades with its share\n'
			.. 'instead of switching on and off, which makes small changes\n'
			.. 'readable. Switch off for a hard step.',
		renderer = R_CHECK,
		default = true,
	},
	{
		key = 'FLAIR_TINT',
		name = 'Flair Tint',
		description = 'The layer behind everything that carries the pulse.',
		renderer = R_COLOR,
		default = colorDefault('FFFFFF'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'FLAIR_ALPHA',
		name = 'Flair Brightness',
		description = 'Set to zero to switch the pulse off entirely.',
		renderer = R_SLIDER,
		default = 0.8,
		argument = sliderArg(0, 1, 0.05, '', 0.8),
	},
	{
		key = 'FLAIR_SPEED',
		name = 'Flair Pulse Speed',
		renderer = R_SLIDER,
		default = 1.4,
		argument = sliderArg(0.2, 2.5, 0.1, '/s', 1.4),
	},
})

--------------------------------------------------------------------------------
-- 9. Numbers
--------------------------------------------------------------------------------

group('Numbers', 'Numbers',
	'A figure under each meter, for when the artwork alone is not precise\n'
	.. 'enough to act on.', {
	{
		key = 'SHOW_NUMBERS',
		name = 'Show Numbers',
		renderer = R_CHECK,
		default = false,
	},
	{
		key = 'NUMBER_FORMAT',
		name = 'Number Format',
		description = 'Percent is the least to read at a glance; Current / Max is\n'
			.. 'the most precise.',
		renderer = R_SELECT,
		default = 'Percent',
		argument = selectArg { 'Percent', 'Current', 'Current / Max' },
	},
	{
		key = 'NUMBER_SIZE',
		name = 'Number Size',
		renderer = R_SLIDER,
		default = 13,
		argument = sliderArg(8, 32, 1, 'px', 13),
	},
	{
		key = 'NUMBER_COLOR',
		name = 'Number Colour',
		renderer = R_COLOR,
		default = colorDefault('FFFFFF'),
		argument = { presetColors = presetColors },
	},
})

--------------------------------------------------------------------------------
-- 10. Low warning
--------------------------------------------------------------------------------

group('LowWarning', 'Low Warning',
	'A pulse when a meter runs low, for when you are watching the fight and\n'
	.. 'not the corner of the screen.', {
	{
		key = 'LOW_WARNING',
		name = 'Pulse When Low',
		description = 'Which meters pulse. Off by default -- it is movement in the\n'
			.. 'corner of your eye, which some people want and some do not.',
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
		renderer = R_SLIDER,
		default = 1.0,
		argument = sliderArg(0.2, 2.5, 0.1, '/s', 1.0),
	},
	{
		key = 'LOW_PULSE_DEPTH',
		name = 'Pulse Depth',
		description = 'How far the pulse dips. Zero is no pulse at all.',
		renderer = R_SLIDER,
		default = 0.45,
		argument = sliderArg(0, 0.9, 0.05, '', 0.45),
	},
})

--------------------------------------------------------------------------------
-- 11. Frame
--------------------------------------------------------------------------------

group('Frame', 'Frame' .. BANNER,
	'An optional backing behind each widget. Both are off by default; they\n'
	.. 'are here for placing the meters over a busy scene, and for finding\n'
	.. 'them while dragging.', {
	{
		key = 'HUD_BACKGROUND',
		name = 'Background',
		description = 'A dark panel behind the meters.',
		renderer = R_CHECK,
		default = false,
	},
	{
		key = 'BACKGROUND_ALPHA',
		name = 'Background Opacity',
		renderer = R_SLIDER,
		default = 0.5,
		argument = sliderArg(0, 1, 0.05, '', 0.5),
	},
	{
		key = 'HUD_BORDER',
		name = 'Border',
		description = 'A drawn border around each widget.',
		renderer = R_CHECK,
		default = false,
	},
	{
		key = 'HUD_BORDER_STYLE',
		name = 'Border Style',
		renderer = R_SELECT,
		default = 'normal',
		argument = selectArg { 'thin', 'normal', 'thick', 'verythick' },
	},
	{
		key = 'HUD_BORDER_COLOR',
		name = 'Border Colour',
		renderer = R_COLOR,
		default = colorDefault('caa560'),
		argument = { presetColors = presetColors },
	},
	{
		key = 'HUD_PADDING',
		name = 'Padding',
		description = 'Space between the border and the meters. Applies whether or\n'
			.. 'not the border is drawn.',
		renderer = R_SLIDER,
		default = 6,
		argument = sliderArg(0, 48, 1, 'px', 6),
	},
})

--------------------------------------------------------------------------------
-- Carrying old settings across
--------------------------------------------------------------------------------
-- A group IS a storage section, so regrouping the page moves settings between
-- sections and an existing install would come back on the defaults. Anything
-- the new section has not got yet is taken from wherever it used to live, once,
-- before anything subscribes. Nobody loses their configuration to a reshuffle.

local LEGACY = {
	'Settings' .. MODNAME .. 'Vials',
	'Settings' .. MODNAME .. 'Runes',
	'Settings' .. MODNAME .. 'Access',
}

--- Settings that have no old counterpart to copy, only one to compute from.
--- Rune Size replaced a column height and a column width; the height is what
--- carries over, divided by the eight runes it used to describe.
local DERIVE = {
	RUNE_SIZE = function(get)
		local h = get('RUNE_HEIGHT')
		if type(h) ~= 'number' then return nil end
		return math.max(4, math.min(64, math.floor(h / 8 + 0.5)))
	end,
}

local function migrate()
	local legacy = {}
	for _, key in ipairs(LEGACY) do legacy[#legacy + 1] = storage.playerSection(key) end
	local function fromLegacy(key)
		for _, sec in ipairs(legacy) do
			local v = sec:get(key)
			if v ~= nil then return v end
		end
		return nil
	end

	for _, template in pairs(settingsTemplate) do
		local section = storage.playerSection(template.key)
		for _, entry in pairs(template.settings) do
			if section:get(entry.key) == nil then
				local v = fromLegacy(entry.key)
				if v == nil and DERIVE[entry.key] then v = DERIVE[entry.key](fromLegacy) end
				if v ~= nil then section:set(entry.key, v) end
			end
		end
	end
end

migrate()

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

I.Settings.registerPage {
	key = MODNAME,
	l10n = 'none',
	name = 'dbsHUD - DBSVials',
	description = 'Health and stamina as filling glass vials, magicka as runes.\n'
		.. 'Two separate widgets: drag either one to move it, and roll the\n'
		.. 'wheel while dragging to resize it.',
}

for _, template in pairs(settingsTemplate) do
	I.Settings.registerGroup(template)
end

--------------------------------------------------------------------------------
-- Mirror into globals
--------------------------------------------------------------------------------

local COLOR_KEYS = {
	HEALTH_COLOR = true, STAMINA_COLOR = true, GLASS_TINT = true,
	BULB_TINT = true, FITTING_TINT = true,
	ENGY_BACKING_TINT = true,
	RUNE_TINT = true, GLOW_TINT = true, FLAIR_TINT = true, FORTIFY_TINT = true,
	NUMBER_COLOR = true, HUD_BORDER_COLOR = true,
}

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
-- Two kinds of change: one that alters the shape of the widget tree and needs it
-- built again, and one that only alters a colour or an opacity, which is a
-- property write on elements that already exist. Everything not listed here
-- takes the cheap path.

local REBUILD = {
	-- the frame the widgets sit in
	HUD_BORDER = true, HUD_BORDER_STYLE = true, HUD_BORDER_COLOR = true,
	HUD_PADDING = true, HUD_BACKGROUND = true, HUD_LOCK = true,
	LAYOUT = true, SPACING = true,
	SHOW_HEALTH = true, SHOW_STAMINA = true, SHOW_RUNES = true,
	-- the vials
	VIAL_STYLE = true, VIAL_SIZE = true, VIAL_LENGTH = true,
	SHOW_FORTIFY = true,
	GLASS_TEXTURE = true, BULB_TEXTURE = true, CLEAR_CLASP_TEXTURE = true,
	SHOW_RESIDUE = true, SHOW_CLASP = true, SHOW_CAP = true,
	ENGY_COLOUR = true, ENGY_SHOW_FRAME = true, ENGY_SHOW_BACKING = true,
	-- the runes
	RUNE_STYLE = true, RUNE_SIZE = true, RUNE_LENGTH = true, RUNE_FILL_FROM = true,
	PIP_COLUMN = true, PIP_WRAP = true, PIP_SIZE = true,
	PIP_GAP = true, PIP_SOURCE = true,
	-- the numbers
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
