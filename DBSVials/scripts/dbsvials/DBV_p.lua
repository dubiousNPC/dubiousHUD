---@omw-context player
--------------------------------------------------------------------------------
-- DBSVials -- dbsHUD
--------------------------------------------------------------------------------
-- Health and stamina as glass vials that fill from the bottom; magicka as a
-- column of eight runes whose glow goes out an eighth at a time.
--
-- Built after ErnMMUI, which is the reference for reading the player's dynamic
-- stats and for keeping a stats HUD honest about when it actually needs to
-- redraw. The rendering is different: ErnMMUI stretches a gradient across a
-- horizontal bar, this fills a vertical tube behind a fixed piece of glass.
--
--------------------------------------------------------------------------------
-- What this costs per frame
--------------------------------------------------------------------------------
-- onUpdate reads three stats, divides, and quantises. If nothing quantised has
-- moved it returns without touching the UI. It allocates nothing in the common
-- path: no tables, no textures, no vectors beyond the two the engine needs when
-- a value genuinely changed.
--
-- The quantisation is the whole trick. A vial is redrawn only when the fill
-- crosses a whole *pixel row* of its own height, so a 139px vial has at most
-- 139 distinct states however smoothly health regenerates. A rune is redrawn
-- only when it lights or goes out -- eight states, or 16 alpha steps when the
-- partial rune is set to fade. Without that, regenerating fatigue would rebuild
-- the widget every frame for a change nobody can see.
--
-- Every texture is built once at load. The eight glow slices are cut from
-- KainGame_RUNES_GLOW by offset and size, so there is one texture per rune and
-- none of them are ever rebuilt -- not even on resize, because a ui.texture's
-- offset and size are in texture pixels and have nothing to do with how big the
-- widget is drawn.
--
-- There is no pcall anywhere in this mod. See README.
--------------------------------------------------------------------------------

local ui      = require('openmw.ui')
local util    = require('openmw.util')
local storage = require('openmw.storage')
local async   = require('openmw.async')
local core    = require('openmw.core')
local self_   = require('openmw.self')
local types   = require('openmw.types')
local input   = require('openmw.input')
local I       = require('openmw.interfaces')

local v2 = util.vector2

-- NOT localised: buildVialsHud, applyVialStyle.
-- This mod uses _G as an inter-module bus. DBV_settings.lua is require()d into
-- this same environment and calls those by name, and it writes changed setting
-- values back with `_G[setting] = ...`. Making them local does not error -- the
-- call sites there are guarded with `if fn then` -- it silently turns every
-- settings callback into a no-op, which is worse.
local refreshUiVisibility, UiModeChanged

MODNAME = 'DBSVials'

--------------------------------------------------------------------------------
-- The art
--------------------------------------------------------------------------------
-- KainGameRUNES.png and KainGame_RUNES_GLOW.png are both 70 x 328, registered
-- pixel-for-pixel with each other: every glow shape sits behind its own rune.
--
-- Only the top 276 rows carry art. The remaining 52 are empty padding, and the
-- textures are shipped exactly as supplied rather than cropped -- the widget
-- reads rows 0..275 and simply never looks at the tail, so there is no dead
-- space under the bottom rune and nothing was destroyed to get that.
local RUNE_SHEET_W    = 70
local RUNE_CONTENT_H  = 276

-- Row boundaries between the eight runes, measured from the two sheets rather
-- than assumed even: the runes are hand-drawn and their heights differ by up to
-- 17px. Seven of the eight cuts fall in rows where both sheets are empty. The
-- exception is between runes 6 and 7, where the glow bridges rows 203-206 while
-- the base runes are already apart; that cut is placed at 205, the narrowest
-- point of the bridge.
local RUNE_CUTS  = { 0, 33, 70, 110, 139, 170, 205, 232, 276 }
local RUNE_COUNT = #RUNE_CUTS - 1

-- The glass is 13 x 139 and almost entirely transparent -- it is a highlight
-- streak and a foot, not a container. That is why the colour goes behind it and
-- spans the full width: there is no rim to stay inside of.
local GLASS_DEFAULT = 'textures/dbsvials/glass_tube.png'
local RUNES_PATH    = 'textures/dbsvials/KainGameRUNES.png'
local GLOW_PATH     = 'textures/dbsvials/KainGame_RUNES_GLOW.png'

-- Quantisation for anything that fades. 16 steps is below what anyone can
-- distinguish on a HUD element this size and caps how often a fade can poke the
-- UI, which is the point.
local ALPHA_STEPS = 16

local borderTemplates = require('scripts.dbsvials.DBV_border')

local generalSection = storage.playerSection('Settings' .. MODNAME .. 'General')

require('scripts.dbsvials.DBV_settings')

--------------------------------------------------------------------------------
-- Stats
--------------------------------------------------------------------------------
-- These are live accessors, not snapshots: reading .current on one of them
-- gives the present value. Resolving them once at load rather than per frame
-- is what makes the read side of onUpdate free.
local healthStat  = types.Actor.stats.dynamic.health(self_)
local fatigueStat = types.Actor.stats.dynamic.fatigue(self_)
local magickaStat = types.Actor.stats.dynamic.magicka(self_)

--- Current value and maximum of a dynamic stat.
--- Maximum is base + modifier, so fortify and drain effects move it, matching
--- what the engine's own bars do.
local function statPair(stat)
	local maxv = (stat.base or 0) + (stat.modifier or 0)
	if maxv < 1 then maxv = 1 end
	local cur = stat.current or 0
	if cur < 0 then cur = 0 end
	if cur > maxv then cur = maxv end
	return cur, maxv
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vialsHud                          -- root element
local vialsBackground                   -- the panel image, when enabled

-- Layout tables per meter, filled by buildVialsHud. Holding the layout tables
-- directly is what lets onUpdate poke a prop without walking the tree.
local parts = {
	health  = { fill = nil, empty = nil, glass = nil, text = nil, wrap = nil },
	stamina = { fill = nil, empty = nil, glass = nil, text = nil, wrap = nil },
	magicka = { base = nil, glows = {}, text = nil, wrap = nil },
}

-- Pre-built textures. Rebuilt only when GLASS_TEXTURE changes.
local glowTex   = {}
local runeTex
local glassTex
local whiteTex

-- Quantised state. -1 means "nothing drawn yet", which forces the first pass
-- through onUpdate to apply everything.
local lastHealthStep  = -1
local lastStaminaStep = -1
local lastRuneLit     = -1
local lastRunePartial = -1
local lastPulse       = { health = -1, stamina = -1, magicka = -1 }
local lastText        = { health = nil, stamina = nil, magicka = nil }

local pulseClock      = 0
local currentUiMode   = nil

--------------------------------------------------------------------------------
-- Texture building
--------------------------------------------------------------------------------

--- True for a texture path that is worth handing to ui.texture.
--- Checked rather than guarded with pcall: an empty path is a legitimate
--- setting here (it means "no glass"), so it is a value to test, not a fault
--- to catch.
local function validPath(p)
	return type(p) == 'string' and p ~= ''
end

local function buildTextures()
	whiteTex = ui.texture { path = 'white' }

	runeTex = ui.texture {
		path   = RUNES_PATH,
		offset = v2(0, 0),
		size   = v2(RUNE_SHEET_W, RUNE_CONTENT_H),
	}

	for i = 1, RUNE_COUNT do
		local y0, y1 = RUNE_CUTS[i], RUNE_CUTS[i + 1]
		glowTex[i] = ui.texture {
			path   = GLOW_PATH,
			offset = v2(0, y0),
			size   = v2(RUNE_SHEET_W, y1 - y0),
		}
	end

	local gp = GLASS_TEXTURE
	if not validPath(gp) then gp = nil end
	glassTex = gp and ui.texture { path = gp } or nil
end

--------------------------------------------------------------------------------
-- Which runes are lit
--------------------------------------------------------------------------------
-- Rune k covers the magicka band [(k-1)/8, k/8]. It is lit whenever that band
-- holds anything at all, which is what "goes out when its eighth is spent and
-- comes back the moment it starts to refill" means: the boundary is at any
-- fill, not at half or full.
--
-- Returns the number of lit runes and, separately, how full the topmost lit
-- one is, quantised to ALPHA_STEPS. The caller only uses the second when
-- GLOW_PARTIAL is on, but computing it is two arithmetic ops and keeping it out
-- of the branch keeps the early-out check in one place.
local function runeState(frac)
	if frac <= 0 then return 0, 0 end
	if frac >= 1 then return RUNE_COUNT, ALPHA_STEPS end

	local scaled  = frac * RUNE_COUNT
	local whole   = math.floor(scaled)
	local partial = scaled - whole

	if partial > 0 then
		-- The partial rune is lit too -- it has something in it.
		return whole + 1, math.max(1, math.floor(partial * ALPHA_STEPS + 0.5))
	end
	return whole, ALPHA_STEPS
end

--- Maps a rune's position in the column (1 = top of the art) to its place in
--- the fill order. Filling from the bottom means the last rune lights first.
local function runeSlotFor(index)
	if RUNE_FILL_FROM == 'Top' then return index end
	return RUNE_COUNT + 1 - index
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local function vialSize()
	return math.max(4, math.floor(VIAL_WIDTH or 13)),
	       math.max(8, math.floor(VIAL_HEIGHT or 139))
end

local function runeSize()
	return math.max(8, math.floor(RUNE_WIDTH or 35)),
	       math.max(16, math.floor(RUNE_HEIGHT or 139))
end

--------------------------------------------------------------------------------
-- Layout construction
--------------------------------------------------------------------------------

local function imageLayout(name, resource, tint, alpha, relPos, relSize)
	return {
		type = ui.TYPE.Image,
		name = name,
		props = {
			resource = resource,
			relativePosition = relPos or v2(0, 0),
			relativeSize = relSize or v2(1, 1),
			color = tint,
			alpha = alpha,
			-- Without both of these MyGUI tiles the texture at its native size
			-- instead of stretching it, and the widget stops being resizable.
			tileH = false,
			tileV = false,
		},
	}
end

local function textLayout(name, size, color)
	return {
		type = ui.TYPE.Text,
		name = name,
		props = {
			text = '',
			textSize = size,
			textColor = color,
			textShadow = true,
			textShadowColor = util.color.rgba(0, 0, 0, 0.9),
			textAlignH = ui.ALIGNMENT.Center,
			textAlignV = ui.ALIGNMENT.Center,
		},
	}
end

--- One vial: the empty wash, the fill, then the glass over both.
--- The fill is anchored to the bottom by moving its top edge down as it
--- shrinks -- relativePosition y = 1 - fraction against relativeSize y =
--- fraction. Leaving position at zero would drain it from the bottom up, which
--- is the wrong way round for a tube.
local function buildVial(key, colour)
	local w, h = vialSize()
	local p = parts[key]

	local stack = ui.content {}

	p.empty = imageLayout(key .. 'Empty', whiteTex, colour, EMPTY_ALPHA or 0)
	stack:add(p.empty)

	p.fill = imageLayout(key .. 'Fill', whiteTex, colour, 1,
		v2(0, 1), v2(1, 0))
	stack:add(p.fill)

	if glassTex then
		p.glass = imageLayout(key .. 'Glass', glassTex, GLASS_TINT, 1)
		stack:add(p.glass)
	else
		p.glass = nil
	end

	local body = {
		type = ui.TYPE.Widget,
		name = key .. 'Vial',
		props = { size = v2(w, h) },
		content = stack,
	}

	if not SHOW_NUMBERS then
		p.text = nil
		p.wrap = body
		return body
	end

	local ts = math.max(8, math.floor(NUMBER_SIZE or 13))
	p.text = textLayout(key .. 'Num', ts, NUMBER_COLOR)
	p.text.props.size = v2(math.max(w, ts * 5), ts + 2)

	p.wrap = {
		type = ui.TYPE.Flex,
		name = key .. 'Group',
		props = { horizontal = false, align = ui.ALIGNMENT.Center, autoSize = true },
		content = ui.content { body, p.text },
	}
	return p.wrap
end

--- The rune column: eight glow slices, then the base runes over all of them.
--- Each slice is placed at its own band's share of the column, so a glow lands
--- exactly on the rune it belongs to however the column is scaled.
local function buildRunes()
	local w, h = runeSize()
	local p = parts.magicka
	p.glows = {}

	local stack = ui.content {}

	for i = 1, RUNE_COUNT do
		local y0, y1 = RUNE_CUTS[i], RUNE_CUTS[i + 1]
		local el = imageLayout('glow' .. i, glowTex[i], GLOW_TINT, GLOW_ALPHA or 1,
			v2(0, y0 / RUNE_CONTENT_H),
			v2(1, (y1 - y0) / RUNE_CONTENT_H))
		-- Created once and hidden. Nothing is added to or removed from the tree
		-- while playing; lighting a rune is a visibility flag.
		el.props.visible = false
		p.glows[i] = el
		stack:add(el)
	end

	p.base = imageLayout('runeBase', runeTex, RUNE_TINT, RUNE_BASE_ALPHA or 1)
	stack:add(p.base)

	local body = {
		type = ui.TYPE.Widget,
		name = 'runeColumn',
		props = { size = v2(w, h) },
		content = stack,
	}

	if not SHOW_NUMBERS then
		p.text = nil
		p.wrap = body
		return body
	end

	local ts = math.max(8, math.floor(NUMBER_SIZE or 13))
	p.text = textLayout('magickaNum', ts, NUMBER_COLOR)
	p.text.props.size = v2(math.max(w, ts * 5), ts + 2)

	p.wrap = {
		type = ui.TYPE.Flex,
		name = 'magickaGroup',
		props = { horizontal = false, align = ui.ALIGNMENT.Center, autoSize = true },
		content = ui.content { body, p.text },
	}
	return p.wrap
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function buildVialsHud()
	if vialsHud then
		vialsHud:destroy()
		vialsHud = nil
	end
	vialsBackground = nil
	for _, p in pairs(parts) do
		p.fill, p.empty, p.glass, p.base, p.text, p.wrap = nil, nil, nil, nil, nil, nil
		p.glows = {}
	end

	buildTextures()

	local horizontal = (LAYOUT or 'Horizontal') == 'Horizontal'
	local gap = math.max(0, math.floor(SPACING or 10))
	local padLayout = {
		name = 'gap',
		props = { size = horizontal and v2(gap, 1) or v2(1, gap) },
	}

	local items = {}
	local function push(el)
		if #items > 0 and gap > 0 then items[#items + 1] = padLayout end
		items[#items + 1] = el
	end

	if SHOW_HEALTH ~= false then push(buildVial('health', HEALTH_COLOR)) end
	if SHOW_STAMINA ~= false then push(buildVial('stamina', STAMINA_COLOR)) end
	if SHOW_RUNES ~= false then push(buildRunes()) end

	-- Nothing enabled. Build a placeholder rather than no element at all, so a
	-- later settings change has something to rebuild from and the drag handler
	-- is not left pointing at a destroyed widget.
	if #items == 0 then
		items[1] = { name = 'empty', props = { size = v2(1, 1) } }
	end

	local body = {
		type = ui.TYPE.Flex,
		name = 'vialsRow',
		props = {
			horizontal = horizontal,
			align = ui.ALIGNMENT.Center,
			arrange = ui.ALIGNMENT.Center,
			autoSize = true,
		},
		content = ui.content(items),
	}

	local template, paddingTemplate
	local pad = v2(HUD_PADDING or 0, HUD_PADDING or 0)

	if HUD_BACKGROUND or HUD_BORDER then
		vialsBackground = {
			type = ui.TYPE.Image,
			name = 'vialsBackground',
			props = {
				resource = ui.texture { path = 'black' },
				relativeSize = v2(1, 1),
				alpha = HUD_BACKGROUND and (BACKGROUND_ALPHA or 0.5) or 0,
			},
		}
		if HUD_BORDER then
			local borderFile = (HUD_BORDER_STYLE == 'thick' or HUD_BORDER_STYLE == 'verythick')
				and 'thick' or 'thin'
			local borderOffset =
				HUD_BORDER_STYLE == 'verythick' and 4
				or HUD_BORDER_STYLE == 'thick' and 3
				or HUD_BORDER_STYLE == 'normal' and 2
				or 1
			local borders = borderTemplates(borderFile, HUD_BORDER_COLOR, borderOffset,
				vialsBackground, pad)
			template = borders.borders
			paddingTemplate = borders.padding
		else
			template = { content = ui.content {} }
			template.content:add(vialsBackground)
		end
	else
		template = { content = ui.content {} }
	end

	vialsHud = ui.create {
		type = ui.TYPE.Container,
		layer = HUD_LOCK and 'Scene' or 'Modal',
		name = 'vialsHud',
		template = template,
		props = {
			position = v2(HUD_X_POS or 40, HUD_Y_POS or 40),
			alpha = HUD_OPACITY or 1,
		},
		content = ui.content {},
		userData = {},
	}

	-- Drag to reposition, same gesture as BSCompass, TimeHUD and ErnCompass.
	vialsHud.layout.events = {
		mousePress = async:callback(function(data, elem)
			if data.button == 1 and not HUD_LOCK then
				elem.userData = elem.userData or {}
				elem.userData.isDragging = true
				elem.userData.lastMousePos = data.position
			end
			vialsHud:update()
		end),
		mouseRelease = async:callback(function(_, elem)
			if elem.userData then elem.userData.isDragging = false end
			vialsHud:update()
		end),
		mouseMove = async:callback(function(data, elem)
			if elem.userData and elem.userData.isDragging then
				local delta = data.position - elem.userData.lastMousePos
				elem.userData.lastMousePos = data.position
				local newPosition = (vialsHud.layout.props.position or v2(0, 0)) + delta
				generalSection:set('HUD_X_POS', math.floor(newPosition.x))
				generalSection:set('HUD_Y_POS', math.floor(newPosition.y))
				vialsHud.layout.props.position = newPosition
				vialsHud:update()
			end
		end),
	}

	if paddingTemplate then
		vialsHud.layout.content:add {
			template = paddingTemplate,
			content = ui.content { body },
		}
	else
		vialsHud.layout.content:add(body)
	end

	-- Force the next update to apply everything to the fresh tree.
	lastHealthStep, lastStaminaStep = -1, -1
	lastRuneLit, lastRunePartial = -1, -1
	lastPulse.health, lastPulse.stamina, lastPulse.magicka = -1, -1, -1
	lastText.health, lastText.stamina, lastText.magicka = nil, nil, nil

	refreshUiVisibility()
end

--------------------------------------------------------------------------------
-- Style pokes
--------------------------------------------------------------------------------
-- Everything here can change without the tree changing shape, so it is set
-- straight onto the live layout tables.

function applyVialStyle()
	if not vialsHud then return end

	vialsHud.layout.props.position = v2(HUD_X_POS or 40, HUD_Y_POS or 40)
	vialsHud.layout.props.alpha = HUD_OPACITY or 1

	if vialsBackground then
		vialsBackground.props.alpha = HUD_BACKGROUND and (BACKGROUND_ALPHA or 0.5) or 0
	end

	local function styleVial(key, colour)
		local p = parts[key]
		if p.fill then p.fill.props.color = colour end
		if p.empty then
			p.empty.props.color = colour
			p.empty.props.alpha = EMPTY_ALPHA or 0
		end
		if p.glass then p.glass.props.color = GLASS_TINT end
		if p.text then p.text.props.textColor = NUMBER_COLOR end
	end
	styleVial('health', HEALTH_COLOR)
	styleVial('stamina', STAMINA_COLOR)

	local m = parts.magicka
	if m.base then
		m.base.props.color = RUNE_TINT
		m.base.props.alpha = RUNE_BASE_ALPHA or 1
	end
	for i = 1, RUNE_COUNT do
		local el = m.glows[i]
		if el then el.props.color = GLOW_TINT end
	end
	if m.text then m.text.props.textColor = NUMBER_COLOR end

	-- Glow alpha is owned by the update pass, because the partial rune's fade
	-- writes it too. Forcing a re-apply hands it back rather than fighting it.
	lastRuneLit, lastRunePartial = -1, -1

	vialsHud:update()
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

refreshUiVisibility = function()
	if not vialsHud then return end
	local visible = true
	if HUD_DISPLAY == 'Interface Only' then
		visible = currentUiMode == 'Interface'
	elseif HUD_DISPLAY == 'Hide on Interface' then
		visible = currentUiMode ~= 'Interface'
	end
	vialsHud.layout.props.visible = visible
	vialsHud:update()
end

UiModeChanged = function(data)
	currentUiMode = data and data.newMode or nil
	refreshUiVisibility()
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

local LOW_APPLIES = {
	['Off']                = {},
	['Health']             = { health = true },
	['Health and Stamina'] = { health = true, stamina = true },
	['All three']          = { health = true, stamina = true, magicka = true },
}

--- Pulse multiplier for a meter that is below the low threshold, quantised so
--- it can only change ALPHA_STEPS times a cycle rather than every frame.
local function pulseStep(active)
	if not active then return 0 end
	local depth = LOW_PULSE_DEPTH or 0
	if depth <= 0 then return 0 end
	local phase = (math.sin(pulseClock * (LOW_PULSE_SPEED or 1) * 2 * math.pi) + 1) * 0.5
	return math.floor(phase * ALPHA_STEPS + 0.5)
end

local function pulseAlpha(step)
	if step <= 0 then return 1 end
	local depth = LOW_PULSE_DEPTH or 0
	return 1 - depth * (step / ALPHA_STEPS)
end

local function numberText(cur, maxv)
	local fmt = NUMBER_FORMAT or 'Percent'
	if fmt == 'Current' then
		return tostring(math.floor(cur + 0.5))
	elseif fmt == 'Current / Max' then
		return math.floor(cur + 0.5) .. '/' .. math.floor(maxv + 0.5)
	end
	return math.floor(cur / maxv * 100 + 0.5) .. '%'
end

--- Applies one vial's fill. `step` is in whole pixel rows of the vial's own
--- height, so this is only ever called when the drawn result would differ.
local function setVialFill(p, step, pixels)
	if not p.fill then return end
	local frac = step / pixels
	p.fill.props.relativePosition = v2(0, 1 - frac)
	p.fill.props.relativeSize = v2(1, frac)
end

local function onUpdate(dt)
	if not vialsHud then return end

	local hCur, hMax = statPair(healthStat)
	local sCur, sMax = statPair(fatigueStat)
	local mCur, mMax = statPair(magickaStat)

	local hFrac = hCur / hMax
	local sFrac = sCur / sMax
	local mFrac = mCur / mMax

	local dirty = false

	-- --- vials ------------------------------------------------------------
	-- Quantised to the vial's own pixel height: a change smaller than one row
	-- cannot be drawn, so there is no reason to notice it.
	local _, vialH = vialSize()

	if SHOW_HEALTH ~= false then
		local step = math.floor(hFrac * vialH + 0.5)
		if step ~= lastHealthStep then
			lastHealthStep = step
			setVialFill(parts.health, step, vialH)
			dirty = true
		end
	end

	if SHOW_STAMINA ~= false then
		local step = math.floor(sFrac * vialH + 0.5)
		if step ~= lastStaminaStep then
			lastStaminaStep = step
			setVialFill(parts.stamina, step, vialH)
			dirty = true
		end
	end

	-- --- runes ------------------------------------------------------------
	if SHOW_RUNES ~= false then
		local lit, partial = runeState(mFrac)
		if not GLOW_PARTIAL then partial = ALPHA_STEPS end

		if lit ~= lastRuneLit or partial ~= lastRunePartial then
			lastRuneLit, lastRunePartial = lit, partial
			local fullAlpha = GLOW_ALPHA or 1
			for i = 1, RUNE_COUNT do
				local el = parts.magicka.glows[i]
				if el then
					local slot = runeSlotFor(i)
					if slot > lit then
						el.props.visible = false
					else
						el.props.visible = true
						-- Only the topmost lit rune is ever partly full.
						el.props.alpha = (slot == lit)
							and (fullAlpha * partial / ALPHA_STEPS)
							or fullAlpha
					end
				end
			end
			dirty = true
		end
	end

	-- --- low warning ------------------------------------------------------
	local applies = LOW_APPLIES[LOW_WARNING or 'Off'] or LOW_APPLIES['Off']
	if next(applies) ~= nil then
		pulseClock = pulseClock + (dt or 0)
		local thr = LOW_THRESHOLD or 0.25

		local function pulse(key, frac, el)
			if not el then return end
			local step = pulseStep(applies[key] and frac < thr)
			if step ~= lastPulse[key] then
				lastPulse[key] = step
				el.props.alpha = pulseAlpha(step)
				dirty = true
			end
		end

		pulse('health', hFrac, parts.health.fill)
		pulse('stamina', sFrac, parts.stamina.fill)
		pulse('magicka', mFrac, parts.magicka.base)
	end

	-- --- numbers ----------------------------------------------------------
	-- Compared as the rendered string, so a stat drifting within the same
	-- displayed value costs one comparison and nothing else.
	if SHOW_NUMBERS then
		local function setText(key, el, cur, maxv)
			if not el then return end
			local t = numberText(cur, maxv)
			if t ~= lastText[key] then
				lastText[key] = t
				el.props.text = t
				dirty = true
			end
		end
		setText('health', parts.health.text, hCur, hMax)
		setText('stamina', parts.stamina.text, sCur, sMax)
		setText('magicka', parts.magicka.text, mCur, mMax)
	end

	if dirty then vialsHud:update() end
end

--------------------------------------------------------------------------------
-- Resize gesture
--------------------------------------------------------------------------------
-- Click-and-scroll while dragging, matching BSCompass and TimeHUD. Scales the
-- vials and the rune column together so the set keeps its proportions.

local function resizeBy(delta)
	if not (vialsHud and vialsHud.layout.userData and vialsHud.layout.userData.isDragging) then
		return
	end
	local section = storage.playerSection('Settings' .. MODNAME .. 'Vials')
	local rsection = storage.playerSection('Settings' .. MODNAME .. 'Runes')
	local h = math.max(32, math.min(512, (VIAL_HEIGHT or 139) + delta))
	local scale = h / math.max(1, VIAL_HEIGHT or 139)
	section:set('VIAL_HEIGHT', math.floor(h))
	section:set('VIAL_WIDTH', math.max(4, math.min(96,
		math.floor((VIAL_WIDTH or 13) * scale + 0.5))))
	rsection:set('RUNE_HEIGHT', math.max(32, math.min(512,
		math.floor((RUNE_HEIGHT or 139) * scale + 0.5))))
	rsection:set('RUNE_WIDTH', math.max(8, math.min(256,
		math.floor((RUNE_WIDTH or 35) * scale + 0.5))))
end

if input.triggers['MenuMouseWheelUp'] then
	input.registerTriggerHandler('MenuMouseWheelUp', async:callback(function()
		resizeBy(6)
	end))
end
if input.triggers['MenuMouseWheelDown'] then
	input.registerTriggerHandler('MenuMouseWheelDown', async:callback(function()
		resizeBy(-6)
	end))
end

input.registerTriggerHandler('ToggleHUD', async:callback(function()
	refreshUiVisibility()
end))

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function onLoad()
	local layerId = ui.layers.indexOf('HUD')
	local hudLayerSize = ui.layers[layerId].size
	generalSection:set('HUD_X_POS',
		math.floor(math.max(-200, math.min(HUD_X_POS or 40, hudLayerSize.x + 200))))
	generalSection:set('HUD_Y_POS',
		math.floor(math.max(-50, math.min(HUD_Y_POS or 40, hudLayerSize.y - 20))))
	buildVialsHud()
end

--------------------------------------------------------------------------------
-- Public interface
--------------------------------------------------------------------------------
-- Other mods can read the meters or hide the set without reaching into it:
--
--   local I = require('openmw.interfaces')
--   I.DBSVials.setVisible(false)
--   local f = I.DBSVials.getFractions()   -- { health = , stamina = , magicka = }
--
-- From a script that cannot see the interface -- a global script, or another
-- mod that loads earlier -- the same things are reachable by event.

local externallyHidden = false

local interface = {
	version = 1,

	--- Current fill of each meter as a 0..1 fraction.
	getFractions = function()
		local hCur, hMax = statPair(healthStat)
		local sCur, sMax = statPair(fatigueStat)
		local mCur, mMax = statPair(magickaStat)
		return { health = hCur / hMax, stamina = sCur / sMax, magicka = mCur / mMax }
	end,

	--- How many of the eight runes are currently lit.
	getLitRunes = function()
		local mCur, mMax = statPair(magickaStat)
		local lit = runeState(mCur / mMax)
		return lit, RUNE_COUNT
	end,

	--- Hide or show the whole set, independently of the user's own setting.
	setVisible = function(show)
		externallyHidden = not show
		if vialsHud then
			vialsHud.layout.props.visible = show and true or false
			vialsHud:update()
		end
	end,

	isVisible = function()
		return not externallyHidden
	end,
}

return {
	interfaceName = 'DBSVials',
	interface = interface,

	engineHandlers = {
		onLoad = onLoad,
		onUpdate = onUpdate,
		UiModeChanged = UiModeChanged,
	},

	eventHandlers = {
		DBSVialsSetVisible = function(data)
			if type(data) == 'table' then interface.setVisible(data.show ~= false) end
		end,
	},
}
