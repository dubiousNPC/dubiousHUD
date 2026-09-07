---@omw-context player
-- BSC_p.lua  (PLAYER script)
--
-- A dial compass driven by a vertical texture atlas.
--
-- PERFORMANCE NOTES, since that was the brief:
--
--   * Every atlas frame is turned into a ui.texture ONCE, at load or when the
--     atlas settings change. ui.texture is never called from onFrame.
--   * onFrame does no table allocation at all. Locals and numbers only.
--   * The element is only :update()d when the heading crosses into a new frame.
--     With 36 frames that is once per 10 degrees of turn, not once per frame.
--   * When the compass is hidden (indoors, HUD off, menu open) onFrame returns
--     after a single boolean test.
--   * The heading itself comes from camera.getYaw(), a scalar read, rather than
--     camera.viewportToWorldVector() which does a matrix transform.
--   * SAMPLE_EVERY gates how often the heading is even read.
--
-- Settings are read from globals rather than storage for the same reason; see
-- BSC_settings.lua.

local ui      = require('openmw.ui')
local util    = require('openmw.util')
local core    = require('openmw.core')
local async   = require('openmw.async')
local storage = require('openmw.storage')
local input   = require('openmw.input')
local types   = require('openmw.types')
local camera  = require('openmw.camera')
self    = require('openmw.self')
local I       = require('openmw.interfaces')
local v2      = util.vector2

-- Forward declarations for this file's PRIVATE helpers, which were
-- implicit globals. Declared up here rather than as `local function` at
-- each definition, because at least one is referenced above its
-- definition line and a local is not in scope before its declaration.
--
-- NOT localised: rebuildTiles, createCompassHud, applyCompassStyle.
-- This mod uses _G as an inter-module bus. BSC_settings.lua is
-- require()d into this same environment and calls those by name, and it
-- writes changed setting values back with `_G[setting] = ...`. Making
-- them local does not error -- the call sites are guarded with
-- `if fn then` -- it silently turns every settings callback into a
-- no-op, which is worse.
local atlasGeometry, refreshUiVisibility, UiModeChanged

MODNAME = 'BSCompass'

--------------------------------------------------------------------------------
-- Bundled atlases
--------------------------------------------------------------------------------
-- Each entry carries its own geometry, because these sheets genuinely differ:
-- BSCompasAtlas is a 36-frame vertical strip, the 360-frame versions have to be
-- grids. A 360-frame strip at 88px would be 31680px tall, past the maximum
-- texture size on essentially every GPU, which is why the grid support exists.
--
--   frames  how many rotation steps
--   cols    columns in the sheet; 1 means a vertical strip
--   cell    pixel size of one square frame
--   overlay optional static art the rotating frame is drawn on top of
local ATLAS_PRESETS = {
	['BSCompasAtlas'] = {
		path = 'textures/bscompass/BSCompasAtlas.png',
		frames = 36, cols = 1, cell = 88,
	},
	['BSCompasAtlas_360'] = {
		path = 'textures/bscompass/BSCompasAtlas_360.png',
		frames = 360, cols = 30, cell = 88,
		-- Built with expand_compass_layered against BSCompasEmpty.png, so the
		-- bezel and glass are bit-identical in every frame and only the needle
		-- moves. Each needle is the nearest hand-drawn original, so its shading
		-- still shifts as it turns.
	},
	['DBS_CompassARROW'] = {
		path = 'textures/bscompass/DBS_CompassARROWAtlas.png',
		frames = 360, cols = 30, cell = 64,
		-- North and south read swapped without this: the sheet starts half a turn
		-- out relative to the corner art it sits on.
		headingOffset = 180,
		backdrop = 'textures/bscompass/DBS_CompassCORNER.png',
		-- The arrow pivot sits at 51.5%, 49.9% of the corner art, and the frame
		-- covers a 242px box of its 1785px width. Measured, not guessed.
		overlayAnchorX = 51.5, overlayAnchorY = 49.9, overlayScale = 13.6,
		-- Full-canvas layers, drawn at the backdrop rect. They are authored on
		-- the same 1785x1610 canvas as the corner art, so they need no placement
		-- figures of their own -- they simply line up.
		--
		-- Note the source filenames are inconsistent: NEWS_Nfade and NEWS_Efade
		-- have no underscore, NEWS_S_fade and NEWS_W_fade do. Mapped explicitly
		-- rather than derived, so the files can stay as the artist named them.
		cardinals = {
			N = 'textures/bscompass/NEWS_N.png',
			E = 'textures/bscompass/NEWS_E.png',
			S = 'textures/bscompass/NEWS_S.png',
			W = 'textures/bscompass/NEWS_W.png',
			Nfade = 'textures/bscompass/NEWS_Nfade.png',
			Efade = 'textures/bscompass/NEWS_Efade.png',
			Sfade = 'textures/bscompass/NEWS_S_fade.png',
			Wfade = 'textures/bscompass/NEWS_W_fade.png',
		},
		-- Named layers nothing turns on by itself. Other mods raise these.
		overlays = {
			eyes       = 'textures/bscompass/DBS_CompassEYES.png',
			dragoneyes = 'textures/bscompass/DBS_CompassDragonEYES.png',
		},
		overlayAspect = 1785 / 1610,
	},
}

local ATLAS_PRESET_ORDER = { 'BSCompasAtlas', 'BSCompasAtlas_360', 'DBS_CompassARROW' }

local borderTemplates = require('scripts.bscompass.BSC_border')

local generalSection = storage.playerSection('Settings' .. MODNAME .. 'General')
local compassSection = storage.playerSection('Settings' .. MODNAME .. 'Compass')

require('scripts.bscompass.BSC_settings')

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local compassHud = nil
local compassImage        = nil    -- the layout table, poked directly
local tiles               = {}     -- pre-built ui.texture, 1-based
local tileCount           = 0
local currentTile         = -1
local cardinalElements    = {}     -- 'N' / 'Nfade' -> layout table
local overlayElements     = {}     -- name -> layout table
local activeOverlays      = {}     -- name -> { alpha, tint, expires }
local currentCardinalKey  = nil
local currentCardinalStep = -1
local overlaysDirty       = false
local frameCountdown      = 1
local hudActive           = false  -- the single hot-path gate
local currentUiMode       = nil
local shouldRefreshUiVisibility = nil
local saveData            = {}

local DEG_PER_RAD = 180 / math.pi

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


-- Resolved geometry for whichever atlas is selected. Custom reads the manual
-- settings; a preset supplies its own so you cannot mismatch frames and columns.
function atlasGeometry()
	local preset = ATLAS_PRESETS[ATLAS_PRESET or '']
	if preset then
		return {
			path = preset.path, frames = preset.frames,
			cols = preset.cols, cell = preset.cell,
			invert = preset.invert, headingOffset = preset.headingOffset,
			backdrop = preset.backdrop, face = preset.face,
			cardinals = preset.cardinals, overlays = preset.overlays,
			overlayAnchorX = preset.overlayAnchorX,
			overlayAnchorY = preset.overlayAnchorY,
			overlayScale = preset.overlayScale,
			overlayAspect = preset.overlayAspect,
			faceAnchorX = preset.faceAnchorX, faceAnchorY = preset.faceAnchorY,
			faceScale = preset.faceScale,
		}
	end
	local path = ATLAS_PATH
	if path == nil or path == '' then path = 'textures/bscompass/BSCompasAtlas.png' end
	local function orNil(v) if v == nil or v == '' then return nil end return v end
	return {
		path = path,
		frames = ATLAS_TILES or 36,
		cols = math.max(1, ATLAS_COLUMNS or 1),
		cell = ATLAS_CELL or 88,
		invert = false,
		headingOffset = 0,
		backdrop = orNil(BACKDROP_TEXTURE),
		face = orNil(FACE_TEXTURE),
		cardinals = nil, overlays = nil,
		overlayAnchorX = OVERLAY_ANCHOR_X,
		overlayAnchorY = OVERLAY_ANCHOR_Y,
		overlayScale = OVERLAY_SCALE,
		overlayAspect = 1,
		faceAnchorX = FACE_ANCHOR_X,
		faceAnchorY = FACE_ANCHOR_Y,
		faceScale = FACE_SCALE,
	}
end

--------------------------------------------------------------------------------
-- Layers
--------------------------------------------------------------------------------
-- Up to three stacked images, all sized from one figure so the whole assembly
-- scales together:
--
--   backdrop  static frame or housing, fills the widget
--   face      static dial art, placed and scaled inside the backdrop
--   arrow     the rotating atlas frame, placed and scaled inside the backdrop
--
-- Every layer is sized from COMPASS_SIZE. Previously the arrow owned that figure
-- and the backdrop was pinned to it, so a 1785px corner texture could not be made
-- any bigger than the needle. Now COMPASS_SIZE is the width of the whole widget
-- and the inner layers are percentages of it, which is what makes the corner art
-- resizable.

local function layerGeometry()
	local geo = atlasGeometry()
	local size = COMPASS_SIZE or 88
	local hasBackdrop = geo.backdrop ~= nil

	local L = { geo = geo }
	if hasBackdrop then
		L.width  = size
		L.height = math.floor(size / (geo.overlayAspect or 1))
		L.arrowSize = math.max(4, math.floor(L.width * (geo.overlayScale or 20) / 100))
		L.arrowX = math.floor(L.width  * (geo.overlayAnchorX or 50) / 100 - L.arrowSize / 2)
		L.arrowY = math.floor(L.height * (geo.overlayAnchorY or 50) / 100 - L.arrowSize / 2)
		if geo.face then
			L.faceSize = math.max(4, math.floor(L.width * (geo.faceScale or 60) / 100))
			L.faceX = math.floor(L.width  * (geo.faceAnchorX or 50) / 100 - L.faceSize / 2)
			L.faceY = math.floor(L.height * (geo.faceAnchorY or 50) / 100 - L.faceSize / 2)
		end
	else
		L.width, L.height = size, size
		L.arrowSize, L.arrowX, L.arrowY = size, 0, 0
	end
	return L
end

-- Builds every frame of the sheet up front. This is the whole performance story:
-- pay once here so onFrame never has to allocate.
--
-- Frames are read row-major: index = row * cols + col. A vertical strip is just
-- the cols = 1 case, so one code path covers both.
function rebuildTiles()
	local geo = atlasGeometry()
	local cell, cols, count = geo.cell, geo.cols, geo.frames

	tiles = {}
	if not validPath(geo.path) then
		-- Nothing to cut. Leave the array empty; the widget draws nothing and the
		-- reason is visible in the settings rather than buried in a log.
		tileCount = 0
		currentTile = -1
		return
	end
	for i = 0, count - 1 do
		local row = math.floor(i / cols)
		local col = i % cols
		tiles[i + 1] = ui.texture {
			path   = geo.path,
			offset = v2(col * cell, row * cell),
			size   = v2(cell, cell),
		}
	end
	tileCount = count
	currentTile = -1        -- force the next frame to apply a texture
end

--------------------------------------------------------------------------------
-- Heading
--------------------------------------------------------------------------------

-- Yaw in degrees, normalised to [0, 360). 0 is north, increasing clockwise.
local function headingDegrees()
	local yaw
	if FACING_SOURCE == 'Body' then
		yaw = self.rotation:getYaw()
	else
		yaw = camera.getYaw()
	end
	local deg = yaw * DEG_PER_RAD
	deg = deg % 360
	if deg < 0 then deg = deg + 360 end
	return deg
end

-- Atlas frame for a heading.
--
-- The needle in BSCompasAtlas.png rotates CLOCKWISE by 10 degrees per frame
-- (measured: frame 0 at -91 degrees, frame 9 at 171, frame 18 at 88, frame 27 at 10).
-- A world-fixed marker has to rotate COUNTER-clockwise on screen as the player
-- turns clockwise, so the frame index has to advance as the heading DECREASES.
-- Hence the subtraction. Verified consistent at all four cardinals.
--------------------------------------------------------------------------------
-- Cardinal overlays
--------------------------------------------------------------------------------
-- Lights the N/E/S/W glyph on the dial as you come round to face it. Two bands:
-- inside the sharp arc the solid art is drawn, between sharp and fade arcs the
-- fade art is drawn and its opacity ramps off with distance.
--
-- The ramp is quantised to ALPHA_STEPS so a slow turn does not force an element
-- update on every single frame. Sixteen steps is smooth to the eye and bounds
-- the work to sixteen updates per approach.

local CARDINAL_POINTS = { { 'N', 0 }, { 'E', 90 }, { 'S', 180 }, { 'W', 270 } }
local ALPHA_STEPS = 16

--- Returns key ('N', 'Nfade', ...) and an alpha step 0..ALPHA_STEPS, or nil.
local function cardinalFor(deg)
	if CARDINAL_OVERLAY == 'Off' or CARDINAL_OVERLAY == nil then return nil, 0 end
	local sharp = CARDINAL_ARC or 15
	local fade  = CARDINAL_FADE_ARC or 45
	if fade < sharp then fade = sharp end

	local bestKey, bestDelta
	for _, p in ipairs(CARDINAL_POINTS) do
		local d = math.abs(((deg - p[2] + 180) % 360) - 180)
		if bestDelta == nil or d < bestDelta then bestDelta, bestKey = d, p[1] end
	end

	if bestDelta <= sharp then
		return bestKey, ALPHA_STEPS
	end
	if CARDINAL_OVERLAY ~= 'Sharp + Fade' then return nil, 0 end
	if bestDelta > fade then return nil, 0 end

	local span = fade - sharp
	local t = 1
	if span > 0 then t = 1 - (bestDelta - sharp) / span end
	local step = math.floor(t * ALPHA_STEPS + 0.5)
	if step <= 0 then return nil, 0 end
	return bestKey .. 'fade', step
end

--------------------------------------------------------------------------------
-- Atlas frame for a heading.
--
-- CORRECTED. This used to subtract from the frame count, on the reasoning that a
-- world-fixed marker counter-rotates on screen as you turn. That reasoning is
-- sound but it does not describe these sheets: in game it put east and west the
-- wrong way round, which is the signature of a mirrored mapping. Both bundled
-- atlases advance their frame index in the same sense as the heading, so the
-- plain form is correct and `invert` is the exception.
--
-- The DBS sheet additionally starts half a turn out -- north and south were
-- swapped -- so it carries a 180 degree headingOffset. A mirror about the
-- east-west axis is exactly an inversion plus 180, which is why the two sheets
-- were wrong in two different-looking ways.
local function tileForHeading(deg)
	local n = tileCount
	if n < 1 then return 0 end
	local geo = atlasGeometry()
	local step = 360 / n
	local offset = (HEADING_OFFSET or 0) + (geo.headingOffset or 0)
	local raw = math.floor((deg + offset) / step + 0.5)
	-- A preset may declare its own handedness; the setting flips whatever it says.
	local invert = (geo.invert == true)
	if INVERT_ROTATION then invert = not invert end
	if not invert then
		return raw % n
	end
	return (n - raw) % n
end

--------------------------------------------------------------------------------
-- Style
--------------------------------------------------------------------------------

-- Applied without rebuilding the tree, for settings that only touch props.
function applyCompassStyle()
	if not compassHud or not compassImage then return end
	-- Size is owned by createCompassHud when an overlay is present, because it
	-- depends on the anchor and scale. Only touch it in the plain case.
	local L = layerGeometry()
	compassImage.props.size = v2(L.arrowSize, L.arrowSize)
	compassImage.props.position = v2(L.arrowX, L.arrowY)
	compassImage.props.color = COMPASS_TINT
	compassImage.props.alpha = COMPASS_ALPHA
	compassHud.layout.props.position = v2(HUD_X_POS, HUD_Y_POS)
	if compassHudBackground then
		compassHudBackground.props.alpha = BACKGROUND_ALPHA
	end
	frameCountdown = 1
	currentTile = -1
	compassHud:update()
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function createCompassHud()
	if compassHud then
		compassHud:destroy()
		compassHud = nil
		compassImage = nil
		compassHudBackground = nil
	end
	if tileCount == 0 then rebuildTiles() end

	local L = layerGeometry()
	local geo = L.geo

	-- tileH/tileV must be false or MyGUI draws the texture at its native size and
	-- repeats it to fill the widget, which looks exactly like the size setting
	-- being ignored. Atlas sub-rect textures are the usual victims.
	local function imageLayer(name, tex, w, h, x, y, tint, alpha)
		return {
			type = ui.TYPE.Image,
			name = name,
			props = {
				resource = tex,
				size = v2(w, h),
				position = v2(x or 0, y or 0),
				color = tint,
				alpha = alpha,
				tileH = false,
				tileV = false,
			},
		}
	end

	local function staticLayer(name, path, w, h, x, y, tint, alpha)
		if not validPath(path) then return nil end
		return imageLayer(name, ui.texture { path = path }, w, h, x, y, tint, alpha)
	end

	compassImage = imageLayer('compassImage', tiles[1],
		L.arrowSize, L.arrowSize, L.arrowX, L.arrowY, COMPASS_TINT, COMPASS_ALPHA)

	local backdropElement = staticLayer('compassBackdrop', geo.backdrop,
		L.width, L.height, 0, 0, OVERLAY_TINT, OVERLAY_ALPHA)

	local faceElement
	if L.faceSize then
		faceElement = staticLayer('compassFace', geo.face,
			L.faceSize, L.faceSize, L.faceX, L.faceY, FACE_TINT, FACE_ALPHA)
	end

	-- Every cardinal and named overlay is built ONCE, hidden, and later toggled
	-- by visibility and alpha. Creating or destroying elements as they come and
	-- go would rebuild the tree mid-play; this keeps the update to a props poke.
	cardinalElements, overlayElements = {}, {}

	local function fullLayer(name, path, tint, alpha)
		local el = staticLayer(name, path, L.width, L.height, 0, 0, tint, alpha)
		if el then el.props.visible = false end
		return el
	end

	if geo.cardinals then
		for key, path in pairs(geo.cardinals) do
			cardinalElements[key] = fullLayer('cardinal' .. key, path,
				CARDINAL_TINT, 1)
		end
	end
	if geo.overlays then
		for name, path in pairs(geo.overlays) do
			overlayElements[name] = fullLayer('overlay' .. name, path, nil, 1)
		end
	end

	local template, paddingTemplate
	local pad = v2(HUD_PADDING or 0, HUD_PADDING or 0)

	if HUD_BACKGROUND or HUD_BORDER then
		compassHudBackground = {
			type = ui.TYPE.Image,
			name = 'compassHudBackground',
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
				compassHudBackground, pad)
			template = borders.borders
			paddingTemplate = borders.padding
		else
			template = { content = ui.content {} }
			template.content:add(compassHudBackground)
		end
	else
		template = { content = ui.content {} }
	end

	compassHud = ui.create {
		type = ui.TYPE.Container,
		layer = HUD_LOCK and 'Scene' or 'Modal',
		name = 'compassHud',
		template = template,
		props = { position = v2(HUD_X_POS, HUD_Y_POS) },
		content = ui.content {},
		userData = {},
	}

	-- Drag to reposition, same gesture as TimeHUD and ErnCompass.
	compassHud.layout.events = {
		mousePress = async:callback(function(data, elem)
			if data.button == 1 and not HUD_LOCK then
				elem.userData = elem.userData or {}
				elem.userData.isDragging = true
				elem.userData.lastMousePos = data.position
			end
			compassHud:update()
		end),
		mouseRelease = async:callback(function(_, elem)
			if elem.userData then elem.userData.isDragging = false end
			compassHud:update()
		end),
		mouseMove = async:callback(function(data, elem)
			if elem.userData and elem.userData.isDragging then
				local delta = data.position - elem.userData.lastMousePos
				elem.userData.lastMousePos = data.position
				local newPosition = (compassHud.layout.props.position or v2(0, 0)) + delta
				generalSection:set('HUD_X_POS', math.floor(newPosition.x))
				generalSection:set('HUD_Y_POS', math.floor(newPosition.y))
				compassHud.layout.props.position = newPosition
				compassHud:update()
			end
		end),
	}

	-- With an overlay both layers live in a fixed-size Widget so the frame can be
	-- positioned absolutely on top of, or underneath, the static art.
	-- Three layers in one fixed-size Widget: backdrop at the bottom, then the
	-- static face, then the rotating arrow. Overlay Layer moves the backdrop to
	-- the top instead, for housings with a glass or bezel that should occlude.
	local hasExtras = next(cardinalElements) ~= nil or next(overlayElements) ~= nil
	local body = compassImage
	if backdropElement or faceElement or hasExtras then
		local stack = ui.content {}
		if OVERLAY_LAYER == 'In front' then
			if faceElement then stack:add(faceElement) end
			stack:add(compassImage)
			if backdropElement then stack:add(backdropElement) end
		else
			if backdropElement then stack:add(backdropElement) end
			if faceElement then stack:add(faceElement) end
			stack:add(compassImage)
		end
		-- Cardinals sit above the arrow so a lit glyph is never hidden by it;
		-- named overlays sit above everything.
		for _, el in pairs(cardinalElements) do stack:add(el) end
		for _, el in pairs(overlayElements) do stack:add(el) end
		body = {
			type = ui.TYPE.Widget,
			name = 'compassStack',
			props = { size = v2(L.width, L.height) },
			content = stack,
		}
	end

	if paddingTemplate then
		compassHud.layout.content:add {
			template = paddingTemplate,
			content = ui.content { body },
		}
	else
		compassHud.layout.content:add(body)
	end

	currentTile = -1
	currentCardinalKey, currentCardinalStep = nil, -1
	overlaysDirty = true
	frameCountdown = 1
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

-- Sets hudActive, which is the only thing onFrame checks in the common case.
function refreshUiVisibility()
	if not compassHud then hudActive = false return end

	local allowed = chargenFinished()
		and I.UI.isHudVisible()
		and (not HUD_EXTERIOR or self.cell.isExterior or self.cell:hasTag('QuasiExterior'))

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

	if compassHud.layout.props.visible ~= visible then
		compassHud.layout.props.visible = visible
		compassHud:update()
	end
	hudActive = visible
end

--------------------------------------------------------------------------------
-- The hot path
--------------------------------------------------------------------------------

local function onFrame()
	if shouldRefreshUiVisibility then
		shouldRefreshUiVisibility = shouldRefreshUiVisibility - 1
		if shouldRefreshUiVisibility <= 0 then
			shouldRefreshUiVisibility = nil
			refreshUiVisibility()
		end
	end

	-- Hidden: one boolean and out. No heading read, no arithmetic, no allocation.
	if not hudActive then return end

	frameCountdown = frameCountdown - 1
	if frameCountdown > 0 then return end
	frameCountdown = SAMPLE_EVERY or 2

	local deg = headingDegrees()
	local tile = tileForHeading(deg)
	local key, step = cardinalFor(deg)

	local dirty = false

	if tile ~= currentTile then
		local tex = tiles[tile + 1]
		if tex ~= nil then
			currentTile = tile
			compassImage.props.resource = tex
			dirty = true
		end
	end

	if key ~= currentCardinalKey or step ~= currentCardinalStep then
		if currentCardinalKey and cardinalElements[currentCardinalKey] then
			cardinalElements[currentCardinalKey].props.visible = false
		end
		if key and cardinalElements[key] then
			local el = cardinalElements[key]
			el.props.visible = true
			el.props.alpha = (step / ALPHA_STEPS) * (CARDINAL_ALPHA or 1)
			el.props.color = CARDINAL_TINT
		end
		currentCardinalKey, currentCardinalStep = key, step
		dirty = true
	end

	if overlaysDirty then
		overlaysDirty = false
		for name, el in pairs(overlayElements) do
			local a = activeOverlays[name]
			el.props.visible = a ~= nil
			if a then
				el.props.alpha = a.alpha or 1
				el.props.color = a.tint
			end
		end
		dirty = true
	end

	-- Timed overlays. Only walked while something is actually up.
	if next(activeOverlays) ~= nil then
		local now = core.getSimulationTime()
		for name, a in pairs(activeOverlays) do
			if a.expires and now >= a.expires then
				activeOverlays[name] = nil
				overlaysDirty = true
			end
		end
	end

	if dirty then compassHud:update() end
end

--------------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------------

function UiModeChanged(data)
	if not compassHud then return end
	currentUiMode = data.newMode
	refreshUiVisibility()
	shouldRefreshUiVisibility = 3
end

local function onLoad(data)
	saveData = data or {}

	local layerId = ui.layers.indexOf('HUD')
	local hudLayerSize = ui.layers[layerId].size
	generalSection:set('HUD_X_POS', math.floor(math.max(-200, math.min(HUD_X_POS, hudLayerSize.x + 200))))
	generalSection:set('HUD_Y_POS', math.floor(math.max(-50, math.min(HUD_Y_POS, hudLayerSize.y - 20))))

	rebuildTiles()
	createCompassHud()
end

-- Click-and-scroll to resize, matching TimeHUD.
if input.triggers['MenuMouseWheelUp'] then
	input.registerTriggerHandler('MenuMouseWheelUp', async:callback(function()
		if compassHud and compassHud.layout.userData and compassHud.layout.userData.isDragging then
			compassSection:set('COMPASS_SIZE', math.min(320, (COMPASS_SIZE or 88) + 4))
		end
	end))
end
if input.triggers['MenuMouseWheelDown'] then
	input.registerTriggerHandler('MenuMouseWheelDown', async:callback(function()
		if compassHud and compassHud.layout.userData and compassHud.layout.userData.isDragging then
			compassSection:set('COMPASS_SIZE', math.max(24, (COMPASS_SIZE or 88) - 4))
		end
	end))
end

input.registerTriggerHandler('ToggleHUD', async:callback(function()
	refreshUiVisibility()
end))

--------------------------------------------------------------------------------
-- Public interface
--------------------------------------------------------------------------------
-- Named overlays are the extension point. Nothing raises them by itself, so a
-- quest, an enchantment or another mod decides when the compass reacts.
--
--   local I = require('openmw.interfaces')
--   I.BSCompass.setOverlay('eyes', { duration = 8 })
--   I.BSCompass.clearOverlay('eyes')
--
-- From a script that cannot see the interface -- a global script, or another
-- mod that would rather not hard-depend -- send the player an event instead:
--
--   player:sendEvent('BSCompass_SetOverlay', { name = 'eyes', duration = 8 })
--
-- Unknown names are ignored rather than raising, so a mod can offer to light an
-- overlay the current artwork does not define without needing to check first.

local interface

local interface = {
	version = 2,

	--- Raise a named overlay.
	-- opts: alpha (0..1), tint (util.color), duration (seconds, omit to persist)
	setOverlay = function(name, opts)
		if type(name) ~= 'string' then return false end
		if overlayElements[name] == nil then return false end
		opts = opts or {}
		local expires = nil
		if type(opts.duration) == 'number' and opts.duration > 0 then
			expires = core.getSimulationTime() + opts.duration
		end
		activeOverlays[name] = {
			alpha = opts.alpha or 1,
			tint = opts.tint,
			expires = expires,
		}
		overlaysDirty = true
		return true
	end,

	clearOverlay = function(name)
		if activeOverlays[name] == nil then return false end
		activeOverlays[name] = nil
		overlaysDirty = true
		return true
	end,

	clearAllOverlays = function()
		local any = next(activeOverlays) ~= nil
		activeOverlays = {}
		overlaysDirty = true
		return any
	end,

	isOverlayActive = function(name)
		return activeOverlays[name] ~= nil
	end,

	--- Names this artwork defines, so a caller can check before asking.
	getOverlayNames = function()
		local out = {}
		for name in pairs(overlayElements) do out[#out + 1] = name end
		table.sort(out)
		return out
	end,

	--- Current heading in degrees, and the cardinal glyph lit, if any.
	getHeading = function()
		local deg = headingDegrees()
		local key = cardinalFor(deg)
		return deg, key
	end,
}

return {
	interfaceName = 'BSCompass',
	interface = interface,
	engineHandlers = {
		onInit  = onLoad,
		onLoad  = onLoad,
		onSave  = function() return saveData end,
		onFrame = onFrame,
	},
	eventHandlers = {
		UiModeChanged = UiModeChanged,
		-- Same event ErnCompass and the HUD transparency mods use, so the two
		-- fade together if you run both.
		BSCompass_SetOverlay = function(data)
			if type(data) == 'table' then interface.setOverlay(data.name, data) end
		end,
		BSCompass_ClearOverlay = function(data)
			if type(data) == 'table' then interface.clearOverlay(data.name) end
		end,
		BSCompass_ClearAllOverlays = function()
			interface.clearAllOverlays()
		end,
		HUDTransparencyChange = function(data)
			if compassHud then
				compassHud.layout.props.alpha = data.alpha
				compassHud:update()
			end
		end,
	},
}
