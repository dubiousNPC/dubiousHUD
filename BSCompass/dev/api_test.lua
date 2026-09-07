---@omw-context none
local mod = _G.LOADED['scripts.bscompass.BSC_p']
local I = mod.interface
local H = mod.eventHandlers
local checks, fails = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print('  FAIL: ' .. m) end end

print('=== overlay API ===')
local names = I.getOverlayNames()
print('  names this artwork defines: ' .. table.concat(names, ', '))
check(#names == 2, 'two named overlays, got ' .. #names)

check(I.setOverlay('eyes') == true, 'setOverlay eyes succeeds')
check(I.isOverlayActive('eyes') == true, 'eyes now active')
check(I.setOverlay('nosuchthing') == false, 'unknown name refused, not raised')
check(I.isOverlayActive('nosuchthing') == false, 'unknown name never active')

check(I.clearOverlay('eyes') == true, 'clearOverlay eyes succeeds')
check(I.isOverlayActive('eyes') == false, 'eyes now clear')
check(I.clearOverlay('eyes') == false, 'clearing twice reports nothing to do')

I.setOverlay('eyes'); I.setOverlay('dragoneyes')
check(I.clearAllOverlays() == true, 'clearAll reports it did something')
check(I.isOverlayActive('dragoneyes') == false, 'all cleared')

print('=== event path (what another mod would send) ===')
H.BSCompass_SetOverlay({ name = 'dragoneyes', alpha = 0.5, duration = 4 })
check(I.isOverlayActive('dragoneyes') == true, 'event raised the overlay')
H.BSCompass_ClearOverlay({ name = 'dragoneyes' })
check(I.isOverlayActive('dragoneyes') == false, 'event cleared it')

H.BSCompass_SetOverlay({ name = 'eyes' })
H.BSCompass_ClearAllOverlays()
check(I.isOverlayActive('eyes') == false, 'clear-all event works')

print('=== malformed input is survivable ===')
check(pcall(H.BSCompass_SetOverlay, nil) , 'nil event data does not raise')
check(pcall(H.BSCompass_SetOverlay, {}) , 'event with no name does not raise')
check(I.setOverlay(nil) == false, 'nil name refused')
check(I.setOverlay(42) == false, 'non-string name refused')

print('=== heading readback ===')
local deg, key = I.getHeading()
print(string.format('  heading %.1f, glyph %s', deg, tostring(key)))
check(deg >= 0 and deg < 360, 'heading normalised')

print(string.format('  %d checks, %d failures', checks, fails))
if fails > 0 then error('api failures') end
