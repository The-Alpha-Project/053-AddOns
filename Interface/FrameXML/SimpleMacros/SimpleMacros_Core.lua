--------------------------------------------------------------------------------
-- SimpleMacros for WoW 0.5.3 - core: data model, helpers, slash commands, events
--
-- Lua 5.0 rules for this client (do not break them):
--   * no string methods (s:sub), use strsub/strfind/gsub/strlen
--   * no # length operator, use getn; no % operator, use mod()
--   * no string.match, use strfind with captures
--   * no non-ASCII characters anywhere in the files
--------------------------------------------------------------------------------

SIMPLEMACROS_VERSION = "2.33";

SIMPLEMACROS_MAX_MACROS = 18;          -- per tab, same as 1.12
SIMPLEMACROS_MAX_BODY = 511;           -- characters per macro (1.12 had 255)
SIMPLEMACROS_MAX_NAME = 16;            -- characters per macro name, same as 1.12
SIMPLEMACROS_MAX_SLOT = 200;             -- highest action slot a macro can be placed in
SIMPLEMACROS_DEFAULT_ICON = "INV_Misc_QuestionMark";
SIMPLEMACROS_ICON_PREFIX = "Interface\\Icons\\";

-- Macros of the current session.
-- SimpleMacros_Macros.g[slot] = general (account wide), SimpleMacros_Macros.c[slot] = this character.
-- Each macro: { name = "Shadowbolt", icon = "Spell_Shadow_ShadowBolt", body = "/cast Shadow Bolt" }
-- icon is stored without the "Interface\Icons\" prefix.
SimpleMacros_Macros = { g = {}, c = {} };

-- Macros placed on action buttons: SimpleMacros_Slot[action slot] = "g3" or "c5"
-- (scope letter + macro slot). Slots are the numbers of the real action slots,
-- so the macro sits on the stock bar and on ActionBars like a spell.
SimpleMacros_Slot = {};

SimpleMacros_PlayerName = nil;
SimpleMacros_Loaded = nil;             -- set when macros have been loaded (server or file)



--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

function SimpleMacros_Print(text)
	local frame = DEFAULT_CHAT_FRAME or ChatFrame;
	if ( frame ) then
		frame:AddMessage("SimpleMacros: "..text, 1.0, 0.82, 0.0);
	end
end

function SimpleMacros_Trim(text)
	if ( not text ) then
		return "";
	end
	text = gsub(text, "^%s+", "");
	text = gsub(text, "%s+$", "");
	return text;
end

-- Returns "Interface\Icons\Name" for a stored icon name.
function SimpleMacros_IconPath(icon)
	if ( not icon or icon == "" ) then
		icon = SIMPLEMACROS_DEFAULT_ICON;
	end
	if ( strfind(icon, "\\", 1, 1) ) then
		return icon;
	end
	return SIMPLEMACROS_ICON_PREFIX..icon;
end

-- Strips "Interface\Icons\" from a texture path.
function SimpleMacros_IconName(path)
	if ( not path or path == "" ) then
		return SIMPLEMACROS_DEFAULT_ICON;
	end
	local lowerPath = strlower(path);
	local lowerPrefix = strlower(SIMPLEMACROS_ICON_PREFIX);
	if ( strsub(lowerPath, 1, strlen(lowerPrefix)) == lowerPrefix ) then
		return strsub(path, strlen(lowerPrefix) + 1);
	end
	return path;
end

-- "g3" -> "g", 3
function SimpleMacros_ParseRef(ref)
	if ( not ref ) then
		return nil, nil;
	end
	local _, _, scope, slot = strfind(ref, "^([gc])(%d+)$");
	if ( not scope ) then
		return nil, nil;
	end
	return scope, tonumber(slot);
end

function SimpleMacros_MakeRef(scope, slot)
	return scope..slot;
end

function SimpleMacros_GetMacro(scope, slot)
	if ( not scope or not slot or not SimpleMacros_Macros[scope] ) then
		return nil;
	end
	return SimpleMacros_Macros[scope][slot];
end

function SimpleMacros_GetMacroByRef(ref)
	local scope, slot = SimpleMacros_ParseRef(ref);
	return SimpleMacros_GetMacro(scope, slot);
end

-- First free slot in a tab, or nil when the tab is full.
function SimpleMacros_FirstFreeSlot(scope)
	local i;
	for i = 1, SIMPLEMACROS_MAX_MACROS do
		if ( not SimpleMacros_Macros[scope][i] ) then
			return i;
		end
	end
	return nil;
end

-- Finds a macro by name (current character first, then general).
function SimpleMacros_FindMacroByName(name)
	local lowerName = strlower(SimpleMacros_Trim(name));
	local scopes = { "c", "g" };
	local s, i, macro;
	for s = 1, 2 do
		for i = 1, SIMPLEMACROS_MAX_MACROS do
			macro = SimpleMacros_Macros[scopes[s]][i];
			if ( macro and strlower(macro.name or "") == lowerName ) then
				return macro, scopes[s], i;
			end
		end
	end
	return nil;
end


--------------------------------------------------------------------------------
-- Changing macros. All edits go through these, so storage and UI stay in sync.
--------------------------------------------------------------------------------

function SimpleMacros_SetMacro(scope, slot, name, icon, body)
	name = SimpleMacros_Trim(name);
	if ( name == "" ) then
		name = "Macro";
	end
	if ( strlen(name) > SIMPLEMACROS_MAX_NAME ) then
		name = strsub(name, 1, SIMPLEMACROS_MAX_NAME);
	end
	body = body or "";
	body = gsub(body, "\r", "");
	if ( strlen(body) > SIMPLEMACROS_MAX_BODY ) then
		body = strsub(body, 1, SIMPLEMACROS_MAX_BODY);
	end
	icon = SimpleMacros_IconName(icon);

	SimpleMacros_Macros[scope][slot] = { name = name, icon = icon, body = body, ref = scope..slot };
	SimpleMacros_Storage_SaveMacro(scope, slot);
	SimpleMacros_OnMacrosChanged();
end

function SimpleMacros_DeleteMacro(scope, slot)
	local ref = SimpleMacros_MakeRef(scope, slot);
	SimpleMacros_Macros[scope][slot] = nil;
	SimpleMacros_Storage_DeleteMacro(scope, slot);
	-- Gone from the action buttons as well.
	SimpleMacros_RemoveRefFromSlots(ref);
	SimpleMacros_OnMacrosChanged();
end

-- Called after any change: refresh everything that shows macros.
function SimpleMacros_OnMacrosChanged()
	if ( SimpleMacrosFrame_Update ) then
		SimpleMacrosFrame_Update();
	end
	if ( SimpleMacrosSlots_Refresh ) then
		SimpleMacrosSlots_Refresh();
	end
end


--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

SLASH_SIMPLEMACROS1 = "/macro";
SLASH_SIMPLEMACROS2 = "/macros";
SLASH_SIMPLEMACROS3 = "/simplemacros";
SLASH_SIMPLEMACROS4 = "/m";
SlashCmdList["SIMPLEMACROS"] = function(msg)
	local simpleVersionAsk = strlower(gsub(msg or "", "%s", ""));
	if ( simpleVersionAsk == "v" or simpleVersionAsk == "version" ) then
		ChatFrame:AddMessage("SimpleMacros "..SIMPLEMACROS_VERSION, 1.0, 0.82, 0.0);
		return;
	end
	msg = strlower(SimpleMacros_Trim(msg));
	if ( msg == "status" ) then
		SimpleMacros_Print(SimpleMacros_Storage_StatusText());
	elseif ( msg == "names" ) then
		SimpleMacros_SetShowNames(not SimpleMacros_ShowNames);
		SimpleMacros_Print(SimpleMacros_NamesText());
	elseif ( msg == "help" ) then
		ShowUIPanel(SimpleMacrosFrame);
		SimpleMacrosHelpFrame:Show();
	else
		SimpleMacrosFrame_Toggle();
	end
end

SLASH_SIMPLEMACROSRUN1 = "/runmacro";
SlashCmdList["SIMPLEMACROSRUN"] = function(msg)
	local macro = SimpleMacros_FindMacroByName(msg);
	if ( macro ) then
		SimpleMacros_RunMacro(macro);
	else
		SimpleMacros_Print("No macro named '"..SimpleMacros_Trim(msg).."'.");
	end
end


--------------------------------------------------------------------------------
-- Events (frame SimpleMacrosEventFrame in SimpleMacros.xml)
--------------------------------------------------------------------------------

function SimpleMacros_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("SPELLS_CHANGED");
	this:RegisterEvent("UPDATE_BINDINGS");
	SimpleMacrosEngine_OnLoad();
	UIPanelWindows["SimpleMacrosFrame"] = { area = "left", pushable = 1 };
	tinsert(UISpecialFrames, "SimpleMacrosPopupFrame");
end

function SimpleMacros_OnEvent(event)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not SimpleMacros_PlayerName ) then
			SimpleMacros_PlayerName = UnitName("player");
			SimpleMacros_Storage_Start();
			SimpleMacros_Compat_Slashes();
		end
	elseif ( event == "SPELLS_CHANGED" ) then
		SimpleMacros_ClearSpellCache();
		SimpleMacros_OnMacrosChanged();
	elseif ( event == "UPDATE_BINDINGS" ) then
		-- SimpleSave only binds its own hidden data keys, which never show on
		-- the bars: its writes need no redraw (not while the Key Bindings
		-- window is open, where the player may change real bindings too).
		if ( SimpleSave_LastWrite and GetTime() - SimpleSave_LastWrite < 1 and not (KeyBindingFrame and KeyBindingFrame:IsVisible()) ) then
			return;
		end
		-- Saving with SimpleSave changes key bindings many times in a row; with
		-- macros on the bars the bars are redrawn once, 0.4 seconds later,
		-- not for every one of those events.
		if ( SimpleMacros_SlotCount and SimpleMacros_SlotCount > 0 and SimpleMacrosSlotFrame and SimpleMacrosSlotFrame:IsVisible() ) then
			SimpleMacros_BindingsDirty = 1;
		else
			SimpleMacros_OnMacrosChanged();
		end
	end
	SimpleMacrosEngine_OnEvent(event);
end




--------------------------------------------------------------------------------
-- Main Menu button "Macros" (under Addons, before Reload UI)
--------------------------------------------------------------------------------

function SimpleMacros_MenuClick()
	PlaySound("igMainMenuOption");
	HideUIPanel(GameMenuFrame);
	SimpleMacrosFrame_Toggle();
end

-- With SimpleQoL the menu order is set there. Without it the button is put
-- under the Addons button (or Sound Options) and the rest moves down.
SimpleMacros_MenuExtended = nil;
function SimpleMacros_AdjustMenu()
	if ( SimpleQoL_AdjustGameMenu ) then
		return;
	end
	local above = MainGameMenuButtonAddons or GameMenuButtonSoundOptions;
	SimpleMacrosMenuButton:ClearAllPoints();
	SimpleMacrosMenuButton:SetPoint("TOP", above:GetName(), "BOTTOM", 0, -1);
	GameMenuButtonLogout:ClearAllPoints();
	GameMenuButtonLogout:SetPoint("TOP", "SimpleMacrosMenuButton", "BOTTOM", 0, -1);
	if ( not SimpleMacros_MenuExtended ) then
		SimpleMacros_MenuExtended = 1;
		GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 22);
	end
end

-- /sv lists the versions of all our installed addons. Every addon carries
-- this same copy, so it works with any of them installed.
function SimpleVersions_Show()
	local list = { "SimpleSave", SIMPLESAVE_VERSION, "SimpleQoL", SIMPLEQOL_VERSION, "ActionBars", ACTIONBARS_VERSION,
		"ImprovedErrorFrame", IEF_VERSION, "TradeSkillPlus", TRADESKILLPLUS_VERSION, "SimpleMap", SIMPLEMAP_VERSION,
		"SimpleChat", SIMPLECHAT_VERSION, "SimpleMacros", SIMPLEMACROS_VERSION, "SimpleWalk", SIMPLEWALK_VERSION };
	local i;
	for i = 1, 17, 2 do
		if ( list[i + 1] ) then
			ChatFrame:AddMessage(list[i].." "..list[i + 1], 1.0, 0.82, 0.0);
		end
	end
	-- Only GMs ever see anything of SimpleGM.
	if ( SIMPLEGM_VERSION and SimpleGM_State == 1 ) then
		ChatFrame:AddMessage("SimpleGM "..SIMPLEGM_VERSION, 1.0, 0.82, 0.0);
	end
end
SlashCmdList["SIMPLEVERSIONS"] = SimpleVersions_Show;
SLASH_SIMPLEVERSIONS1 = "/sv";
SLASH_SIMPLEVERSIONS2 = "/simpleversion";
