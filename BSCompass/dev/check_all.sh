#!/usr/bin/env bash
# Runs every offline check for BSCompass. Needs any Lua 5.3+ as `lua`.
set -u
LUA="${LUA:-lua}"
cd "$(dirname "$0")/.."
fail=0

echo "--- dev/test_heading.lua"
"$LUA" dev/test_heading.lua >/tmp/bs_out 2>&1 || fail=1
tail -1 /tmp/bs_out

echo "--- colour validator (replaced a pcall)"
out=$(API_SCRIPT=dev/test_colour.lua "$LUA" dev/load_check.lua . \
    scripts/bscompass/BSC_p.lua 2>&1)
echo "$out" | grep -E "checks, . failures" || true
last=$(echo "$out" | tail -1); echo "  $last"; [ "$last" = OK ] || fail=1

echo "--- bundled renderers (MENU scripts)"
out=$("$LUA" dev/load_check.lua . \
    scripts/SuperSettingsRenderers/SuperSlider6.lua \
    scripts/SuperSettingsRenderers/SuperSelect3.lua \
    scripts/SuperSettingsRenderers/SuperColorPicker4.lua \
    scripts/SuperSettingsRenderers/SuperKeybind2.lua \
    scripts/SuperSettingsRenderers/optionalRenderer1.lua 2>&1)
echo "$out" | grep -E "^renderers registered" || true
last=$(echo "$out" | tail -1)
echo "  $last"
[ "$last" = OK ] || fail=1

echo "--- dev/test_overlays.lua"
"$LUA" dev/test_overlays.lua >/tmp/bs_ov 2>&1 || fail=1
tail -1 /tmp/bs_ov

echo "--- overlay interface and event path"
out=$(PRESEED="ATLAS_PRESET=DBS_CompassARROW" API_SCRIPT=dev/api_test.lua \
    "$LUA" dev/load_check.lua . scripts/bscompass/BSC_p.lua 2>&1)
echo "$out" | grep -E "checks, . failures" || true
last=$(echo "$out" | tail -1)
echo "  $last"
[ "$last" = OK ] || fail=1

echo "--- load check, every atlas preset"
for p in "ATLAS_PRESET=BSCompasAtlas" "ATLAS_PRESET=BSCompasAtlas_360" \
         "ATLAS_PRESET=DBS_CompassARROW" "ATLAS_PRESET=Custom" \
         "ATLAS_PRESET=DBS_CompassARROW,COMPASS_SIZE=1024" \
         "ATLAS_PRESET=DBS_CompassARROW,OVERLAY_LAYER=In front" \
         "ATLAS_PRESET=DBS_CompassARROW,CARDINAL_OVERLAY=Off" \
         "ATLAS_PRESET=DBS_CompassARROW,CARDINAL_OVERLAY=Sharp" \
         "ATLAS_PRESET=BSCompasAtlas,CARDINAL_OVERLAY=Sharp + Fade"; do
    out=$(PRESEED="$p" "$LUA" dev/load_check.lua . \
        scripts/bscompass/BSC_p.lua 2>&1 | tail -1)
    printf '  %-48s %s\n' "$p" "$out"
    [ "$out" = OK ] || fail=1
done

echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "FAILURES"
exit $fail
