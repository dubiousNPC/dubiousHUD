#!/usr/bin/env bash
# Runs every offline check for MoonHUD. Needs any Lua 5.3+ as `lua`.
set -u
LUA="${LUA:-lua}"
cd "$(dirname "$0")/.."
fail=0
run() { echo "--- $*"; "$@" >/tmp/mh_out 2>&1 || fail=1; tail -1 /tmp/mh_out; }

run "$LUA" dev/test_tracker.lua
run "$LUA" dev/test_presets.lua

echo "--- colour validator (replaced a pcall)"
out=$(API_SCRIPT=dev/test_colour.lua "$LUA" dev/load_check.lua . \
    scripts/moonhud/MH_tracker.lua 2>&1)
echo "$out" | grep -E "checks, . failures" || true
last=$(echo "$out" | tail -1); echo "  $last"; [ "$last" = OK ] || fail=1

echo "--- nil-cell guard (replaced a pcall)"
out=$(API_SCRIPT=dev/test_nocell.lua "$LUA" dev/load_check.lua . \
    scripts/moonhud/MH_tracker.lua 2>&1)
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

echo "--- load check, every artwork and layout combination"
for p in ATLAS_PRESET=moon_atlas ATLAS_PRESET=moon_atlas_1 ATLAS_PRESET=moon_atlas_2 \
         ATLAS_PRESET=moon_atlas_3 ATLAS_PRESET=moon_atlas_4 ATLAS_PRESET=Custom \
         BACKGROUND_PRESET=None BACKGROUND_PRESET=panel_bg_stars \
         BACKGROUND_PRESET=panel_bg_stone BACKGROUND_PRESET=panel_bg_linen \
         "PANEL_SHAPE=Circle,LAYOUT=Triangle" "PANEL_SHAPE=Circle,LAYOUT=Vertical" \
         "PANEL_SHAPE=Rectangle,LAYOUT=Triangle Inverted" \
         "PANEL_SHAPE=None,LAYOUT=Horizontal" \
         "LAYOUT=Triangle,ICON_SIZE=64" "LAYOUT=Triangle Inverted,ICON_SIZE=16"; do
    out=$(PRESEED="$p" "$LUA" dev/load_check.lua . \
        scripts/moonhud/MH_tracker.lua scripts/moonhud/MH_hud.lua 2>&1 | tail -1)
    printf '  %-52s %s\n' "$p" "$out"
    [ "$out" = OK ] || fail=1
done

echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "FAILURES"
exit $fail
