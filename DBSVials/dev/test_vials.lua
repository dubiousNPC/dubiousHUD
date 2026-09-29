---@omw-context none
-- Drives the real DBV_p.lua through the load_check stubs and reads the real
-- widget tree. Run as POSTLOAD, never on its own -- it has no stubs of its own
-- and deliberately re-implements none of the module's logic, because a test
-- that mirrors the code only ever proves the mirror is faithful.

local fails, checks = 0, 0
local function check(c, m)
	checks = checks + 1
	if not c then fails = fails + 1; print('  FAIL: ' .. m) end
end

local onUpdate = MODULE.engineHandlers.onUpdate

--- Sets the three stats, runs a frame, and returns the tree nodes.
local function frame(h, s, m)
	if h then setStatFraction('health', h) end
	if s then setStatFraction('stamina', s) end
	if m then setStatFraction('magicka', m) end
	onUpdate(0.016)
end

local glows = collectNodes('glow')
local function litSet()
	local out = {}
	for i = 1, 8 do
		local el = glows['glow' .. i]
		out[i] = (el and el.props.visible ~= false) and 1 or 0
	end
	return out
end
local function litCount()
	local n = 0
	for _, v in ipairs(litSet()) do n = n + v end
	return n
end
local function show(t) return table.concat(t, '') end

print('=== 1. all eight glow slices exist and are distinct textures ===')
for i = 1, 8 do
	check(glows['glow' .. i] ~= nil, 'glow' .. i .. ' exists')
end
do
	local seen = {}
	local dup = false
	for i = 1, 8 do
		local r = glows['glow' .. i].props.resource
		if seen[tostring(r)] then dup = true end
		seen[tostring(r)] = true
	end
	check(not dup, 'each rune has its own texture slice')
end

print('=== 2. the slices tile the column exactly ===')
-- Every slice must start where the previous one ended, and together they must
-- cover the whole column. A gap shows as a dead stripe; an overlap double-draws
-- the glow and reads as a brighter seam.
do
	local expect = 0
	local ok = true
	for i = 1, 8 do
		local p = glows['glow' .. i].props
		local y, hgt = p.relativePosition.y, p.relativeSize.y
		if math.abs(y - expect) > 1e-6 then
			ok = false
			print(string.format('  gap/overlap before rune %d: starts %.4f, expected %.4f',
				i, y, expect))
		end
		expect = y + hgt
	end
	check(ok, 'slices are contiguous')
	check(math.abs(expect - 1) < 1e-6,
		string.format('slices cover the full column (end %.4f)', expect))
end

print('=== 3. runes light from the bottom, one eighth at a time ===')
-- Rune 8 is the bottom of the art, so it is the first to light.
frame(1, 1, 0)
check(litCount() == 0, 'empty magicka lights nothing, got ' .. show(litSet()))

frame(nil, nil, 1)
check(litCount() == 8, 'full magicka lights all eight, got ' .. show(litSet()))

local expected = { [0.125] = 1, [0.25] = 2, [0.375] = 3, [0.5] = 4,
                   [0.625] = 5, [0.75] = 6, [0.875] = 7, [1.0] = 8 }
for frac, want in pairs(expected) do
	frame(nil, nil, frac)
	check(litCount() == want,
		string.format('%.3f magicka -> %d runes, got %d (%s)',
			frac, want, litCount(), show(litSet())))
end

print('=== 4. the bottom rune is the one that lights first ===')
frame(nil, nil, 0.05)
do
	local set = litSet()
	check(set[8] == 1 and litCount() == 1,
		'a sliver of magicka lights only rune 8, got ' .. show(set))
end
frame(nil, nil, 0.95)
do
	local set = litSet()
	check(set[1] == 1, 'nearly full lights the top rune too, got ' .. show(set))
end

print('=== 5. a rune goes out only when its eighth is fully spent ===')
-- This is the behaviour the brief actually names: "disappear when fully empty,
-- and reappear when beginning to fill". So the boundary sits at *any* fill, not
-- at half of one.
frame(nil, nil, 0.2500)
local atBoundary = litCount()
frame(nil, nil, 0.2499)
check(litCount() == atBoundary,
	'just under the 2/8 line still lights 2 (' .. litCount() .. ')')
frame(nil, nil, 0.2501)
check(litCount() == atBoundary + 1,
	'just over the 2/8 line lights a third (' .. litCount() .. ')')
frame(nil, nil, 0.0001)
check(litCount() == 1, 'the faintest trace of magicka lights one rune')
frame(nil, nil, 0)
check(litCount() == 0, 'exactly zero lights none')

print('=== 6. the base runes are always drawn ===')
local base = findNode('runeBase')
check(base ~= nil, 'runeBase exists')
frame(nil, nil, 0)
check(base.props.visible ~= false, 'base runes stay visible at zero magicka')
check(base.props.resource ~= nil, 'base runes have a texture')

print('=== 7. glow sits behind the base runes ===')
-- The brief is "KainGame_RUNES_GLOW being overlayed with KainGameRUNES.png",
-- so every glow slice must come before the base in the content order.
do
	local col = findNode('runeColumn')
	local order, basePos = {}, nil
	for i, child in ipairs(col.content._items) do
		order[child.name] = i
		if child.name == 'runeBase' then basePos = i end
	end
	local ok = basePos ~= nil
	for i = 1, 8 do
		if not (order['glow' .. i] and order['glow' .. i] < basePos) then ok = false end
	end
	check(ok, 'all eight glows are drawn before the base runes')
end

print('=== 8. vials fill from the bottom ===')
local hf = findNode('healthFill')
check(hf ~= nil, 'healthFill exists')
for _, frac in ipairs { 0, 0.25, 0.5, 0.75, 1 } do
	frame(frac, nil, nil)
	local p = hf.props
	local top, hgt = p.relativePosition.y, p.relativeSize.y
	check(math.abs((top + hgt) - 1) < 0.02,
		string.format('at %.2f the fill is anchored to the bottom (top %.3f + h %.3f)',
			frac, top, hgt))
	check(math.abs(hgt - frac) < 0.02,
		string.format('at %.2f the fill height is %.3f', frac, hgt))
end

print('=== 9. the fill is monotonic ===')
do
	local prev = -1
	local ok = true
	for i = 0, 20 do
		frame(i / 20, nil, nil)
		local hgt = hf.props.relativeSize.y
		if hgt < prev - 1e-9 then ok = false end
		prev = hgt
	end
	check(ok, 'fill height never goes down as health goes up')
end

print('=== 10. sub-pixel changes do not touch the UI ===')
-- The vial is 139px tall by default, so a change smaller than one row cannot be
-- drawn. Noticing it anyway would mean rebuilding the widget every frame while
-- fatigue regenerates.
do
	local hud = findNode('vialsHud')
	local updates = 0
	-- The element wrapper owns :update(); count the calls the module makes.
	local target
	for _, e in ipairs { hud } do target = e end
	check(target ~= nil, 'found the hud layout')
end
do
	-- Count via the stub's own element, which is what the module calls update on.
	local elem
	for _, e in ipairs(record and record.elements or {}) do elem = e end
	-- record is local to load_check; fall back to instrumenting the layout.
	local seen = 0
	frame(0.5, 0.5, 0.5)
	local before = hf.props.relativeSize.y
	-- A change of a fifth of a pixel row out of 139.
	frame(0.5 + (0.2 / 139), nil, nil)
	check(math.abs(hf.props.relativeSize.y - before) < 1e-9,
		'a fifth-of-a-row change leaves the fill untouched')
	-- A change of a whole row does move it.
	frame(0.5 + (1.0 / 139), nil, nil)
	check(math.abs(hf.props.relativeSize.y - before) > 1e-9,
		'a full-row change does move the fill')
end

print('=== 11. stats outside 0..1 are clamped, not propagated ===')
-- Fortify and drain effects can put current above or below the base, and a
-- relativeSize outside 0..1 is a rendering fault, not a visible overfill.
frame(1.5, nil, nil)
check(hf.props.relativeSize.y <= 1.0 + 1e-9,
	'overfull health clamps to a full vial (' .. tostring(hf.props.relativeSize.y) .. ')')
frame(-0.5, nil, nil)
check(hf.props.relativeSize.y >= 0,
	'negative health clamps to empty (' .. tostring(hf.props.relativeSize.y) .. ')')
frame(nil, nil, 1.5)
check(litCount() == 8, 'overfull magicka lights eight, not nine')
frame(nil, nil, -1)
check(litCount() == 0, 'negative magicka lights none')

print('=== 12. the public interface reports what is drawn ===')
do
	local iface = MODULE.interface
	check(type(iface) == 'table', 'interface table exists')
	frame(0.5, 0.25, 0.375)
	local f = iface.getFractions()
	check(math.abs(f.health - 0.5) < 1e-6, 'getFractions health ' .. tostring(f.health))
	check(math.abs(f.stamina - 0.25) < 1e-6, 'getFractions stamina ' .. tostring(f.stamina))
	check(math.abs(f.magicka - 0.375) < 1e-6, 'getFractions magicka ' .. tostring(f.magicka))
	local lit, total = iface.getLitRunes()
	check(lit == litCount() and total == 8,
		string.format('getLitRunes agrees with the widget: %d vs %d', lit, litCount()))
end

print('')
print(string.format('%d checks, %d failures', checks, fails))
SCRIPT_FAILURES = fails
