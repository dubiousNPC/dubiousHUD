-- Does anything written during startup overwrite a value the user had stored?
-- That is the shape of "my settings reset every session".
local storage = require('openmw.storage')
local fails, checks = 0, 0
local function check(c,m) checks=checks+1; if not c then fails=fails+1; print('  FAIL: '..m) end end

local groups = {
  SettingsDBSVialsGeneral = { 'HUD_LOCK', 'HUD_DISPLAY', 'SPACING' },
  SettingsDBSVialsVials   = { 'VIAL_SIZE', 'VIAL_X_POS', 'VIAL_Y_POS' },
  SettingsDBSVialsRunes   = { 'RUNE_HEIGHT', 'RUNE_X_POS', 'RUNE_Y_POS' },
  SettingsDBSVialsAccess  = { 'SHOW_NUMBERS', 'LOW_WARNING' },
  SettingsDBSVialsFrame   = { 'HUD_BACKGROUND', 'HUD_PADDING' },
}
-- snapshot everything the mod thinks it has, right after load
local before = {}
for g, keys in pairs(groups) do
  before[g] = {}
  for _, k in ipairs(keys) do before[g][k] = storage.playerSection(g):get(k) end
end

print('=== 1. startup does not write over stored values ===')
-- give every key a distinctly non-default value, as a returning player would have
local marked = {
  SettingsDBSVialsGeneral = { HUD_LOCK = true, HUD_DISPLAY = 'Hide on Interface', SPACING = 31 },
  SettingsDBSVialsVials   = { VIAL_SIZE = 333, VIAL_X_POS = 271, VIAL_Y_POS = 143 },
  SettingsDBSVialsRunes   = { RUNE_HEIGHT = 222, RUNE_X_POS = 701, RUNE_Y_POS = 155 },
  SettingsDBSVialsAccess  = { SHOW_NUMBERS = true, LOW_WARNING = 'All three' },
  SettingsDBSVialsFrame   = { HUD_BACKGROUND = true, HUD_PADDING = 17 },
}
for g, kv in pairs(marked) do
  for k, v in pairs(kv) do storage.playerSection(g):set(k, v) end
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
