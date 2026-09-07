---@omw-context none
-- load_check.lua
--
-- Executes a mod's player scripts against a stubbed OpenMW API, so load-time
-- errors surface without launching the game. Syntax checking (luac -p) does not
-- catch undefined globals, nil calls, or bad API shapes; this does.
--
--   texlua load_check.lua <modRoot> <scriptPath> [<scriptPath> ...]
--
-- Example:
--   texlua load_check.lua /path/to/MoonHUD scripts/moonhud/MH_hud.lua

local modRoot = arg[1]
if not modRoot then
	print('usage: texlua load_check.lua <modRoot> <scriptPath>...')
	os.exit(2)
end
package.path = modRoot .. '/?.lua;' .. package.path

--------------------------------------------------------------------------------
-- Stubs
--------------------------------------------------------------------------------

local function vec2(x, y)
	local v = { x = x or 0, y = y or 0 }
	setmetatable(v, {
		__add = function(a, b) return vec2(a.x + b.x, a.y + b.y) end,
		__sub = function(a, b) return vec2(a.x - b.x, a.y - b.y) end,
		__mul = function(a, b)
			if type(a) == 'number' then return vec2(a * b.x, a * b.y) end
			if type(b) == 'number' then return vec2(a.x * b, a.y * b) end
			return vec2(a.x * b.x, a.y * b.y)
		end,
		__div = function(a, b)
			if type(b) == 'number' then return vec2(a.x / b, a.y / b) end
			return vec2(a.x / b.x, a.y / b.y)
		end,
		__unm = function(a) return vec2(-a.x, -a.y) end,
		__tostring = function(a) return '(' .. a.x .. ',' .. a.y .. ')' end,
	})
	return v
end

local function colour(r, g, b, a)
	return { r = r or 1, g = g or 1, b = b or 1, a = a or 1, __isColour = true }
end

-- Records everything the mod registers so we can assert on it afterwards.
local record = {
	groups = {}, pages = {}, textures = {}, subscriptions = 0,
	triggers = {}, warnings = {}, bundledUsed = {}, renderers = {},
}

-- Renderers OpenMW ships with. Anything else has to come from another mod, and
-- registering a group that names an unknown renderer is exactly the sort of
-- silent breakage this harness exists to catch.
local BUILTIN_RENDERERS = {
	checkbox = true, textLine = true, number = true, select = true,
	color = true, ['nil'] = true,
}
local EXTERNAL_RENDERERS = {
	SuperSlider6 = 'SuperSettingsRenderers',
	SuperSelect3 = 'SuperSettingsRenderers',
	SuperColorPicker4 = 'SuperSettingsRenderers',
	SuperKeybind2 = 'SuperSettingsRenderers',
	SuperColorPicker2 = 'TimeHUD / LocationHUD',
}

-- A renderer only counts as available if the mod BOTH ships the file AND lists
-- it as a MENU script. Shipping it without the manifest entry is silent
-- breakage, so the two are checked separately.
local bundled, manifested = {}, {}
do
	local function fileExists(path)
		local f = io.open(path, 'r')
		if f then f:close() return true end
		return false
	end

	for name in pairs(EXTERNAL_RENDERERS) do
		if fileExists(modRoot .. '/scripts/SuperSettingsRenderers/' .. name .. '.lua') then
			bundled[name] = true
		end
	end

	local pipe = io.popen('ls "' .. modRoot .. '"/*.omwscripts 2>/dev/null')
	if pipe then
		for manifest in pipe:lines() do
			local f = io.open(manifest, 'r')
			if f then
				for line in f:lines() do
					local script = line:match('^%s*MENU:%s*(%S+)')
					if script then
						local base = script:match('([^/\\]+)%.lua$')
						if base then manifested[base] = true end
					end
				end
				f:close()
			end
		end
		pipe:close()
	end
end

local storageSections = {}

-- PRESEED lets a caller force settings values before the mod reads them, so
-- code paths behind a non-default preset actually get executed.
local PRESEED = {}
do
	local raw = os.getenv('PRESEED')
	if raw then
		for pair in raw:gmatch('[^,]+') do
			local k, v = pair:match('^%s*(%S+)%s*=%s*(.*)$')
			if k then PRESEED[k] = tonumber(v) or v end
		end
	end
end

local stubs = {}

stubs['openmw.util'] = {
	vector2 = vec2,
	vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
	color = {
		rgb = function(r, g, b) return colour(r, g, b, 1) end,
		rgba = colour,
		hex = function(h)
			if type(h) ~= 'string' or not h:match('^%x%x%x%x%x%x$') then
				error('util.color.hex: bad hex "' .. tostring(h) .. '"', 2)
			end
			return colour(1, 1, 1, 1)
		end,
	},
}

local function contentList(init)
	local c = { _items = {} }
	for _, v in ipairs(init or {}) do c._items[#c._items + 1] = v end
	function c:add(v) self._items[#self._items + 1] = v end
	function c:insert(i, v) table.insert(self._items, i, v) end
	function c:indexOf(v)
		for i, x in ipairs(self._items) do if x == v then return i end end
		return nil
	end
	function c:remove(v) end
	return c
end

stubs['openmw.ui'] = {
	TYPE = setmetatable({}, { __index = function(_, k) return 'TYPE.' .. k end }),
	ALIGNMENT = setmetatable({}, { __index = function(_, k) return 'ALIGN.' .. k end }),
	layers = setmetatable({
		indexOf = function() return 1 end,
	}, { __index = function() return { size = vec2(1920, 1080) } end }),
	content = contentList,
	screenSize = function() return vec2(1920, 1080) end,
	showMessage = function() end,
	registerSettingsPage = function() end,
	texture = function(opts)
		if type(opts) ~= 'table' or type(opts.path) ~= 'string' then
			error('ui.texture: needs a table with a string path', 2)
		end
		record.textures[#record.textures + 1] = opts.path
		return { _texture = opts.path }
	end,
	_getMenuTransparency = function() return 0.7 end,
	create = function(layout)
		local e = { layout = layout }
		function e:update() end
		function e:destroy() end
		return e
	end,
}

stubs['openmw.async'] = {
	callback = function(f) return f end,
	registerTimerCallback = function(_, f) return f end,
}

stubs['openmw.storage'] = {
	globalSection = function(key) return stubs['openmw.storage'].playerSection('G:' .. key) end,
	LIFE_TIME = { Persistent = 0, Temporary = 1 },
	playerSection = function(key)
		if storageSections[key] then return storageSections[key] end
		local sec = { _key = key, _v = {} }
		function sec:get(k)
			if PRESEED[k] ~= nil then return PRESEED[k] end
			return self._v[k]
		end
		function sec:set(k, v) self._v[k] = v end
		function sec:subscribe() record.subscriptions = record.subscriptions + 1 end
		function sec:setLifeTime() end
		function sec:asTable() return self._v end
		function sec:reset() self._v = {} end
		function sec:removeOnExit() end
		storageSections[key] = sec
		return sec
	end,
}

stubs['openmw.interfaces'] = {
	Settings = {
		registerGroup = function(t)
			if type(t) ~= 'table' or type(t.key) ~= 'string' then
				error('registerGroup: needs a key', 2)
			end
			if type(t.settings) ~= 'table' then
				error('registerGroup: ' .. t.key .. ' has no settings list', 2)
			end
			for _, e in ipairs(t.settings) do
				if type(e.key) ~= 'string' then
					error('registerGroup: ' .. t.key .. ' has a setting with no key', 2)
				end
				if e.renderer == nil then
					error('registerGroup: ' .. t.key .. '/' .. e.key
						.. ' has renderer = nil', 2)
				end
				if type(e.renderer) ~= 'string' then
					error('registerGroup: ' .. t.key .. '/' .. e.key
						.. ' renderer is ' .. type(e.renderer), 2)
				end
				if not BUILTIN_RENDERERS[e.renderer] then
					local r = e.renderer
					if bundled[r] and manifested[r] then
						record.bundledUsed[r] = true
					elseif bundled[r] then
						error('registerGroup: ' .. t.key .. '/' .. e.key
							.. ' uses "' .. r .. '". The file is bundled but is NOT'
							.. ' listed as a MENU script in the .omwscripts manifest,'
							.. ' so it will never be registered.', 2)
					else
						local from = EXTERNAL_RENDERERS[r]
						record.warnings[#record.warnings + 1] =
							t.key .. '/' .. e.key .. ' uses renderer "' .. r
							.. '"' .. (from and (' from ' .. from) or ' (unknown)')
							.. ' which is not bundled with this mod'
					end
				end
				if e.argument ~= nil and type(e.argument) ~= 'table' then
					error('registerGroup: ' .. t.key .. '/' .. e.key
						.. ' argument is ' .. type(e.argument), 2)
				end
			end
			record.groups[#record.groups + 1] = t
		end,
		registerRenderer = function(name, fn)
			if type(name) ~= 'string' then error('registerRenderer: needs a name', 2) end
			if type(fn) ~= 'function' then error('registerRenderer: needs a function', 2) end
			record.renderers[#record.renderers + 1] = name
		end,
		updateRendererArgument = function() end,
		registerPage = function(t)
			if type(t) ~= 'table' or type(t.key) ~= 'string' then
				error('registerPage: needs a key', 2)
			end
			record.pages[#record.pages + 1] = t
		end,
	},
	UI = { isHudVisible = function() return true end,
	       setMode = function() end, removeMode = function() end },
	MWUI = {
		templates = setmetatable({}, {
			__index = function(_, k) return { name = 'template.' .. k, props = {} } end,
		}),
		constants = { border = 2, padding = 2, textNormalSize = 16 },
	},
	MoonTracker = nil,
}

stubs['openmw.core'] = {
	API_REVISION = 147,
	getGMST = function(n)
		if n == 'FontColor_color_normal' then return '202,165,96' end
		return nil
	end,
	getSimulationTime = function() return 0 end,
	getRealTime = function() return 0 end,
	l10n = function()
		return function(key, args)
			if type(args) == 'table' then
				return (tostring(key):gsub('{(%w+)}', function(k)
					return tostring(args[k] ~= nil and args[k] or ('{' .. k .. '}'))
				end))
			end
			return tostring(key)
		end
	end,
	getRealFrameDuration = function() return 1 / 60 end,
	weather = {
		MOON_PHASE = { Full = 0, WaningGibbous = 1, ThirdQuarter = 2,
			WaningCrescent = 3, New = 4, WaxingCrescent = 5,
			FirstQuarter = 6, WaxingGibbous = 7 },
		getCurrentMoons = function() return nil end,
	},
}

stubs['openmw.menu'] = { getState = function() return 'Running' end }
stubs['openmw.ambient'] = { playSound = function() end }

stubs['openmw.input'] = {
	triggers = { MenuMouseWheelUp = true, MenuMouseWheelDown = true, ToggleHUD = true },
	registerTriggerHandler = function(name, _)
		record.triggers[#record.triggers + 1] = name
	end,
	isShiftPressed = function() return false end,
	isCtrlPressed = function() return false end,
	isAltPressed = function() return false end,
	getKeyName = function() return 'K' end,
	ACTION = setmetatable({}, { __index = function(_, k) return k end }),
	KEY = setmetatable({}, { __index = function(_, k) return k end }),
	CONTROL_SWITCH = setmetatable({}, { __index = function(_, k) return k end }),
	CONTROLLER_BUTTON = setmetatable({}, { __index = function(_, k) return k end }),
	CONTROLLER_AXIS = setmetatable({}, { __index = function(_, k) return k end }),
	getControllerButtonName = function() return 'B' end,
	getActionInfo = function() return { key = 'x', name = 'x' } end,
	actions = setmetatable({}, { __index = function(_, k) return k end }),
	registerActionHandler = function() end,
}

stubs['openmw.types'] = {
	Player = {
		isCharGenFinished = function() return true end,
		getBirthSign = function() return 'sign' end,
	},
}

stubs['openmw.self'] = {
	cell = { isExterior = true, hasTag = function() return false end },
	rotation = { getYaw = function() return 0 end },
	sendEvent = function() end,
}

stubs['openmw.camera'] = { getYaw = function() return 0 end, getPitch = function() return 0 end }

stubs['openmw_aux.time'] = {
	second = 1, minute = 60, hour = 3600, day = 86400,
	GameTime = 'GameTime', SimulationTime = 'SimulationTime',
	runRepeatedly = function() return function() end end,
}

stubs['openmw_aux.ui'] = {
	deepLayoutCopy = function(t)
		local function copy(v)
			if type(v) ~= 'table' then return v end
			local o = {}
			for k, vv in pairs(v) do o[k] = copy(vv) end
			return o
		end
		return copy(t)
	end,
	updateAllTextures = function() end,
	_getMenuTransparency = function() return 0.7 end,
	_dummy = true,
}

-- OpenMW's built-in MWUI constants, which the shared border module reads.
stubs['scripts.omw.mwui.constants'] = {
	border = 2, padding = 2, margin = 4,
	textNormalSize = 16, headerSize = 20,
	textureResolution = 1,
	whiteTexture = { _texture = 'white' },
	sandColor = colour(0.79, 0.65, 0.38, 1),
	whiteColor = colour(1, 1, 1, 1),
	blackColor = colour(0, 0, 0, 1),
	disabledColor = colour(0.5, 0.5, 0.5, 1),
	headerColor = colour(0.87, 0.78, 0.62, 1),
	normalColor = colour(0.79, 0.65, 0.38, 1),
}

stubs['openmw_aux.calendar'] = {
	gameTime = function() return 228 * 86400 end,
	formatGameTime = function(fmt)
		if fmt == '%d' then return '16' end
		if fmt == '%m' then return '8' end
		if fmt == '%Y' then return '427' end
		return ''
	end,
	monthName = function() return 'Last Seed' end,
}

local realRequire = require
_G.require = function(name)
	if stubs[name] then return stubs[name] end
	return realRequire(name)
end

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

local failures = 0

for i = 2, #arg do
	local scriptPath = arg[i]
	local modName = scriptPath:gsub('%.lua$', ''):gsub('/', '.')
	print('--- ' .. scriptPath)

	local ok, result = pcall(realRequire, modName)
	_G.LOADED = _G.LOADED or {}
	if ok then _G.LOADED[modName] = result end
	if not ok then
		failures = failures + 1
		print('  LOAD ERROR: ' .. tostring(result))
	else
		print('  loaded')
		if type(result) == 'table' and result.engineHandlers then
			local h = result.engineHandlers
			if h.onInit then
				local ok2, err = pcall(h.onInit, nil)
				if not ok2 then
					failures = failures + 1
					print('  onInit ERROR: ' .. tostring(err))
				else
					print('  onInit ok')
				end
			end
			if h.onFrame then
				local ok3, err = pcall(h.onFrame)
				if not ok3 then
					failures = failures + 1
					print('  onFrame ERROR: ' .. tostring(err))
				else
					print('  onFrame ok')
				end
			end
		end
	end
end

print('')
print('settings groups registered: ' .. #record.groups)
for _, g in ipairs(record.groups) do
	print(string.format('  %-40s %d settings', g.key, #g.settings))
end
print('settings pages registered:  ' .. #record.pages)
print('storage subscriptions:      ' .. record.subscriptions)
print('textures requested:         ' .. #record.textures)
if #record.renderers > 0 then
	table.sort(record.renderers)
	print('renderers registered:       ' .. table.concat(record.renderers, ', '))
end

local nb = 0
for _ in pairs(record.bundledUsed) do nb = nb + 1 end
if nb > 0 then
	print('')
	print('bundled renderers in use (file present and listed as MENU):')
	local names = {}
	for r in pairs(record.bundledUsed) do names[#names + 1] = r end
	table.sort(names)
	for _, r in ipairs(names) do print('  ' .. r) end
end

if #record.warnings > 0 then
	print('')
	print('EXTERNAL RENDERERS (these break the page if the provider is missing):')
	local seen = {}
	for _, w in ipairs(record.warnings) do
		local r = w:match('renderer "([^"]+)"')
		if not seen[r] then
			seen[r] = true
			print('  ' .. w)
		end
	end
end

-- API_SCRIPT=<path> runs a Lua file after loading, with the stubs in place and
-- the loaded modules' interfaces available as _G.LOADED. Lets the real interface
-- be driven without launching the game.
local apiScript = os.getenv('API_SCRIPT')
if apiScript then
	local fn, err = loadfile(apiScript)
	if not fn then
		failures = failures + 1
		print('  API SCRIPT LOAD ERROR: ' .. tostring(err))
	else
		local ok, e = pcall(fn)
		if not ok then
			failures = failures + 1
			print('  API SCRIPT ERROR: ' .. tostring(e))
		end
	end
end

-- DUMP=<globalName> walks the built element tree and prints every named node's
-- size and position, so layout can be inspected without launching the game.
local dumpName = os.getenv('DUMP_TREE')
if dumpName then
	local rootEl = _G[dumpName]
	local function walk(node, depth)
		if type(node) ~= 'table' then return end
		local pad = string.rep('  ', depth)
		local props = node.props or {}
		if node.name then
			local sz = props.size and tostring(props.size) or '-'
			local pos = props.position and tostring(props.position) or '-'
			print(string.format('%s%-22s size=%-12s pos=%-12s%s', pad, node.name, sz, pos,
				props.visible == false and '  [hidden]' or ''))
		end
		local c = node.content
		if c and c._items then
			for _, child in ipairs(c._items) do walk(child, depth + 1) end
		end
		if node.layout then walk(node.layout, depth) end
	end
	print('')
	print('--- element tree (' .. dumpName .. ')')
	walk(rootEl, 0)
end

print('')
print(failures == 0 and 'OK' or (failures .. ' failure(s)'))
os.exit(failures == 0 and 0 or 1)
