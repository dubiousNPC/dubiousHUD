#!/usr/bin/env bash
# Runs every offline check for DBSVials. Needs any Lua 5.3+ as `lua`.
#
# A LuaTeX install already carries one: LUA=texlua dev/check_all.sh
set -u
LUA="${LUA:-lua}"
cd "$(dirname "$0")/.."
fail=0
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

run_script() {   # <label> <test file>
    echo "--- $1"
    out=$(API_SCRIPT="$2" "$LUA" dev/load_check.lua . \
        scripts/dbsvials/DBV_p.lua 2>&1)
    echo "$out" | grep -E "^[0-9]+ checks" | sed 's/^/  /' || true
    echo "$out" | grep -E "^  FAIL|ERROR" || true
    last=$(echo "$out" | tail -1)
    [ "$last" = OK ] || fail=1
}

run_script "vials, runes and the public interface" dev/test_vials.lua
run_script "preset slots and built-in presets"     dev/test_presets_slots.lua

echo "--- bundled renderers (MENU scripts)"
out=$("$LUA" dev/load_check.lua . \
    scripts/SuperSettingsRenderers/SuperSlider6.lua \
    scripts/SuperSettingsRenderers/SuperSelect3.lua \
    scripts/SuperSettingsRenderers/SuperColorPicker4.lua \
    scripts/SuperSettingsRenderers/SuperKeybind2.lua \
    scripts/SuperSettingsRenderers/optionalRenderer1.lua 2>&1)
echo "$out" | grep -E "^renderers registered" || true
last=$(echo "$out" | tail -1); echo "  $last"; [ "$last" = OK ] || fail=1

# Every branch that changes the shape of the widget tree, loaded for real. These
# are the paths a settings change can take you down, and a typo in any of them
# is a script error at runtime rather than a visual glitch.
echo "--- load check, settings that change the tree"
while IFS= read -r cfg; do
    [ -z "$cfg" ] && continue
    out=$(PRESEED="$cfg" "$LUA" dev/load_check.lua . \
        scripts/dbsvials/DBV_p.lua 2>&1 | tail -1)
    printf '  %-54s %s\n' "$cfg" "$out"
    [ "$out" = OK ] || fail=1
done <<'CONFIGS'
LAYOUT=Horizontal
LAYOUT=Vertical
SHOW_HEALTH=false
SHOW_STAMINA=false
SHOW_RUNES=false
SHOW_HEALTH=false,SHOW_STAMINA=false,SHOW_RUNES=false
SHOW_NUMBERS=true
SHOW_NUMBERS=true,NUMBER_FORMAT=Current / Max
SHOW_NUMBERS=true,NUMBER_FORMAT=Current
HUD_BACKGROUND=true,HUD_BORDER=true
HUD_BORDER=true,HUD_BORDER_STYLE=verythick
HUD_LOCK=true
HUD_DISPLAY=Interface Only
GLASS_TEXTURE=
RUNE_FILL_FROM=Top
GLOW_PARTIAL=false
LOW_WARNING=All three
GLOW_PARTIAL=false,LOW_WARNING=All three
FLAIR_ALPHA=0
FLAIR_SPEED=2.5
VIAL_SIZE=600,RUNE_HEIGHT=512,RUNE_WIDTH=256
VIAL_SIZE=24,RUNE_HEIGHT=32,RUNE_WIDTH=8
SHOW_CLASP=false
SHOW_CAP=false
SHOW_RESIDUE=false
SHOW_CLASP=false,SHOW_CAP=false,SHOW_RESIDUE=false
BULB_TEXTURE=textures/dbsvials/VIAL_CLEAR_GLASS.png
CONFIGS

# The runes have to land on the runes at every column height, or the glow sits
# off its own glyph. Read off the tree the module builds, not asserted against a
# copy of the arithmetic.
# The vial is six pieces placed from measured art figures and scaled by one
# factor. If any of them were placed with an unscaled number it would drift out
# of register at a non-default size and nowhere else.
echo "--- vial pieces stay in register at any size"
for size in 24 86 172 344 600; do
    out=$(PRESEED="VIAL_SIZE=$size" DUMP_TREE=vialsHud "$LUA" dev/load_check.lua . \
        scripts/dbsvials/DBV_p.lua 2>&1)
    n=$(echo "$out" | grep -cE '^      (bulb|residue|fill|glass|clasp|cap)health')
    last=$(echo "$out" | tail -1)
    if [ "$n" = 6 ] && [ "$last" = OK ]; then
        printf '  size %-4s OK  (6 pieces)\n' "$size"
    else
        printf '  size %-4s FAIL  %s pieces, %s\n' "$size" "$n" "$last"
        fail=1
    fi
done

echo "--- rune slices line up at any size"
for h in 64 139 276 512; do
    out=$(PRESEED="RUNE_HEIGHT=$h" DUMP_TREE=runesHud "$LUA" dev/load_check.lua . \
        scripts/dbsvials/DBV_p.lua 2>&1)
    n=$(echo "$out" | grep -cE '^    glowThin[1-8] ')
    last=$(echo "$out" | tail -1)
    if [ "$n" = 8 ] && [ "$last" = OK ]; then
        printf '  height %-4s OK  (8 slices)\n' "$h"
    else
        printf '  height %-4s FAIL  %s slices, %s\n' "$h" "$n" "$last"
        fail=1
    fi
done

# The empty case is the one that tends to crash: nothing enabled means an empty
# Flex, and a drag handler still pointing at it.
echo "--- stat extremes"
for st in "health=0,stamina=0,magicka=0" "health=1,stamina=1,magicka=1" \
          "magicka=0.001" "magicka=0.999"; do
    out=$(STATS="$st" "$LUA" dev/load_check.lua . scripts/dbsvials/DBV_p.lua 2>&1 | tail -1)
    printf '  %-36s %s\n' "$st" "$out"
    [ "$out" = OK ] || fail=1
done

# pcall is audited out of this project. The harness uses it -- that is a test
# runner reporting failures, not shipped code -- so only the mod is checked.
echo "--- no pcall in shipped code"
# Comments are stripped first: this file explains at length why certain things
# are NOT pcall'd, and matching the word rather than the call would flag every
# one of those explanations.
hits=$(sed 's/--.*$//' scripts/dbsvials/*.lua | grep -cE '\bx?pcall[[:space:]]*\(' || true)
if [ "$hits" = 0 ]; then
    echo "  none in scripts/dbsvials  OK"
else
    echo "  FAIL: $hits pcall(s) in scripts/dbsvials"
    grep -rnE '\bx?pcall[[:space:]]*\(' scripts/dbsvials/ | grep -v '^\s*--' | sed 's/^/    /'
    fail=1
fi

echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "FAILURES"
exit $fail
