--------------------------------------------------------------------------------
-- SimpleMacros help window: what a macro can do. Opened with the Help button in
-- the macro window or /macro help. The list follows the engine
-- (SimpleMacros_Engine.lua); keep it in step when something is added.
--------------------------------------------------------------------------------

SIMPLEMACROS_HELP_HEAD = "|cffffd200";
SIMPLEMACROS_HELP_END = "|r";

SIMPLEMACROS_HELP_LINES = {
	"H:The basics",
	"One command on each line, up to 511 characters in total. Lines that start with # are settings for the macro and are not run. Anything that is not listed here is sent to the chat box as typed, so /say, /p, /g, /emote and so on work.",
	"",
	"H:Icon and tooltip",
	"Pick the question mark icon to get an automatic icon: it shows the first spell or item the macro uses.",
	"#showtooltip              automatic icon and tooltip",
	"#showtooltip Spell Name   show this spell",
	"#showtooltip Item Name    show this item (in your bags or worn)",
	"#show 13                  show the item worn in slot 13",
	"#show works the same way as #showtooltip.",
	"",
	"H:Casting",
	"/cast Spell Name",
	"/cast Spell Name(Rank 3)",
	"/cast !Spell Name         does not turn a toggle (like Shoot) off",
	"/cast [conditions] Spell; Other Spell    the first one whose conditions are true",
	"/castrandom Spell, Spell, Spell          one of them at random",
	"/castsequence Spell, Spell, Spell        the next one each time you press it",
	"/castsequence reset=10/target/combat Spell, Spell    start over after 10 seconds, a new target, or a change in or out of combat (also reset=shift, ctrl, alt)",
	"/stopcasting              stop what you are casting",
	"",
	"H:Items and equipment",
	"/use Item Name            from your bags, or worn",
	"/use 13                   the item worn in slot 13 (1 to 19)",
	"/use 0 3                  bag 0, slot 3",
	"/use [conditions] Item; Other Item",
	"/userandom Item, Item     one of them at random",
	"/equip Item Name          put on an item from your bags",
	"",
	"H:Target",
	"/target Name              a unit like player, pet, party1, mouseover or targettarget, or part of a name in range",
	"/target nearest           nearest enemy",
	"/targetenemy              nearest enemy (Tab target)",
	"/targetenemyplayer        the next enemy player",
	"/targetfriend             nearest friend",
	"/targetlasttarget         your previous target",
	"/targetexact Name         an enemy with exactly this name, in range",
	"/targetparty              the next party member",
	"/cleartarget              no target",
	"/assist                   target what your target targets (or /assist Name)",
	"",
	"H:Attack and pet",
	"/startattack              start auto attack (does nothing if you already attack)",
	"/stopattack               stop auto attack",
	"/petattack                send the pet at your target",
	"/petfollow  /petwait  /petpassive  /petdefensive  /petaggressive  /petdismiss",
	"",
	"H:Auras, forms and mounts",
	"/cancelaura Name          remove a buff of yours",
	"/cancelform               leave your shapeshift form",
	"/dismount                 get off your mount",
	"",
	"H:Other",
	"/click FrameName          click a button on the screen",
	"/stopmacro                stop the macro here (use it with a condition)",
	"/run  /script             run Lua code (not described here)",
	"/macro or /m              open this window",
	"/runmacro Name            run a macro by its name",
	"/changeactionbar 2        show page 2 of the main action bar",
	"/swapactionbar 1 2        switch between page 1 and page 2",
	"/macro names              show or hide macro names on the action buttons (also the button in the window)",
	"",
	"H:Conditions",
	"Put conditions in [ ] before the spell or item. Several conditions in one [ ] must all be true: [combat,harm]. Several [ ][ ] means any one: [mod:shift][mod:ctrl]. Put no in front to turn one around: [nocombat], [noharm], [nomod].",
	"[combat]                  you are in combat",
	"[harm]  [help]            the unit can be attacked / is a friend",
	"[dead]  [exists]          the unit is dead / exists    ([notarget] = no target)",
	"[mod:shift]  [mod:ctrl]  [mod:alt]    key held down; [mod:shift/ctrl] means either; [mod] any of them",
	"[button:1]  [button:2]    left or right mouse button on the action button",
	"[group]  [group:party]  [group:raid]  you are in a group, a party, a raid",
	"[pet]  [pet:Name]         you have a pet / a pet of that name or kind (voidwalker, imp, ...)",
	"[form:1]  [stance:1]  [form:0]   shapeshift form or stance number ([form:0] = none, or the form name)",
	"[stealth]                 you are stealthed (Stealth or Prowl)",
	"[mounted]                 you are mounted",
	"[worn:Type]               an item type is worn (for example Shield, Dagger)",
	"[casting]  [nocast]       you are casting",
	"[channeling]  [channeling:Name]   you are channeling",
	"[buff:Name]  [debuff:Name]   aura on the unit (buffs of yourself are checked best)",
	"[party]                   the unit is in your party",
	"[known:Spell]             you know this spell ([noknown:Spell] = you do not)",
	"[bar:2]  [actionbar:2]    the main action bar shows page 2",
	"",
	"H:Who a command is aimed at",
	"[@mouseover]  [target=mouseover]    the unit under the mouse",
	"Units: target, player (or me), pet, mouseover, targettarget, pettarget, party1 to party4, partypet1 to partypet4, mouseovertarget, cursor",
	"Example: /cast [@mouseover,help] Heal; [help] Heal; [@player] Heal",
	"",
	"H:Examples",
	"#showtooltip",
	"/cast [nopet] Summon Imp",
	"",
	"#showtooltip Shadow Bolt",
	"/startattack",
	"/cast Shadow Bolt",
	"/petattack",
	"",
	"#showtooltip",
	"/cast [mod:shift] Corruption; [mod:ctrl] Curse of Agony; Shadow Bolt",
	"",
	"#showtooltip",
	"/stopcasting [nochanneling]",
	"/castsequence reset=target Corruption, Curse of Agony, Immolate",
	"",
	"H:Putting a macro on a button",
	"Drag a macro from the window and let go over any action button (the standard bar or ActionBars). Or Shift+click it in the window and click the button. You can drag it from button to button the same way: pick it up, then click the button where it should go (right-click or Escape cancels). A spell dragged on top of a macro replaces it, and the macro is carried so you can place it somewhere else. The first letters of the macro name show on the button (switch off with the \"Button names\" button). Right-click a macro in the window to test it.",
	"",
	"H:Share and icons",
	"Share exports the selected macro as one line of text (click the box, Ctrl+A, Ctrl+C) and imports such a line (Ctrl+V, then Import) into the first free square of the open tab. In the icon list, type in Search icons to find an icon by name, for example fire or shadow.",
};

SimpleMacrosHelp_Built = nil;

function SimpleMacrosHelp_Text()
	local lines = SIMPLEMACROS_HELP_LINES;
	local text = "";
	local i, line;
	for i = 1, getn(lines) do
		line = lines[i];
		if ( strsub(line, 1, 2) == "H:" ) then
			line = SIMPLEMACROS_HELP_HEAD..strsub(line, 3)..SIMPLEMACROS_HELP_END;
		end
		if ( i > 1 ) then
			text = text.."\n";
		end
		text = text..line;
	end
	return text;
end

function SimpleMacrosHelp_OnShow()
	if ( not SimpleMacrosHelp_Built ) then
		SimpleMacrosHelp_Built = 1;
		SimpleMacrosHelpText:SetText(SimpleMacrosHelp_Text());
	end
	local height = SimpleMacrosHelpText:GetHeight();
	if ( height and height > 0 ) then
		SimpleMacrosHelpScrollChild:SetHeight(height + 8);
	end
	SimpleMacrosHelpScrollFrame:UpdateScrollChildRect();
end

function SimpleMacrosHelp_Toggle()
	if ( SimpleMacrosHelpFrame:IsVisible() ) then
		SimpleMacrosHelpFrame:Hide();
	else
		SimpleMacrosPopupFrame:Hide();
		SimpleMacrosShareFrame:Hide();
		SimpleMacrosHelpFrame:Show();
	end
end
