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
| SimpleSave | Saves the settings of the other Simple AddOns | `/ssave` | |
| SimpleMap | Bigger movable world map with zoom | `/smap` | [Image](https://github.com/user-attachments/assets/af333ea7-4d1a-4332-8f16-f58bbf03ca3c) |
| SimpleChat | Movable, resizable chat with tabs | `/sc` | [Image](https://github.com/user-attachments/assets/34170e6e-d0fe-4cae-99b6-7a16073ae488) |
| SimpleQoL | Quality-of-life collection | `/qol` | [Image](https://github.com/user-attachments/assets/b6c133cf-4ab3-4210-b866-2b0acabd9934) |
| SimpleMacro | Macro window with extended functionality | `/macro` | [Image](https://github.com/user-attachments/assets/8cdf312f-0a60-443a-961f-9f51cbe41599) |

`/sv` lists the versions of all installed Simple AddOns.
