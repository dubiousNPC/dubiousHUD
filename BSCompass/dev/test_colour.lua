---@omw-context player
-- The colour validator now has to do the job pcall was doing.
local util = require('openmw.util')
local COLOR_KEYS = { TEXT_COLOR = true }
local function normalise(k, v)
	if COLOR_KEYS[k] and type(v) == 'string' then
		local hex = v:gsub('^#', '')
		if hex:match('^%x%x%x%x%x%x$') then return util.color.hex(hex) end
		local short = hex:match('^(%x%x%x)$')
		if short then return util.color.hex(short:gsub('(%x)', '%1%1')) end
		return util.color.rgb(1, 1, 1)
	end
	return v
end
local checks, fails = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: '..m) end end
local function ok(v) return pcall(normalise, 'TEXT_COLOR', v) end

for _, good in ipairs({ 'caa560', '#caa560', 'CAA560', 'fff', '#000', 'ABCdef' }) do
	local s, r = ok(good)
	check(s and type(r) == 'table', 'accepts ' .. good)
end
for _, bad in ipairs({ '', 'xyz', 'gggggg', 'caa56', 'caa5600', 'not a colour', '##fff', '   ' }) do
	local s, r = ok(bad)
	check(s, 'does not raise on ' .. string.format('%q', bad))
	check(s and type(r) == 'table', 'falls back to a colour for ' .. string.format('%q', bad))
end
local s, r = ok(nil); check(s, 'nil survives')
s, r = ok(12345);     check(s and r == 12345, 'non-string passes through untouched')
print(string.format('  %d checks, %d failures', checks, fails))
if fails > 0 then error('hex failures') end
