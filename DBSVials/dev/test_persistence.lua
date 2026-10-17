-- Does anything written during startup overwrite a value the user had stored?
-- That is the shape of "my settings reset every session".
local storage = require('openmw.storage')
local fails, checks = 0, 0
local function check(c,m) checks=checks+1; if not c then fails=fails+1; print('  FAIL: '..m) end end

-- Keys, not sections: sectionOf() looks each one up in what the mod actually
-- registered, so regrouping the settings page cannot silently turn these writes
-- into writes to a section nobody reads.
local WATCHED = {
  'HUD_LOCK', 'HUD_DISPLAY', 'SPACING',
  'VIAL_SIZE', 'VIAL_X_POS', 'VIAL_Y_POS', 'VIAL_LENGTH',
  'RUNE_SIZE', 'RUNE_X_POS', 'RUNE_Y_POS', 'RUNE_LENGTH',
  'SHOW_NUMBERS', 'LOW_WARNING',
  'HUD_BACKGROUND', 'HUD_PADDING',
}
local groups = {}
for _, k in ipairs(WATCHED) do
  local g = sectionOf(k)
  groups[g] = groups[g] or {}
  table.insert(groups[g], k)
end
-- snapshot everything the mod thinks it has, right after load
local before = {}
for g, keys in pairs(groups) do
  before[g] = {}
  for _, k in ipairs(keys) do before[g][k] = storage.playerSection(g):get(k) end
end

print('=== 1. startup does not write over stored values ===')
-- give every key a distinctly non-default value, as a returning player would have
local VALUES = {
  HUD_LOCK = true, HUD_DISPLAY = 'Hide on Interface', SPACING = 31,
  VIAL_SIZE = 333, VIAL_X_POS = 271, VIAL_Y_POS = 143, VIAL_LENGTH = 97,
  RUNE_SIZE = 29, RUNE_X_POS = 701, RUNE_Y_POS = 155, RUNE_LENGTH = 16,
  SHOW_NUMBERS = true, LOW_WARNING = 'All three',
  HUD_BACKGROUND = true, HUD_PADDING = 17,
}
local marked = {}
for k, v in pairs(VALUES) do
  local g = sectionOf(k)
  marked[g] = marked[g] or {}
  marked[g][k] = v
  storage.playerSection(g):set(k, v)
end

-- now do what a new session does: run the lifecycle handlers again
MODULE.engineHandlers.onInit()
MODULE.engineHandlers.onLoad()
MODULE.engineHandlers.onUpdate(0.016)

for g, kv in pairs(marked) do
  for k, want in pairs(kv) do
    local got = storage.playerSection(g):get(k)
    check(got == want, string.format('%s.%s survived startup: wanted %s, got %s',
      g:gsub('SettingsDBSVials',''), k, tostring(want), tostring(got)))
  end
end

print('=== 2. and the globals the widget reads agree with storage ===')
for g, kv in pairs(marked) do
  for k, want in pairs(kv) do
    check(_G[k] == want, string.format('_G.%s = %s (storage says %s)',
      k, tostring(_G[k]), tostring(want)))
  end
end

print('')
print(string.format('%d checks, %d failures', checks, fails))
SCRIPT_FAILURES = fails
