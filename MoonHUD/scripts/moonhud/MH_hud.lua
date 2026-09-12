---@omw-context player
-- MH_hud.lua  (PLAYER script)
--
-- On-screen moon phase widget. Structure, drag/scroll handling, border templates
-- and visibility rules follow TimeHUD and LocationHUD so it behaves the same way.
--
-- Reads phases from the MoonTracker interface (MH_tracker.lua), never from the
-- engine directly, so the HUD keeps showing something sensible in interiors.

local ui      = require('openmw.ui')
local util    = require('openmw.util')
local core    = require('openmw.core')
local async   = require('openmw.async')
local storage = require('openmw.storage')
local input   = require('openmw.input')
local types   = require('openmw.types')
self    = require('openmw.self')
local time    = require('openmw_aux.time')
local I       = require('openmw.interfaces')
local v2      = util.vector2

-- Forward declarations for this file's PRIVATE helpers, which were
-- implicit globals. Declared up here rather than as `local function` at
-- each definition, because at least one is referenced above its
-- definition line and a local is not in scope before its declaration.
--
-- NOT localised: createMoonHud, updateMoonDisplay.
-- This mod uses _G as an inter-module bus. MH_settings.lua is
-- require()d into this same environment and calls those by name, and it
-- writes changed setting values back with `_G[setting] = ...`. Making
-- them local does not error -- the call sites are guarded with
-- `if fn then` -- it silently turns every settings callback into a
-- no-op, which is worse.
local refreshUiVisibility, UiModeChanged

MODNAME = 'MoonHUD'

local C = require('scripts.moonhud.MH_constants')
local borderTemplates = require('scripts.moonhud.MH_makeborder')

local generalSection    = storage.playerSection('Settings' .. MODNAME .. 'General')
local appearanceSection = storage.playerSection('Settings' .. MODNAME .. 'Appearance')

require('scripts.moonhud.MH_settings')

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local moonHud        = nil
local moonFlex = nil
local rowFor   = {}          -- moonName -> { icon = elem, text = elem }
local atlasCache = {}
local fadeStartTime = nil
local currentUiMode = nil
local shouldRefreshUiVisibility = nil
local stopTimerFn = nil
local saveData = {}

--------------------------------------------------------------------------------
-- Atlas
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Texture paths
--------------------------------------------------------------------------------
-- ui.texture is called directly, not through pcall. A missing file is not an
-- error: OpenMW logs "Failed to open image: Resource ... not found" and carries
-- on. The only way ui.texture raises is a malformed argument -- a non-string
-- path, or none at all -- which is a bug in this script, and swallowing it would
-- turn a loud, findable failure into a silently blank widget. It would also hide
-- a future change to the binding, which is the opposite of compatibility.
--
-- So the one thing worth checking is checked explicitly, and anything else is
-- allowed to raise.
local function validPath(path)
	return type(path) == 'string' and path ~= ''
end


-- One ui.texture per (moon, phase index), cut out of the sheet by offset.
-- Cached because ui.texture registers a resource each call.
local function atlasTexture(moonName, phaseIndex)
	-- ATLAS_PRESET names a bundled sheet; 'Custom' falls through to ATLAS_PATH.
	local path = C.presetPath(ATLAS_PRESET)
	if path == nil then path = ATLAS_PATH end
	if path == nil or path == '' then path = C.ATLAS_PATH end
	local cell = ATLAS_CELL or C.ATLAS_CELL
	local row  = C.ATLAS_ROW[moonName] or 0

	local id = path .. '|' .. cell .. '|' .. row .. '|' .. phaseIndex
	if atlasCache[id] then return atlasCache[id] end

	if not validPath(path) then return nil end
	local tex = ui.texture {
		path   = path,
		offset = v2(phaseIndex * cell, row * cell),
		size   = v2(cell, cell),
	}
	atlasCache[id] = tex
	return tex
end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------

local function phaseLabel(moon)
	if PHASE_NAMING == 'Value' then return tostring(moon.phaseValue) end
	if PHASE_NAMING == 'Simple' then return moon.bucket end
	return moon.displayName
end

local function lineFor(moon)
	local parts = {}
	if SHOW_MOON_NAMES then parts[#parts + 1] = moon.name .. ':' end
	parts[#parts + 1] = phaseLabel(moon)
	local s = table.concat(parts, ' ')
	if SHOW_SOURCE then s = s .. ' [' .. tostring(moon.source) .. ']' end
	return s
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function textElement(name, size)
	return {
		type = ui.TYPE.Text,
		name = name,
		props = {
			text = '',
			textColor = TEXT_COLOR,
			textShadow = true,
			textShadowColor = util.color.rgba(0, 0, 0, 0.9),
			textAlignV = ui.ALIGNMENT.Center,
			textAlignH = ui.ALIGNMENT.Start,
			textSize = size,
		},
	}
end

local MONTH_INDEX = {}
for i, n in ipairs(C.MONTH_NAMES) do MONTH_INDEX[n] = i end

-- Push the settings-driven anchor into the tracker whenever it changes.
local function syncShadeConfig()
	if not I.MoonTracker or not I.MoonTracker.setShadeConfig then return end
	I.MoonTracker.setShadeConfig {
		ANCHOR_MONTH  = MONTH_INDEX[SHADE_ANCHOR_MONTH] or C.SHADE.ANCHOR_MONTH,
		ANCHOR_DAY    = SHADE_ANCHOR_DAY or C.SHADE.ANCHOR_DAY,
		INTERVAL_DAYS = SHADE_INTERVAL or C.SHADE.INTERVAL_DAYS,
	}
end

local function shadeLabel(shade)
	if shade.active then return 'Shade of the Revenant' end
	if shade.daysUntil == 1 then return 'Shade: tomorrow' end
	return 'Shade: ' .. shade.daysUntil .. ' days (' .. shade.dateString .. ')'
end

-- Which elements are on, in draw order. Triangle needs this as a list.
local function enabledElements()
	local list = {}
	if SHOW_MASSER  then list[#list + 1] = 'Masser'  end
	if SHOW_SECUNDA then list[#list + 1] = 'Secunda' end
	if SHOW_SHADE   then list[#list + 1] = 'Shade'   end
	return list
end

-- The panel fill. A texture path if one is set, otherwise flat black, tinted and
-- faded by the Panel settings.
local function backgroundImage(name, sizeProps)
	-- BACKGROUND_PRESET names a bundled fill. 'None' means flat black, which is
	-- what the panel drew before any of these existed. 'Custom' uses the path.
	local path = C.presetPath(BACKGROUND_PRESET)
	if path == nil and BACKGROUND_PRESET == 'Custom' then path = BACKGROUND_TEXTURE end
	if not validPath(path) then path = 'black' end
	local tex = ui.texture { path = path }

	local props = {
		resource = tex,
		alpha = BACKGROUND_ALPHA,
		color = BACKGROUND_TINT,
	}
	for k, v in pairs(sizeProps or {}) do props[k] = v end
	return { type = ui.TYPE.Image, name = name, props = props }
end

-- Widest label the current settings can produce, in characters. The old
-- heuristic was FONT_SIZE * 5, i.e. it assumed five characters; "Waning
-- Crescent" is fifteen, so descriptive labels spilled out of their cell and got
-- clipped by the neighbouring one.
local function maxLabelChars()
	local longest = 1
	if PHASE_NAMING == 'Value' then
		longest = 1
	elseif PHASE_NAMING == 'Simple' then
		for _, n in pairs(C.BUCKET) do longest = math.max(longest, #n) end
	else
		for _, n in pairs(C.DISPLAY_NAME) do longest = math.max(longest, #n) end
	end
	if SHOW_MOON_NAMES then longest = longest + 9 end   -- "Secunda: "
	if SHOW_SOURCE then longest = longest + 12 end      -- " [projected]"
	return longest
end

-- Rough advance width. Measured against MysticCards at pointsize 32, where six
-- characters trim to 101px, giving 0.53 em; 0.58 leaves a little margin.
local function labelWidth()
	return math.ceil(maxLabelChars() * (FONT_SIZE or 20) * 0.58)
end

-- One triangle vertex: the icon, with its label centred underneath.
local function buildVertex(elementName, cellW, cellH, iconSize, showIcon, showText)
	local content = ui.content {}
	local icon, text

	if showIcon then
		icon = {
			type = ui.TYPE.Image,
			name = 'icon' .. elementName,
			props = {
				resource = atlasTexture(elementName, 0),
				size = v2(iconSize, iconSize),
				-- Must be false, or MyGUI draws the atlas cell at its native 64px
				-- and repeats it to fill the widget. That looks exactly like the
				-- Icon Size setting doing nothing.
				tileH = false,
				tileV = false,
				position = v2(math.floor((cellW - iconSize) / 2), 0),
				alpha = 1,
			},
		}
		content:add(icon)
	end
	if showText then
		text = {
			type = ui.TYPE.Text,
			name = 'text' .. elementName,
			props = {
				text = '',
				textColor = TEXT_COLOR,
				textShadow = true,
				textShadowColor = util.color.rgba(0, 0, 0, 0.9),
				textAlignH = ui.ALIGNMENT.Center,
				textAlignV = ui.ALIGNMENT.Center,
				textSize = FONT_SIZE,
				size = v2(cellW, FONT_SIZE + 2),
				position = v2(0, showIcon and (iconSize + 2) or 0),
			},
		}
		content:add(text)
	end

	rowFor[elementName] = { icon = icon, text = text }

	return {
		type = ui.TYPE.Widget,
		name = 'vertex' .. elementName,
		props = { size = v2(cellW, cellH) },
		content = content,
	}
end

-- Absolute-positioned triangle. Flex cannot do this, so the vertices are placed
-- by hand inside a Widget of known size. Returns the element and its dimensions,
-- which the circular panel needs in order to size itself.
local function buildTriangle(inverted)
	local names = enabledElements()
	local showIcon = DISPLAY_MODE ~= 'Text'
	local showText = DISPLAY_MODE ~= 'Icons'
	local iconSize = ICON_SIZE or 32
	local spread = TRIANGLE_SPREAD or 10

	-- A label is wider than its icon, so the cell has to allow for it.
	local cellW = iconSize
	if showText then cellW = math.max(cellW, labelWidth()) end
	local cellH = (showIcon and iconSize or 0) + (showText and (FONT_SIZE + 2) or 0)

	local w = cellW * 2 + spread
	local h = cellH * 2 + spread

	local slots
	if inverted then
		-- Two across the top, one below the middle.
		slots = {
			v2(0, 0),
			v2(w - cellW, 0),
			v2(math.floor((w - cellW) / 2), cellH + spread),
		}
	else
		-- One on top, two below.
		slots = {
			v2(math.floor((w - cellW) / 2), 0),
			v2(0, cellH + spread),
			v2(w - cellW, cellH + spread),
		}
	end

	local content = ui.content {}
	for i, name in ipairs(names) do
		local slot = slots[i]
		if slot == nil then break end
		local vertex = buildVertex(name, cellW, cellH, iconSize, showIcon, showText)
		vertex.props.position = slot
		content:add(vertex)
	end

	return {
		type = ui.TYPE.Widget,
		name = 'moonTriangle',
		props = { size = v2(w, h) },
		content = content,
	}, w, h
end

local function buildRow(moonName)
	local showIcon = DISPLAY_MODE ~= 'Text'
	local showText = DISPLAY_MODE ~= 'Icons'
	local iconSize = ICON_SIZE or 32

	local content = ui.content {}
	local row = {
		type = ui.TYPE.Flex,
		name = 'row' .. moonName,
		props = {
			horizontal = true,
			autoSize = true,
			align = ui.ALIGNMENT.Center,
			arrange = ui.ALIGNMENT.Center,
		},
		content = content,
	}

	local icon, text
	if showIcon then
		icon = {
			type = ui.TYPE.Image,
			name = 'icon' .. moonName,
			props = {
				resource = atlasTexture(moonName, 0),
				size = v2(iconSize, iconSize),
				-- Must be false, or MyGUI draws the atlas cell at its native 64px
				-- and repeats it to fill the widget. That looks exactly like the
				-- Icon Size setting doing nothing.
				tileH = false,
				tileV = false,
				alpha = 1,
			},
		}
		content:add(icon)
		if showText then
			content:add { name = 'gap', props = { size = v2(ICON_SPACING or 6, 0) } }
		end
	end
	if showText then
		text = textElement('text' .. moonName, FONT_SIZE)
		content:add(text)
	end

	rowFor[moonName] = { icon = icon, text = text }
	return row
end

function createMoonHud()
	syncShadeConfig()
	if moonHud then
		moonHud:destroy()
		moonHud = nil
	end
	rowFor = {}

	local shape = PANEL_SHAPE or 'Rectangle'
	local triangle = (LAYOUT == 'Triangle' or LAYOUT == 'Triangle Inverted')

	-- Build the contents first. The circular panel has to know how big they are.
	local contentElement, contentW, contentH
	if triangle then
		contentElement, contentW, contentH = buildTriangle(LAYOUT == 'Triangle Inverted')
	else
		local arrange = ui.ALIGNMENT.Start
		if TEXT_ALIGNMENT == 'Center' then arrange = ui.ALIGNMENT.Center
		elseif TEXT_ALIGNMENT == 'Right' then arrange = ui.ALIGNMENT.End end

		moonFlex = {
			type = ui.TYPE.Flex,
			name = 'moonFlex',
			props = {
				horizontal = (LAYOUT == 'Horizontal'),
				autoSize = true,
				arrange = arrange,
			},
			content = ui.content {},
		}

		local names = enabledElements()
		for i, name in ipairs(names) do
			if i > 1 then
				local gapSize = (LAYOUT == 'Horizontal')
					and v2((ICON_SPACING or 6) * 2, 0) or v2(0, 2)
				moonFlex.content:add { name = 'gap' .. i, props = { size = gapSize } }
			end
			moonFlex.content:add(buildRow(name))
		end
		contentElement = moonFlex
		-- Flex auto-sizes at layout time, so its dimensions have to be estimated
		-- here for the circle to size itself around it.
		local n = #names
		local showIcon = DISPLAY_MODE ~= 'Text'
		local showText = DISPLAY_MODE ~= 'Icons'
		local iconSize = ICON_SIZE or 32
		local labelW = showText and labelWidth() or 0
		local rowW = (showIcon and iconSize or 0)
			+ ((showIcon and showText) and (ICON_SPACING or 6) or 0) + labelW
		local rowH = math.max(showIcon and iconSize or 0,
			showText and ((FONT_SIZE or 20) + 2) or 0)
		if LAYOUT == 'Horizontal' then
			contentW = rowW * n + (ICON_SPACING or 6) * 2 * (n - 1)
			contentH = rowH
		else
			contentW = rowW
			contentH = rowH * n + 2 * (n - 1)
		end
	end

	local anchorPoint = v2(0, 0)
	if TEXT_ALIGNMENT == 'Center' then anchorPoint = v2(0.5, 0)
	elseif TEXT_ALIGNMENT == 'Right' then anchorPoint = v2(1, 0) end

	local pad = v2(HUD_PADDING or 0, HUD_PADDING or 0)

	if shape == 'Circle' then
		-- A round plate needs an explicit square canvas, so this branch uses a
		-- Widget with a known size rather than an auto-sizing Container.
		local diameter = CIRCLE_SIZE or 0
		if diameter <= 0 then
			-- The circle has to enclose the content box, so the governing figure
			-- is its diagonal, not its longer side. max(w,h) * 1.35 happens to
			-- land close for a square triangle layout but is badly oversized for
			-- a tall stack: a 40x124 vertical layout needs 130, not 175.
			local cw, ch = contentW or 0, contentH or 0
			if cw <= 0 or ch <= 0 then
				local fallback = (ICON_SIZE or 32) * 3
				cw, ch = fallback, fallback
			end
			local diagonal = math.sqrt(cw * cw + ch * ch)
			diameter = math.ceil(diagonal * 1.06) + (HUD_PADDING or 0) * 2
		end

		local content = ui.content {}

		content:add(backgroundImage('moonHudBackground', {
			size = v2(diameter, diameter),
			position = v2(0, 0),
		}))

		if CIRCLE_BORDER and validPath(CIRCLE_BORDER_TEXTURE) then
			local ringTex = ui.texture { path = CIRCLE_BORDER_TEXTURE }
			do
				content:add {
					type = ui.TYPE.Image,
					name = 'moonHudRing',
					props = {
						resource = ringTex,
						size = v2(diameter, diameter),
						position = v2(0, 0),
						color = CIRCLE_BORDER_COLOR,
					},
				}
			end
		end

		-- Centre the contents on the plate.
		local holder = {
			type = ui.TYPE.Widget,
			name = 'moonHolder',
			props = {
				size = v2(diameter, diameter),
				position = v2(0, 0),
			},
			content = ui.content { contentElement },
		}
		-- Centre the contents on the plate whatever the layout. Previously only
		-- the triangle was centred and everything else sat at top-left plus
		-- padding, which pushed a vertical stack off the edge of the circle.
		contentElement.props.position = v2(
			math.floor((diameter - (contentW or 0)) / 2),
			math.floor((diameter - (contentH or 0)) / 2))
		content:add(holder)

		moonHud = ui.create {
			type = ui.TYPE.Widget,
			layer = HUD_LOCK and 'Scene' or 'Modal',
			name = 'moonHud',
			props = {
				position = v2(HUD_X_POS, HUD_Y_POS),
				size = v2(diameter, diameter),
				anchor = anchorPoint,
			},
			content = content,
			userData = {},
		}

	else
		-- None or Rectangle: the original auto-sizing Container plus 9-slice border.
		local background = backgroundImage('moonHudBackground', { relativeSize = v2(1, 1) })
		if shape == 'None' then background.props.alpha = 0 end

		local template, paddingTemplate
		if shape == 'Rectangle' and HUD_BORDER then
			local borderFile = (HUD_BORDER_STYLE == 'thick' or HUD_BORDER_STYLE == 'verythick')
				and 'thick' or 'thin'
			local borderOffset =
				HUD_BORDER_STYLE == 'verythick' and 4
				or HUD_BORDER_STYLE == 'thick' and 3
				or HUD_BORDER_STYLE == 'normal' and 2
				or 1
			local borders = borderTemplates(borderFile, HUD_BORDER_COLOR, borderOffset, background, pad)
			template = borders.borders
			paddingTemplate = borders.padding
		else
			template = { content = ui.content {} }
			template.content:add(background)
			if (HUD_PADDING or 0) > 0 then
				paddingTemplate = {
					type = ui.TYPE.Container,
					content = ui.content {
						{ props = { size = pad } },
						{ external = { slot = true }, props = { position = pad, relativeSize = v2(1, 1) } },
						{ props = { position = pad, relativePosition = v2(1, 1), size = pad } },
					},
				}
			end
		end

		moonHud = ui.create {
			type = ui.TYPE.Container,
			layer = HUD_LOCK and 'Scene' or 'Modal',
			name = 'moonHud',
			template = template,
			props = {
				position = v2(HUD_X_POS, HUD_Y_POS),
				anchor = anchorPoint,
			},
			content = ui.content {},
			userData = { windowStartPosition = v2(HUD_X_POS, HUD_Y_POS) },
		}

		if paddingTemplate then
			moonHud.layout.content:add {
				template = paddingTemplate,
				content = ui.content { contentElement },
			}
		else
			moonHud.layout.content:add(contentElement)
		end
	end

	-- Drag to reposition, exactly as TimeHUD does it.
	moonHud.layout.events = {
		mousePress = async:callback(function(data, elem)
			if data.button == 1 and not HUD_LOCK then
				elem.userData = elem.userData or {}
				elem.userData.isDragging = true
				elem.userData.lastMousePos = data.position
			end
			moonHud:update()
		end),
		mouseRelease = async:callback(function(_, elem)
			if elem.userData then elem.userData.isDragging = false end
			moonHud:update()
		end),
		mouseMove = async:callback(function(data, elem)
			if elem.userData and elem.userData.isDragging then
				local delta = data.position - elem.userData.lastMousePos
				elem.userData.lastMousePos = data.position
				local newPosition = (moonHud.layout.props.position or v2(0, 0)) + delta
				generalSection:set('HUD_X_POS', math.floor(newPosition.x))
				generalSection:set('HUD_Y_POS', math.floor(newPosition.y))
				moonHud.layout.props.position = newPosition
				moonHud:update()
			end
		end),
	}

	updateMoonDisplay(true)
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

local lastSignature = nil

function updateMoonDisplay(force)
	if not moonHud then return end
	if not I.MoonTracker then
		refreshUiVisibility()
		return
	end

	local moons = I.MoonTracker.getMoons()
	local shade = I.MoonTracker.getShade and I.MoonTracker.getShade() or nil
	local signature = ''
	for _, name in ipairs(C.MOON_NAMES) do
		local m = moons[name]
		signature = signature .. name .. (m and (m.index .. (m.source or '')) or '-')
	end
	if shade then signature = signature .. '|S' .. shade.daysUntil end
	if not force and signature == lastSignature then
		refreshUiVisibility()
		return
	end
	lastSignature = signature

	for name, elems in pairs(rowFor) do
		local moon = moons[name]
		if name == 'Shade' then
			local visible = shade ~= nil
				and (SHADE_DISPLAY ~= 'Only When Active' or shade.active)
			if elems.icon then
				local cell = (shade and shade.active and SHADE_DISPLAY ~= 'Countdown Only')
					and C.ATLAS_SHADE_ACTIVE or C.ATLAS_SHADE_INACTIVE
				local tex = atlasTexture('Shade', cell)
				if tex then elems.icon.props.resource = tex end
				elems.icon.props.size = v2(ICON_SIZE, ICON_SIZE)
				elems.icon.props.visible = visible
				elems.icon.props.alpha = 1
			end
			if elems.text then
				elems.text.props.text = shade and shadeLabel(shade) or 'Shade: ?'
				elems.text.props.textColor = TEXT_COLOR
				elems.text.props.textSize = FONT_SIZE
				elems.text.props.visible = visible
			end
		elseif moon then
			if elems.icon then
				local tex = atlasTexture(name, moon.index)
				if tex then elems.icon.props.resource = tex end
				elems.icon.props.size = v2(ICON_SIZE, ICON_SIZE)
				if DIM_WITH_ALPHA and moon.alpha ~= nil then
					elems.icon.props.alpha = 0.25 + 0.75 * moon.alpha
				else
					elems.icon.props.alpha = 1
				end
			end
			if elems.text then
				elems.text.props.text = lineFor(moon)
				elems.text.props.textColor = TEXT_COLOR
				elems.text.props.textSize = FONT_SIZE
			end
		elseif elems.text then
			elems.text.props.text = (SHOW_MOON_NAMES and (name .. ': ') or '') .. '?'
		end
	end

	moonHud:update()
	refreshUiVisibility()
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

local function chargenFinished()
	if saveData.chargenFinished then return true end
	if types.Player.isCharGenFinished and types.Player.isCharGenFinished(self) then
		saveData.chargenFinished = true
		return true
	end
	if types.Player.getBirthSign(self) ~= '' then
		saveData.chargenFinished = true
		return true
	end
	return false
end

local function anyMoonVisible()
	if not I.MoonTracker then return true end
	local moons = I.MoonTracker.getMoons()
	local sawAlpha = false
	for _, m in pairs(moons) do
		if m.alpha ~= nil then
			sawAlpha = true
			if m.alpha > 0.01 then return true end
		end
	end
	-- No alpha data means we are indoors or the cell is inactive; do not hide
	-- on the strength of a guess.
	return not sawAlpha
end

function refreshUiVisibility()
	if not moonHud then return end

	local allowed = chargenFinished()
		and I.UI.isHudVisible()
		and (not HUD_EXTERIOR or self.cell:hasTag('QuasiExterior') or self.cell.isExterior)
		and (not HUD_NIGHT_ONLY or anyMoonVisible())

	local visible
	if not allowed then
		visible = false
	elseif HUD_DISPLAY == 'Always' then
		visible = true
	elseif HUD_DISPLAY == 'Never' then
		visible = false
	elseif HUD_DISPLAY == 'Interface Only' then
		visible = currentUiMode == 'Interface'
	elseif HUD_DISPLAY == 'Hide on Interface' then
		visible = currentUiMode == nil
	else -- Hide on Dialogue Only
		visible = currentUiMode ~= 'Dialogue' and currentUiMode ~= 'Barter'
	end

	if visible and SHOW_MODE == 'On Phase Change' and fadeStartTime == nil then
		visible = false
	end

	moonHud.layout.props.visible = visible
	moonHud:update()
end

--------------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------------

local function onFrame()
	if shouldRefreshUiVisibility then
		shouldRefreshUiVisibility = shouldRefreshUiVisibility - 1
		if shouldRefreshUiVisibility <= 0 then
			shouldRefreshUiVisibility = nil
			refreshUiVisibility()
		end
	end

	if fadeStartTime and moonHud then
		local elapsed = core.getSimulationTime() - fadeStartTime
		if elapsed < HOLD_DURATION then
			moonHud.layout.props.alpha = 1
		elseif elapsed < HOLD_DURATION + FADE_DURATION then
			moonHud.layout.props.alpha = 1 - (elapsed - HOLD_DURATION) / math.max(FADE_DURATION, 0.001)
			moonHud:update()
		else
			moonHud.layout.props.alpha = 0
			fadeStartTime = nil
			refreshUiVisibility()
		end
	end
end

function UiModeChanged(data)
	if not moonHud then return end
	currentUiMode = data.newMode
	refreshUiVisibility()
	shouldRefreshUiVisibility = 3
	if data.oldMode == 'Rest' then updateMoonDisplay(true) end
end

local function onPhaseChanged(data)
	updateMoonDisplay(true)
	if SHOW_MODE == 'On Phase Change' then
		fadeStartTime = core.getSimulationTime()
		if moonHud then moonHud.layout.props.alpha = 1 end
		refreshUiVisibility()
	end
end

local function onLoad(data)
	saveData = data or {}

	local layerId = ui.layers.indexOf('HUD')
	local hudLayerSize = ui.layers[layerId].size
	generalSection:set('HUD_X_POS', math.floor(math.max(-200, math.min(HUD_X_POS, hudLayerSize.x + 200))))
	generalSection:set('HUD_Y_POS', math.floor(math.max(-50, math.min(HUD_Y_POS, hudLayerSize.y - 20))))

	syncShadeConfig()
	createMoonHud()

	if stopTimerFn then stopTimerFn() end
	stopTimerFn = time.runRepeatedly(function() updateMoonDisplay(false) end,
		(UPDATE_INTERVAL or 30) * time.minute, {
			type = time.GameTime,
			initialDelay = 0,
		})
end

-- Click-and-scroll resize, same gesture as TimeHUD.
if input.triggers['MenuMouseWheelUp'] then
	input.registerTriggerHandler('MenuMouseWheelUp', async:callback(function()
		if moonHud and moonHud.layout.userData and moonHud.layout.userData.isDragging then
			if input.isShiftPressed() then
				appearanceSection:set('BACKGROUND_ALPHA', math.min(1, BACKGROUND_ALPHA + 0.1))
			else
				appearanceSection:set('FONT_SIZE', FONT_SIZE + 1)
			end
		end
	end))
end
if input.triggers['MenuMouseWheelDown'] then
	input.registerTriggerHandler('MenuMouseWheelDown', async:callback(function()
		if moonHud and moonHud.layout.userData and moonHud.layout.userData.isDragging then
			if input.isShiftPressed() then
				appearanceSection:set('BACKGROUND_ALPHA', math.max(0, BACKGROUND_ALPHA - 0.1))
			else
				appearanceSection:set('FONT_SIZE', math.max(5, FONT_SIZE - 1))
			end
		end
	end))
end

input.registerTriggerHandler('ToggleHUD', async:callback(function()
	refreshUiVisibility()
end))

return {
	engineHandlers = {
		onInit = onLoad,
		onLoad = onLoad,
		onSave = function() return saveData end,
		onFrame = onFrame,
	},
	eventHandlers = {
		UiModeChanged = UiModeChanged,
		MoonTracker_PhaseChanged = onPhaseChanged,
		MoonTracker_ShadeOfTheRevenant = onPhaseChanged,
	},
}
