---@omw-context menu
local util = require('openmw.util')
local input = require('openmw.input')
local I = require('openmw.interfaces')

-- demo page showcasing every renderer in this mod, delete after screenshots
-- name/description strings double as l10n keys, no l10n files so they show verbatim

-- ------------------------------ page ------------------------------
I.Settings.registerPage {
	key = "DemoRenderers",
	l10n = "DemoRenderers",
	name = "Demo Renderers",
	description = "Every custom settings renderer on one page.",
}

-- ------------------------------ one setting per renderer ------------------------------
I.Settings.registerGroup {
	key = "SettingsPlayerDemoRenderers",
	page = "DemoRenderers",
	l10n = "DemoRenderers",
	name = "Renderers",
	description = "One example per renderer.",
	permanentStorage = false,
	settings = {
		{
			key = "SLIDER",
			name = "SuperSlider6",
			description = "Drag, arrows, mousewheel, text input, reset button, default mark, unit and labels.",
			renderer = "SuperSlider6",
			default = 90,
			argument = {
				min = 0,
				max = 300,
				step = 5,
				default = 90,
				showDefaultMark = true,
				showResetButton = true,
				stepAffectsTextInput = false,
				bottomRow = true,
				tinyReset = true,
				minLabel = "Silent",
				maxLabel = "Loud",
				centerLabel = "Normal",
				unit = "%",
				width = 150,
			},
		},
		-- snapping test, min is not a multiple of step
		{
			key = "SLIDER_OFFGRID",
			name = "SuperSlider6 (off-grid min)",
			description = "min 5, step 10. Dragging to the left end should reach 5, not stop at 10.",
			renderer = "SuperSlider6",
			default = 5,
			argument = {
				min = 5,
				max = 100,
				step = 10,
				default = 5,
				stepAffectsTextInput = true,
				showResetButton = true,
				bottomRow = true,
				width = 150,
			},
		},
		{
			key = "COLOR",
			name = "SuperColorPicker4",
			description = "HSV map, hex/RGB input, preset and history swatches.",
			renderer = "SuperColorPicker4",
			default = util.color.hex("ffcc66"),
			argument = {
				presetColors = {
					"c83c1e", -- HEALTH_COL red
					"9b050a", -- HEALTHLAG_COL red dark
					"3ca01e", -- HEALING_COL green
					"00963c", -- FATIGUE_COL green
					"f3ed16", -- FATIGUELAG_COL yellow
					"35459f", -- MAGICKA_COL blue
					"5a0f8c", -- MAGICKALAG_COL purple
					"caa560", -- fontColor_color_normal
					"d4b77f", -- goldenMix
					"dfc99f", -- FontColor_color_normal_over
					"eee2c9", -- lightText
					"253170", -- fontColor_color_journal_link
					"3a4daf", -- fontColor_color_journal_link_over
					"6070ca", -- FontColor_color_active
					"707ecf", -- fontColor_color_journal_link_pressed
				},
			},
		},
		{
			key = "KEYBIND",
			name = "SuperKeybind2",
			description = "Click to listen, next key binds. Del unbinds, Escape cancels.",
			renderer = "SuperKeybind2",
			default = input.KEY.F,
			argument = {
				default = input.KEY.F,
				showResetButton = true,
			},
		},
		{
			key = "SELECT",
			name = "SuperSelect3",
			description = "Arrow-cycled select with per-item icons and an extra button.",
			renderer = "SuperSelect3",
			default = "Strength",
			argument = {
				items = { "Strength", "Intelligence", "Willpower", "Agility", "Endurance" },
				width = 200,
				textSize = 18,
				icon = {
					Strength     = "icons/k/attribute_strength.dds",
					Intelligence = "icons/k/attribute_int.dds",
					Willpower    = "icons/k/attribute_wilpower.dds",
					Agility      = "icons/k/attribute_agility.dds",
					Endurance    = "icons/k/attribute_endurance.dds",
				},
				buttons = {
					{
						width = 60,
						text = "Export",
						side = "right",
						event = "DemoRenderers_SelectButton",
						eventData = { action = "export" },
					},
				},
			},
		},
		{
			key = "OPT_CHECKBOX",
			name = "OptionalCheckboxRenderer1",
			description = "Checkbox-gated, unchecked resolves to nil.",
			renderer = "OptionalCheckboxRenderer1",
			default = { enabled = false, value = true },
			argument = {
				trueLabel = "On",
				falseLabel = "Off",
			},
		},
		{
			key = "OPT_SELECT",
			name = "OptionalSelectRenderer1",
			description = "Checkbox-gated select.",
			renderer = "OptionalSelectRenderer1",
			default = { enabled = false, value = "center" },
			argument = {
				items = { "center", "left", "right" },
			},
		},
		{
			key = "OPT_TEXTLINE",
			name = "OptionalTextLineRenderer1",
			description = "Checkbox-gated text line.",
			renderer = "OptionalTextLineRenderer1",
			default = { enabled = false, value = "Custom text" },
		},
		{
			key = "OPT_NUMBER",
			name = "OptionalNumberRenderer1",
			description = "Checkbox-gated number.",
			renderer = "OptionalNumberRenderer1",
			default = { enabled = false, value = 10 },
			argument = {
				min = 0,
				max = 100,
				integer = true,
			},
		},
		{
			key = "OPT_COLOR",
			name = "OptionalColorRenderer1",
			description = "Checkbox-gated color.",
			renderer = "OptionalColorRenderer1",
			default = { enabled = false, value = util.color.hex("ffffff") },
		},
	},
}
