# 0.5.3.3368 AddOns

Collection of 0.5.3 compatible AddOns.

## Instructions

- Place the `Interface` folder in the root of your 0.5.3 game installation.
- Edit `FrameXML.toc` to enable or disable AddOns. Add a `#` at the beginning of a line to disable an AddOn, or remove the `#` to enable it.

## Simple AddOns

Integrates with AlphaUI, but also works with the stock UI.
Enabled in `FrameXML.toc` (put a `#` in front of a line to turn one off).
`SimpleSave` saves the settings of the others between sessions (through
`Interface\Bindings.xml`, which therefore has to stay in place).

| AddOn | What it does | Command | Image |
|---|---|---|---|
| SimpleSave | <details><summary>Saves the settings of the other Simple AddOns</summary>• 0.5.3 cannot save addon settings by itself. SimpleSave stores them in <code>bindings.wtf</code>, so they are kept after you log out<br>• No lag while playing: settings are saved at most every 30 seconds, collected data every 5 minutes, and everything when you log out<br>• Needs <code>Interface\Bindings.xml</code> to stay in place</details> | `/ssave` | |
| SimpleMap | <details><summary>World map in a window you can move, with zoom</summary>• Keep walking and fighting while the map is open<br>• Use it as a small movable window or switch to full screen with one click<br>• Zoom with the mouse wheel and drag the map to look around<br>• Shows your coordinates, the cursor's coordinates, party members and area names<br>• Dungeon maps that open automatically when you are inside a dungeon<br>• Shows flight masters, boats, zeppelins, innkeepers, trainers and rare mobs<br>• Remembers where you found herbs, ore and chests<br>• Adjustable size and transparency, and coordinates under the minimap</details> | `/smap` | [Image](https://github.com/user-attachments/assets/af333ea7-4d1a-4332-8f16-f58bbf03ca3c) |
| SimpleChat | <details><summary>Chat window with tabs that you can move and resize</summary>• Separate tabs for General, Whispers and Guild<br>• Choose the name of each tab and which messages it shows<br>• Move and resize the chat window, with an optional dark background<br>• Scroll with the mouse wheel<br>• Copy any chat line with the Copy button<br>• Right-click a player's name to whisper, invite, add as friend or ignore</details> | `/sc` | [Image](https://github.com/user-attachments/assets/34170e6e-d0fe-4cae-99b6-7a16073ae488) |
| SimpleQoL | <details><summary>Many small improvements in one addon</summary>Turn each feature on or off in <code>/qol</code>.<br>• <b>Quests:</b> quest tracker on screen, your party's quest progress, accept and finish quests automatically<br>• <b>Items:</b> loot everything with one click, sell grey items, buy back supplies, open clams, compare with what you wear, free bag slots, right-click to trade<br>• <b>Group and guild:</b> accept resurrections and group invites, decline duels, see when guild members log in, Guild tab in the Friends window, share your position on the map<br>• <b>Combat:</b> attack back when hit, target the nearest enemy, cast heals on yourself without a target, keep stealth, dismount automatically, emergency spells at low health<br>• <b>On screen:</b> buff and weapon timers, health and mana numbers, distance to your target, FPS, ping and clock, kills to next level, name plates always on, move frames with Shift + drag<br>• <b>Included addons:</b> ActionBars for extra action bars (<code>/ab</code>), TradeSkillPlus to craft many items at once, ImprovedErrorFrame to collect Lua errors in one window (<code>/errors</code>)</details> | `/qol` | [Image](https://github.com/user-attachments/assets/b6c133cf-4ab3-4210-b866-2b0acabd9934) |
| SimpleMacros | <details><summary>Macro window with the macro commands of later WoW versions</summary>• Macros up to 511 characters, for all your characters or just one, on any action bar<br>• Automatic icons and <code>#showtooltip</code><br>• Cast and use: <code>/cast</code>, <code>/use</code>, <code>/castsequence</code>, <code>/castrandom</code>, <code>/equip</code><br>• Targeting: <code>/target</code>, <code>/targetenemy</code>, <code>/assist</code> and more<br>• Conditions such as <code>[combat]</code>, <code>[harm]</code>, <code>[mod:shift]</code> and <code>[button:2]</code><br>• Pet commands, <code>/cancelaura</code>, <code>/dismount</code> and <code>/click</code><br>• A help window lists everything a macro can do: <code>/macro help</code></details> | `/macro` | [Image](https://github.com/user-attachments/assets/8cdf312f-0a60-443a-961f-9f51cbe41599) |

`/sv` lists the versions of all installed Simple AddOns.
