---@omw-context player
--------------------------------------------------------------------------------
-- DBSVials -- dbsHUD
--------------------------------------------------------------------------------
-- Health and stamina as glass vials that fill from the bottom; magicka as a
-- column of eight runes whose glow goes out an eighth at a time.
--
-- The vials and the runes are two independent widgets with their own positions,
-- so they can be dragged to opposite corners of the screen if that is what you
-- want. They share the stat-reading pass and the frame styling, nothing else.
--
-- Built after ErnMMUI, which is the reference for reading the player's dynamic
-- stats and for keeping a stats HUD honest about when it actually needs to
-- redraw.
--
--------------------------------------------------------------------------------
-- What this costs per frame
--------------------------------------------------------------------------------
-- onUpdate reads three stats, divides, and quantises. If nothing quantised has
-- moved it returns without touching the UI. It allocates nothing in the common
-- path: no tables, no textures, no vectors beyond the few the engine needs when
-- a value genuinely changed.
--
-- The quantisation is the whole trick. A vial is redrawn only when the fill
-- crosses a whole *row of the tube art*, so there are 140 distinct states
-- however smoothly health regenerates. A rune is redrawn only when it lights or
-- goes out -- eight states, or 16 alpha steps when the partial rune is set to
-- fade. Without that, regenerating fatigue would rebuild the widget every frame
-- for a change nobody can see.
--
-- Every texture is built once at load, including the 140 pre-cut fill heights.
-- Cutting the fill rather than stretching one texture is what keeps the taper at
-- the bottom of the tube the right shape at every level; a stretched texture
-- would squash the whole 139 rows into however many the fill currently occupies.
--
-- There is no pcall anywhere in this mod. See README.
--------------------------------------------------------------------------------

local ui      = require('openmw.ui')
local util    = require('openmw.util')
local storage = require('openmw.storage')
local async   = require('openmw.async')
local self_   = require('openmw.self')
local types   = require('openmw.types')
local input   = require('openmw.input')

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
-- The vial, in art pixels
--------------------------------------------------------------------------------
-- Every figure here was measured off the supplied art, not chosen.
--
-- The TUBE pngs are a single flat colour occupying x3..x9 of a 13px canvas, so
-- the liquid is 7px wide with 3px of padding either side -- it does NOT span the
-- tube. That padding is the glass wall. The last two rows taper to 5px.
--
-- The base art is a 40px canvas holding two pieces that are already registered
-- against each other: the bulb at x10..x18, y24..y58, and the clasp diamond at
-- x2..x28, y24..y48. Drawing both at the same rect lines them up by
-- construction -- there is nothing to align by hand.
--
-- The tube sits at x8 on that canvas, which puts its liquid column (x3..x9, so
-- x11..x17 once offset) inside the bulb's mouth (x10..x18) with one pixel of
-- glass either side.
local TUBE_W, TUBE_H        = 13, 139
local BASE_W, BASE_H        = 40, 67
local CAP_W, CAP_H          = 15, 19

-- Placement on the assembly canvas, taken off the supplied example flasks.
-- VIAL_TOP lands on them bit-exactly at (8,4), which is what fixed the rest:
-- the collar is 15 wide over a 13-wide tube, so the tube is at x9, and the
-- tube's own liquid column (x3..x9 of its 13) then falls on x12..x18 -- exactly
-- where the green and red examples differ from the empty one.
local NATURAL_W, NATURAL_H  = 40, 190
-- Every one of these was found by searching the offset against the supplied
-- flasks rather than reasoned about, because the tube's glass and its liquid do
-- not share a left edge -- the glass sits one pixel left of the column it
-- covers. Reasoning from "they are both the tube" gets that wrong.
local CAP_X, CAP_Y          = 8, 4
local GLASS_X, GLASS_Y      = 8, 15
local FILL_X                = 9
local BASE_X, BASE_Y        = 1, 112

-- The liquid is ONE column running the whole height of the vessel: down the
-- tube, through the clasp, and into the bulb. That is the change the example
-- flasks show -- it is not a tube fill sitting on top of a separate bulb.
--
-- It is drawn from the same VIAL_FILL master as before, just placed against the
-- vessel rather than the tube: 139 rows ending at y168, which is the inside of
-- the bulb's foot.
local FILL_BOTTOM           = 169        -- one past the last liquid row
local FILL_ROWS             = TUBE_H     -- 139, so a full vial reaches y30

-- Nothing is hidden at either end any more. The clasp no longer covers the
-- liquid -- it is underneath it now -- and the collar sits clear of the top of
-- the travel, so every row of it is on screen.
local FILL_MIN              = 0
local FILL_MAX              = FILL_ROWS

local TEX = {
	fill    = 'textures/dbsvials/VIAL_FILL.png',
	glass   = 'textures/dbsvials/glass_tube.png',
	clasp   = 'textures/dbsvials/VIAL_CLASP.png',
	cap     = 'textures/dbsvials/VIAL_TOP.png',
	residue = 'textures/dbsvials/VIAL_RESIDUE.png',
}

-- Draw order, lowest first. The clasp moved to the bottom of the stack and a
-- clear front piece went on top of the liquid, which is what makes the liquid
-- read as being *inside* the vessel at the clasp rather than passing in front
-- of it.
--
--   VIAL_CLASP          the metal, behind everything
--   bulb backing        so the bulb is not hollow where no liquid has reached
--   VIAL_RESIDUE        the dreg, tinted, under the liquid
--   VIAL_FILL           the liquid
--   VIAL_CLEAR_CLASP    the vessel's front glass over the liquid
--   glass_tube          the tube's own glass
--   VIAL_TOP            the collar

--------------------------------------------------------------------------------
-- The runes, in art pixels
--------------------------------------------------------------------------------
-- Four sheets, all 70 x 328 and registered pixel-for-pixel, drawn back to front:
--
--   FLAIR      a solid blob behind everything, for pulses and flashes
--   GLOW_UP2   the thick halo, on a rune whose eighth is completely full
--   GLOW_UP1   the thin halo, on the one rune currently filling or emptying
--   RUNES_x    the runes themselves, always drawn
--
-- They nest: every GLOW_UP1 pixel is inside GLOW_UP2, every GLOW_UP2 pixel is
-- inside FLAIR, and every rune pixel is inside FLAIR. That is what lets a rune
-- step from thin halo to thick without the outline jumping.
--
-- Only the top 292 rows carry art; the rest is empty padding the widget never
-- looks at, so the sheets ship uncropped.
local RUNE_SHEET_W          = 70
local RUNE_CONTENT_H        = 292

-- Measured, not assumed even: the runes are hand-drawn and their heights differ
-- by up to 17px. The cuts come from the front runes, which are the only sheet
-- whose eight shapes are cleanly separated -- the FLAIR is fat enough to bridge
-- them. Each cut then sits at the narrowest point of the FLAIR across that gap,
-- so at most 7 pixels of art fall on any boundary.
local RUNE_CUTS             = { 0, 33, 69, 111, 143, 178, 216, 249, 292 }
local RUNE_COUNT            = #RUNE_CUTS - 1
local RUNES_PATH            = 'textures/dbsvials/RUNES_x.png'
local GLOW1_PATH            = 'textures/dbsvials/GLOW_UP1.png'
local GLOW2_PATH            = 'textures/dbsvials/GLOW_UP2.png'
local FLAIR_PATH            = 'textures/dbsvials/FLAIR.png'

-- Quantisation for anything that fades. Below what anyone can distinguish on a
-- HUD element this size, and it caps how often a fade can poke the UI.
local ALPHA_STEPS           = 16

local borderTemplates = require('scripts.dbsvials.DBV_border')

local vialSection = storage.playerSection('Settings' .. MODNAME .. 'Vials')
local runeSection = storage.playerSection('Settings' .. MODNAME .. 'Runes')

require('scripts.dbsvials.DBV_settings')

--------------------------------------------------------------------------------
-- Stats
--------------------------------------------------------------------------------
-- Live accessors, not snapshots: reading .current gives the present value.
-- Resolving them once at load is what makes the read side of onUpdate free.
local healthStat  = types.Actor.stats.dynamic.health(self_)
local fatigueStat = types.Actor.stats.dynamic.fatigue(self_)
local magickaStat = types.Actor.stats.dynamic.magicka(self_)

--- Current value and maximum of a dynamic stat. Maximum is base + modifier, so
--- fortify and drain effects move it, matching the engine's own bars.
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

local vialsHud, runesHud                -- two independent roots
local vialsBackground, runesBackground

local parts = {
	health  = {},
	stamina = {},
	magicka = { flair = {}, glow2 = {}, glow1 = {} },
}

local fillTex   = {}        -- [rows] -> texture showing the bottom `rows` of the tube
local glow1Tex, glow2Tex, flairTex = {}, {}, {}
local runeTex, glassTex, claspTex, capTex, residueTex, bulbTex, clearClaspTex

local lastHealthRows  = -1
local lastStaminaRows = -1
local lastRuneLit     = -1
local lastRunePartial = -1
local lastFlair       = -1
local flairTimer      = 0      -- seconds left on an externally requested flash
local lastPulse       = { health = -1, stamina = -1, magicka = -1 }
local lastText        = { health = nil, stamina = nil, magicka = nil }

local pulseClock      = 0
local currentUiMode   = nil

--------------------------------------------------------------------------------
-- Textures
--------------------------------------------------------------------------------

--- True for a texture path worth handing to ui.texture. Checked rather than
--- guarded with pcall: an empty path is a legitimate setting -- it means "no
--- glass" -- so it is a value to test, not a fault to catch.
local function validPath(p)
	return type(p) == 'string' and p ~= ''
end

local function maybeTexture(path)
	if not validPath(path) then return nil end
	return ui.texture { path = path }
end

local function buildTextures()
	-- One texture per possible fill height, cut from the bottom of the tube art
	-- so the taper stays the right shape. 140 of them, built once.
	fillTex = {}
	for h = 0, TUBE_H do
		fillTex[h] = ui.texture {
			path   = TEX.fill,
			offset = v2(0, TUBE_H - h),
			size   = v2(TUBE_W, h),
		}
	end

	glassTex       = maybeTexture(GLASS_TEXTURE)
	clearClaspTex  = maybeTexture(CLEAR_CLASP_TEXTURE)
	claspTex   = SHOW_CLASP ~= false and maybeTexture(TEX.clasp) or nil
	capTex     = SHOW_CAP ~= false and maybeTexture(TEX.cap) or nil
	residueTex = SHOW_RESIDUE ~= false and maybeTexture(TEX.residue) or nil
	bulbTex    = maybeTexture(BULB_TEXTURE)

	runeTex = ui.texture {
		path   = RUNES_PATH,
		offset = v2(0, 0),
		size   = v2(RUNE_SHEET_W, RUNE_CONTENT_H),
	}
	-- One slice per rune per sheet. The front runes stay whole: they are always
	-- fully drawn, so there is nothing to switch and no reason to cut them.
	glow1Tex, glow2Tex, flairTex = {}, {}, {}
	for i = 1, RUNE_COUNT do
		local y0, y1 = RUNE_CUTS[i], RUNE_CUTS[i + 1]
		local function slice(path)
			return ui.texture {
				path   = path,
				offset = v2(0, y0),
				size   = v2(RUNE_SHEET_W, y1 - y0),
			}
		end
		glow1Tex[i] = slice(GLOW1_PATH)
		glow2Tex[i] = slice(GLOW2_PATH)
		flairTex[i] = slice(FLAIR_PATH)
	end
end

--------------------------------------------------------------------------------
-- Which runes are lit
--------------------------------------------------------------------------------
-- Rune k covers the magicka band [(k-1)/8, k/8]. It is lit whenever that band
-- holds anything at all, which is what "goes out when its eighth is spent and
-- comes back the moment it starts to refill" means: the boundary is at any
-- fill, not at half or full.
local function runeState(frac)
	if frac <= 0 then return 0, 0 end
	if frac >= 1 then return RUNE_COUNT, ALPHA_STEPS end
	local scaled  = frac * RUNE_COUNT
	local whole   = math.floor(scaled)
	local partial = scaled - whole
	if partial > 0 then
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

--- Fill height in tube rows for a 0..1 fraction.
local function fillRowsFor(frac)
	return math.floor(FILL_MIN + frac * (FILL_MAX - FILL_MIN) + 0.5)
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

--- Scale factor and pixel size of one vial assembly.
local function vialMetrics()
	local size = math.max(24, math.floor(VIAL_SIZE or NATURAL_H))
	local k = size / NATURAL_H
	return k, math.max(1, math.floor(NATURAL_W * k)), size
end

local function runeMetrics()
	return math.max(8, math.floor(RUNE_WIDTH or 35)),
	       math.max(16, math.floor(RUNE_HEIGHT or 139))
end

--------------------------------------------------------------------------------
-- Layout pieces
--------------------------------------------------------------------------------

--- An absolutely-positioned image inside a fixed-size parent.
local function pixelImage(name, resource, x, y, w, h, tint, alpha)
	return {
		type = ui.TYPE.Image,
		name = name,
		props = {
			resource = resource,
			position = v2(math.floor(x), math.floor(y)),
			size = v2(math.max(1, math.floor(w)), math.max(1, math.floor(h))),
			color = tint,
			alpha = alpha,
			-- Without both of these MyGUI tiles the texture at its native size
			-- instead of stretching it, and nothing is resizable.
			tileH = false,
			tileV = false,
		},
	}
end

local function textLayout(name, size, color, width)
	return {
		type = ui.TYPE.Text,
		name = name,
		props = {
			text = '',
			size = v2(width, size + 2),
			textSize = size,
			textColor = color,
			textShadow = true,
			textShadowColor = util.color.rgba(0, 0, 0, 0.9),
			textAlignH = ui.ALIGNMENT.Center,
			textAlignV = ui.ALIGNMENT.Center,
		},
	}
end

--- One complete vial: bulb, residue, liquid, glass, clasp, collar.
--- Everything is placed from the measured art figures and scaled by one factor,
--- so the fittings keep their proportions at any size.
local function buildVial(key, colour)
	local k, w, h = vialMetrics()
	local p = parts[key]
	local stack = ui.content {}

	local function place(name, tex, ax, ay, aw, ah, tint, alpha)
		if not tex then return nil end
		local el = pixelImage(name, tex, ax * k, ay * k, aw * k, ah * k, tint, alpha)
		stack:add(el)
		return el
	end

	-- The bulb and its dreg. The residue is tinted with the vial's own colour,
	-- so a health vial keeps a red dreg and a stamina vial a green one, which is
	-- what the supplied examples show.
	-- Lowest: the metal. It used to sit on top, which put it in front of the
	-- liquid; the example flasks show the liquid crossing it, so it goes under.
	p.clasp = place('clasp' .. key, claspTex, BASE_X, BASE_Y, BASE_W, BASE_H,
		FITTING_TINT, 1)

	-- The bulb's back, so it is not hollow above the liquid line.
	p.bulb = place('bulb' .. key, bulbTex, BASE_X, BASE_Y, BASE_W, BASE_H,
		BULB_TINT, BULB_ALPHA or 1)
	p.residue = place('residue' .. key, residueTex, BASE_X, BASE_Y, BASE_W, BASE_H,
		colour, RESIDUE_ALPHA or 1)

	-- The liquid. Position and size are set every time the level changes, so the
	-- figures here are only the starting state.
	local rows = FILL_MIN
	p.fill = place('fill' .. key, fillTex[rows],
		FILL_X, FILL_BOTTOM - rows, TUBE_W, math.max(1, rows), colour, 1)

	-- Top: the vessel's front glass, then the tube's, then the collar.
	p.clearClasp = place('clear' .. key, clearClaspTex, BASE_X, BASE_Y,
		BASE_W, BASE_H, GLASS_TINT, 1)
	p.glass = place('glass' .. key, glassTex,
		GLASS_X, GLASS_Y, TUBE_W, TUBE_H, GLASS_TINT, 1)
	p.cap = place('cap' .. key, capTex, CAP_X, CAP_Y, CAP_W, CAP_H, FITTING_TINT, 1)

	local body = {
		type = ui.TYPE.Widget,
		name = key .. 'Vial',
		props = { size = v2(w, h) },
		content = stack,
	}

	if not SHOW_NUMBERS then
		p.text = nil
		return body
	end

	local ts = math.max(8, math.floor(NUMBER_SIZE or 13))
	p.text = textLayout(key .. 'Num', ts, NUMBER_COLOR, math.max(w, ts * 5))
	return {
		type = ui.TYPE.Flex,
		name = key .. 'Group',
		props = { horizontal = false, align = ui.ALIGNMENT.Center, autoSize = true },
		content = ui.content { body, p.text },
	}
end

--- The rune column: eight glow slices, then the base runes over all of them.
local function buildRunes()
	local w, h = runeMetrics()
	local p = parts.magicka
	p.flair, p.glow2, p.glow1 = {}, {}, {}
	local stack = ui.content {}

	-- Both edges are rounded first and the height taken as their difference.
	-- Rounding the position and the height separately lets them disagree by a
	-- pixel, which opens a hairline gap between two runes at some column
	-- heights -- a dead stripe across the glow.
	local top, bottom = {}, {}
	for i = 1, RUNE_COUNT do
		top[i]    = math.floor(h * RUNE_CUTS[i] / RUNE_CONTENT_H)
		bottom[i] = math.floor(h * RUNE_CUTS[i + 1] / RUNE_CONTENT_H)
	end

	-- Back to front, each layer complete before the next starts, so every flair
	-- sits behind every halo. Interleaving them per rune would put rune 2's
	-- flair on top of rune 1's halo where their slices touch.
	local function layer(prefix, texes, tint, alpha, into)
		for i = 1, RUNE_COUNT do
			local el = pixelImage(prefix .. i, texes[i],
				0, top[i], w, bottom[i] - top[i], tint, alpha)
			-- Created once and hidden. Nothing is added to or removed from the
			-- tree while playing; lighting a rune is a visibility flag.
			el.props.visible = false
			into[i] = el
			stack:add(el)
		end
	end
	layer('flair', flairTex, FLAIR_TINT, 0, p.flair)
	layer('glowThick', glow2Tex, GLOW_TINT, GLOW_ALPHA or 1, p.glow2)
	layer('glowThin', glow1Tex, GLOW_TINT, GLOW_ALPHA or 1, p.glow1)

	p.base = pixelImage('runeBase', runeTex, 0, 0, w, h, RUNE_TINT, RUNE_BASE_ALPHA or 1)
	stack:add(p.base)

	local body = {
		type = ui.TYPE.Widget,
		name = 'runeColumn',
		props = { size = v2(w, h) },
		content = stack,
	}

	if not SHOW_NUMBERS then
		p.text = nil
		return body
	end

	local ts = math.max(8, math.floor(NUMBER_SIZE or 13))
	p.text = textLayout('magickaNum', ts, NUMBER_COLOR, math.max(w, ts * 5))
	return {
		type = ui.TYPE.Flex,
		name = 'magickaGroup',
		props = { horizontal = false, align = ui.ALIGNMENT.Center, autoSize = true },
		content = ui.content { body, p.text },
	}
end

--------------------------------------------------------------------------------
-- Roots
--------------------------------------------------------------------------------
-- Both widgets are built the same way and differ only in what they contain and
-- which pair of settings holds their position, so one function makes both. That
-- is also what keeps the two drag handlers from drifting apart.

local function makeRoot(name, body, section, xKey, yKey, bgOut)
	local template, paddingTemplate
	local pad = v2(HUD_PADDING or 0, HUD_PADDING or 0)

	if HUD_BACKGROUND or HUD_BORDER then
		local bg = {
			type = ui.TYPE.Image,
			name = name .. 'Background',
			props = {
				resource = ui.texture { path = 'black' },
				relativeSize = v2(1, 1),
				alpha = HUD_BACKGROUND and (BACKGROUND_ALPHA or 0.5) or 0,
			},
		}
		bgOut[1] = bg
		if HUD_BORDER then
			local borderFile = (HUD_BORDER_STYLE == 'thick' or HUD_BORDER_STYLE == 'verythick')
				and 'thick' or 'thin'
			local borderOffset =
				HUD_BORDER_STYLE == 'verythick' and 4
				or HUD_BORDER_STYLE == 'thick' and 3
				or HUD_BORDER_STYLE == 'normal' and 2
				or 1
			local borders = borderTemplates(borderFile, HUD_BORDER_COLOR, borderOffset, bg, pad)
			template = borders.borders
			paddingTemplate = borders.padding
		else
			template = { content = ui.content {} }
			template.content:add(bg)
		end
	else
		bgOut[1] = nil
		template = { content = ui.content {} }
	end

	local root = ui.create {
		type = ui.TYPE.Container,
		layer = HUD_LOCK and 'Scene' or 'Modal',
		name = name,
		template = template,
		props = {
			position = v2(_G[xKey] or 40, _G[yKey] or 40),
			alpha = HUD_OPACITY or 1,
		},
		content = ui.content {},
		userData = {},
	}

	-- Drag to reposition, same gesture as BSCompass, TimeHUD and ErnCompass.
	-- Each widget carries its own, writing to its own pair of keys, which is
	-- what lets them be placed independently.
	root.layout.events = {
		mousePress = async:callback(function(data, elem)
			if data.button == 1 and not HUD_LOCK then
				elem.userData = elem.userData or {}
				elem.userData.isDragging = true
				elem.userData.lastMousePos = data.position
			end
			root:update()
		end),
		mouseRelease = async:callback(function(_, elem)
			if elem.userData then elem.userData.isDragging = false end
			root:update()
		end),
		mouseMove = async:callback(function(data, elem)
			if elem.userData and elem.userData.isDragging then
				local delta = data.position - elem.userData.lastMousePos
				elem.userData.lastMousePos = data.position
				local newPosition = (root.layout.props.position or v2(0, 0)) + delta
				section:set(xKey, math.floor(newPosition.x))
				section:set(yKey, math.floor(newPosition.y))
				root.layout.props.position = newPosition
				root:update()
			end
		end),
	}

	if paddingTemplate then
		root.layout.content:add {
			template = paddingTemplate,
			content = ui.content { body },
		}
	else
		root.layout.content:add(body)
	end
	return root
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function buildVialsHud()
	if vialsHud then vialsHud:destroy() end
	if runesHud then runesHud:destroy() end
	vialsHud, runesHud = nil, nil
	vialsBackground, runesBackground = nil, nil
	parts.health, parts.stamina = {}, {}
	parts.magicka = { flair = {}, glow2 = {}, glow1 = {} }

	buildTextures()

	-- --- the vials -------------------------------------------------------
	if SHOW_HEALTH ~= false or SHOW_STAMINA ~= false then
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
		local out = {}
		vialsHud = makeRoot('vialsHud', body, vialSection, 'VIAL_X_POS', 'VIAL_Y_POS', out)
		vialsBackground = out[1]
	end

	-- --- the runes -------------------------------------------------------
	if SHOW_RUNES ~= false then
		local out = {}
		runesHud = makeRoot('runesHud', buildRunes(), runeSection,
			'RUNE_X_POS', 'RUNE_Y_POS', out)
		runesBackground = out[1]
	end

	-- Force the next update to apply everything to the fresh tree.
	lastHealthRows, lastStaminaRows = -1, -1
	lastRuneLit, lastRunePartial, lastFlair = -1, -1, -1
	lastPulse.health, lastPulse.stamina, lastPulse.magicka = -1, -1, -1
	lastText.health, lastText.stamina, lastText.magicka = nil, nil, nil

	refreshUiVisibility()
end

--------------------------------------------------------------------------------
-- Style pokes
--------------------------------------------------------------------------------

function applyVialStyle()
	if vialsHud then
		vialsHud.layout.props.position = v2(VIAL_X_POS or 40, VIAL_Y_POS or 40)
		vialsHud.layout.props.alpha = HUD_OPACITY or 1
		if vialsBackground then
			vialsBackground.props.alpha = HUD_BACKGROUND and (BACKGROUND_ALPHA or 0.5) or 0
		end
	end
	if runesHud then
		runesHud.layout.props.position = v2(RUNE_X_POS or 40, RUNE_Y_POS or 40)
		runesHud.layout.props.alpha = HUD_OPACITY or 1
		if runesBackground then
			runesBackground.props.alpha = HUD_BACKGROUND and (BACKGROUND_ALPHA or 0.5) or 0
		end
	end

	local function styleVial(key, colour)
		local p = parts[key]
		if p.fill then p.fill.props.color = colour end
		if p.residue then
			p.residue.props.color = colour
			p.residue.props.alpha = RESIDUE_ALPHA or 1
		end
		if p.bulb then
			p.bulb.props.color = BULB_TINT
			p.bulb.props.alpha = BULB_ALPHA or 1
		end
		if p.glass then p.glass.props.color = GLASS_TINT end
		if p.clearClasp then p.clearClasp.props.color = GLASS_TINT end
		if p.clasp then p.clasp.props.color = FITTING_TINT end
		if p.cap then p.cap.props.color = FITTING_TINT end
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
		if m.glow1[i] then m.glow1[i].props.color = GLOW_TINT end
		if m.glow2[i] then m.glow2[i].props.color = GLOW_TINT end
		if m.flair[i] then m.flair[i].props.color = FLAIR_TINT end
	end
	if m.text then m.text.props.textColor = NUMBER_COLOR end

	-- Glow alpha is owned by the update pass, because the partial rune's fade
	-- writes it too. Forcing a re-apply hands it back rather than fighting it.
	lastRuneLit, lastRunePartial, lastFlair = -1, -1, -1

	if vialsHud then vialsHud:update() end
	if runesHud then runesHud:update() end
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

refreshUiVisibility = function()
	local visible = true
	if HUD_DISPLAY == 'Interface Only' then
		visible = currentUiMode == 'Interface'
	elseif HUD_DISPLAY == 'Hide on Interface' then
		visible = currentUiMode ~= 'Interface'
	end
	if vialsHud then
		vialsHud.layout.props.visible = visible
		vialsHud:update()
	end
	if runesHud then
		runesHud.layout.props.visible = visible
		runesHud:update()
	end
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

local function pulseStep(active)
	if not active then return 0 end
	local depth = LOW_PULSE_DEPTH or 0
	if depth <= 0 then return 0 end
	local phase = (math.sin(pulseClock * (LOW_PULSE_SPEED or 1) * 2 * math.pi) + 1) * 0.5
	return math.floor(phase * ALPHA_STEPS + 0.5)
end

local function pulseAlpha(step)
	if step <= 0 then return 1 end
	return 1 - (LOW_PULSE_DEPTH or 0) * (step / ALPHA_STEPS)
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

--- Swaps in the pre-cut texture for this fill height and moves the rect up to
--- match. Both are needed: the texture is the bottom `rows` of the tube art, so
--- the widget has to be exactly that tall and sit exactly that far up, or the
--- art is stretched and the taper at the bottom goes wrong.
local function setVialFill(p, rows, k)
	if not p.fill then return end
	p.fill.props.resource = fillTex[rows]
	p.fill.props.position = v2(math.floor(FILL_X * k), math.floor((FILL_BOTTOM - rows) * k))
	p.fill.props.size = v2(math.max(1, math.floor(TUBE_W * k)),
		math.max(1, math.floor(rows * k)))
	-- An empty vessel draws no liquid at all, rather than a one-pixel sliver in
	-- the bottom of the bulb.
	p.fill.props.visible = rows > 0
end

local function onUpdate(dt)
	if not (vialsHud or runesHud) then return end

	local hCur, hMax = statPair(healthStat)
	local sCur, sMax = statPair(fatigueStat)
	local mCur, mMax = statPair(magickaStat)

	local hFrac = hCur / hMax
	local sFrac = sCur / sMax
	local mFrac = mCur / mMax

	local vialsDirty, runesDirty = false, false
	local k = vialMetrics()

	-- --- vials ------------------------------------------------------------
	-- Quantised to whole rows of the tube art, which is also the index into the
	-- pre-cut texture array. A change smaller than one row cannot be drawn, so
	-- there is no reason to notice it.
	if vialsHud then
		if SHOW_HEALTH ~= false then
			local rows = fillRowsFor(hFrac)
			if rows ~= lastHealthRows then
				lastHealthRows = rows
				setVialFill(parts.health, rows, k)
				vialsDirty = true
			end
		end
		if SHOW_STAMINA ~= false then
			local rows = fillRowsFor(sFrac)
			if rows ~= lastStaminaRows then
				lastStaminaRows = rows
				setVialFill(parts.stamina, rows, k)
				vialsDirty = true
			end
		end
	end

	-- --- runes ------------------------------------------------------------
	-- Three states per rune, which is what the two glow sheets are for:
	--   spent            no halo
	--   filling/emptying GLOW_UP1, the thin halo
	--   full             GLOW_UP2, the thick one
	-- Only ever one rune is in the middle state -- the one the current eighth
	-- is moving through.
	if runesHud and SHOW_RUNES ~= false then
		local lit, partial = runeState(mFrac)
		if not GLOW_PARTIAL then partial = ALPHA_STEPS end
		if lit ~= lastRuneLit or partial ~= lastRunePartial then
			lastRuneLit, lastRunePartial = lit, partial
			local fullAlpha = GLOW_ALPHA or 1
			local m = parts.magicka
			for i = 1, RUNE_COUNT do
				local slot = runeSlotFor(i)
				local thin, thick = false, false
				if slot < lit then
					thick = true
				elseif slot == lit then
					-- At exactly full this rune is done, so it takes the thick
					-- halo too; anything less and it is the one in motion.
					if partial >= ALPHA_STEPS then thick = true else thin = true end
				end
				if m.glow2[i] then
					m.glow2[i].props.visible = thick
					m.glow2[i].props.alpha = fullAlpha
				end
				if m.glow1[i] then
					m.glow1[i].props.visible = thin
					-- GLOW_PARTIAL fades the moving rune with what is left of
					-- its eighth instead of holding it at full brightness.
					m.glow1[i].props.alpha = GLOW_PARTIAL
						and (fullAlpha * partial / ALPHA_STEPS)
						or fullAlpha
				end
			end
			runesDirty = true
		end
	end

	-- --- low warning ------------------------------------------------------
	local applies = LOW_APPLIES[LOW_WARNING or 'Off'] or LOW_APPLIES['Off']
	if next(applies) ~= nil then
		pulseClock = pulseClock + (dt or 0)
		local thr = LOW_THRESHOLD or 0.25
		local function pulse(key, frac, el)
			if not el then return false end
			local step = pulseStep(applies[key] and frac < thr)
			if step ~= lastPulse[key] then
				lastPulse[key] = step
				el.props.alpha = pulseAlpha(step)
				return true
			end
			return false
		end
		if pulse('health', hFrac, parts.health.fill) then vialsDirty = true end
		if pulse('stamina', sFrac, parts.stamina.fill) then vialsDirty = true end
	end

	-- --- flair ------------------------------------------------------------
	-- The layer behind the runes, for pulses and flashes. It carries the
	-- magicka low warning -- which used to dim the runes themselves, a poor cue,
	-- since going darker is what running out already looks like -- and any flash
	-- another mod asks for through the interface.
	--
	-- It shows only under lit runes, so what pulses is what you have left.
	if runesHud and SHOW_RUNES ~= false then
		if flairTimer > 0 then
			flairTimer = flairTimer - (dt or 0)
			if flairTimer < 0 then flairTimer = 0 end
		end
		local warn = (applies.magicka and mFrac < (LOW_THRESHOLD or 0.25))
		local step = 0
		if warn or flairTimer > 0 then
			if not applies.magicka then pulseClock = pulseClock + (dt or 0) end
			local phase = (math.sin(pulseClock * (FLAIR_SPEED or 1.4) * 2 * math.pi) + 1) * 0.5
			step = math.floor(phase * ALPHA_STEPS + 0.5)
		end
		if step ~= lastFlair then
			lastFlair = step
			local a = (FLAIR_ALPHA or 0.8) * step / ALPHA_STEPS
			local lit = lastRuneLit
			for i = 1, RUNE_COUNT do
				local el = parts.magicka.flair[i]
				if el then
					local on = step > 0 and runeSlotFor(i) <= lit
					el.props.visible = on
					el.props.alpha = on and a or 0
				end
			end
			runesDirty = true
		end
	end

	-- --- numbers ----------------------------------------------------------
	-- Compared as the rendered string, so a stat drifting within the same
	-- displayed value costs one comparison and nothing else.
	if SHOW_NUMBERS then
		local function setText(key, el, cur, maxv)
			if not el then return false end
			local t = numberText(cur, maxv)
			if t ~= lastText[key] then
				lastText[key] = t
				el.props.text = t
				return true
			end
			return false
		end
		if setText('health', parts.health.text, hCur, hMax) then vialsDirty = true end
		if setText('stamina', parts.stamina.text, sCur, sMax) then vialsDirty = true end
		if setText('magicka', parts.magicka.text, mCur, mMax) then runesDirty = true end
	end

	if vialsDirty and vialsHud then vialsHud:update() end
	if runesDirty and runesHud then runesHud:update() end
end

--------------------------------------------------------------------------------
-- Resize gesture
--------------------------------------------------------------------------------
-- Click-and-scroll while dragging. Each widget resizes on its own, because each
-- is dragged on its own -- whichever one you are holding is the one that grows.

local function resizeBy(delta)
	if vialsHud and vialsHud.layout.userData and vialsHud.layout.userData.isDragging then
		vialSection:set('VIAL_SIZE',
			math.max(24, math.min(600, math.floor((VIAL_SIZE or NATURAL_H) + delta))))
		return
	end
	if runesHud and runesHud.layout.userData and runesHud.layout.userData.isDragging then
		local h = math.max(32, math.min(512, math.floor((RUNE_HEIGHT or 139) + delta)))
		local scale = h / math.max(1, RUNE_HEIGHT or 139)
		runeSection:set('RUNE_HEIGHT', h)
		runeSection:set('RUNE_WIDTH', math.max(8, math.min(256,
			math.floor((RUNE_WIDTH or 35) * scale + 0.5))))
	end
end

if input.triggers['MenuMouseWheelUp'] then
	input.registerTriggerHandler('MenuMouseWheelUp', async:callback(function() resizeBy(6) end))
end
if input.triggers['MenuMouseWheelDown'] then
	input.registerTriggerHandler('MenuMouseWheelDown', async:callback(function() resizeBy(-6) end))
end

input.registerTriggerHandler('ToggleHUD', async:callback(function()
	refreshUiVisibility()
end))

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function onLoad()
	local layerId = ui.layers.indexOf('HUD')
	local size = ui.layers[layerId].size
	local function clampInto(section, xKey, yKey)
		section:set(xKey, math.floor(math.max(-200, math.min(_G[xKey] or 40, size.x + 200))))
		section:set(yKey, math.floor(math.max(-50, math.min(_G[yKey] or 40, size.y - 20))))
	end
	clampInto(vialSection, 'VIAL_X_POS', 'VIAL_Y_POS')
	clampInto(runeSection, 'RUNE_X_POS', 'RUNE_Y_POS')
	buildVialsHud()
end

--------------------------------------------------------------------------------
-- Public interface
--------------------------------------------------------------------------------

local externallyHidden = false

local interface = {
	version = 2,

	--- Current fill of each meter as a 0..1 fraction.
	getFractions = function()
		local hCur, hMax = statPair(healthStat)
		local sCur, sMax = statPair(fatigueStat)
		local mCur, mMax = statPair(magickaStat)
		return { health = hCur / hMax, stamina = sCur / sMax, magicka = mCur / mMax }
	end,

	--- How many of the eight runes are currently lit, and the total.
	getLitRunes = function()
		local mCur, mMax = statPair(magickaStat)
		local lit = runeState(mCur / mMax)
		return lit, RUNE_COUNT
	end,

	--- Hide or show. `which` is 'vials', 'runes', or nil for both.
	setVisible = function(show, which)
		externallyHidden = not show
		if which ~= 'runes' and vialsHud then
			vialsHud.layout.props.visible = show and true or false
			vialsHud:update()
		end
		if which ~= 'vials' and runesHud then
			runesHud.layout.props.visible = show and true or false
			runesHud:update()
		end
	end,

	isVisible = function() return not externallyHidden end,

	--- Pulse the flair behind the lit runes for `seconds` (default 1.5).
	--- This is what the FLAIR sheet is there for: a mod that wants to mark a
	--- spell going off, or magicka coming back, can flash the runes without
	--- knowing anything about how they are drawn.
	flashRunes = function(seconds)
		flairTimer = math.max(0, tonumber(seconds) or 1.5)
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
			if type(data) == 'table' then
				interface.setVisible(data.show ~= false, data.which)
			end
		end,
		DBSVialsFlashRunes = function(data)
			interface.flashRunes(type(data) == 'table' and data.seconds or nil)
		end,
	},
}
