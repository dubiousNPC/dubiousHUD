---@omw-context none
-- Cardinal band logic and the named-overlay API, offline.
local fails, checks = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: ' .. m) end end

local CARDINAL_POINTS = { { 'N', 0 }, { 'E', 90 }, { 'S', 180 }, { 'W', 270 } }
local ALPHA_STEPS = 16

-- mirrors cardinalFor() in BSC_p.lua
local function cardinalFor(deg, mode, sharp, fade)
	if mode == 'Off' or mode == nil then return nil, 0 end
	sharp = sharp or 15; fade = fade or 45
	if fade < sharp then fade = sharp end
	local bestKey, bestDelta
	for _, p in ipairs(CARDINAL_POINTS) do
		local d = math.abs(((deg - p[2] + 180) % 360) - 180)
		if bestDelta == nil or d < bestDelta then bestDelta, bestKey = d, p[1] end
	end
	if bestDelta <= sharp then return bestKey, ALPHA_STEPS end
	if mode ~= 'Sharp + Fade' then return nil, 0 end
	if bestDelta > fade then return nil, 0 end
	local span = fade - sharp
	local t = 1
	if span > 0 then t = 1 - (bestDelta - sharp) / span end
	local step = math.floor(t * ALPHA_STEPS + 0.5)
	if step <= 0 then return nil, 0 end
	return bestKey .. 'fade', step
end

print('=== 1. the four cardinals light their own glyph ===')
for _, p in ipairs(CARDINAL_POINTS) do
	local k, st = cardinalFor(p[2], 'Sharp + Fade')
	check(k == p[1] and st == ALPHA_STEPS,
		string.format('%d deg -> %s at full, got %s/%d', p[2], p[1], tostring(k), st))
end

print('=== 2. band edges ===')
check(select(1, cardinalFor(15, 'Sharp + Fade')) == 'N', '15 deg still solid N')
check(select(1, cardinalFor(16, 'Sharp + Fade')) == 'Nfade', '16 deg switches to fade')
-- Cardinals are 90 degrees apart, so at the default fade arc of 45 the bands
-- meet exactly at the midpoint and tile the whole circle. Past 45 the nearest
-- cardinal is the NEXT one, not a gap.
check(select(1, cardinalFor(46, 'Sharp + Fade')) == 'Efade',
	'past 45 the nearest cardinal is east, got ' .. tostring(cardinalFor(46, 'Sharp + Fade')))
check(cardinalFor(45, 'Sharp + Fade') == nil,
	'at the exact midpoint the ramp reaches zero, so nothing is drawn')

-- A dead band exists only when the fade arc is narrower than the midpoint.
check(cardinalFor(45, 'Sharp + Fade', 15, 30) == nil, 'narrow fade arc leaves a gap at 45')
check(cardinalFor(40, 'Sharp + Fade', 15, 30) == nil, 'and at 40')
check(select(1, cardinalFor(25, 'Sharp + Fade', 15, 30)) == 'Nfade', 'but not at 25')

print('=== 3. Sharp mode has no approach ===')
check(select(1, cardinalFor(0, 'Sharp')) == 'N', 'Sharp lights on the nose')
check(cardinalFor(20, 'Sharp') == nil, 'Sharp shows nothing in the fade band')
check(cardinalFor(0, 'Off') == nil, 'Off shows nothing at all')

print('=== 4. the ramp is monotonic and bounded ===')
local prev, bad = nil, 0
for d = 15, 45 do
	local _, st = cardinalFor(d, 'Sharp + Fade')
	if st < 0 or st > ALPHA_STEPS then bad = bad + 1 end
	if prev and st > prev then bad = bad + 1 end
	prev = st
end
check(bad == 0, 'alpha step falls monotonically across the fade band')

print('=== 5. quantisation bounds the update rate ===')
-- A full slow turn must not force an update every frame.
local changes, last = 0, nil
for d = 0, 359 do
	local k, st = cardinalFor(d, 'Sharp + Fade')
	local sig = tostring(k) .. ':' .. st
	if sig ~= last then changes = changes + 1 end
	last = sig
end
print('  distinct cardinal states across a full turn: ' .. changes)
check(changes <= 4 * (2 * ALPHA_STEPS + 2), 'bounded by the step count, got ' .. changes)
check(changes < 360, 'far fewer than one per degree')

print('=== 6. every glyph is reachable, and only one at a time ===')
local seen = {}
for d = 0, 359 do
	local k = cardinalFor(d, 'Sharp + Fade')
	if k then seen[k] = true end
end
local n = 0
for _ in pairs(seen) do n = n + 1 end
check(n == 8, 'all four solid and four fade glyphs reachable, got ' .. n)

print('=== 7. arcs that overlap or invert are handled ===')
check(select(1, cardinalFor(0, 'Sharp + Fade', 60, 10)) == 'N', 'fade < sharp does not error')
check(select(1, cardinalFor(0, 'Sharp + Fade', 1, 1)) == 'N', 'degenerate arcs still light on the nose')
local k = cardinalFor(44, 'Sharp + Fade', 45, 45)
check(k == 'N', 'sharp == fade behaves as Sharp only, got ' .. tostring(k))

print('')
print(string.format('%d checks, %d failures', checks, fails))
os.exit(fails == 0 and 0 or 1)
