---@omw-context menu
local ui = require('openmw.ui')
local util = require('openmw.util')
local async = require('openmw.async')
local core = require('openmw.core')
local storage = require('openmw.storage')
local I = require('openmw.interfaces')

-- Checkbox gated versions of the engine settings renderers.
-- unchecked settings resolve to nil.
--
-- Example:
-- {
-- 	key = "TOOLTIP_TEXT_ALIGNMENT",
-- 	name = "Tooltip text alignment",
-- 	renderer = "OptionalSelectRenderer1",
-- 	default = {
-- 		enabled = false, -- whether the setting applies
-- 		value = "center", -- plain value the wrapped control edits
-- 	},
-- 	argument = {
-- 		disabled = false, -- default: false, grays out the whole row, all renderers
-- 		l10n = "none", -- default: "none" (select), "Interface" (checkbox)
-- 		items = {"center", "left", "right"}, -- required, select only
-- 		trueLabel = "Yes", -- default: "Yes", checkbox only
-- 		falseLabel = "No", -- default: "No", checkbox only
-- 		min = 0, -- default: nil, number only
-- 		max = 100, -- default: nil, number only
-- 		integer = false, -- default: false, number only
-- 	},
-- },
--
-- stored values:
-- { enabled = boolean, value = <plain value> }
-- readers should treat the setting as absent while enabled is false

local OPTIONAL_SELECT_RENDERER_ID = "OptionalSelectRenderer1"
local OPTIONAL_CHECKBOX_RENDERER_ID = "OptionalCheckboxRenderer1"
local OPTIONAL_TEXTLINE_RENDERER_ID = "OptionalTextLineRenderer1"
local OPTIONAL_NUMBER_RENDERER_ID = "OptionalNumberRenderer1"
local OPTIONAL_COLOR_RENDERER_ID = "OptionalColorRenderer1"

-- session only installed flags for other mods, eg. "OptionalSelectRenderer1" = true, "OptionalSelectRenderer" = 1
local installedRenderers = storage.playerSection("InstalledSettingsRenderers")
installedRenderers:setLifeTime(storage.LIFE_TIME.GameSession)
for _, rendererId in ipairs({
	OPTIONAL_SELECT_RENDERER_ID,
	OPTIONAL_CHECKBOX_RENDERER_ID,
	OPTIONAL_TEXTLINE_RENDERER_ID,
	OPTIONAL_NUMBER_RENDERER_ID,
	OPTIONAL_COLOR_RENDERER_ID,
}) do
	installedRenderers:set(rendererId, true)
	local familyKey, familyVersion = rendererId:match("^(.-)(%d+)$")
	if (installedRenderers:get(familyKey) or 0) < tonumber(familyVersion) then
		installedRenderers:set(familyKey, tonumber(familyVersion))
	end
end

local leftArrow = ui.texture { path = 'textures/omw_menu_scroll_left.dds' }
local rightArrow = ui.texture { path = 'textures/omw_menu_scroll_right.dds' }
local whiteTexture = ui.texture { path = 'white' }
local checkColor = I.MWUI.templates.textHeader.props.textColor

-- ------------------------------ Helper Functions ------------------------------

local function applyDefaults(argument, defaults)
	if not argument then return defaults end
	if pairs(defaults) and pairs(argument) then
		local result = {}
		for k, v in pairs(defaults) do
			result[k] = v
		end
		for k, v in pairs(argument) do
			result[k] = v
		end
		return result
	end
	return argument
end

local function disable(disabled, layout)
	if disabled then
		return {
			template = I.MWUI.templates.disabled,
			content = ui.content {
				layout,
			},
		}
	else
		return layout
	end
end

local function paddedBox(layout)
	return {
		template = I.MWUI.templates.box,
		content = ui.content {
			{
				template = I.MWUI.templates.padding,
				content = ui.content { layout },
			},
		},
	}
end

-- storage may hand stored tables back as userdata
local function unpackValue(value)
	local valueType = type(value)
	if valueType == "table" or valueType == "userdata" then
		local ok, enabled = pcall(function() return value.enabled end)
		if ok and enabled ~= nil then
			return enabled == true, value.value
		end
	end
	return value ~= nil, value
end

-- small toggle box behind the actual control
local function makeEnableBox(enabled, set, innerValue)
	local toggleEnabled = async:callback(function()
		set({
			enabled = not enabled,
			value = innerValue,
		})
	end)
	-- checkbox frame
	return {
		template = I.MWUI.templates.box,
		content = ui.content {
			-- click area
			{
				type = ui.TYPE.Widget,
				props = {
					size = util.vector2(14, 14),
				},
				content = ui.content {
					-- check fill
					{
						type = ui.TYPE.Image,
						props = {
							resource = whiteTexture,
							color = checkColor,
							alpha = enabled and 1 or 0,
							position = util.vector2(3, 3),
							size = util.vector2(8, 8),
						},
					},
				},
			},
		},
		events = {
			mouseClick = toggleEnabled,
		},
	}
end

-- control plus checkbox, the control grays out while unchecked
local function makeRow(enabled, enableBox, innerLayout)
	return {
		type = ui.TYPE.Flex,
		props = {
			horizontal = true,
			arrange = ui.ALIGNMENT.Center,
		},
		content = ui.content {
			disable(not enabled, innerLayout),
			{ template = I.MWUI.templates.interval },
			enableBox,
		},
	}
end

-- ------------------------------ Select Renderer ------------------------------

local selectDefaultArgument = {
	disabled = false,
	l10n = "none",
	items = {},
}

I.Settings.registerRenderer(OPTIONAL_SELECT_RENDERER_ID, function(value, set, argument)
	argument = applyDefaults(argument, selectDefaultArgument)
	if #argument.items == 0 then
		error('"' .. OPTIONAL_SELECT_RENDERER_ID .. '" requires an "items" array as an argument')
	end
	local enabled, innerValue = unpackValue(value)
	if innerValue == nil then
		innerValue = argument.items[1]
	end
	local l10n = core.l10n(argument.l10n)
	local itemCount = #argument.items
	local index = nil
	for i, item in ipairs(argument.items) do
		if item == innerValue then
			index = i
		end
	end
	-- unknown values render red like the engine select
	local labelColor = nil
	if index == nil then
		labelColor = util.color.rgb(1, 0, 0)
	end
	local function setItem(newIndex)
		set({
			enabled = enabled,
			value = argument.items[newIndex],
		})
	end
	local selectPrevious = async:callback(function()
		if not index then
			setItem(itemCount)
			return
		end
		setItem((index - 2) % itemCount + 1)
	end)
	local selectNext = async:callback(function()
		if not index then
			setItem(1)
			return
		end
		setItem(index % itemCount + 1)
	end)
	-- select body
	local selectBody = {
		type = ui.TYPE.Flex,
		props = {
			horizontal = true,
			arrange = ui.ALIGNMENT.Center,
		},
		content = ui.content {
			-- left arrow
			{
				type = ui.TYPE.Image,
				props = {
					resource = leftArrow,
					size = util.vector2(12, 12),
				},
				events = {
					mouseClick = selectPrevious,
				},
			},
			{ template = I.MWUI.templates.interval },
			-- item label
			{
				template = I.MWUI.templates.textNormal,
				props = {
					text = l10n(tostring(innerValue)),
					textColor = labelColor,
				},
				external = {
					grow = 1,
				},
			},
			{ template = I.MWUI.templates.interval },
			-- right arrow
			{
				type = ui.TYPE.Image,
				props = {
					resource = rightArrow,
					size = util.vector2(12, 12),
				},
				events = {
					mouseClick = selectNext,
				},
			},
		},
	}
	return disable(argument.disabled, makeRow(enabled, makeEnableBox(enabled, set, innerValue), paddedBox(selectBody)))
end)

-- ------------------------------ Checkbox Renderer ------------------------------

local checkboxDefaultArgument = {
	disabled = false,
	l10n = "Interface",
	trueLabel = "Yes",
	falseLabel = "No",
}

I.Settings.registerRenderer(OPTIONAL_CHECKBOX_RENDERER_ID, function(value, set, argument)
	argument = applyDefaults(argument, checkboxDefaultArgument)
	local enabled, innerValue = unpackValue(value)
	innerValue = innerValue == true
	local l10n = core.l10n(argument.l10n)
	local toggleValue = async:callback(function()
		set({
			enabled = enabled,
			value = not innerValue,
		})
	end)
	-- yes no box
	local checkboxBody = paddedBox {
		template = I.MWUI.templates.padding,
		content = ui.content {
			-- state label
			{
				template = I.MWUI.templates.textNormal,
				props = {
					text = l10n(innerValue and argument.trueLabel or argument.falseLabel),
				},
			},
		},
	}
	checkboxBody.events = {
		mouseClick = toggleValue,
	}
	return disable(argument.disabled, makeRow(enabled, makeEnableBox(enabled, set, innerValue), checkboxBody))
end)

-- ------------------------------ TextLine Renderer ------------------------------

local textLineDefaultArgument = {
	disabled = false,
}

I.Settings.registerRenderer(OPTIONAL_TEXTLINE_RENDERER_ID, function(value, set, argument)
	argument = applyDefaults(argument, textLineDefaultArgument)
	local enabled, innerValue = unpackValue(value)
	if innerValue == nil then
		innerValue = ""
	end
	-- text input
	local textLineBody = paddedBox {
		template = I.MWUI.templates.textEditLine,
		props = {
			text = tostring(innerValue),
		},
		events = {
			textChanged = async:callback(function(text)
				set({
					enabled = enabled,
					value = text,
				})
			end),
		},
	}
	return disable(argument.disabled, makeRow(enabled, makeEnableBox(enabled, set, innerValue), textLineBody))
end)

-- ------------------------------ Number Renderer ------------------------------

local function validateNumber(text, argument)
	local number = tonumber(text)
	if not number then return end
	if argument.min and number < argument.min then return end
	if argument.max and number > argument.max then return end
	if argument.integer and math.floor(number) ~= number then return end
	return number
end

local numberDefaultArgument = {
	disabled = false,
	integer = false,
	min = nil,
	max = nil,
}

I.Settings.registerRenderer(OPTIONAL_NUMBER_RENDERER_ID, function(value, set, argument)
	argument = applyDefaults(argument, numberDefaultArgument)
	local enabled, innerValue = unpackValue(value)
	local lastInput = nil
	-- number input
	local numberBody = paddedBox {
		template = I.MWUI.templates.textEditLine,
		props = {
			text = innerValue ~= nil and tostring(innerValue) or "",
			size = util.vector2(80, 0),
		},
		events = {
			textChanged = async:callback(function(text)
				lastInput = text
			end),
			focusLoss = async:callback(function()
				if not lastInput then return end
				local number = validateNumber(lastInput, argument)
				if not number then
					set({
						enabled = enabled,
						value = innerValue,
					})
				elseif number ~= innerValue then
					set({
						enabled = enabled,
						value = number,
					})
				end
			end),
		},
	}
	return disable(argument.disabled, makeRow(enabled, makeEnableBox(enabled, set, innerValue), numberBody))
end)

-- ------------------------------ Color Renderer ------------------------------

local colorDefaultArgument = {
	disabled = false,
}

I.Settings.registerRenderer(OPTIONAL_COLOR_RENDERER_ID, function(value, set, argument)
	argument = applyDefaults(argument, colorDefaultArgument)
	local enabled, innerValue = unpackValue(value)
	if innerValue == nil then
		innerValue = util.color.rgb(1, 1, 1)
	end
	local lastInput = nil
	-- color swatch
	local colorDisplay = {
		template = I.MWUI.templates.box,
		content = ui.content {
			{
				type = ui.TYPE.Image,
				props = {
					resource = whiteTexture,
					color = innerValue,
					size = util.vector2(20, 20),
				},
			},
		},
	}
	-- hex input
	local hexInput = paddedBox {
		template = I.MWUI.templates.textEditLine,
		props = {
			text = innerValue:asHex(),
		},
		events = {
			textChanged = async:callback(function(text)
				lastInput = text
			end),
			focusLoss = async:callback(function()
				if not lastInput then return end
				local ok, parsedColor = pcall(util.color.hex, lastInput)
				set({
					enabled = enabled,
					value = ok and parsedColor or innerValue,
				})
			end),
		},
	}
	-- swatch plus input
	local colorBody = {
		type = ui.TYPE.Flex,
		props = {
			horizontal = true,
			arrange = ui.ALIGNMENT.Center,
		},
		content = ui.content {
			colorDisplay,
			{ template = I.MWUI.templates.interval },
			hexInput,
		},
	}
	return disable(argument.disabled, makeRow(enabled, makeEnableBox(enabled, set, innerValue), colorBody))
end)