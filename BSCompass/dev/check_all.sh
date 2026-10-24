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

echo "--- preset slots"
out=$(API_SCRIPT=dev/test_presets_slots.lua "$LUA" dev/load_check.lua . scripts/bscompass/BSC_p.lua 2>&1)
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

echo "--- the preset list in the settings matches the module"
# Two lists, in two files, naming the same presets. They have drifted before.
inmod=$(grep -oE "\['[A-Za-z0-9_]+'\] = \{" scripts/bscompass/BSC_p.lua \
    | sed "s/\\['//; s/'\\] = {//" | sort)
inset=$(sed -n "/argument = selectArg { 'BSCompasAtlas'/,/},/p" scripts/bscompass/BSC_settings.lua \
    | grep -oE "'[A-Za-z0-9_]+'" | tr -d "'" | grep -v '^Custom$' | sort)
if [ "$inmod" = "$inset" ]; then
    echo "  $(echo "$inmod" | wc -l) presets, both lists agree  OK"
else
    echo "  FAIL: the two lists differ"
    diff <(echo "$inmod") <(echo "$inset") | sed 's/^/    /'
    fail=1
fi

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

echo "--- every preset fits its frame at every size"
out=$(API_SCRIPT=dev/test_fit.lua "$LUA" dev/load_check.lua . scripts/bscompass/BSC_p.lua 2>&1)
echo "$out" | grep -E "checks, . failures" | sed 's/^/  /' || true
echo "$out" | grep -E "^  FAIL" || true
last=$(echo "$out" | tail -1); [ "$last" = OK ] || fail=1

echo "--- load check, every atlas preset"
for p in "ATLAS_PRESET=BSCompasAtlas" "ATLAS_PRESET=BSCompasAtlas_360" \
         "ATLAS_PRESET=BSCompas_Layered_360" \
         "ATLAS_PRESET=BSCompas_Demons" \
         "ATLAS_PRESET=BSCompas_Demons,COMPASS_SIZE=512" \
         "ATLAS_PRESET=BSCompas_Demons_Wide" \
         "ATLAS_PRESET=BSCompas_Demons_Wide,COMPASS_SIZE=640" \
         "ATLAS_PRESET=Redguard_Classic" \
         "ATLAS_PRESET=Redguard_Classic,COMPASS_SIZE=512" \
         "ATLAS_PRESET=DBSpretty" "ATLAS_PRESET=DBSpretty,COMPASS_SIZE=512" \
         "ATLAS_PRESET=Redguard_Compass" "ATLAS_PRESET=Redguard_Compass,COMPASS_SIZE=48" \
         "ATLAS_PRESET=RG_Compass" \
         "ATLAS_PRESET=BSCompas_Layered_360,COMPASS_SIZE=320" \
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

# The glass has to end up ON TOP of the needle, and every layer has to take the
# same size, or the compass stops being resizable. Both are read off the tree
# the mod actually builds rather than asserted against a mirror of the code.
echo "--- layered 360: stacking order and scaling"
for size in 64 176 320; do
    order=$(PRESEED="ATLAS_PRESET=BSCompas_Layered_360,COMPASS_SIZE=$size" \
        DUMP_TREE=compassHud "$LUA" dev/load_check.lua . \
        scripts/bscompass/BSC_p.lua 2>&1 \
        | awk '/^    compass/ { print $1, $2 }')
    names=$(printf '%s\n' "$order" | awk '{print $1}' | tr '\n' ' ')
    sizes=$(printf '%s\n' "$order" | awk '{print $2}' | sort -u | tr '\n' ' ')
    want="compassBackdrop compassImage compassCover "
    wantsize="size=($size,$size) "
    if [ "$names" = "$want" ] && [ "$sizes" = "$wantsize" ]; then
        printf '  size %-4s OK\n' "$size"
    else
        printf '  size %-4s FAIL  order=[%s] sizes=[%s]\n' "$size" "$names" "$sizes"
        fail=1
    fi
done

echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "FAILURES"
exit $fail
