---@omw-context player
--------------------------------------------------------------------------------
-- DBSVials -- dbsHUD
--------------------------------------------------------------------------------
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
-- No tint at all. Handed to anything whose artwork is meant to be shown as it
-- was drawn, so "untinted" is explicit in the call rather than a missing one.
local WHITE = util.color.rgb(1, 1, 1)

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
local VIAL_SIZE_MIN         = 24
local VIAL_SIZE_MAX         = 600
-- Every one of these was found by searching the offset against the supplied
-- flasks rather than reasoned about, because the tube's glass and its liquid do
-- not share a left edge -- the glass sits one pixel left of the column it
-- covers. Reasoning from "they are both the tube" gets that wrong.
local CAP_X, CAP_Y          = 8, 4
local GLASS_X, GLASS_Y      = 8, 15
local FILL_X                = 9
local BASE_X, BASE_Y        = 1, 112

-- The tube's glass is CUT, not drawn whole. Its art is 139 rows and carries a
-- flared foot at the bottom, but in this vessel the clasp is the termination,
-- so the tube ends where the clasp begins -- y140 -- and its own foot is never
-- shown. Drawn whole it runs on to y154 and crosses the clasp, which is the
-- clipping the example flasks do not have.
local GLASS_ROWS            = 125

-- Tube length. glass_tube_lengths.png holds one tube per height from 63 to 139
-- rows, each bottom-aligned in a 139-row cell, so any frame draws at one rect
-- and the foot never moves. 139 is bit-identical to glass_tube.png.
--
-- Shortening the tube moves everything below it up by the same amount, which is
-- the single figure D below: the clasp, the bulb and the foot of the liquid all
-- shift together, so the vessel stays one object.
local TUBE_LEN_MIN          = 63
local TUBE_LEN_MAX          = TUBE_H          -- 139
local TUBE_LEN_SHEET        = 'textures/dbsvials/glass_tube_lengths.png'

-- The transparent clasp is authored on the whole 40x190 canvas rather than on
-- the 40x67 the other lower pieces share, so it is placed at the origin.
local CLEAR_CLASP_W         = 40
local CLEAR_CLASP_H         = 190

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

-- Battlespire Vials: a test tube that drains through a colour ramp rather than
-- a vessel assembled from parts. One 32-frame atlas per set, 28x82 a frame,
-- frame 0 full and frame 31 empty, plus an outline that can go over it.
local ENGY_W, ENGY_H        = 28, 82
local ENGY_FRAMES           = 32
-- The two ramps are not interchangeable sets to pick between: one is the health
-- liquid and the other is the stamina liquid, which is what tells the two tubes
-- apart. ENGY01 runs yellow to red, ENGY02 blue to red.
local ENGY_PATHS = {
	health  = 'textures/dbsvials/ENGY01.png',
	stamina = 'textures/dbsvials/ENGY02.png',
}
local ENGY_FRAME_PATH       = 'textures/dbsvials/dbs_ENGY_frame.png'
-- Two masks generated from that art by dev/build_engy_masks.py, both white so
-- they can be tinted to anything. The liquid one is the region of each frame
-- that differs from the empty tube; the backing one is what the outline
-- encloses, which is where a tube-shaped background goes instead of a
-- rectangle behind a round-ended tube.
local ENGY_LIQUID_PATH      = 'textures/dbsvials/dbs_ENGY_liquid.png'
local ENGY_BACKING_PATH     = 'textures/dbsvials/dbs_ENGY_backing.png'
-- The last frame is the empty tube: glass and nothing else, which is the glass
-- layer the Vanilla colouring draws over its own flat liquid.
local ENGY_EMPTY_FRAME      = ENGY_FRAMES - 1

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
--   VIAL_CLEAR_CLASP    the fitted transparent clasp, over the liquid.
--                       Built from VIAL_CLEAR_GLASS + VIAL_CLASP_FRAME, which
--                       is what gives the clasp a glass front the liquid shows
--                       through instead of a solid one it hides behind.
--   glass_tube          the tube's own glass, cut to end at the clasp
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

-- The xs set, which is the default. Same eight runes, redrawn separated and
-- ordered on an even grid: 27 x 240, eight cells of exactly 30 rows. No
-- measuring needed, unlike the classic sheet.
--
-- Two layers, and only two: the outline is always drawn, the blue sits on top
-- of it per rune. KainGameRUNES_xs_empty + KainGameRUNES_xs reproduces
-- KainGameRUNES_xs_full exactly -- 0 difference -- so a rune empties by losing
-- its blue and leaving the outline behind, which is the whole idea.
-- One size setting drives the rune column. It is the height of ONE rune, so
-- Rune Length adds runes without resizing the ones already there, exactly as
-- Vial Length adds tube without resizing the vessel.
local RUNE_SIZE_DEFAULT     = 24
local RUNE_SIZE_MIN         = 4
local RUNE_SIZE_MAX         = 64
local XS_W, XS_H            = 27, 240
local XS_CELL               = 30
local XS_COUNT_MAX          = 32        -- elements built once; nothing is added later
local XS_BLUE_PATH          = 'textures/dbsvials/KainGameRUNES_xs.png'
local XS_EMPTY_PATH         = 'textures/dbsvials/KainGameRUNES_xs_empty.png'

-- Pips: the same eight runes as separate 45x45 images, stacked in the sheet's
-- order and repeating upward. How many fit before a new column starts, and
-- which side that column goes, are settings.
local PIP_SIZE_ART          = 45
local PIP_COUNT_MAX         = 64        -- elements built once; nothing is added later
local PIP_PATHS = {}
for i = 1, 8 do PIP_PATHS[i] = 'textures/dbsvials/kg_rune' .. i .. '.png' end
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

--- Current value, the scale to draw against, and the unfortified maximum.
---
--- The three are not the same thing. The scale is max(base, base + modifier),
--- which differs from base + modifier in the two directions for good reasons:
---
---   A FORTIFY raises the scale, so the vessel does hold more and your liquid
---   is a smaller share of it. That is honest -- you really do have more
---   capacity -- and the part above `base` is drawn in its own colour, so the
---   smaller share reads as "the vessel grew" rather than "I lost something".
---
---   A DRAIN does NOT lower the scale. Scaling to base + modifier there would
---   make the liquid jump UP as your maximum is taken away, which reads as a
---   gain. The vessel keeps its size and the headroom above the liquid is what
---   has gone.
local function statPair(stat)
	local base = stat.base or 0
	local eff  = base + (stat.modifier or 0)
	local maxv = math.max(base, eff)
	if maxv < 1 then maxv = 1 end
	if base < 0 then base = 0 end
	if base > maxv then base = maxv end
	local cur = stat.current or 0
	if cur < 0 then cur = 0 end
	if cur > maxv then cur = maxv end
	return cur, maxv, base
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vialsHud, runesHud                -- two independent roots

-- Drag state lives here rather than on the widget. Resizing is a settings
-- change, a settings change rebuilds the widget, and a rebuilt widget gets a
-- fresh userData -- so the first notch of the wheel used to wipe the very flag
-- the second notch tests, and the wheel appeared to work once and then stop.
-- Keeping the table here and handing the SAME table to each new root means the
-- gesture survives being rebuilt underneath itself.
local dragState = { vialsHud = {}, runesHud = {} }

--------------------------------------------------------------------------------
-- Eased display values
--------------------------------------------------------------------------------
-- The fraction that gets DRAWN, which chases the real one rather than jumping
-- to it. `1 - exp(-k*dt)` is the frame-rate-independent form: a plain
-- `d * 0.1` per frame moves at a speed that depends on the frame rate, which is
-- why a mod tuned at 60fps looks wrong at 144.
--
-- `animating` is what keeps this affordable. Once every value is within a hair
-- of its target it snaps, the flag clears, and onUpdate goes back to the cheap
-- quantised comparison that does nothing when nothing has moved. Without the
-- snap an exponential approach never arrives and the HUD works forever.
local shown = { health = nil, stamina = nil, magicka = nil }
local animating = false
local SNAP = 0.0005

local function ease(key, target, dt)
	local cur = shown[key]
	if cur == nil then shown[key] = target; return target end
	local rate = FILL_SMOOTHING or 0
	if rate <= 0 then shown[key] = target; return target end
	local d = target - cur
	if math.abs(d) < SNAP then shown[key] = target; return target end
	cur = cur + d * (1 - math.exp(-rate * dt))
	shown[key] = cur
	animating = true
	return cur
end

local function dragging(hud)
	return hud and hud.layout.userData and hud.layout.userData.isDragging
end

--- A rebuild in the middle of a drag destroys the widget that captured the
--- mouse, so its release can go nowhere and the flag would stay set for good.
--- One button read a frame settles it.
local function clearStuckDrag()
	if not input.isMouseButtonPressed then return end
	if input.isMouseButtonPressed(1) then return end
	for _, st in pairs(dragState) do st.isDragging = false end
end

local vialsBackground, runesBackground

local parts = {
	health  = {},
	stamina = {},
	magicka = { flair = {}, glow2 = {}, glow1 = {}, xs = {}, pips = {}, xsOutline = {} },
}

local fillTex   = {}        -- [rows] -> texture showing the bottom `rows` of the tube
local glow1Tex, glow2Tex, flairTex = {}, {}, {}
local xsBlueTex, xsEmptyTex, pipTex = {}, {}, {}
local engyTex, engyFrameTex = {}, {}
local engyLiquidTex, engyBackingTex = {}, nil
local tubeLenTex
local runeTex, glassTex, claspTex, capTex, residueTex, bulbTex, clearClaspTex

-- The three stats as they were last read, for the idle check in onUpdate. The
-- sentinel is a value no stat can hold, so the first frame after a rebuild is
-- never mistaken for an idle one -- a rebuilt tree has everything still to draw
-- however steady the player's health is.
local lastRaw = { -1, -1, -1, -1, -1, -1 }
local lastHealthRows  = -1
local lastHealthPlain = -1
local lastStaminaPlain = -1
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

-- A ui.texture is decided entirely by its path and its sub-rect, so the same
-- three numbers always produce the same resource. Every rebuild used to cut the
-- whole set again -- around 250 of them, including a 140-frame fill ramp -- and
-- a rebuild happens on every settings change, which means on every notch of the
-- resize wheel. Cutting them once and keeping them is the difference between a
-- wheel that drags and one that does not.
local texCache = {}

local function tex(path, ox, oy, w, h)
	if not validPath(path) then return nil end
	local key = ox and (path .. '|' .. ox .. ',' .. oy .. ',' .. w .. ',' .. h) or path
	local t = texCache[key]
	if t == nil then
		t = ox and ui.texture { path = path, offset = v2(ox, oy), size = v2(w, h) }
			or ui.texture { path = path }
		texCache[key] = t
	end
	return t
end

local function maybeTexture(path)
	return tex(path)
end

--- Tube length in art rows, and D: how far everything below the tube moves up.
--- Every figure under the tube -- clasp, bulb, the foot of the liquid, the
--- assembly height -- is its full-length value minus D, so one number shortens
--- the whole vessel and nothing drifts out of register.
local function tubeLength()
	local L = math.floor(VIAL_LENGTH or TUBE_LEN_MAX)
	if L < TUBE_LEN_MIN then L = TUBE_LEN_MIN end
	if L > TUBE_LEN_MAX then L = TUBE_LEN_MAX end
	return L, TUBE_LEN_MAX - L
end

local function battlespire()
	return (VIAL_STYLE or 'Classic') == 'Battlespire'
end

--- Which of the two Battlespire colourings is in use.
---
--- Classic is the artwork as supplied: the liquid shifts through its own ramp
--- as it drains -- yellow to red for health, blue to red for stamina -- and the
--- glass is left alone, so nothing here is tinted at all.
---
--- Vanilla replaces the liquid with one flat colour that does not shift, taking
--- the same two colours the Classic LOK vials use, so the two vial sets read
--- alike. The glass comes from the empty frame of the same artwork, drawn over
--- the flat liquid, so the tube is still the tube.
local function engyVanilla()
	return (ENGY_COLOUR or 'Classic') == 'Vanilla'
end

local function buildTextures()
	-- One texture per possible fill height, cut from the bottom of the tube art
	-- so the taper stays the right shape. 140 of them, cut once and cached.
	fillTex = {}
	for h = 0, TUBE_H do
		fillTex[h] = tex(TEX.fill, 0, TUBE_H - h, TUBE_W, h)
	end

	-- The tube, cut from the length sheet. The frame for length L starts
	-- L - TUBE_LEN_MIN cells down, and the tube occupies the bottom L rows of
	-- its 139-row cell, so the drawn part starts D rows into that cell.
	--
	-- Cut, not squashed: handing the widget a 139-row texture in a shorter rect
	-- would compress the whole tube instead of ending it.
	local L, D = tubeLength()
	local drawn = math.max(1, GLASS_ROWS - D)
	-- The length sheet is the source unless the setting names some OTHER file.
	-- The default path is glass_tube.png, whose art is the sheet's last frame,
	-- so it has to count as "use the sheet" -- otherwise the length setting
	-- silently does nothing, which is exactly what it did until this check.
	local custom = validPath(GLASS_TEXTURE)
		and GLASS_TEXTURE ~= TUBE_LEN_SHEET
		and GLASS_TEXTURE ~= TEX.glass
	if custom then
		-- A custom path overrides the sheet and is taken from its own top.
		glassTex = tex(GLASS_TEXTURE, 0, 0, TUBE_W, drawn)
	else
		glassTex = tex(TUBE_LEN_SHEET, 0, (L - TUBE_LEN_MIN) * TUBE_H + D,
			TUBE_W, drawn)
	end

	-- Battlespire: one cut per frame of the drain, and the same for the outline.
	-- One ramp per vial now, so both are cut and each vial picks its own.
	engyTex, engyFrameTex, engyLiquidTex = { health = {}, stamina = {} }, {}, {}
	for i = 0, ENGY_FRAMES - 1 do
		local y = i * ENGY_H
		engyTex.health[i]  = tex(ENGY_PATHS.health,  0, y, ENGY_W, ENGY_H)
		engyTex.stamina[i] = tex(ENGY_PATHS.stamina, 0, y, ENGY_W, ENGY_H)
		engyFrameTex[i]    = tex(ENGY_FRAME_PATH,    0, y, ENGY_W, ENGY_H)
		engyLiquidTex[i]   = tex(ENGY_LIQUID_PATH,   0, y, ENGY_W, ENGY_H)
	end
	engyBackingTex = tex(ENGY_BACKING_PATH, 0, 0, ENGY_W, ENGY_H)

	clearClaspTex  = maybeTexture(CLEAR_CLASP_TEXTURE)
	claspTex   = SHOW_CLASP ~= false and maybeTexture(TEX.clasp) or nil
	capTex     = SHOW_CAP ~= false and maybeTexture(TEX.cap) or nil
	residueTex = SHOW_RESIDUE ~= false and maybeTexture(TEX.residue) or nil
	bulbTex    = maybeTexture(BULB_TEXTURE)

	runeTex = tex(RUNES_PATH, 0, 0, RUNE_SHEET_W, RUNE_CONTENT_H)
	-- Both xs sheets cut into their eight even cells. The outline used to be
	-- drawn as one whole image, which was fine while the column was always
	-- eight runes long -- it cannot repeat, so a longer column needs it cut.
	xsBlueTex, xsEmptyTex = {}, {}
	for i = 1, RUNE_COUNT do
		local y = (i - 1) * XS_CELL
		xsBlueTex[i]  = tex(XS_BLUE_PATH,  0, y, XS_W, XS_CELL)
		xsEmptyTex[i] = tex(XS_EMPTY_PATH, 0, y, XS_W, XS_CELL)
	end
	pipTex = {}
	for i = 1, 8 do pipTex[i] = tex(PIP_PATHS[i]) end

	-- One slice per rune per sheet. The front runes stay whole: they are always
	-- fully drawn, so there is nothing to switch and no reason to cut them.
	glow1Tex, glow2Tex, flairTex = {}, {}, {}
	for i = 1, RUNE_COUNT do
		local y0, y1 = RUNE_CUTS[i], RUNE_CUTS[i + 1]
		local function slice(path)
			return tex(path, 0, y0, RUNE_SHEET_W, y1 - y0)
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
--- How many runes the xs column is drawn with. The Classic sheet cannot vary --
--- its eight are measured bands of one specific image -- but the xs sheet is an
--- even grid, so the eight shapes can repeat to make a longer column, the same
--- way the pips repeat.
---
--- This changes what a rune MEANS, which the vial's length does not: a rune is
--- one Nth of magicka, so a longer column is a finer readout, not just a taller
--- one. Multiples of eight keep the pattern whole.
local function xsCount()
	local n = math.floor(RUNE_LENGTH or RUNE_COUNT)
	if n < 1 then n = 1 end
	if n > XS_COUNT_MAX then n = XS_COUNT_MAX end
	return n
end

local function runeState(frac, n)
	n = n or RUNE_COUNT
	if frac <= 0 then return 0, 0 end
	if frac >= 1 then return n, ALPHA_STEPS end
	local scaled  = frac * n
	local whole   = math.floor(scaled)
	local partial = scaled - whole
	if partial > 0 then
		return whole + 1, math.max(1, math.floor(partial * ALPHA_STEPS + 0.5))
	end
	return whole, ALPHA_STEPS
end

--- Maps a rune's position in the column (1 = top of the art) to its place in
--- the fill order. Filling from the bottom means the last rune lights first.
local function runeSlotFor(index, n)
	n = n or RUNE_COUNT
	if RUNE_FILL_FROM == 'Top' then return index end
	return n + 1 - index
end

--- How many pips to show, and what one pip is worth.
--- MMUI counts castings of the selected spell, so the row shortens as a spell
--- gets dearer; with nothing selected there is nothing to count, so it falls
--- back to a flat amount of magicka rather than showing an empty row.
local function pipsFor(mCur)
	local per = math.max(1, math.floor(PIP_MAGICKA or 10))
	if (PIP_SOURCE or 'One casting of the selected spell')
			== 'One casting of the selected spell' then
		local getSpell = types.Actor.getSelectedSpell
		local spell = getSpell and getSpell(self_) or nil
		local cost = spell and spell.cost or nil
		if type(cost) == 'number' and cost >= 1 then per = math.floor(cost) end
	end
	local n = math.floor(mCur / per)
	if n < 0 then n = 0 end
	if n > PIP_COUNT_MAX then n = PIP_COUNT_MAX end
	return n, per
end

local function runeStyle()
	return RUNE_STYLE or 'Runes'
end

--- Fill height in tube rows for a 0..1 fraction. A shorter tube has a shorter
--- travel, so the liquid still reaches the collar at full and the foot at empty.
local function fillRowsFor(frac)
	local _, D = tubeLength()
	return math.floor(FILL_MIN + frac * (FILL_MAX - D - FILL_MIN) + 0.5)
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

--- Scale factor and pixel size of one vial assembly.
---
--- Scale and length are independent, which is the whole point of having both.
--- The scale comes from the FULL art height, never from the shortened one, so
--- Vial Size means "how big the glass is" and Vial Length means "how much of it
--- there is". Dividing by the shortened height instead would make the setting
--- "fill this many pixels whatever the length", and shortening the vial would
--- silently fatten it -- same screen height, thicker glass.
local function vialMetrics()
	local size = math.max(24, math.floor(VIAL_SIZE or NATURAL_H))
	if battlespire() then
		-- A plain 28x82 tube, so the size setting is its height and the width
		-- follows the art. Nothing shifts, so D is zero.
		local k = size / ENGY_H
		return k, math.max(1, math.floor(ENGY_W * k)), size, 0
	end
	local _, D = tubeLength()
	local k = size / NATURAL_H
	-- The widget shrinks with the vessel rather than the vessel growing to fill
	-- the widget. Size is the height at full length; a shorter vial is shorter.
	local h = math.max(1, math.floor((NATURAL_H - D) * k + 0.5))
	return k, math.max(1, math.floor(NATURAL_W * k)), h, D
end

--- Width and height of the rune column, from one size setting.
---
--- There used to be two sliders and the wheel drove them together by ratio,
--- recomputing the width from the width it had just rounded. That compounds:
--- twenty notches up and twenty back does not return the column to where it
--- started, and the art ends up stretched. One number and a fixed aspect
--- cannot drift, because the width is never read back -- it is derived.
---
--- The aspect is the art's own. The xs sheet is 27x240 in eight 30-row cells,
--- so a rune is 27x30; the Classic sheet is 70 wide over 292 rows of content.
--- They are quite different shapes, which is why the aspect has to follow the
--- style rather than being one constant.
local function runeMetrics()
	local size = math.max(4, math.floor(RUNE_SIZE or RUNE_SIZE_DEFAULT))
	if runeStyle() == 'Classic' then
		-- The Classic sheet is one drawing of eight bands, so its height is
		-- fixed at eight runes' worth whatever the count setting says.
		local h = size * RUNE_COUNT
		return math.max(4, math.floor(h * RUNE_SHEET_W / RUNE_CONTENT_H + 0.5)), h
	end
	return math.max(4, math.floor(size * XS_W / XS_CELL + 0.5)), size * RUNE_COUNT
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
	local k, w, h, D = vialMetrics()
	local p = parts[key]
	local stack = ui.content {}

	-- Battlespire: no assembly, a drain atlas. Lowest is an optional backing
	-- cut to what the outline encloses -- a rectangle behind a round-ended tube
	-- reads as a mistake -- then the liquid, then the outline.
	if battlespire() then
		if ENGY_SHOW_BACKING then
			p.engyBacking = pixelImage('engyback' .. key, engyBackingTex, 0, 0, w, h,
				ENGY_BACKING_TINT, ENGY_BACKING_ALPHA or 1)
			stack:add(p.engyBacking)
		end
		if engyVanilla() then
			-- Flat liquid first, then the empty tube's glass over it. The glass
			-- is the artwork's own last frame, so the highlights still fall
			-- where they were drawn to fall.
			if SHOW_FORTIFY ~= false then
				p.engyFort = pixelImage('engyfort' .. key, engyLiquidTex[0],
					0, 0, w, h, FORTIFY_TINT, 1)
				p.engyFort.props.visible = false
				stack:add(p.engyFort)
			end
			p.engyLiquid = pixelImage('engyliquid' .. key, engyLiquidTex[0],
				0, 0, w, h, colour, 1)
			stack:add(p.engyLiquid)
			p.engy = pixelImage('engy' .. key, engyTex[key][ENGY_EMPTY_FRAME],
				0, 0, w, h, GLASS_TINT, 1)
			stack:add(p.engy)
		else
			-- Classic: the artwork as drawn, ramp and glass in one image and
			-- nothing tinted. Health gets the warm ramp, stamina the cool one.
			p.engy = pixelImage('engy' .. key, engyTex[key][0], 0, 0, w, h,
				WHITE, 1)
			stack:add(p.engy)
		end
		if ENGY_SHOW_FRAME then
			p.engyFrame = pixelImage('engyframe' .. key, engyFrameTex[0], 0, 0, w, h,
				FITTING_TINT, ENGY_FRAME_ALPHA or 1)
			stack:add(p.engyFrame)
		end
		local body = {
			type = ui.TYPE.Widget,
			name = key .. 'Vial',
			props = { size = v2(w, h) },
			content = stack,
		}
		if not SHOW_NUMBERS then p.text = nil; return body end
		local ts = math.max(8, math.floor(NUMBER_SIZE or 13))
		p.text = textLayout(key .. 'Num', ts, NUMBER_COLOR, math.max(w, ts * 5))
		return {
			type = ui.TYPE.Flex,
			name = key .. 'Group',
			props = { horizontal = false, align = ui.ALIGNMENT.Center, autoSize = true },
			content = ui.content { body, p.text },
		}
	end

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
	p.clasp = place('clasp' .. key, claspTex, BASE_X, BASE_Y - D, BASE_W, BASE_H,
		FITTING_TINT, 1)

	-- The bulb's back, so it is not hollow above the liquid line.
	p.bulb = place('bulb' .. key, bulbTex, BASE_X, BASE_Y - D, BASE_W, BASE_H,
		BULB_TINT, BULB_ALPHA or 1)
	p.residue = place('residue' .. key, residueTex, BASE_X, BASE_Y - D, BASE_W, BASE_H,
		colour, RESIDUE_ALPHA or 1)

	-- The liquid, in two layers. The lower one is the whole column in the
	-- fortify colour and the upper one is the unfortified part over it, so what
	-- shows of the lower is exactly what a fortify effect has added. With no
	-- effect running the lower one is hidden and this is one draw, as before.
	-- Position and size are set every time the level changes, so the figures
	-- here are only the starting state.
	local rows = FILL_MIN
	if SHOW_FORTIFY ~= false then
		p.fort = place('fort' .. key, fillTex[rows],
			FILL_X, FILL_BOTTOM - D - rows, TUBE_W, math.max(1, rows),
			FORTIFY_TINT, 1)
		if p.fort then p.fort.props.visible = false end
	end
	p.fill = place('fill' .. key, fillTex[rows],
		FILL_X, FILL_BOTTOM - D - rows, TUBE_W, math.max(1, rows), colour, 1)

	-- Top: the vessel's front glass, then the tube's, then the collar.
	-- The transparent clasp is authored on the full-length canvas, so it is
	-- drawn shifted up with everything else rather than rescaled.
	p.clearClasp = place('clear' .. key, clearClaspTex, 0, -D,
		CLEAR_CLASP_W, CLEAR_CLASP_H, GLASS_TINT, 1)
	p.glass = place('glass' .. key, glassTex,
		GLASS_X, GLASS_Y, TUBE_W, GLASS_ROWS - D, GLASS_TINT, 1)
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
	p.flair, p.glow2, p.glow1, p.xs, p.pips, p.xsOutline = {}, {}, {}, {}, {}, {}
	local stack = ui.content {}

	-- Pips: one rune per casting, stacking upward and starting a new column
	-- once the set length is reached. Every element is built here and hidden;
	-- counting up and down is a visibility flag, never a tree edit.
	if runeStyle() == 'Pips' then
		local size = math.max(6, math.floor(PIP_SIZE or 22))
		local gap  = math.floor(PIP_GAP or -4)
		local perCol = math.max(1, math.floor(PIP_COLUMN or 8))
		local step = math.max(1, size + gap)
		local cols = math.ceil(PIP_COUNT_MAX / perCol)
		local leftward = (PIP_WRAP or 'Right') == 'Left'
		local cw = cols * step
		local ch = perCol * step
		for i = 1, PIP_COUNT_MAX do
			local c = math.floor((i - 1) / perCol)
			local r = (i - 1) % perCol
			-- Columns are laid out for the maximum, so the main column stays put
			-- and later ones grow to the chosen side without anything moving.
			local cx = leftward and (cols - 1 - c) or c
			local el = pixelImage('pip' .. i, pipTex[((i - 1) % 8) + 1],
				cx * step, (perCol - 1 - r) * step, size, size,
				RUNE_TINT, RUNE_BASE_ALPHA or 1)
			el.props.visible = false
			p.pips[i] = el
			stack:add(el)
		end
		local body = {
			type = ui.TYPE.Widget,
			name = 'runeColumn',
			props = { size = v2(cw, ch) },
			content = stack,
		}
		if not SHOW_NUMBERS then p.text = nil; return body end
		local ts = math.max(8, math.floor(NUMBER_SIZE or 13))
		p.text = textLayout('magickaNum', ts, NUMBER_COLOR, math.max(cw, ts * 5))
		return {
			type = ui.TYPE.Flex,
			name = 'magickaGroup',
			props = { horizontal = false, align = ui.ALIGNMENT.Center, autoSize = true },
			content = ui.content { body, p.text },
		}
	end

	-- The xs set: the outlines underneath, one per rune, and the blue over them
	-- one rune at a time. An even 30-row grid, so the cells need no measuring.
	if runeStyle() == 'Runes' then
		-- A rune keeps the height it has at eight, so a longer column is a
		-- longer column rather than the same one subdivided smaller. That is
		-- what makes this the same gesture as the vial's length.
		local n = xsCount()
		-- A rune keeps the height it has at eight, so the column is extended by
		-- gaining runes rather than by subdividing the same space smaller.
		-- Rune Height stays the height of eight of them, which is what makes
		-- the default pixel-identical to a fixed eight.
		local cellF = h / RUNE_COUNT
		local edge  = {}
		for i = 0, n do edge[i] = math.floor(i * cellF) end
		local colH = edge[n]
		for i = 1, n do
			-- The eight shapes repeat, as the pips do.
			local shape = ((i - 1) % RUNE_COUNT) + 1
			local el = pixelImage('runeOutline' .. i, xsEmptyTex[shape],
				0, edge[i - 1], w, edge[i] - edge[i - 1],
				RUNE_TINT, RUNE_BASE_ALPHA or 1)
			p.xsOutline[i] = el
			stack:add(el)
		end
		for i = 1, n do
			local shape = ((i - 1) % RUNE_COUNT) + 1
			local el = pixelImage('xs' .. i, xsBlueTex[shape],
				0, edge[i - 1], w, edge[i] - edge[i - 1],
				GLOW_TINT, GLOW_ALPHA or 1)
			el.props.visible = false
			p.xs[i] = el
			stack:add(el)
		end
		p.base = p.xsOutline[1]
		local body = {
			type = ui.TYPE.Widget,
			name = 'runeColumn',
			props = { size = v2(w, colH) },
			content = stack,
		}
		if not SHOW_NUMBERS then p.text = nil; return body end
		local ts = math.max(8, math.floor(NUMBER_SIZE or 13))
		p.text = textLayout('magickaNum', ts, NUMBER_COLOR, math.max(w, ts * 5))
		return {
			type = ui.TYPE.Flex,
			name = 'magickaGroup',
			props = { horizontal = false, align = ui.ALIGNMENT.Center, autoSize = true },
			content = ui.content { body, p.text },
		}
	end

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
				resource = tex('black'),
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
		userData = dragState[name] or {},
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
	parts.magicka = { flair = {}, glow2 = {}, glow1 = {}, xs = {}, pips = {}, xsOutline = {} }

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
	lastHealthPlain, lastStaminaPlain = -1, -1
	lastRaw[1] = -1
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
		-- Classic leaves the artwork alone; Vanilla tints the flat liquid with
		-- the same colour the LOK vial uses and the glass with the glass tint.
		if p.engy then
			p.engy.props.color = engyVanilla() and GLASS_TINT or WHITE
		end
		if p.engyLiquid then p.engyLiquid.props.color = colour end
		if p.engyFort then p.engyFort.props.color = FORTIFY_TINT end
		if p.engyBacking then
			p.engyBacking.props.color = ENGY_BACKING_TINT
			p.engyBacking.props.alpha = ENGY_BACKING_ALPHA or 1
		end
		if p.engyFrame then
			p.engyFrame.props.color = FITTING_TINT
			p.engyFrame.props.alpha = ENGY_FRAME_ALPHA or 1
		end
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
	for i = 1, XS_COUNT_MAX do
		if m.xs[i] then m.xs[i].props.color = GLOW_TINT end
		if m.xsOutline and m.xsOutline[i] then
			m.xsOutline[i].props.color = RUNE_TINT
			m.xsOutline[i].props.alpha = RUNE_BASE_ALPHA or 1
		end
	end
	for i = 1, PIP_COUNT_MAX do
		if m.pips[i] then m.pips[i].props.color = RUNE_TINT end
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
local function placeFill(el, rows, k, D)
	if not el then return end
	el.props.resource = fillTex[rows]
	el.props.position = v2(math.floor(FILL_X * k),
		math.floor((FILL_BOTTOM - (D or 0) - rows) * k))
	el.props.size = v2(math.max(1, math.floor(TUBE_W * k)),
		math.max(1, math.floor(rows * k)))
	-- An empty vessel draws no liquid at all, rather than a one-pixel sliver in
	-- the bottom of the bulb.
	el.props.visible = rows > 0
end

--- `rows` is the whole liquid column; `plain` is how much of it is unfortified.
---
--- The fortified part is NOT drawn as a band. A band would need a sub-rect cut
--- from the middle of the tube art, and there are 140 x 140 possible middles --
--- far too many to cut and keep. Instead the fortified layer is a FULL column
--- to `rows` in its own colour, with the ordinary liquid drawn to `plain` on
--- top of it, so only the part above shows. Two draws from the 140 cuts that
--- already exist, and the taper at the foot stays correct in both.
local function setVialFill(p, rows, k, D, plain)
	plain = math.min(plain or rows, rows)
	if p.fort then
		if rows > plain then
			placeFill(p.fort, rows, k, D)
		else
			p.fort.props.visible = false
		end
	end
	placeFill(p.fill, plain, k, D)
end

--- True when nothing about the stats has moved since the last frame. Three
--- reads and six comparisons, against a body that otherwise does three
--- divisions, six quantisations and a walk over every rune.
---
--- The pulse and the flair are animations in their own right, so they are asked
--- too: idle means nothing on screen has any reason to change, not merely that
--- the player's health is steady.
local function statsIdle()
	local a, b, c = healthStat, fatigueStat, magickaStat
	local r = lastRaw
	if r[1] == a.current and r[2] == a.base + (a.modifier or 0)
		and r[3] == b.current and r[4] == b.base + (b.modifier or 0)
		and r[5] == c.current and r[6] == c.base + (c.modifier or 0) then
		return true
	end
	r[1], r[2] = a.current, a.base + (a.modifier or 0)
	r[3], r[4] = b.current, b.base + (b.modifier or 0)
	r[5], r[6] = c.current, c.base + (c.modifier or 0)
	return false
end

local function onUpdate(dt)
	if not (vialsHud or runesHud) then return end
	clearStuckDrag()

	-- Nothing to draw and nothing moving towards being drawn: stop here. That
	-- is the state the HUD is in for most of the game, and it is the whole
	-- point of the snap in `ease` -- an exponential approach never arrives on
	-- its own, so without it this would never be true again.
	local applies = LOW_APPLIES[LOW_WARNING or 'Off'] or LOW_APPLIES['Off']
	if statsIdle() and not animating and flairTimer <= 0
		and next(applies) == nil then
		return
	end

	local hCur, hMax, hBase = statPair(healthStat)
	local sCur, sMax, sBase = statPair(fatigueStat)
	local mCur, mMax, mBase = statPair(magickaStat)

	-- The eased values are what gets drawn. With smoothing off these are the
	-- real ones and `animating` never sets, so the cheap path is unchanged.
	animating = false
	local hFrac = ease('health',  hCur / hMax, dt)
	local sFrac = ease('stamina', sCur / sMax, dt)
	local mFrac = ease('magicka', mCur / mMax, dt)

	-- The share of the column that is NOT fortified. Everything above it is
	-- what an effect has added, and is drawn in the fortify colour.
	local hPlain = math.min(hFrac, hBase / hMax)
	local sPlain = math.min(sFrac, sBase / sMax)

	local vialsDirty, runesDirty = false, false
	local k, _, _, D = vialMetrics()

	-- --- vials ------------------------------------------------------------
	-- Quantised to whole rows of the tube art, which is also the index into the
	-- pre-cut texture array. A change smaller than one row cannot be drawn, so
	-- there is no reason to notice it.
	if vialsHud then
		if battlespire() then
			-- Quantised to the atlas: 32 states, so the texture is only swapped
			-- when a different frame would be drawn. Frame 0 is full.
			local function engyFrameFor(frac)
				return ENGY_FRAMES - 1 - math.floor(frac * (ENGY_FRAMES - 1) + 0.5)
			end
			local function setEngy(key, frac, plainFrac, last, lastPlain)
				local f  = engyFrameFor(frac)
				local pf = engyFrameFor(plainFrac)
				if f == last and pf == lastPlain then return last, lastPlain, false end
				local p = parts[key]
				-- Vanilla can show a fortified part the same way the Classic
				-- vials do: the whole column underneath in the fortify colour,
				-- the unfortified part over it. The Classic ramp cannot -- it is
				-- one image carrying its own colour -- so it just draws the
				-- whole column, as it always has.
				if p.engyFort then
					p.engyFort.props.visible = pf > f
					if pf > f then p.engyFort.props.resource = engyLiquidTex[f] end
				end
				if p.engyLiquid then
					p.engyLiquid.props.resource = engyLiquidTex[pf]
					return f, pf, true
				end
				-- Classic swaps the whole tube; Vanilla swaps only the flat
				-- liquid, because its glass is one fixed frame.
				if p.engy then p.engy.props.resource = engyTex[key][f] end
				if p.engyFrame then p.engyFrame.props.resource = engyFrameTex[f] end
				return f, pf, true
			end
			if SHOW_HEALTH ~= false then
				local f, pf, ch = setEngy('health', hFrac, hPlain,
					lastHealthRows, lastHealthPlain)
				lastHealthRows, lastHealthPlain = f, pf
				vialsDirty = vialsDirty or ch
			end
			if SHOW_STAMINA ~= false then
				local f, pf, ch = setEngy('stamina', sFrac, sPlain,
					lastStaminaRows, lastStaminaPlain)
				lastStaminaRows, lastStaminaPlain = f, pf
				vialsDirty = vialsDirty or ch
			end
		else
			-- Two quantised numbers now, the whole column and its unfortified
			-- part, so the comparison is on both. Without a fortify effect the
			-- second equals the first and this is the old single comparison.
			if SHOW_HEALTH ~= false then
				local rows = fillRowsFor(hFrac)
				local plain = fillRowsFor(hPlain)
				if rows ~= lastHealthRows or plain ~= lastHealthPlain then
					lastHealthRows, lastHealthPlain = rows, plain
					setVialFill(parts.health, rows, k, D, plain)
					vialsDirty = true
				end
			end
			if SHOW_STAMINA ~= false then
				local rows = fillRowsFor(sFrac)
				local plain = fillRowsFor(sPlain)
				if rows ~= lastStaminaRows or plain ~= lastStaminaPlain then
					lastStaminaRows, lastStaminaPlain = rows, plain
					setVialFill(parts.stamina, rows, k, D, plain)
					vialsDirty = true
				end
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
	if runesHud and SHOW_RUNES ~= false and runeStyle() == 'Pips' then
		-- Quantised to the count, so a pip row only changes when a whole pip
		-- is gained or lost.
		local n = pipsFor(mCur)
		if n ~= lastRuneLit then
			lastRuneLit = n
			for i = 1, PIP_COUNT_MAX do
				local el = parts.magicka.pips[i]
				if el then el.props.visible = i <= n end
			end
			runesDirty = true
		end
	elseif runesHud and SHOW_RUNES ~= false and runeStyle() == 'Runes' then
		-- A rune keeps its outline always and loses its blue as its share
		-- drains. The outlines never change, so only the blue is touched.
		local n = xsCount()
		local lit, partial = runeState(mFrac, n)
		if not GLOW_PARTIAL then partial = ALPHA_STEPS end
		if lit ~= lastRuneLit or partial ~= lastRunePartial then
			lastRuneLit, lastRunePartial = lit, partial
			local fullAlpha = GLOW_ALPHA or 1
			for i = 1, n do
				local el = parts.magicka.xs[i]
				if el then
					local slot = runeSlotFor(i, n)
					el.props.visible = slot <= lit
					el.props.alpha = (slot == lit)
						and (fullAlpha * partial / ALPHA_STEPS)
						or fullAlpha
				end
			end
			runesDirty = true
		end
	elseif runesHud and SHOW_RUNES ~= false then
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
		if pulse('health', hFrac, parts.health.fill or parts.health.engyLiquid or parts.health.engy) then
			vialsDirty = true
		end
		if pulse('stamina', sFrac, parts.stamina.fill or parts.stamina.engyLiquid or parts.stamina.engy) then
			vialsDirty = true
		end
	end

	-- --- flair ------------------------------------------------------------
	-- The layer behind the runes, for pulses and flashes. It carries the
	-- magicka low warning -- which used to dim the runes themselves, a poor cue,
	-- since going darker is what running out already looks like -- and any flash
	-- another mod asks for through the interface.
	--
	-- It shows only under lit runes, so what pulses is what you have left.
	if runesHud and SHOW_RUNES ~= false and runeStyle() == 'Classic' then
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

-- A fixed step in pixels cannot feel the same at both ends of a range: +6 on a
-- 24px vial is a quarter of it, +6 on a 600px one is a rounding error, and the
-- two widgets had different ranges on top of that. The step is a RATIO instead,
-- so a notch moves everything by the same proportion and the two widgets behave
-- alike. A twelfth of an octave is about 6% -- twelve notches to double.
local WHEEL_RATIO = 2 ^ (1 / 12)

--- One notch. `dir` is +1 or -1; holding Shift steps a single pixel instead,
--- for the last bit of placement.
local function nudge(value, dir, lo, hi, fine)
	value = value or lo
	local out
	if fine then
		out = value + dir
	else
		out = (dir > 0) and (value * WHEEL_RATIO) or (value / WHEEL_RATIO)
		-- Near the bottom of a range a 6% step rounds to nothing at all, which
		-- reads as a dead wheel. Fall back to a pixel so it always moves.
		if math.floor(out + 0.5) == math.floor(value + 0.5) then out = value + dir end
	end
	out = math.floor(out + 0.5)
	if out < lo then out = lo end
	if out > hi then out = hi end
	return out
end

local function resizeBy(dir)
	local fine = input.isShiftPressed and input.isShiftPressed()
	if dragging(vialsHud) then
		local v = nudge(VIAL_SIZE or NATURAL_H, dir, VIAL_SIZE_MIN, VIAL_SIZE_MAX, fine)
		-- A redundant set still fires the subscription and rebuilds the tree.
		if v ~= VIAL_SIZE then vialSection:set('VIAL_SIZE', v) end
		return
	end
	if dragging(runesHud) then
		local v = nudge(RUNE_SIZE or RUNE_SIZE_DEFAULT, dir,
			RUNE_SIZE_MIN, RUNE_SIZE_MAX, fine)
		-- One setting, one write, one rebuild. The width follows from the art's
		-- own aspect, so there is nothing else to keep in step.
		if v ~= RUNE_SIZE then runeSection:set('RUNE_SIZE', v) end
	end
end

if input.triggers['MenuMouseWheelUp'] then
	input.registerTriggerHandler('MenuMouseWheelUp', async:callback(function() resizeBy(1) end))
end
if input.triggers['MenuMouseWheelDown'] then
	input.registerTriggerHandler('MenuMouseWheelDown', async:callback(function() resizeBy(-1) end))
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
		if runeStyle() == 'Pips' then
			local n = pipsFor(mCur)
			return n, PIP_COUNT_MAX
		end
		local n = (runeStyle() == 'Runes') and xsCount() or RUNE_COUNT
		local lit = runeState(mCur / mMax, n)
		return lit, n
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
		-- onInit as well as onLoad. onLoad fires when a save is loaded; onInit
		-- when the script is first attached, which is what happens on a new
		-- game. With onLoad alone nothing is built until some other thing
		-- rebuilds it -- which is why the meters only appeared after touching a
		-- setting. BSCompass and MoonHUD both bind the pair; this did not.
		onInit = onLoad,
		onLoad = onLoad,
		onUpdate = onUpdate,
	},

	eventHandlers = {
		-- UiModeChanged is an EVENT, not an engine handler. In engineHandlers
		-- it is simply never called, which silently disabled the whole
		-- "When to Show" setting.
		UiModeChanged = UiModeChanged,
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
