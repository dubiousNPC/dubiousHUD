# dubiousHUD
an attempt to recreate retro style HUDs for Morrowind

## What is in it

| folder | what it is |
|---|---|
| `00 Core` | Required by the three mods. The shared settings renderers (`dbsHUD.omwscripts`), and a MyGUI HUD layout that removes the vanilla compass and health bars |
| `DBSVials` | health and stamina as glass vials, magicka as runes |
| `MoonHUD` | the phases of Masser and Secunda, and the Shade of the Revenant |
| `BSCompass` | a dial compass |

## Install

Add `00 Core` and whichever of the three you want as data directories, and
tick their content files, with **`dbsHUD.omwscripts` first**:

```
data="path/to/dubiousHUD/00 Core"
data="path/to/dubiousHUD/DBSVials"
data="path/to/dubiousHUD/MoonHUD"
data="path/to/dubiousHUD/BSCompass"
content=dbsHUD.omwscripts
content=dbsvials.omwscripts
content=moonhud.omwscripts
content=bscompass.omwscripts
```

`00 Core` holds the one copy of SuperSettingsRenderers the three mods share.
Each mod used to bundle its own, at the same path, so whichever folder loaded
last silently supplied all three. Its HUD layout also hides the spell-effects
icons and the cell-name popup, and moves the weapon, spell and sneak boxes to
the top right.

