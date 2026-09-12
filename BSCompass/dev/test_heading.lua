---@omw-context none
-- Offline check of the heading -> atlas frame mapping.
-- Reimplements tileForHeading exactly as BSC_p.lua has it, then verifies it
-- against the needle angles measured out of BSCompasAtlas.png.

local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then fails = fails + 1; print('  FAIL: ' .. msg) end
end

local TILES = 36
local INVERT_ROTATION = false
local HEADING_OFFSET = 0

-- Mirrors tileForHeading in BSC_p.lua after the handedness correction.
-- The frame index now advances WITH the heading; `invert` is the exception.
local function tileForHeading(deg, n, invert, offset)
	n = n or TILES
	local step = 360 / n
	local raw = math.floor((deg + (offset or 0)) / step + 0.5)
	if invert then return (n - raw) % n end
	return raw % n
end

-- Measured from BSCompasAtlas.png: on-screen angle of the long needle arm for
-- every frame, in degrees where 0 = right and 90 = up. Taken as the principal
-- axis of the needle pixels, which is stable to about a degree.
local MEASURED = {
	[0] = -91.7, [1] = -100.4, [2] = -110.1, [3] = -120.3, [4] = -131.0, [5] = -139.8,
	[6] = -149.2, [7] = -160.4, [8] = -171.6, [9] = 178.6, [10] = 169.9, [11] = 159.6,
	[12] = 150.1, [13] = 140.2, [14] = 130.1, [15] = 119.8, [16] = 109.7, [17] = 99.6,
	[18] = 90.1, [19] = 80.9, [20] = 70.6, [21] = 59.1, [22] = 48.2, [23] = 39.5,
	[24] = 30.6, [25] = 21.7, [26] = 10.5, [27] = 0.7, [28] = -10.1, [29] = -20.3,
	[30] = -30.6, [31] = -40.3, [32] = -50.0, [33] = -60.1, [34] = -71.1, [35] = -81.2,
}

local function angdiff(a, b)
	local d = (a - b) % 360
	if d > 180 then d = d - 360 end
	return d
end

print('=== 1. the atlas rotates clockwise, 10 deg per frame ===')
local total, worst = 0, 0
for t = 1, 35 do
	local d = angdiff(MEASURED[t], MEASURED[t - 1])
	total = total + d
	if math.abs(d + 10) > math.abs(worst + 10) then worst = d end
	check(math.abs(d - (-10)) < 3,
		string.format('frame %d->%d turned %.1f deg, expected -10', t - 1, t, d))
end
-- and the wrap back to frame 0 closes the circle
total = total + angdiff(MEASURED[0], MEASURED[35])
print(string.format('  mean %.2f deg per frame, worst %.1f, full loop %.1f deg',
	total / 36, worst, total))
check(math.abs(total + 360) < 6, 'the 36 frames close a full 360, got ' .. string.format('%.1f', total))

print('=== 2. basic mapping ===')
check(tileForHeading(0) == 0, 'north is frame 0')
check(tileForHeading(360) == 0, '360 wraps to frame 0')
check(tileForHeading(355) == 0, '355 rounds into frame 0')
check(tileForHeading(5) == 1, '5 deg rounds up into frame 1')
for d = 0, 359 do
	local t = tileForHeading(d)
	if t < 0 or t >= TILES then
		check(false, 'frame out of range at ' .. d)
	end
end
check(true, 'all 360 headings map inside 0..35')

print('=== 3. every frame is reachable, and each covers 10 degrees ===')
local seen, counts = {}, {}
for d = 0, 359 do
	local t = tileForHeading(d)
	seen[t] = true
	counts[t] = (counts[t] or 0) + 1
end
local n = 0
for _ in pairs(seen) do n = n + 1 end
check(n == TILES, 'all 36 frames reachable, got ' .. n)
local uneven = 0
for t = 0, TILES - 1 do if counts[t] ~= 10 then uneven = uneven + 1 end end
check(uneven == 0, 'each frame covers exactly 10 degrees, ' .. uneven .. ' did not')

print('=== 4. handedness ===')
-- In game, east and west read swapped under the old subtracting form, and the
-- DBS sheet was additionally half a turn out. A mirror about the north-south
-- axis is a sign flip on the heading; a mirror about the east-west axis is that
-- same flip plus 180. Both sheets needing the same flip is the evidence that the
-- heading handedness, not the artwork, was the problem.
--
-- These assertions pin the corrected mapping so it cannot silently flip back.
check(tileForHeading(0)   == 0,  'north -> frame 0')
check(tileForHeading(90)  == 9,  'east  -> frame 9,  got ' .. tileForHeading(90))
check(tileForHeading(180) == 18, 'south -> frame 18, got ' .. tileForHeading(180))
check(tileForHeading(270) == 27, 'west  -> frame 27, got ' .. tileForHeading(270))

-- east and west must be a quarter turn either side of north, not swapped
check((tileForHeading(90) - tileForHeading(0)) % 36 == 9, 'east is +9 from north')
check((tileForHeading(270) - tileForHeading(0)) % 36 == 27, 'west is -9 from north')
check(tileForHeading(90) ~= tileForHeading(270), 'east and west are distinct')

print('=== 5. the DBS 180 degree offset ===')
-- North and south read swapped on that sheet without it.
local DBS = 180
check(tileForHeading(0,   360, false, DBS) == 180, 'DBS north -> frame 180')
check(tileForHeading(180, 360, false, DBS) == 0,   'DBS south -> frame 0')
check(tileForHeading(90,  360, false, DBS) == 270, 'DBS east  -> frame 270')
check(tileForHeading(270, 360, false, DBS) == 90,  'DBS west  -> frame 90')
-- applying the offset twice returns to the start
check(tileForHeading(0, 360, false, 360) == tileForHeading(0, 360, false, 0),
	'a full turn of offset is a no-op')

print('=== 6. inverted mapping is the mirror ===')
for d = 0, 350, 10 do
	local a = tileForHeading(d, 36, false)
	local b = tileForHeading(d, 36, true)
	check((a + b) % 36 == 0, 'invert mirrors at ' .. d)
end

print('=== 7. heading offset ===')
check(tileForHeading(0, 36, false, 10) == 1, '+10 offset shifts one frame forward')
check(tileForHeading(0, 36, false, -10) == 35, '-10 offset shifts one frame back')

print('=== 8. other tile counts ===')
for _, n in ipairs({ 4, 8, 16, 32, 64, 360 }) do
	local s = {}
	for d = 0, 359 do s[tileForHeading(d, n)] = true end
	local c = 0
	for _ in pairs(s) do c = c + 1 end
	check(c == n, n .. '-frame atlas uses all its frames, got ' .. c)
end

print('=== 9. grid indexing ===')
-- Frames are read row-major: index = row * cols + col. A vertical strip is the
-- cols = 1 case, so both share one code path.
local function cellOffset(i, cols, cell)
	return (i % cols) * cell, math.floor(i / cols) * cell
end

-- vertical strip, as BSCompasAtlas has always been
for _, i in ipairs({ 0, 1, 17, 35 }) do
	local x, y = cellOffset(i, 1, 88)
	check(x == 0 and y == i * 88, string.format('strip frame %d at 0,%d', i, i * 88))
end

-- 30-column grid, as BSCompasAtlas_360 and the DBS sheet use
local GRID = {
	[0]   = { 0, 0 },
	[29]  = { 29, 0 },
	[30]  = { 0, 1 },
	[59]  = { 29, 1 },
	[359] = { 29, 11 },
}
for i, want in pairs(GRID) do
	local x, y = cellOffset(i, 30, 88)
	check(x == want[1] * 88 and y == want[2] * 88,
		string.format('grid frame %d -> col %d row %d', i, want[1], want[2]))
end

-- every frame of a 30x12 grid lands in a distinct cell, and inside the sheet
local seen, out = {}, 0
for i = 0, 359 do
	local x, y = cellOffset(i, 30, 88)
	local k = x .. ',' .. y
	if seen[k] then out = out + 1 end
	seen[k] = true
	if x + 88 > 30 * 88 or y + 88 > 12 * 88 then out = out + 1 end
end
check(out == 0, 'all 360 grid cells distinct and in bounds, ' .. out .. ' bad')

print('=== 10. 360-frame mapping ===')
-- one frame per degree, and the cardinals still land where they should
check(tileForHeading(0, 360) == 0, 'north is frame 0 at 360 steps')
check(tileForHeading(90, 360) == 90, 'east -> frame 90')
check(tileForHeading(180, 360) == 180, 'south -> frame 180')
check(tileForHeading(270, 360) == 270, 'west -> frame 270')
local uniq = {}
for d = 0, 359 do uniq[tileForHeading(d, 360)] = true end
local nu = 0
for _ in pairs(uniq) do nu = nu + 1 end
check(nu == 360, '360 headings map to 360 distinct frames, got ' .. nu)

-- the 36 and 360 sheets have to agree on where north is
for _, d in ipairs({ 0, 90, 180, 270 }) do
	local coarse = tileForHeading(d, 36)
	local fine = tileForHeading(d, 360)
	check((coarse * 10) % 360 == fine,
		string.format('heading %d: 36-frame %d matches 360-frame %d', d, coarse, fine))
end

print('=== 11. texture size limits ===')
-- Why the grid exists at all.
local function stripHeight(frames, cell) return frames * cell end
check(stripHeight(36, 88) == 3168, '36-frame strip is 3168px, fine')
check(stripHeight(360, 88) == 31680, '360-frame strip would be 31680px')
check(stripHeight(360, 88) > 16384, 'which is past the usual 16384 limit')
check(88 * 30 <= 16384 and 88 * 12 <= 16384, '30x12 grid fits comfortably')

print('')
print(string.format('%d checks, %d failures', checks, fails))
os.exit(fails == 0 and 0 or 1)
