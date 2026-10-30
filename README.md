# 0.5.3.3368 AddOns

Collection of 0.5.3 compatible AddOns.

## Instructions

- Place the `Interface` folder in the root of your 0.5.3 game installation.
- Edit the `FrameXML.toc` file to enable or disable AddOns. Place a `#` to disable an AddOn, remove the `#` to enable it.

## Simple AddOns

Enabled in `FrameXML.toc` (put a `#` in front of a line to turn one off).
`SimpleSave` saves the settings of the others between sessions (through
`Interface\Bindings.xml`, which therefore has to stay in place).

| AddOn | What it does | Command |
|---|---|---|
| SimpleSave | Saves the settings of the other Simple AddOns | `/ssave` |
| SimpleMap | Bigger movable world map with zoom, coordinates, dungeon maps, trainers and flight masters on map and minimap | `/smap` |
| SimpleChat | Movable, resizable chat with tabs, copy any line, chat settings | `/sc` |
| SimpleQoL | Quality-of-life collection (quest tracker, quick loot, auto repair, sort bags, extra action bars, error frame, tradeskill "Create All" and much more) | `/qol` |
| SimpleMacros | Macro window with 255-character macros and vanilla/classic macro conditions | `/macro` |

`/sv` lists the versions of all installed Simple AddOns.
