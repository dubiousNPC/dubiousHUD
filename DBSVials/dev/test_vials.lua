---@omw-context none
-- Drives the real DBV_p.lua through the load_check stubs and reads the real
-- widget tree. Run as API_SCRIPT, never on its own -- it has no stubs of its own
-- and deliberately re-implements none of the module's logic, because a test that
-- mirrors the code only ever proves the mirror is faithful.

local fails, checks = 0, 0
local function check(c, m)
	checks = checks + 1
	if not c then fails = fails + 1; print('  FAIL: ' .. m) end
end

local onUpdate = MODULE.engineHandlers.onUpdate

local function frame(h, s, m)
	if h then setStatFraction('health', h) end
	if s then setStatFraction('stamina', s) end
	if m then setStatFraction('magicka', m) end
	onUpdate(0.016)
end

-- Art figures, from the supplied files. Repeated here on purpose: if the module
-- changes one of them, this file is where the disagreement shows up.
local TUBE_W, TUBE_H     = 13, 139
local FILL_X0, FILL_X1   = 3, 9          -- the TUBE pngs' liquid column
local FILL_X             = 9             -- where that column sits on the canvas
local FILL_BOTTOM        = 169

local base
-- Three layers behind the runes now. A rune is "lit" if it wears either halo.
local thin, thick, flair
local function rebindRunes()
	thin, thick, flair = collectNodes('glowThin'), collectNodes('glowThick'),
		collectNodes('flair')
end
rebindRunes()
local function vis(t, i) local e = t['' .. i]; return e and e.props.visible ~= false end
local function on(tbl, i)
	local e = tbl[i]
	return e and e.props.visible ~= false
end
local function thinOn(i)  return on(thin, 'glowThin' .. i) end
local function thickOn(i) return on(thick, 'glowThick' .. i) end
local function flairOn(i) return on(flair, 'flair' .. i) end
local function litSet()
	local out = {}
	for i = 1, 8 do out[i] = (thinOn(i) or thickOn(i)) and 1 or 0 end
	return out
end
local function litCount()
	local n = 0
	for _, v in ipairs(litSet()) do n = n + v end
	return n
end
local function stateStr()
	local out = {}
	for i = 1, 8 do
		out[i] = thickOn(i) and 'F' or (thinOn(i) and 'p' or '.')
	end
	return table.concat(out)
end
local function show(t) return table.concat(t, '') end

print('=== 1. the vials and the runes are two independent widgets ===')
local vialRoot, runeRoot = findNode('vialsHud'), findNode('runesHud')
check(vialRoot ~= nil, 'vialsHud exists')
check(runeRoot ~= nil, 'runesHud exists')
check(vialRoot ~= runeRoot, 'they are different elements')
do
	local vp, rp = vialRoot.props.position, runeRoot.props.position
	check(vp ~= nil and rp ~= nil, 'both carry their own position')
	check(not (vp.x == rp.x and vp.y == rp.y),
		string.format('they start apart, not stacked (%s,%s) vs (%s,%s)',
			tostring(vp.x), tostring(vp.y), tostring(rp.x), tostring(rp.y)))
end
do
	-- Each root owns its own drag handler, writing its own keys. Sharing one
	-- would move both widgets together, which is the thing being fixed.
	check(type(vialRoot.events) == 'table' and vialRoot.events.mouseMove ~= nil,
		'the vials have a drag handler')
	check(type(runeRoot.events) == 'table' and runeRoot.events.mouseMove ~= nil,
		'the runes have a drag handler')
	check(vialRoot.events.mouseMove ~= runeRoot.events.mouseMove,
		'the two drag handlers are not the same function')
end
do
	-- The runes must not be inside the vials' tree, or moving one drags both.
	local inside = false
	local function walk(n)
		if type(n) ~= 'table' then return end
		if n.name == 'runeColumn' then inside = true end
		local c = n.content
		if c and c._items then for _, ch in ipairs(c._items) do walk(ch) end end
		if n.layout then walk(n.layout) end
	end
	walk(vialRoot)
	check(not inside, 'the rune column is not nested inside the vials widget')
end

print('=== 2. the vial is assembled from all six pieces ===')
for _, key in ipairs { 'health', 'stamina' } do
	-- The five the brief names. The bulb backing and the dreg are optional
	-- extras and default off, since the transparent clasp carries that glass.
	for _, piece in ipairs { 'clasp', 'fill', 'clear', 'glass', 'cap' } do
		check(findNode(piece .. key) ~= nil, piece .. ' present on the ' .. key .. ' vial')
	end
end

print('=== 3. the layers are in the order the art needs ===')
local hf, hglass, hclasp, hcap = findNode('fillhealth'), findNode('glasshealth'),
	findNode('clasphealth'), findNode('caphealth')
local hclear = findNode('clearhealth')
do
	-- The whole point of this revision: the clasp is UNDER the liquid and a
	-- clear front piece is over it. Drawn the other way round, the metal covers
	-- the liquid where it passes through and the vessel reads as two parts
	-- rather than one.
	local vial = findNode('healthVial')
	local pos = {}
	for i, child in ipairs(vial.content._items) do pos[child.name] = i end
	local order = { 'clasphealth', 'fillhealth', 'clearhealth', 'glasshealth',
	                'caphealth' }
	local ok = true
	for i = 2, #order do
		if not (pos[order[i - 1]] and pos[order[i]] and pos[order[i - 1]] < pos[order[i]]) then
			ok = false
			print('  out of order: ' .. order[i - 1] .. ' should precede ' .. order[i])
		end
	end
	check(ok, 'clasp, liquid, clear clasp, glass, collar')
	check(pos['clasphealth'] < pos['fillhealth'], 'the clasp is BELOW the liquid')
	check(pos['clearhealth'] > pos['fillhealth'], 'the clear clasp is ABOVE the liquid')
end
do
	-- The tube's glass ends where the clasp begins. Drawn its full 139 rows it
	-- runs on past the clasp and clips through it, which is what the example
	-- flasks do not do.
	local glassBottom = hglass.props.position.y + hglass.props.size.y
	local claspTop = hclasp.props.position.y + 24
	check(glassBottom <= claspTop + 4,
		string.format('the tube stops at the clasp, not past it (%d vs %d)',
			glassBottom, claspTop))
	check(hglass.props.size.y < TUBE_H,
		'the tube glass is cut short of its full art (' .. hglass.props.size.y .. ' of ' .. TUBE_H .. ')')
	-- and it must be CUT, not squashed: the texture has to match the rect.
	local r = hglass.props.resource
	check(r._size and r._size.y == hglass.props.size.y,
		'the tube texture is cut to the rows drawn, not stretched into them')
end
do
	-- The liquid is one column for the whole vessel, not a tube fill sitting on
	-- a separate bulb: it has to reach below the clasp into the bulb.
	local claspTop = hclasp.props.position.y + 24
	frame(1, nil, nil)
	local liqBottom = hf.props.position.y + hf.props.size.y
	check(liqBottom > claspTop,
		string.format('the liquid reaches past the clasp into the bulb (%d vs %d)',
			liqBottom, claspTop))
	check(hf.props.position.y < hglass.props.position.y + 30,
		'and reaches up into the tube')
end

print('=== 3b. the registration holds at a different size ===')
-- VIAL_SIZE scales the whole assembly by one factor. If any piece were placed
-- with an unscaled figure it would drift out of register here and nowhere else.
do
	local storage = require('openmw.storage')
	local sec = storage.playerSection('SettingsDBSVialsVials')
	for _, size in ipairs { 95, 380 } do
		sec:set('VIAL_SIZE', size)
		-- The widgets were destroyed and rebuilt by that write, so everything
		-- has to be looked up again. Anything cached from before now points at
		-- a tree that no longer exists.
		local v = findNode('healthVial')
		local f, g = findNode('fillhealth'), findNode('glasshealth')
		local c, cp = findNode('clasphealth'), findNode('caphealth')
		check(v.props.size.y == size,
			string.format('at %d the assembly is %d tall', size, v.props.size.y))
		check(f.props.size.x == g.props.size.x,
			'liquid and glass are the same width at ' .. size)
		local claspTop = c.props.position.y + math.floor(24 * size / 190)
		check(f.props.position.y + f.props.size.y > claspTop,
			'the liquid still reaches past the clasp at ' .. size)
		check(cp.props.position.y + cp.props.size.y > g.props.position.y,
			'the collar still overlaps the tube top at ' .. size)
	end
	sec:set('VIAL_SIZE', 190)
end

-- Re-bind everything the earlier sections captured: the tree above is gone.
vialRoot, runeRoot = findNode('vialsHud'), findNode('runesHud')
rebindRunes()
hf, hglass = findNode('fillhealth'), findNode('glasshealth')
hclasp, hcap = findNode('clasphealth'), findNode('caphealth')
hclear = findNode('clearhealth')
base = findNode('runeBase')

print('=== 4. the liquid is cut, not stretched ===')
-- Stretching one texture would squash all 139 rows into however many the fill
-- occupies, which distorts the taper at the bottom of the tube. Each level gets
-- its own pre-cut texture instead, and the drawn rect must match what was cut.
do
	local seen, ok = {}, true
	for i = 1, 20 do          -- from 1: an empty vessel draws nothing at all
		frame(i / 20, nil, nil)
		local r = hf.props.resource
		local cutH = r._size and r._size.y
		if cutH ~= hf.props.size.y then
			ok = false
			print(string.format('  cut %s rows but drew %s at %.2f',
				tostring(cutH), tostring(hf.props.size.y), i / 20))
		end
		if r._offset and r._size and (r._offset.y + r._size.y) ~= TUBE_H then
			ok = false
			print('  the cut is not taken from the bottom of the tube')
		end
		seen[tostring(cutH)] = true
	end
	check(ok, 'every level draws exactly the rows it cut, from the tube bottom')
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	check(n > 15, 'the 20 levels produced ' .. n .. ' distinct cuts, not one stretched texture')
end

print('=== 5. the liquid fills from the bottom ===')
do
	local prev = -1
	local ok, anchored = true, true
	for i = 1, 20 do
		frame(i / 20, nil, nil)
		local bottom = hf.props.position.y + hf.props.size.y
		-- Welded to the foot of the VESSEL now, not the foot of the tube: the
		-- liquid pools in the bulb.
		if bottom ~= FILL_BOTTOM then anchored = false end
		if hf.props.size.y < prev then ok = false end
		prev = hf.props.size.y
	end
	check(anchored, 'the liquid stays welded to the foot of the bulb at every level')
	check(ok, 'the liquid height never goes down as the stat goes up')
end

print('=== 6. the whole travel is visible ===')
-- Nothing is hidden at either end any more: the clasp is underneath the liquid
-- and the collar sits clear of the top of the travel.
do
	frame(0, nil, nil)
	check(hf.props.visible == false, 'an empty vessel draws no liquid at all')
	frame(0.01, nil, nil)
	local h1 = hf.props.size.y
	check(hf.props.visible ~= false and h1 > 0, '1%% shows a little')
	frame(1, nil, nil)
	local hFull = hf.props.size.y
	check(hFull == TUBE_H, 'a full vessel is the whole column, got ' .. hFull)
	local top = hf.props.position.y
	local capBottom = hcap.props.position.y + hcap.props.size.y
	check(top >= capBottom, 'and stops clear of the collar (' .. top .. ' vs ' .. capBottom .. ')')
	frame(0.99, nil, nil)
	check(hf.props.size.y < hFull, '99%% is distinguishable from full')
end

print('=== 7. the optional dreg is tinted per vial ===')
-- Off by default now, but when switched on it has to take each vial's own
-- colour: it is the same texture in both, so the tint is what differs.
do
	local storage = require('openmw.storage')
	local sec = storage.playerSection('SettingsDBSVialsVials')
	sec:set('SHOW_RESIDUE', true)
	local rh, rs = findNode('residuehealth'), findNode('residuestamina')
	check(rh ~= nil and rs ~= nil, 'switching the dreg on adds it to both vials')
	if rh and rs then
		check(rh.props.resource._texture == rs.props.resource._texture,
			'it is the same texture in both')
		check(tostring(rh.props.color) ~= tostring(rs.props.color),
			'but tinted differently')
	end
	sec:set('SHOW_RESIDUE', false)
	check(findNode('residuehealth') == nil, 'and switching it off removes it again')
	-- the tree was rebuilt three times over; re-bind everything
	rebindRunes()
	hf, hglass = findNode('fillhealth'), findNode('glasshealth')
	hclasp, hcap = findNode('clasphealth'), findNode('caphealth')
	hclear = findNode('clearhealth')
	vialRoot, runeRoot = findNode('vialsHud'), findNode('runesHud')
	base = findNode('runeBase')
end

-- Sections 8 to 13 are the Classic rune sheet, which is no longer the default,
-- so switch to it first. Everything cached above belongs to the previous tree.
do
	local storage = require('openmw.storage')
	storage.playerSection('SettingsDBSVialsRunes'):set('RUNE_STYLE', 'Classic')
	rebindRunes()
	base = findNode('runeBase')
	hf, hglass = findNode('fillhealth'), findNode('glasshealth')
	hclasp, hcap = findNode('clasphealth'), findNode('caphealth')
	hclear = findNode('clearhealth')
	vialRoot, runeRoot = findNode('vialsHud'), findNode('runesHud')
end

print('=== 8. all three rune layers are sliced eight ways ===')
for i = 1, 8 do
	check(thin['glowThin' .. i] ~= nil, 'thin halo ' .. i .. ' exists')
	check(thick['glowThick' .. i] ~= nil, 'thick halo ' .. i .. ' exists')
	check(flair['flair' .. i] ~= nil, 'flair ' .. i .. ' exists')
end
do
	local seen, dup = {}, false
	for i = 1, 8 do
		local r = thin['glowThin' .. i].props.resource
		local key = tostring(r._offset and r._offset.y) .. ':' .. tostring(r._size and r._size.y)
		if seen[key] then dup = true end
		seen[key] = true
	end
	check(not dup, 'each rune is cut from its own band of the sheet')
end
do
	-- The three sheets are registered against each other, so rune i must be the
	-- same band on all three or a halo lands on its neighbour.
	local ok = true
	for i = 1, 8 do
		local a = thin['glowThin' .. i].props.resource
		local b = thick['glowThick' .. i].props.resource
		local c = flair['flair' .. i].props.resource
		if not (a._offset.y == b._offset.y and b._offset.y == c._offset.y
		        and a._size.y == b._size.y and b._size.y == c._size.y) then
			ok = false
		end
		if a._texture == b._texture then ok = false end
	end
	check(ok, 'thin, thick and flair take the same band of three different sheets')
end
do
	-- Every flair must be behind every halo. Interleaving them per rune would
	-- put rune 2's flair over rune 1's halo where their slices touch.
	local col = findNode('runeColumn')
	local pos = {}
	for i, child in ipairs(col.content._items) do pos[child.name] = i end
	local lastFlair, firstHalo = 0, math.huge
	for i = 1, 8 do
		lastFlair = math.max(lastFlair, pos['flair' .. i])
		firstHalo = math.min(firstHalo, pos['glowThick' .. i], pos['glowThin' .. i])
	end
	check(lastFlair < firstHalo,
		'the whole flair layer is drawn before any halo')
end

print('=== 9. the slices tile the column with no gap or overlap ===')
-- A gap shows as a dead stripe across the glow; an overlap double-draws it and
-- reads as a brighter seam. Both edges are rounded before the height is taken,
-- which is what makes this hold at every column height.
do
	local col = findNode('runeColumn')
	local expect, ok = 0, true
	for i = 1, 8 do
		local p = thin['glowThin' .. i].props
		if p.position.y ~= expect then
			ok = false
			print(string.format('  rune %d starts at %d, expected %d', i, p.position.y, expect))
		end
		expect = p.position.y + p.size.y
	end
	check(ok, 'slices are contiguous')
	check(expect == col.props.size.y,
		string.format('slices cover the full column (%d of %d)', expect, col.props.size.y))
end

print('=== 10. runes light from the bottom, one eighth at a time ===')
frame(1, 1, 0)
check(litCount() == 0, 'empty magicka lights nothing, got ' .. show(litSet()))
frame(nil, nil, 1)
check(litCount() == 8, 'full magicka lights all eight, got ' .. show(litSet()))
for frac, want in pairs { [0.125] = 1, [0.25] = 2, [0.375] = 3, [0.5] = 4,
                          [0.625] = 5, [0.75] = 6, [0.875] = 7, [1.0] = 8 } do
	frame(nil, nil, frac)
	check(litCount() == want,
		string.format('%.3f magicka -> %d runes, got %d (%s)',
			frac, want, litCount(), show(litSet())))
end

print('=== 11. the bottom rune lights first ===')
frame(nil, nil, 0.05)
check(litSet()[8] == 1 and litCount() == 1,
	'a sliver of magicka lights only rune 8, got ' .. show(litSet()))
frame(nil, nil, 0.95)
check(litSet()[1] == 1, 'nearly full lights the top rune too, got ' .. show(litSet()))

print('=== 12. a rune goes out only when its eighth is fully spent ===')
frame(nil, nil, 0.2500)
local atBoundary = litCount()
frame(nil, nil, 0.2499)
check(litCount() == atBoundary, 'just under the 2/8 line still lights 2 (' .. litCount() .. ')')
frame(nil, nil, 0.2501)
check(litCount() == atBoundary + 1, 'just over the 2/8 line lights a third (' .. litCount() .. ')')
frame(nil, nil, 0.0001)
check(litCount() == 1, 'the faintest trace of magicka lights one rune')
frame(nil, nil, 0)
check(litCount() == 0, 'exactly zero lights none')

print('=== 12b. a rune wears exactly one halo, never two ===')
-- GLOW_UP1 and GLOW_UP2 are alternatives for the same rune, not layers to
-- stack. Both at once would double the outline and read as a seam.
do
	local ok = true
	for i = 0, 40 do
		frame(nil, nil, i / 40)
		for r = 1, 8 do
			if thinOn(r) and thickOn(r) then
				ok = false
				print(string.format('  rune %d wore both at %.3f', r, i / 40))
			end
		end
	end
	check(ok, 'no rune ever wears both halos')
end

print('=== 12c. thin halo marks the rune in motion, thick marks the full ones ===')
do
	-- Below a full eighth: that rune is filling, so it takes the thin halo and
	-- everything under it is already full.
	frame(nil, nil, 0.30)   -- 2.4 eighths: two full, one part-way
	check(stateStr() == '.....pFF',
		'at 30%% two are full and one is filling, got ' .. stateStr())
	frame(nil, nil, 0.75)   -- exactly six eighths, nothing in motion
	check(stateStr() == '..FFFFFF',
		'at exactly 6/8 all six are full and none is in motion, got ' .. stateStr())
	frame(nil, nil, 0.80)
	check(stateStr() == '.pFFFFFF',
		'just past 6/8 a seventh starts filling, got ' .. stateStr())
	frame(nil, nil, 1.0)
	check(stateStr() == 'FFFFFFFF', 'full magicka is eight thick halos, got ' .. stateStr())
	frame(nil, nil, 0)
	check(stateStr() == '........', 'empty magicka is none, got ' .. stateStr())
end
do
	-- Only ever one rune is in motion: the eighth the level is passing through.
	local ok = true
	for i = 1, 39 do
		frame(nil, nil, i / 40)
		local n = 0
		for r = 1, 8 do if thinOn(r) then n = n + 1 end end
		if n > 1 then ok = false; print(string.format('  %d thin halos at %.3f', n, i / 40)) end
	end
	check(ok, 'at most one rune is in motion at any level')
end

print('=== 12d. the flair is the pulse layer, and is off until something pulses ===')
do
	local storage = require('openmw.storage')
	storage.playerSection('SettingsDBSVialsAccess'):set('LOW_WARNING', 'Off')
	rebindRunes()
	frame(1, 1, 1)
	local anyOn = false
	for i = 1, 8 do if flairOn(i) then anyOn = true end end
	check(not anyOn, 'nothing is pulsing, so no flair is showing')

	-- A mod asks for a flash through the interface.
	MODULE.interface.flashRunes(2.0)
	frame(nil, nil, 0.5)
	local lit = {}
	for i = 1, 8 do lit[i] = flairOn(i) end
	local shown, past = 0, 0
	for i = 1, 8 do
		if lit[i] then shown = shown + 1 end
		-- rune 8 is the bottom; at 50%% runes 5..8 are lit
		if lit[i] and i < 5 then past = past + 1 end
	end
	check(shown > 0, 'flashRunes lit the flair, got ' .. tostring(shown) .. ' slices')
	check(past == 0, 'the flair only shows under lit runes, not spent ones')

	-- and it decays
	for _ = 1, 200 do frame(nil, nil, 0.5) end
	local stillOn = false
	for i = 1, 8 do if flairOn(i) then stillOn = true end end
	check(not stillOn, 'the flash ran out and the flair went away')
end
do
	-- The magicka low warning drives the flair rather than dimming the runes.
	-- Dimming was the wrong cue: going darker is what running out already
	-- looks like.
	local storage = require('openmw.storage')
	storage.playerSection('SettingsDBSVialsAccess'):set('LOW_WARNING', 'All three')
	rebindRunes()
	base = findNode('runeBase')
	local baseAlphaBefore = base.props.alpha
	local seen = false
	for _ = 1, 60 do
		frame(nil, nil, 0.1)
		for i = 1, 8 do if flairOn(i) then seen = true end end
	end
	check(seen, 'low magicka pulses the flair')
	check(base.props.alpha == baseAlphaBefore,
		'and leaves the runes themselves at full brightness')
	storage.playerSection('SettingsDBSVialsAccess'):set('LOW_WARNING', 'Off')
	rebindRunes()
	base = findNode('runeBase')
end

print('=== 13. the base runes are always drawn, glow behind them ===')
base = findNode('runeBase')
frame(nil, nil, 0)
check(base.props.visible ~= false, 'base runes stay visible at zero magicka')
do
	local col = findNode('runeColumn')
	local order, basePos = {}, nil
	for i, child in ipairs(col.content._items) do
		order[child.name] = i
		if child.name == 'runeBase' then basePos = i end
	end
	local ok = basePos ~= nil
	for i = 1, 8 do
		for _, n in ipairs { 'flair' .. i, 'glowThick' .. i, 'glowThin' .. i } do
			if not (order[n] and order[n] < basePos) then ok = false end
		end
	end
	check(ok, 'every halo and flair is drawn before the front runes')
end

print('=== 14. sub-row changes do not touch the UI ===')
do
	frame(0.5, 0.5, 0.5)
	local before = hf.props.size.y
	frame(0.5 + (0.2 / 139), nil, nil)
	check(hf.props.size.y == before, 'a fifth-of-a-row change leaves the liquid untouched')
	frame(0.5 + (3.0 / 139), nil, nil)
	check(hf.props.size.y ~= before, 'a multi-row change does move it')
end

print('=== 15. stats outside 0..1 are clamped, not propagated ===')
frame(1.5, nil, nil)
check(hf.props.size.y <= TUBE_H, 'overfull health does not overflow the column')
frame(-0.5, nil, nil)
check(hf.props.visible == false, 'negative health reads as empty')
frame(nil, nil, 1.5)
check(litCount() == 8, 'overfull magicka lights eight, not nine')
frame(nil, nil, -1)
check(litCount() == 0, 'negative magicka lights none')

print('=== 16. the public interface reports what is drawn ===')
do
	local iface = MODULE.interface
	frame(0.5, 0.25, 0.375)
	local f = iface.getFractions()
	check(math.abs(f.health - 0.5) < 1e-6, 'getFractions health ' .. tostring(f.health))
	check(math.abs(f.stamina - 0.25) < 1e-6, 'getFractions stamina ' .. tostring(f.stamina))
	check(math.abs(f.magicka - 0.375) < 1e-6, 'getFractions magicka ' .. tostring(f.magicka))
	local lit, total = iface.getLitRunes()
	check(lit == litCount() and total == 8,
		string.format('getLitRunes agrees with the widget: %d vs %d', lit, litCount()))
	-- setVisible can address one widget or both, since they are separate now.
	iface.setVisible(false, 'runes')
	check(runeRoot.props.visible == false, 'hiding the runes hid the runes')
	check(vialRoot.props.visible ~= false, 'and left the vials alone')
	iface.setVisible(true)
	check(runeRoot.props.visible ~= false and vialRoot.props.visible ~= false,
		'showing both brought them back')
end

print('=== 17. the xs rune set: outline always, blue per rune ===')
-- The default style. An outline per rune underneath and a blue cell over each,
-- on an even 30-row grid. A rune empties by losing its blue, which is the whole
-- reason the set was redrawn. The outlines are cut per cell rather than drawn as
-- one image so that the column can be lengthened by repeating them.
do
	local storage = require('openmw.storage')
	storage.playerSection('SettingsDBSVialsRunes'):set('RUNE_STYLE', 'Runes')
	local outlines = collectNodes('runeOutline')
	local xs = collectNodes('xs')
	local no = 0
	for i = 1, 8 do if outlines['runeOutline' .. i] then no = no + 1 end end
	check(no == 8, 'an outline per rune, got ' .. no)
	local n = 0
	for i = 1, 8 do if xs['xs' .. i] then n = n + 1 end end
	check(n == 8, 'eight blue cells, got ' .. n)

	-- every outline must be BEHIND every blue cell, or a lit rune is outlined
	-- over: the whole outline layer goes down before any blue starts
	local col = findNode('runeColumn')
	local pos = {}
	for i, ch in ipairs(col.content._items) do pos[ch.name] = i end
	local lastOutline, firstBlue = 0, math.huge
	for i = 1, 8 do
		lastOutline = math.max(lastOutline, pos['runeOutline' .. i] or 0)
		firstBlue   = math.min(firstBlue, pos['xs' .. i] or math.huge)
	end
	check(lastOutline < firstBlue, 'the outline layer is complete before any blue')

	-- cells tile the column with no gap
	local expect, tiled = 0, true
	for i = 1, 8 do
		local pr = xs['xs' .. i].props
		if pr.position.y ~= expect then tiled = false end
		expect = pr.position.y + pr.size.y
	end
	check(tiled, 'the eight cells are contiguous')
	check(expect == col.props.size.y,
		string.format('and cover the column (%d of %d)', expect, col.props.size.y))

	-- each cell is cut from its own 30-row band of the sheet
	local seen, dup = {}, false
	for i = 1, 8 do
		local r = xs['xs' .. i].props.resource
		local key = tostring(r._offset and r._offset.y)
		if seen[key] then dup = true end
		seen[key] = true
		if r._size and r._size.y ~= 30 then dup = true end
	end
	check(not dup, 'each cell is its own 30-row band of the sheet')

	-- and it drains like the others
	frame(1, 1, 1)
	local lit = 0
	for i = 1, 8 do if xs['xs' .. i].props.visible ~= false then lit = lit + 1 end end
	check(lit == 8, 'full magicka shows all eight blues, got ' .. lit)
	frame(nil, nil, 0)
	lit = 0
	for i = 1, 8 do if xs['xs' .. i].props.visible ~= false then lit = lit + 1 end end
	check(lit == 0, 'empty magicka shows none, got ' .. lit)
	local allOut = true
	for i = 1, 8 do
		if outlines['runeOutline' .. i].props.visible == false then allOut = false end
	end
	check(allOut, 'but every outline is still there when empty')
	frame(nil, nil, 0.5)
	lit = 0
	for i = 1, 8 do if xs['xs' .. i].props.visible ~= false then lit = lit + 1 end end
	check(lit == 4, 'half magicka shows four, got ' .. lit)
end

print('=== 18. rune length extends the xs column ===')
-- The same gesture as the vial's length, but on the runes: the column grows by
-- gaining runes rather than by subdividing the same space smaller, so a rune
-- keeps the height it has at eight and the eight shapes repeat upward. What
-- changes is what a rune MEANS -- one Nth of magicka, so a finer readout.
do
	local storage = require('openmw.storage')
	local sec = storage.playerSection('SettingsDBSVialsRunes')
	sec:set('RUNE_STYLE', 'Runes')
	local base = findNode('runeColumn').props.size.y
	local baseCell = collectNodes('xs').xs1.props.size.y

	for _, n in ipairs { 8, 9, 16, 24, 32 } do
		sec:set('RUNE_LENGTH', n)
		local col = findNode('runeColumn')
		local xs  = collectNodes('xs')
		local out = collectNodes('runeOutline')

		local built, outBuilt = 0, 0
		for i = 1, 64 do
			if xs['xs' .. i] then built = built + 1 end
			if out['runeOutline' .. i] then outBuilt = outBuilt + 1 end
		end
		check(built == n, n .. ' runes build ' .. n .. ' cells, got ' .. built)
		check(outBuilt == n, 'and ' .. n .. ' outlines, got ' .. outBuilt)

		-- contiguous and covering, at every length -- the same property the
		-- Classic slices are held to, for the same reason
		local expect, tiled = 0, true
		for i = 1, n do
			local pr = xs['xs' .. i].props
			if pr.position.y ~= expect then tiled = false end
			if out['runeOutline' .. i].props.position.y ~= pr.position.y
				or out['runeOutline' .. i].props.size.y ~= pr.size.y then
				tiled = false
			end
			expect = pr.position.y + pr.size.y
		end
		check(tiled, 'the ' .. n .. ' cells are contiguous and their outlines agree')
		check(expect == col.props.size.y,
			string.format('and cover the column at %d (%d of %d)',
				n, expect, col.props.size.y))

		-- a rune does not shrink: Rune Height stays the height of eight
		check(xs.xs1.props.size.y == baseCell,
			'a rune keeps its height at ' .. n .. ' (' .. xs.xs1.props.size.y
				.. ' vs ' .. baseCell .. ')')
		check(math.abs(col.props.size.y - base * n / 8) <= 1,
			string.format('the column is %d/8 of its height at %d (%d)',
				n, n, col.props.size.y))

		-- the eight shapes repeat upward, as the pips do
		local repeats = true
		for i = 1, n do
			local a = xs['xs' .. i].props.resource
			local b = xs['xs' .. (((i - 1) % 8) + 1)].props.resource
			if a._offset.y ~= b._offset.y then repeats = false end
			if out['runeOutline' .. i].props.resource._offset.y ~= b._offset.y then
				repeats = false
			end
		end
		check(repeats, 'the eight shapes repeat every eight at ' .. n)

		-- and the readout is in Nths now, not eighths
		local function lit()
			local c = 0
			for i = 1, n do
				if xs['xs' .. i].props.visible ~= false then c = c + 1 end
			end
			return c
		end
		frame(1, 1, 1)
		check(lit() == n, 'full magicka lights all ' .. n .. ', got ' .. lit())
		frame(nil, nil, 0)
		check(lit() == 0, 'empty lights none at ' .. n .. ', got ' .. lit())
		frame(nil, nil, 0.5)
		check(lit() == n / 2 or lit() == math.ceil(n / 2),
			'half magicka lights half of ' .. n .. ', got ' .. lit())
		-- one rune's worth: finer column, finer step
		frame(nil, nil, 0.5 / n)
		check(lit() == 1, 'one Nth of magicka lights one rune at ' .. n
			.. ', got ' .. lit())
	end

	-- the public interface reports the count that is actually drawn
	sec:set('RUNE_LENGTH', 16)
	frame(nil, nil, 1)
	local l, total = MODULE.interface.getLitRunes()
	check(total == 16, 'getLitRunes reports 16 runes, got ' .. tostring(total))
	check(l == 16, 'and all of them lit at full magicka, got ' .. tostring(l))
	sec:set('RUNE_LENGTH', 8)
end

print('=== 19. pips ===')
do
	local storage = require('openmw.storage')
	local sec = storage.playerSection('SettingsDBSVialsRunes')
	sec:set('RUNE_STYLE', 'Pips')
	sec:set('PIP_SOURCE', 'A fixed amount of magicka')
	sec:set('PIP_MAGICKA', 10)
	sec:set('PIP_COLUMN', 8)
	sec:set('PIP_WRAP', 'Right')
	local pips = collectNodes('pip')
	local function shown()
		local n = 0
		for i = 1, 64 do
			local e = pips['pip' .. i]
			if e and e.props.visible ~= false then n = n + 1 end
		end
		return n
	end
	check(pips.pip1 ~= nil, 'pips are built')

	-- one pip per 10 magicka, out of a 100 maximum
	frame(1, 1, 1)
	check(shown() == 10, 'full magicka at 10 per pip shows 10, got ' .. shown())
	frame(nil, nil, 0.45)
	check(shown() == 4, '45 magicka shows 4 whole pips, got ' .. shown())
	frame(nil, nil, 0)
	check(shown() == 0, 'no magicka shows none, got ' .. shown())

	print('--- pips stack upward and wrap into columns')
	-- pip 1 is at the bottom of the main column, and each one above it.
	local y1, y2 = pips.pip1.props.position.y, pips.pip2.props.position.y
	check(y2 < y1, 'pip 2 sits above pip 1 (' .. y2 .. ' vs ' .. y1 .. ')')
	check(pips.pip1.props.position.x == pips.pip8.props.position.x,
		'the first eight share a column')
	check(pips.pip9.props.position.x ~= pips.pip1.props.position.x,
		'the ninth starts a new one')
	check(pips.pip9.props.position.x > pips.pip1.props.position.x,
		'which is to the RIGHT by default')
	check(pips.pip9.props.position.y == pips.pip1.props.position.y,
		'and starts at the bottom again')

	sec:set('PIP_WRAP', 'Left')
	pips = collectNodes('pip')
	check(pips.pip9.props.position.x < pips.pip1.props.position.x,
		'set to Left, the new column goes the other way')
	check(pips.pip1.props.position.x > 0,
		'and the main column moves off the left edge to make room')

	sec:set('PIP_COLUMN', 4)
	pips = collectNodes('pip')
	check(pips.pip4.props.position.x == pips.pip1.props.position.x and
	      pips.pip5.props.position.x ~= pips.pip1.props.position.x,
		'Pips per Column controls where the break falls')

	print('--- the eight shapes repeat')
	local a = collectNodes('pip')
	check(a.pip1.props.resource._texture == a.pip9.props.resource._texture,
		'pip 9 reuses the first shape')
	check(a.pip1.props.resource._texture ~= a.pip2.props.resource._texture,
		'but pip 2 is a different one')

	sec:set('RUNE_STYLE', 'Runes')
	sec:set('PIP_COLUMN', 8)
	sec:set('PIP_WRAP', 'Right')
end

print('=== 20. Battlespire vials ===')
do
	local storage = require('openmw.storage')
	local sec = storage.playerSection('SettingsDBSVialsVials')
	sec:set('VIAL_STYLE', 'Battlespire')
	local e = findNode('engyhealth')
	check(e ~= nil, 'the Battlespire tube is drawn')
	check(findNode('fillhealth') == nil, 'and none of the Classic assembly is')
	check(findNode('clasphealth') == nil, 'no clasp')
	check(findNode('caphealth') == nil, 'no collar')

	-- 32 frames, 0 full and 31 empty, and the frame is CUT not stretched
	local function frameOf()
		local r = findNode('engyhealth').props.resource
		return r._offset and (r._offset.y / 82) or nil, r._size and r._size.y
	end
	frame(1, 1, 1)
	local f, h = frameOf()
	check(f == 0 and h == 82, 'full health is frame 0 of 82 rows, got ' .. tostring(f))
	frame(0, nil, nil)
	f = frameOf()
	check(f == 31, 'empty health is frame 31, got ' .. tostring(f))
	frame(0.5, nil, nil)
	f = frameOf()
	check(f > 10 and f < 21, 'half health lands mid-ramp, got frame ' .. tostring(f))

	-- monotonic: draining never makes the frame go backwards
	local prev = -1
	local ok = true
	for i = 20, 0, -1 do
		frame(i / 20, nil, nil)
		local g = frameOf()
		if g < prev then ok = false end
		prev = g
	end
	check(ok, 'the frame index rises steadily as the tube drains')

	-- the optional outline
	check(findNode('engyframehealth') == nil, 'the frame is off by default')
	sec:set('ENGY_SHOW_FRAME', true)
	check(findNode('engyframehealth') ~= nil, 'switching it on adds it')
	do
		local col = findNode('healthVial')
		local pos = {}
		for i, ch in ipairs(col.content._items) do pos[ch.name] = i end
		check(pos.engyframehealth > pos.engyhealth, 'and it is drawn over the tube')
	end
	sec:set('ENGY_SHOW_FRAME', false)
	sec:set('VIAL_STYLE', 'Classic')
	hf, hglass = findNode('fillhealth'), findNode('glasshealth')
	hclasp, hcap = findNode('clasphealth'), findNode('caphealth')
	hclear = findNode('clearhealth')
	vialRoot, runeRoot = findNode('vialsHud'), findNode('runesHud')
end

print('=== 21. vial length ===')
-- Shortening the tube has to move everything below it by the same amount, or
-- the clasp detaches from the tube and the liquid stops reaching the foot.
do
	local storage = require('openmw.storage')
	local sec = storage.playerSection('SettingsDBSVialsVials')
	local function geom()
		local g, c, f = findNode('glasshealth'), findNode('clasphealth'), findNode('fillhealth')
		return g, c, f
	end
	local prevGap
	for _, L in ipairs { 139, 120, 100, 80, 63 } do
		sec:set('VIAL_LENGTH', L)
		local g, c, f = geom()
		check(g ~= nil and c ~= nil and f ~= nil, 'the vial still builds at length ' .. L)
		-- the tube is cut from the length sheet at the frame for L
		local r = g.props.resource
		check(r._offset ~= nil, 'the tube is cut, not whole, at ' .. L)
		-- The clasp has to stay the same distance from the tube's end. Measured
		-- in ART rows, not drawn pixels: a shorter vial at the same Vial Size is
		-- drawn at a larger scale, so every drawn distance grows with it.
		local v = findNode('healthVial')
		local k = v.props.size.y / (190 - (139 - L))
		local gap = (c.props.position.y - (g.props.position.y + g.props.size.y)) / k
		if prevGap then
			check(math.abs(gap - prevGap) <= 1.5,
				string.format('the clasp stays with the tube at %d (%.1f art rows vs %.1f)',
					L, gap, prevGap))
		end
		prevGap = gap
		-- a full vial still fills to the top of the tube
		frame(1, nil, nil)
		check(f.props.size.y > 0, 'a full vial has liquid at length ' .. L)
	end
	sec:set('VIAL_LENGTH', 139)
	do
		local g = findNode('glasshealth')
		local r = g.props.resource
		check(r._offset.y == (139 - 63) * 139, 'full length reads the last frame of the sheet')
	end
	hf, hglass = findNode('fillhealth'), findNode('glasshealth')
	hclasp, hcap = findNode('clasphealth'), findNode('caphealth')
end

print('')
print(string.format('%d checks, %d failures', checks, fails))
SCRIPT_FAILURES = fails
