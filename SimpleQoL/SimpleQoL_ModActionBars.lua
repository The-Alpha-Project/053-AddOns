--------------------------------------------------------------------------------
-- ActionBars for WoW 0.5.3
-- Four extra action bars on the same action slots as vanilla:
--   bar 1: slots 61-72, above the main bar      (vanilla "bottom left")
--   bar 2: slots 49-60, above bar 1             (vanilla "bottom right")
--   bar 3: slots 25-36, vertical, right edge    (vanilla "right")
--   bar 4: slots 37-48, vertical, left of bar 3 (vanilla "right 2")
-- The server stores 120 action slots per character, so the bar contents are
-- saved by the server like the main bar.
--
-- The buttons use the stock ActionBarButtonTemplate. The stock code finds the
-- slot through ActionButton_GetPagedID, which is extended here: a button whose
-- id is above 12 uses its id as the slot (stock buttons have ids 1-12).
--
-- Settings (hidden bars, places, empty slots) are saved with SimpleSave when
-- it is installed. Alt self cast moved to SimpleQoL in 1.6; the Quit fix is
-- always on (shared by all our addons).
--
-- Lua 5.0 rules for this client: no string methods, no # or % operators,
-- no pairs/ipairs/type, ASCII only.
--------------------------------------------------------------------------------

-- Installed on its own and inside SimpleQoL: 0.5.3 keeps the frames of the
-- copy loaded first under their names, so no frame is hidden here (that hid
-- the frames in use). The newest version runs: a copy loaded after an equal
-- or newer version stops here, and the other copy's frames stop themselves.
local function ActionBars_VersionValue(v)
	local s, e, major, minor = strfind(v or "", "^(%d+)%.?(%d*)");
	if ( not major ) then
		return 0;
	end
	return major * 1000 + (tonumber(minor) or 0);
end
if ( ACTIONBARS_VERSION and ActionBars_VersionValue(ACTIONBARS_VERSION) >= ActionBars_VersionValue("1.26") ) then
	return;
end
ACTIONBARS_VERSION = "1.28";
ACTIONBARS_NUM_BARS = 4;
ACTIONBARS_FIRST_SLOT = { 61, 49, 25, 37 };
ACTIONBARS_VERTICAL = { nil, nil, 1, 1 };
ACTIONBARS_BAR_NAMES = { "Bar 1 (slots 61-72)", "Bar 2 (slots 49-60)", "Bar 3 (slots 25-36)", "Bar 4 (slots 37-48)" };
ACTIONBARS_ROW_HEIGHT = 42;          -- button 36 + gap 6

-- Visibility: ActionBars_Mode[bar] is "1" = shown (default) or "0" = hidden.
-- A shown bar only shows the buttons that have an action, unless "Always show
-- empty slots" is on; while you drag a spell or item all slots of shown bars
-- appear (stock behaviour). So nothing has to be saved: empty bars are invisible.
-- Settings below are saved with SimpleSave (addon "ActionBars").
ActionBars_Mode = { "1", "1", "1", "1" };
ActionBars_Shown = {};               -- computed: 1 = bar is shown now
ActionBars_DragGrid = nil;           -- 1 = a spell or item is being dragged
ActionBars_Pos = {};                 -- [bar] = { x, y } center offset from UIParent BOTTOMLEFT, nil = default
ActionBars_Grid = nil;               -- 1 = always show empty slots
ActionBars_CooldownText = 1;         -- 1 = cooldown numbers on the buttons (default on)
ActionBars_MoveMode = nil;           -- 1 = bars can be moved
ActionBars_Loaded = nil;

ActionBars_Dragging = nil;           -- bar index being moved
ActionBars_DragK = 1;                -- cursor units -> SetPoint units while dragging
ActionBars_DragX = 0;
ActionBars_DragY = 0;

-- Key binding names (Interface\Bindings.xml, see ActionBars_Bindings.txt)
BINDING_HEADER20 = "Extra Action Bars";


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function ActionBars_Print(text)
	if ( ChatFrame ) then
		ChatFrame:AddMessage("ActionBars: "..text, 1.0, 0.82, 0.0);
	end
end

function ActionBars_Button(slot)
	return getglobal("ActionBarsButton"..slot);
end

-- Binding display names, e.g. "Bar 1 Button 3"
BINDING_NAME_ACTIONBARS_SLOT61 = "Bar 1 Button 1";
BINDING_NAME_ACTIONBARS_SLOT62 = "Bar 1 Button 2";
BINDING_NAME_ACTIONBARS_SLOT63 = "Bar 1 Button 3";
BINDING_NAME_ACTIONBARS_SLOT64 = "Bar 1 Button 4";
BINDING_NAME_ACTIONBARS_SLOT65 = "Bar 1 Button 5";
BINDING_NAME_ACTIONBARS_SLOT66 = "Bar 1 Button 6";
BINDING_NAME_ACTIONBARS_SLOT67 = "Bar 1 Button 7";
BINDING_NAME_ACTIONBARS_SLOT68 = "Bar 1 Button 8";
BINDING_NAME_ACTIONBARS_SLOT69 = "Bar 1 Button 9";
BINDING_NAME_ACTIONBARS_SLOT70 = "Bar 1 Button 10";
BINDING_NAME_ACTIONBARS_SLOT71 = "Bar 1 Button 11";
BINDING_NAME_ACTIONBARS_SLOT72 = "Bar 1 Button 12";
BINDING_NAME_ACTIONBARS_SLOT49 = "Bar 2 Button 1";
BINDING_NAME_ACTIONBARS_SLOT50 = "Bar 2 Button 2";
BINDING_NAME_ACTIONBARS_SLOT51 = "Bar 2 Button 3";
BINDING_NAME_ACTIONBARS_SLOT52 = "Bar 2 Button 4";
BINDING_NAME_ACTIONBARS_SLOT53 = "Bar 2 Button 5";
BINDING_NAME_ACTIONBARS_SLOT54 = "Bar 2 Button 6";
BINDING_NAME_ACTIONBARS_SLOT55 = "Bar 2 Button 7";
BINDING_NAME_ACTIONBARS_SLOT56 = "Bar 2 Button 8";
BINDING_NAME_ACTIONBARS_SLOT57 = "Bar 2 Button 9";
BINDING_NAME_ACTIONBARS_SLOT58 = "Bar 2 Button 10";
BINDING_NAME_ACTIONBARS_SLOT59 = "Bar 2 Button 11";
BINDING_NAME_ACTIONBARS_SLOT60 = "Bar 2 Button 12";
BINDING_NAME_ACTIONBARS_SLOT25 = "Bar 3 Button 1";
BINDING_NAME_ACTIONBARS_SLOT26 = "Bar 3 Button 2";
BINDING_NAME_ACTIONBARS_SLOT27 = "Bar 3 Button 3";
BINDING_NAME_ACTIONBARS_SLOT28 = "Bar 3 Button 4";
BINDING_NAME_ACTIONBARS_SLOT29 = "Bar 3 Button 5";
BINDING_NAME_ACTIONBARS_SLOT30 = "Bar 3 Button 6";
BINDING_NAME_ACTIONBARS_SLOT31 = "Bar 3 Button 7";
BINDING_NAME_ACTIONBARS_SLOT32 = "Bar 3 Button 8";
BINDING_NAME_ACTIONBARS_SLOT33 = "Bar 3 Button 9";
BINDING_NAME_ACTIONBARS_SLOT34 = "Bar 3 Button 10";
BINDING_NAME_ACTIONBARS_SLOT35 = "Bar 3 Button 11";
BINDING_NAME_ACTIONBARS_SLOT36 = "Bar 3 Button 12";
BINDING_NAME_ACTIONBARS_SLOT37 = "Bar 4 Button 1";
BINDING_NAME_ACTIONBARS_SLOT38 = "Bar 4 Button 2";
BINDING_NAME_ACTIONBARS_SLOT39 = "Bar 4 Button 3";
BINDING_NAME_ACTIONBARS_SLOT40 = "Bar 4 Button 4";
BINDING_NAME_ACTIONBARS_SLOT41 = "Bar 4 Button 5";
BINDING_NAME_ACTIONBARS_SLOT42 = "Bar 4 Button 6";
BINDING_NAME_ACTIONBARS_SLOT43 = "Bar 4 Button 7";
BINDING_NAME_ACTIONBARS_SLOT44 = "Bar 4 Button 8";
BINDING_NAME_ACTIONBARS_SLOT45 = "Bar 4 Button 9";
BINDING_NAME_ACTIONBARS_SLOT46 = "Bar 4 Button 10";
BINDING_NAME_ACTIONBARS_SLOT47 = "Bar 4 Button 11";
BINDING_NAME_ACTIONBARS_SLOT48 = "Bar 4 Button 12";


--------------------------------------------------------------------------------
-- Hooks into the stock action button code
--------------------------------------------------------------------------------

-- Which copy runs: each loaded copy sets ActionBars_Copy to its own table;
-- hooks of an earlier copy then only pass the call on to the game's code.
local ActionBars_ThisCopy = {};
ActionBars_Copy = ActionBars_ThisCopy;

ActionBars_Orig_GetPagedID = ActionBars_Orig_GetPagedID or ActionButton_GetPagedID;
local ActionBars_StockGetPagedID = ActionBars_Orig_GetPagedID;
function ActionButton_GetPagedID(button)
	if ( ActionBars_Copy ~= ActionBars_ThisCopy ) then
		return ActionBars_StockGetPagedID(button);
	end
	if ( button and not button.isBonus and button:GetID() > 12 ) then
		return button:GetID();
	end
	return ActionBars_StockGetPagedID(button);
end

ActionBars_Orig_UpdateHotkeys = ActionBars_Orig_UpdateHotkeys or ActionButton_UpdateHotkeys;
local ActionBars_StockUpdateHotkeys = ActionBars_Orig_UpdateHotkeys;
function ActionButton_UpdateHotkeys()
	if ( ActionBars_Off or ActionBars_Copy ~= ActionBars_ThisCopy ) then
		ActionBars_StockUpdateHotkeys();
		return;
	end
	if ( this and not this.isBonus and this:GetID() > 12 ) then
		local hotkey = getglobal(this:GetName().."HotKey");
		local key = GetBindingKey("ACTIONBARS_SLOT"..this:GetID());
		hotkey:SetText(KeyBindingFrame_GetLocalizedName(key, "KEY_"));
		return;
	end
	-- The stock code asks for the binding of the paged slot ("ACTIONBUTTON"
	-- plus page / stance offset), which has none on page 2+ or in a stance:
	-- the text vanished on some characters. Keys 1-12 belong to the button.
	if ( this and this.GetID and this:GetID() >= 1 and this:GetID() <= 12 ) then
		local hotkey = getglobal(this:GetName().."HotKey");
		if ( hotkey ) then
			hotkey:SetText(KeyBindingFrame_GetLocalizedName(GetBindingKey("ACTIONBUTTON"..this:GetID()), "KEY_"));
			return;
		end
	end
	ActionBars_StockUpdateHotkeys();
end

-- Quit fix, shared by all our 0.5.3 addons and always on: the normal Quit
-- often freezes the client, ForceQuit closes at once (settings are still
-- written). Whichever addon loads first installs it, only once.
if ( not SIMPLE_QUITFIX_DONE ) then
	SIMPLE_QUITFIX_DONE = 1;
	SimpleQuitFix_OrigQuit = Quit;
	Quit = function()
		if ( ForceQuit ) then
			ForceQuit();
		elseif ( SimpleQuitFix_OrigQuit ) then
			SimpleQuitFix_OrigQuit();
		end
	end;
end

-- Online signal, shared by all our 0.5.3 addons: once after login a short
-- "H1" message goes to a hidden password channel, and "B1" on Logout / Quit.
-- SimpleQoL shows these as "Name has come online / gone offline". The
-- channel never shows in the chat. Whichever addon loads first installs it,
-- and each addon calls SimpleHello_Tick() from an OnUpdate it already has.
if ( not SIMPLE_HELLO_DONE ) then
	SIMPLE_HELLO_DONE = 1;
	SIMPLE_HELLO_CHANNEL = "SimpleAddons";
	SIMPLE_HELLO_PASSWORD = "sAdd0nz7q";
	SimpleHello_Sent = nil;
	SimpleHello_Start = nil;
	SimpleHello_JoinTime = 0;
	SimpleHello_Last = 0;

	function SimpleHello_Channel(join)
		local number = GetChannelName and GetChannelName(SIMPLE_HELLO_CHANNEL);
		if ( number and number > 0 ) then
			return number;
		end
		if ( join and JoinChannelByName and GetTime() - SimpleHello_JoinTime > 15 ) then
			SimpleHello_JoinTime = GetTime();
			JoinChannelByName(SIMPLE_HELLO_CHANNEL, SIMPLE_HELLO_PASSWORD);
		end
		return nil;
	end

	function SimpleHello_Tick()
		if ( SimpleHello_Sent ) then
			SimpleHello_Tick = nil;
			return;
		end
		if ( GetTime() - SimpleHello_Last < 1 ) then
			return;
		end
		SimpleHello_Last = GetTime();
		-- A few seconds after entering the world, so the channel can be joined.
		if ( not SimpleHello_Start ) then
			SimpleHello_Start = GetTime();
		end
		if ( GetTime() - SimpleHello_Start < 5 ) then
			return;
		end
		local number = SimpleHello_Channel(1);
		if ( number ) then
			SimpleHello_Sent = 1;
			SendChatMessage("H1", "CHANNEL", nil, number);
			SimpleHello_Tick = nil;
		end
	end

	function SimpleHello_Bye()
		local number = SimpleHello_Channel();
		if ( number ) then
			SendChatMessage("B1", "CHANNEL", nil, number);
		end
	end

	SimpleHello_OrigLogout = Logout;
	Logout = function()
		SimpleHello_Bye();
		SimpleHello_OrigLogout();
	end;
	SimpleHello_OrigForceQuit = ForceQuit;
	ForceQuit = function()
		SimpleHello_Bye();
		SimpleHello_OrigForceQuit();
	end;

	SimpleHello_OrigChatOnEvent = ChatFrame_OnEvent;
	function ChatFrame_OnEvent(event)
		if ( strfind(event, "^CHAT_MSG_CHANNEL") and strfind(strlower((arg4 or "").." "..(arg9 or "")), "simpleaddons", 1, 1) ) then
			return;
		end
		SimpleHello_OrigChatOnEvent(event);
	end
end

-- Tooltip placement, shared by all our 0.5.3 addons: the tooltip opens on the
-- side of its owner that faces the middle of the screen, so it never ends up
-- outside the screen. Whichever addon loads first installs it, only once.
-- Version 2 adds line wrapping; a newer copy replaces an older one.
if ( not SIMPLE_TOOLTIP_DONE or SIMPLE_TOOLTIP_DONE < 2 ) then
	SIMPLE_TOOLTIP_DONE = 2;
	function SimpleTooltip_SetOwner(owner, tooltip)
		if ( not tooltip ) then
			tooltip = GameTooltip;
		end
		local x, y = owner:GetCenter();
		local sx, sy = UIParent:GetCenter();
		-- SetPoint in 0.5.3 needs the frame's name, not the frame itself.
		local ownerName = owner.GetName and owner:GetName();
		if ( not x or not sx or not ownerName ) then
			tooltip:SetOwner(owner, "ANCHOR_RIGHT");
			return;
		end
		tooltip:SetOwner(owner, "ANCHOR_NONE");
		local v = "BOTTOM";
		local ov = "TOP";
		if ( y > sy ) then
			v = "TOP";
			ov = "BOTTOM";
		end
		local h = "LEFT";
		local oh = "RIGHT";
		if ( x > sx ) then
			h = "RIGHT";
			oh = "LEFT";
		end
		tooltip:ClearAllPoints();
		tooltip:SetPoint(v..h, ownerName, ov..oh, 0, 0);
	end
	-- Stock action buttons (all bars) use the same placement.
	if ( ActionButton_SetTooltip ) then
		ActionButton_SetTooltip = function()
			SimpleTooltip_SetOwner(this);
			if ( GameTooltip:SetAction(ActionButton_GetPagedID(this)) ) then
				this.updateTooltip = TOOLTIP_UPDATE_TIME;
			else
				this.updateTooltip = nil;
			end
		end;
	end
	-- Long tooltip lines are split at spaces into lines of about 45 visible
	-- characters, so no tooltip gets wider than the screen. Color codes are
	-- carried over to the next line.
	SIMPLE_TOOLTIP_WIDTH = 45;
	function SimpleTooltip_VisibleLen(text)
		local visible = gsub(text, "|c%x%x%x%x%x%x%x%x", "");
		visible = gsub(visible, "|r", "");
		return strlen(visible);
	end
	function SimpleTooltip_Wrap(text, width)
		local lines = {};
		if ( not width ) then
			width = SIMPLE_TOOLTIP_WIDTH;
		end
		if ( SimpleTooltip_VisibleLen(text) <= width ) then
			tinsert(lines, text);
			return lines;
		end
		local line = "";
		local lineLen = 0;
		local color = nil;
		local pos = 1;
		while ( 1 ) do
			local s, e, word = strfind(text, "(%S+)", pos);
			if ( not s ) then
				break
			end
			pos = e + 1;
			local len = SimpleTooltip_VisibleLen(word);
			if ( lineLen > 0 and lineLen + 1 + len > width ) then
				if ( color ) then
					line = line.."|r";
				end
				tinsert(lines, line);
				line = color or "";
				lineLen = 0;
			end
			if ( lineLen > 0 ) then
				line = line.." ";
				lineLen = lineLen + 1;
			end
			line = line..word;
			lineLen = lineLen + len;
			-- The color in effect after this word.
			local p = 1;
			while ( 1 ) do
				local cs, ce = strfind(word, "|c%x%x%x%x%x%x%x%x", p);
				local rs, re = strfind(word, "|r", p, 1);
				if ( not cs and not rs ) then
					break
				end
				if ( cs and (not rs or cs < rs) ) then
					color = strsub(word, cs, ce);
					p = ce + 1;
				else
					color = nil;
					p = re + 1;
				end
			end
		end
		if ( line ~= "" ) then
			tinsert(lines, line);
		end
		return lines;
	end
	if ( GameTooltip and not SIMPLE_TOOLTIP_WRAP ) then
		SIMPLE_TOOLTIP_WRAP = 1;
		SimpleTooltip_OrigAddLine = GameTooltip.AddLine;
		SimpleTooltip_OrigSetText = GameTooltip.SetText;
		GameTooltip.AddLine = function(self, text, a, r, g, b)
			if ( not text or text == "" ) then
				SimpleTooltip_OrigAddLine(self, text, a, r, g, b);
				return;
			end
			local lines = SimpleTooltip_Wrap(text);
			local i;
			for i = 1, getn(lines) do
				local right = "";
				if ( i == 1 and a ) then
					right = a;
				end
				SimpleTooltip_OrigAddLine(self, lines[i], right, r, g, b);
			end
		end;
		GameTooltip.SetText = function(self, text, r, g, b, a)
			if ( not text or text == "" ) then
				SimpleTooltip_OrigSetText(self, text, r, g, b, a);
				return;
			end
			local lines = SimpleTooltip_Wrap(text);
			SimpleTooltip_OrigSetText(self, lines[1], r, g, b, a);
			local i;
			for i = 2, getn(lines) do
				SimpleTooltip_OrigAddLine(self, lines[i], "", r or 1.0, g or 1.0, b or 1.0);
			end
		end;
	end
end


--------------------------------------------------------------------------------
-- Key bindings (called from Interface\Bindings.xml)
--------------------------------------------------------------------------------

function ActionBars_KeyDown(slot)
	local button = ActionBars_Button(slot);
	if ( button and button:IsVisible() and button:GetButtonState() == "NORMAL" ) then
		button:SetButtonState("PUSHED");
	end
end

function ActionBars_KeyUp(slot)
	local button = ActionBars_Button(slot);
	if ( button and button:GetButtonState() == "PUSHED" ) then
		button:SetButtonState("NORMAL");
	end
	UseAction(slot, 0);
	if ( button ) then
		if ( IsCurrentAction(slot) ) then
			button:SetChecked(1);
		else
			button:SetChecked(0);
		end
	end
end


--------------------------------------------------------------------------------
-- Saving with SimpleSave (addon "ActionBars", values "Cfg" and "Pos").
-- Settings from the old Config.wtf lines (ActionBars 1.5) are taken over once.
--------------------------------------------------------------------------------

-- Reads an old CVar; unknown CVars raise an error, so only through pcall.
function ActionBars_GetCVar(name)
	if ( not pcall or not GetCVar ) then
		return nil;
	end
	local ok, value = pcall(GetCVar, name);
	if ( ok ) then
		return value;
	end
	return nil;
end

function ActionBars_HasSave()
	return SimpleSave_Set;
end

function ActionBars_Load()
	local cfg, pos;
	if ( ActionBars_HasSave() ) then
		cfg = SimpleSave_Get("ActionBars", "Cfg");
		pos = SimpleSave_Get("ActionBars", "Pos");
	end
	local imported = nil;
	if ( not cfg ) then
		cfg = ActionBars_GetCVar("ActionBarsCfg");
		pos = ActionBars_GetCVar("ActionBarsPos");
		if ( cfg ) then
			imported = 1;
		end
	end
	if ( cfg ) then
		-- "1101,0" (1.6) or "1101,0,1,1" (1.5): bars, empty slots
		local _, _, bars, grid = strfind(cfg, "^([01a]+),([01])");
		if ( bars ) then
			local bar;
			for bar = 1, ACTIONBARS_NUM_BARS do
				if ( strsub(bars, bar, bar) == "0" ) then
					ActionBars_Mode[bar] = "0";
				else
					ActionBars_Mode[bar] = "1";
				end
			end
			ActionBars_Grid = ActionBars_Flag(grid);
		end
	end
	if ( pos ) then
		-- "x,y;-;x,y;-": one part per bar, "-" = default place
		local bar = 0;
		local start = 1;
		while ( bar < ACTIONBARS_NUM_BARS ) do
			bar = bar + 1;
			local stop = strfind(pos, ";", start, 1);
			local part;
			if ( stop ) then
				part = strsub(pos, start, stop - 1);
				start = stop + 1;
			else
				part = strsub(pos, start);
				start = strlen(pos) + 1;
			end
			local _, _, x, y = strfind(part, "^(%-?%d+),(%-?%d+)$");
			if ( x ) then
				ActionBars_Pos[bar] = { x + 0, y + 0 };
			else
				ActionBars_Pos[bar] = nil;
			end
		end
	end
	if ( ActionBars_HasSave() ) then
		ActionBars_ParseExtra(SimpleSave_Get("ActionBars", "Extra"));
		if ( SimpleSave_Get("ActionBars", "CD") == "0" ) then
			ActionBars_CooldownText = nil;
		end
	end
	if ( imported ) then
		ActionBars_Save();
	end
end

function ActionBars_Flag(text)
	if ( text == "1" ) then
		return 1;
	end
	return nil;
end

function ActionBars_FlagText(value)
	if ( value ) then
		return "1";
	end
	return "0";
end

function ActionBars_CfgText()
	local bars = "";
	local bar;
	for bar = 1, ACTIONBARS_NUM_BARS do
		bars = bars..ActionBars_Mode[bar];
	end
	return bars..","..ActionBars_FlagText(ActionBars_Grid);
end

function ActionBars_PosText()
	local pos = "";
	local bar;
	for bar = 1, ACTIONBARS_NUM_BARS do
		if ( bar > 1 ) then
			pos = pos..";";
		end
		if ( ActionBars_Pos[bar] ) then
			pos = pos..ActionBars_Pos[bar][1]..","..ActionBars_Pos[bar][2];
		else
			pos = pos.."-";
		end
	end
	return pos;
end

function ActionBars_Save()
	if ( ActionBars_HasSave() ) then
		SimpleSave_Set("ActionBars", "Cfg", ActionBars_CfgText());
		SimpleSave_Set("ActionBars", "Pos", ActionBars_PosText());
		SimpleSave_Set("ActionBars", "Extra", ActionBars_ExtraText());
		SimpleSave_Set("ActionBars", "CD", ActionBars_FlagText(ActionBars_CooldownText));
	end
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

function ActionBars_HasActions(bar)
	local i;
	for i = 0, 11 do
		if ( HasAction(ACTIONBARS_FIRST_SLOT[bar] + i) ) then
			return 1;
		end
	end
	return nil;
end

-- Shown and actually showing something (an action, or empty slots).
function ActionBars_Visible(bar)
	return ActionBars_Shown[bar] and ( ActionBars_Grid or ActionBars_MoveMode or ActionBars_HasActions(bar) );
end

function ActionBars_ComputeShown()
	local bar;
	for bar = 1, ACTIONBARS_NUM_BARS do
		if ( ActionBars_Mode[bar] == "0" ) then
			ActionBars_Shown[bar] = nil;
		else
			ActionBars_Shown[bar] = 1;
		end
	end
end

function ActionBars_ApplyLayout()
	local bar;
	ActionBars_ComputeShown();
	for bar = 1, ACTIONBARS_NUM_BARS do
		local frame = getglobal("ActionBarsBar"..bar);
		frame:ClearAllPoints();
		if ( ActionBars_Pos[bar] ) then
			frame:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", ActionBars_Pos[bar][1], ActionBars_Pos[bar][2]);
		elseif ( bar == 1 ) then
			frame:SetPoint("BOTTOMLEFT", "ActionButton1", "TOPLEFT", 0, 17);
		elseif ( bar == 2 ) then
			if ( ActionBars_Visible(1) and not ActionBars_Pos[1] ) then
				frame:SetPoint("BOTTOMLEFT", "ActionBarsBar1", "TOPLEFT", 0, 6);
			else
				frame:SetPoint("BOTTOMLEFT", "ActionButton1", "TOPLEFT", 0, 17);
			end
		elseif ( bar == 3 ) then
			frame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -6, 98);
		else
			if ( ActionBars_Visible(3) and not ActionBars_Pos[3] ) then
				frame:SetPoint("TOPRIGHT", "ActionBarsBar3", "TOPLEFT", -6, 0);
			else
				frame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -6, 98);
			end
		end
		if ( ActionBars_Shown[bar] ) then
			frame:Show();
		else
			frame:Hide();
		end
	end
	ActionBars_UpdateMovers();
	ActionBars_UpdateGrid();
	ActionBars_UpdateOtherBars();
end

--------------------------------------------------------------------------------
-- Pet bar and stance bar. While bar 1 or bar 2 is visible they become small
-- bars without their art (buttons close together) above the extra bars, and
-- can be moved with Shift + drag on the small handle at their left end (or
-- with /ab move). Otherwise they look and sit exactly as normal.
--------------------------------------------------------------------------------

ACTIONBARS_SMALL_GAP = 2;
ACTIONBARS_PET_GAP = 8;              -- stock gaps
ACTIONBARS_STANCE_GAP = 7;
ActionBars_Compact = nil;
ActionBars_WasCompact = nil;
ActionBars_ExtraPos = {};            -- ["pet"] / ["stance"] = { x, y } center, SetPoint units
ActionBars_ExtraDrag = nil;
ActionBars_Placing = nil;
ActionBars_HandleTime = 0;

function ActionBars_WantCompact()
	return ActionBars_Visible(1) or ActionBars_Visible(2);
end

-- While compact, other code (AlphaUI) may not move these back.
function ActionBars_Guard(object)
	if ( not object or object.abGuarded ) then
		return;
	end
	object.abGuarded = 1;
	local origSetPoint = object.SetPoint;
	local origClear = object.ClearAllPoints;
	object.SetPoint = function(self, a, b, c, d, e)
		if ( ActionBars_Compact and not ActionBars_Placing ) then
			return;
		end
		origSetPoint(self, a, b, c, d, e);
	end
	object.ClearAllPoints = function(self)
		if ( ActionBars_Compact and not ActionBars_Placing ) then
			return;
		end
		origClear(self);
	end
end

function ActionBars_LayoutPet(compact)
	if ( not PetActionButton1 ) then
		return;
	end
	ActionBars_Guard(PetActionButton1);
	ActionBars_Guard(SlidingActionBarTexture0);
	ActionBars_Placing = 1;
	local gap = ACTIONBARS_PET_GAP;
	if ( compact ) then
		gap = ACTIONBARS_SMALL_GAP;
		PetActionButton1:ClearAllPoints();
		PetActionButton1:SetPoint("LEFT", "ActionBarsPetAnchor", "LEFT", 14, 0);
		-- The second art texture has no name; it is anchored to the first,
		-- so moving the first far off screen takes both away.
		SlidingActionBarTexture0:ClearAllPoints();
		SlidingActionBarTexture0:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", -4000, 4000);
		SlidingActionBarTexture0:Hide();
	elseif ( ActionBars_WasCompact ) then
		PetActionButton1:ClearAllPoints();
		PetActionButton1:SetPoint("BOTTOMLEFT", "PetActionBarFrame", "BOTTOMLEFT", 36, 1);
		SlidingActionBarTexture0:ClearAllPoints();
		SlidingActionBarTexture0:SetPoint("TOPLEFT", "PetActionBarFrame", "TOPLEFT", 0, 0);
		SlidingActionBarTexture0:Show();
	end
	if ( compact or ActionBars_WasCompact ) then
		local i;
		for i = 2, (NUM_PET_ACTION_SLOTS or 10) do
			local button = getglobal("PetActionButton"..i);
			button:ClearAllPoints();
			button:SetPoint("LEFT", "PetActionButton"..(i - 1), "RIGHT", gap, 0);
		end
	end
	ActionBars_Placing = nil;
end

function ActionBars_LayoutStance(compact)
	if ( not ShapeshiftButton1 ) then
		return;
	end
	ActionBars_Guard(ShapeshiftButton1);
	ActionBars_Placing = 1;
	local gap = ACTIONBARS_STANCE_GAP;
	if ( compact ) then
		gap = ACTIONBARS_SMALL_GAP;
		ShapeshiftButton1:ClearAllPoints();
		ShapeshiftButton1:SetPoint("LEFT", "ActionBarsStanceAnchor", "LEFT", 14, 0);
	elseif ( ActionBars_WasCompact ) then
		ShapeshiftButton1:ClearAllPoints();
		ShapeshiftButton1:SetPoint("BOTTOMLEFT", "ShapeshiftBarFrame", "BOTTOMLEFT", 11, 3);
	end
	if ( compact or ActionBars_WasCompact ) then
		local i;
		for i = 2, (NUM_SHAPESHIFT_SLOTS or 4) do
			local button = getglobal("ShapeshiftButton"..i);
			if ( button ) then
				button:ClearAllPoints();
				button:SetPoint("LEFT", "ShapeshiftButton"..(i - 1), "RIGHT", gap, 0);
			end
		end
	end
	ActionBars_Placing = nil;
	ActionBars_StanceArt();
end

-- The stock stance code shows its art again on every update.
function ActionBars_StanceArt()
	if ( not ShapeshiftBarLeft ) then
		return;
	end
	if ( ActionBars_Compact ) then
		ShapeshiftBarLeft:Hide();
		ShapeshiftBarMiddle:Hide();
		ShapeshiftBarRight:Hide();
	elseif ( ActionBars_WasCompact ) then
		ShapeshiftBarLeft:Show();
		ShapeshiftBarRight:Show();
		if ( ShapeshiftBar_Update ) then
			ActionBars_InStanceUpdate = 1;
			ShapeshiftBar_Update();
			ActionBars_InStanceUpdate = nil;
		end
	end
end

ActionBars_Orig_ShapeshiftBar_Update = ActionBars_Orig_ShapeshiftBar_Update or ShapeshiftBar_Update;
local ActionBars_StockShapeshiftBar_Update = ActionBars_Orig_ShapeshiftBar_Update;
function ShapeshiftBar_Update()
	if ( ActionBars_StockShapeshiftBar_Update ) then
		ActionBars_StockShapeshiftBar_Update();
	end
	if ( ActionBars_Copy ~= ActionBars_ThisCopy ) then
		return;
	end
	if ( ActionBars_Compact and not ActionBars_InStanceUpdate ) then
		ActionBars_StanceArt();
	end
end

-- Default places: the stance bar right above the extra bar that really is
-- highest down at the main bar (also when it was moved a little), the pet
-- bar to its right; a saved place wins. Bars moved far up the screen do not
-- count (like the cast bar).
function ActionBars_TopBar()
	local top = "ActionButton1";
	local topY = 17;
	local best = nil;
	local k = ActionBars_Scale();
	local sx, sy = ActionBarsProbeScreen:GetCenter();
	local bar;
	for bar = 1, 2 do
		if ( ActionBars_Visible(bar) ) then
			local value = nil;
			if ( sy ) then
				value = ActionBars_FrameTop(getglobal("ActionBarsBar"..bar), 18, k, sy);
			end
			if ( not ActionBars_Pos[bar] and not value ) then
				value = bar;      -- not measurable yet: the stock order
			end
			if ( value and value < 400 and (not best or value > best) ) then
				best = value;
				top = "ActionBarsBar"..bar;
				topY = 6;
			end
		end
	end
	return top, topY, best;
end

-- Stance / pet bars you moved yourself go back to their default place when
-- an extra bar above the main bar fills or empties.
function ActionBars_FollowTopBar()
	-- Counts the extra bars shown down at the main bar.
	local top, topY, value = ActionBars_TopBar();
	local steps = 0;
	local bar;
	for bar = 1, 2 do
		if ( ActionBars_Visible(bar) ) then
			local frame = getglobal("ActionBarsBar"..bar);
			local k = ActionBars_Scale();
			local sx, sy = ActionBarsProbeScreen:GetCenter();
			local height = sy and ActionBars_FrameTop(frame, 18, k, sy);
			if ( not height or height < 400 ) then
				steps = steps + 1;
			end
		end
	end
	local last = ActionBars_LastSteps;
	ActionBars_LastSteps = steps;
	if ( not last or steps == last ) then
		return;
	end
	-- A bar above the main bar filled or emptied: the stance and pet bars go
	-- back to their default place, tight above the top bar. Moving them by
	-- hand afterwards is kept until that happens again.
	if ( ActionBars_ExtraPos["pet"] or ActionBars_ExtraPos["stance"] ) then
		ActionBars_ExtraPos["pet"] = nil;
		ActionBars_ExtraPos["stance"] = nil;
		ActionBars_PlaceExtra();
		ActionBars_Save();
	end
end

function ActionBars_PlaceExtra()
	local top, topY = ActionBars_TopBar();
	ActionBars_ExtraTop = top;
	ActionBarsStanceAnchor:ClearAllPoints();
	if ( ActionBars_ExtraPos["stance"] ) then
		ActionBarsStanceAnchor:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", ActionBars_ExtraPos["stance"][1], ActionBars_ExtraPos["stance"][2]);
	else
		ActionBarsStanceAnchor:SetPoint("BOTTOMLEFT", top, "TOPLEFT", -14, topY);
	end
	ActionBarsPetAnchor:ClearAllPoints();
	if ( ActionBars_ExtraPos["pet"] ) then
		ActionBarsPetAnchor:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", ActionBars_ExtraPos["pet"][1], ActionBars_ExtraPos["pet"][2]);
	elseif ( ShapeshiftBarFrame and ShapeshiftBarFrame:IsVisible() ) then
		ActionBarsPetAnchor:SetPoint("LEFT", "ActionBarsStanceAnchor", "RIGHT", 8, 0);
	else
		ActionBarsPetAnchor:SetPoint("BOTTOMLEFT", top, "TOPLEFT", -14, topY);
	end
end

function ActionBars_UpdateOtherBars()
	if ( not ActionBars_BasePetY ) then
		ActionBars_BasePetY = PETACTIONBAR_YPOS;
	end
	local compact = ActionBars_WantCompact();
	ActionBars_Compact = compact;
	if ( compact ) then
		ActionBarsPetAnchor:Show();
		ActionBarsStanceAnchor:Show();
		ActionBars_PlaceExtra();
	else
		ActionBarsPetAnchor:Hide();
		ActionBarsStanceAnchor:Hide();
	end
	-- Compact: the (now empty) pet bar frame goes below the screen so its
	-- invisible area does not block clicks; its buttons sit on our anchor.
	if ( ActionBars_BasePetY ) then
		if ( compact ) then
			PETACTIONBAR_YPOS = -120;
		else
			PETACTIONBAR_YPOS = ActionBars_BasePetY;
		end
		if ( PetActionBarFrame and PetActionBarFrame.state == "top" ) then
			PetActionBarFrame.yTarget = PETACTIONBAR_YPOS;
			PetActionBarFrame:SetPoint("TOPLEFT", "MainMenuBar", "BOTTOMLEFT", PETACTIONBAR_XPOS, PETACTIONBAR_YPOS);
		end
	end
	ActionBars_LayoutPet(compact);
	ActionBars_LayoutStance(compact);
	ActionBars_WasCompact = compact;
	ActionBars_UpdateHandles();
	if ( compact ) then
		ActionBars_PlaceCastBar();
	else
		ActionBars_RestoreCastBar();
	end
end

-- A handle shows only while its bar is shown.
function ActionBars_UpdateHandles()
	local petShown = ActionBars_Compact and PetActionBarFrame and PetActionBarFrame:IsVisible();
	local stanceShown = ActionBars_Compact and ShapeshiftBarFrame and ShapeshiftBarFrame:IsVisible();
	if ( petShown ) then
		ActionBarsPetAnchorHandle:Show();
	else
		ActionBarsPetAnchorHandle:Hide();
	end
	if ( stanceShown ) then
		ActionBarsStanceAnchorHandle:Show();
	else
		ActionBarsStanceAnchorHandle:Hide();
	end
end

-- Cursor units -> SetPoint units (0.5.3 reports positions in another scale).
function ActionBars_Scale()
	local x1 = ActionBarsProbeBoxTopLeft:GetCenter();
	local x2 = ActionBarsProbeBoxBottomRight:GetCenter();
	if ( not x1 or not x2 or x2 - x1 < 10 ) then
		return 1;
	end
	return 98 / (x2 - x1);
end

function ActionBars_Handle_OnMouseDown(which)
	if ( not IsShiftKeyDown() and not ActionBars_MoveMode ) then
		return;
	end
	local anchor = getglobal("ActionBars"..which.."Anchor");
	local k = ActionBars_Scale();
	local cx, cy = GetCursorPosition();
	local ax, ay = anchor:GetCenter();
	local sx, sy = ActionBarsProbeScreen:GetCenter();
	if ( not ax or not sx ) then
		return;
	end
	-- The screen probe's center sits 1 unit inside the corner.
	ActionBars_ExtraDrag = { which, cx, cy, (ax - sx) * k + 1, (ay - sy) * k + 1, k };
end

function ActionBars_Handle_OnMouseUp()
	if ( ActionBars_ExtraDrag ) then
		ActionBars_ExtraDrag = nil;
		ActionBars_Save();
	end
end

function ActionBars_ExtraDragUpdate()
	local drag = ActionBars_ExtraDrag;
	local cx, cy = GetCursorPosition();
	local key = "pet";
	if ( drag[1] == "Stance" ) then
		key = "stance";
	end
	ActionBars_ExtraPos[key] = { floor(drag[4] + (cx - drag[2]) * drag[6] + 0.5), floor(drag[5] + (cy - drag[3]) * drag[6] + 0.5) };
	ActionBars_PlaceExtra();
	ActionBars_PlaceCastBar();
end

function ActionBars_Handle_OnEnter(which)
	SimpleTooltip_SetOwner(this);
	if ( which == "Pet" ) then
		GameTooltip:SetText("Pet bar");
	else
		GameTooltip:SetText("Stance bar");
	end
	GameTooltip:AddLine("|cffffffffShift + drag to move.|r");
	GameTooltip:Show();
end

function ActionBars_Handle_OnLeave()
	GameTooltip:Hide();
end

-- Mouse position in SetPoint units from the screen's bottom left.
function ActionBars_CursorPos()
	local k = ActionBars_Scale();
	local sx, sy = ActionBarsProbeScreen:GetCenter();
	local cx, cy = GetCursorPosition();
	if ( not sx or not cx ) then
		return nil;
	end
	return (cx - sx) * k + 1, (cy - sy) * k + 1, k, sx, sy;
end

-- 1 if the mouse is over a compact bar's area (with a small margin).
function ActionBars_MouseOver(anchor, width)
	local x, y, k, sx, sy = ActionBars_CursorPos();
	local ax, ay = anchor:GetCenter();
	if ( not x or not ax ) then
		return nil;
	end
	ax = (ax - sx) * k + 1;
	ay = (ay - sy) * k + 1;
	return x >= ax - width / 2 - 4 and x <= ax + width / 2 + 4 and y >= ay - 20 and y <= ay + 20;
end

-- The Shift+drag handles are invisible until the mouse is over their bar.
function ActionBars_UpdateHandleAlpha()
	local pet = ActionBarsPetAnchorHandle:IsVisible() and ( (ActionBars_ExtraDrag and ActionBars_ExtraDrag[1] == "Pet") or ActionBars_MouseOver(ActionBarsPetAnchor, 14 + 10 * 32) );
	local stance = ActionBarsStanceAnchorHandle:IsVisible() and ( (ActionBars_ExtraDrag and ActionBars_ExtraDrag[1] == "Stance") or ActionBars_MouseOver(ActionBarsStanceAnchor, 14 + 4 * 32) );
	-- Only set when it changes.
	pet = pet and 1 or 0;
	stance = stance and 1 or 0;
	if ( pet ~= ActionBars_PetHandleShown ) then
		ActionBars_PetHandleShown = pet;
		ActionBarsPetAnchorHandle:SetAlpha(0.6 * pet);
	end
	if ( stance ~= ActionBars_StanceHandleShown ) then
		ActionBars_StanceHandleShown = stance;
		ActionBarsStanceAnchorHandle:SetAlpha(0.6 * stance);
	end
end


--------------------------------------------------------------------------------
-- Cast bar: while the pet and stance bars are compact, it sits centered just
-- above the highest of them and the bottom extra bars, so it is never hidden
-- behind them. Otherwise it is where the game puts it.
--------------------------------------------------------------------------------

function ActionBars_FrameTop(frame, halfHeight, k, sy)
	if ( not frame or not frame:IsVisible() ) then
		return nil;
	end
	local cx, cy = frame:GetCenter();
	if ( not cy ) then
		return nil;
	end
	return (cy - sy) * k + 1 + halfHeight;
end

function ActionBars_PlaceCastBar()
	if ( not CastingBarFrame ) then
		return;
	end
	ActionBars_Guard(CastingBarFrame);
	if ( not ActionBars_Compact ) then
		return;
	end
	local k = ActionBars_Scale();
	local sx, sy = ActionBarsProbeScreen:GetCenter();
	if ( not sy ) then
		return;
	end
	local top = nil;
	local list = {
		{ ActionBarsPetAnchorHandle, ActionBarsPetAnchor, 16 },
		{ ActionBarsStanceAnchorHandle, ActionBarsStanceAnchor, 16 },
		{ ActionBarsBar1, ActionBarsBar1, 18 },
		{ ActionBarsBar2, ActionBarsBar2, 18 },
	};
	local i;
	for i = 1, getn(list) do
		-- The handle is shown only while that bar is shown.
		if ( list[i][1]:IsVisible() and (list[i][1] ~= ActionBarsBar1 or ActionBars_Visible(1)) and (list[i][1] ~= ActionBarsBar2 or ActionBars_Visible(2)) ) then
			local value = ActionBars_FrameTop(list[i][2], list[i][3], k, sy);
			-- Bars moved far up the screen do not count.
			if ( value and value < 400 and (not top or value > top) ) then
				top = value;
			end
		end
	end
	if ( not top ) then
		return;
	end
	top = floor(top + 12);
	if ( ActionBars_CastBarY == top ) then
		return;
	end
	ActionBars_CastBarY = top;
	ActionBars_Placing = 1;
	CastingBarFrame:ClearAllPoints();
	CastingBarFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", 0, top);
	ActionBars_Placing = nil;
	if ( CastingBarFrame.SetFrameStrata and not ActionBars_CastStrata ) then
		ActionBars_CastStrata = 1;
		CastingBarFrame:SetFrameStrata("DIALOG");
		if ( CastingBarFrame.SetFrameLevel and CastingBarFrame.GetFrameLevel ) then
			CastingBarFrame:SetFrameLevel(CastingBarFrame:GetFrameLevel() + 10);
		end
	end
end

-- Back to the game's own place for the cast bar.
function ActionBars_RestoreCastBar()
	if ( not CastingBarFrame or not ActionBars_CastBarY ) then
		return;
	end
	ActionBars_CastBarY = nil;
	local y = 60;
	if ( PetActionBarFrame and PetActionBarFrame:IsVisible() ) then
		y = 100;
	elseif ( ShapeshiftBarFrame and ShapeshiftBarFrame:IsVisible() ) then
		y = 83;
	end
	CastingBarFrame:ClearAllPoints();
	CastingBarFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", 0, y);
end

-- "x,y;x,y" (pet;stance), "-" = default place
function ActionBars_ExtraText()
	local text = "";
	local keys = { "pet", "stance" };
	local i;
	for i = 1, 2 do
		if ( i > 1 ) then
			text = text..";";
		end
		local pos = ActionBars_ExtraPos[keys[i]];
		if ( pos ) then
			text = text..pos[1]..","..pos[2];
		else
			text = text.."-";
		end
	end
	return text;
end

function ActionBars_ParseExtra(text)
	ActionBars_ExtraPos = {};
	if ( not text ) then
		return;
	end
	local s, e, px, py, sx, sy;
	s, e, px, py = strfind(text, "^(%-?%d+),(%-?%d+);");
	if ( px ) then
		ActionBars_ExtraPos["pet"] = { px + 0, py + 0 };
	end
	s, e, sx, sy = strfind(text, ";(%-?%d+),(%-?%d+)$");
	if ( sx ) then
		ActionBars_ExtraPos["stance"] = { sx + 0, sy + 0 };
	end
end


--------------------------------------------------------------------------------
-- Empty slots (grid)
--------------------------------------------------------------------------------

function ActionBars_UpdateGrid()
	local bar, i;
	for bar = 1, ACTIONBARS_NUM_BARS do
		local show = ActionBars_Grid or ActionBars_MoveMode;
		for i = 1, 12 do
			local slot = ACTIONBARS_FIRST_SLOT[bar] + i - 1;
			local button = ActionBars_Button(slot);
			if ( show and not button.abGrid ) then
				button.abGrid = 1;
				button.showgrid = button.showgrid + 1;
				getglobal(button:GetName().."NormalTexture"):SetVertexColor(1.0, 1.0, 1.0);
				button:Show();
			elseif ( not show and button.abGrid ) then
				button.abGrid = nil;
				button.showgrid = button.showgrid - 1;
				if ( button.showgrid <= 0 and not HasAction(slot) ) then
					button.showgrid = 0;
					button:Hide();
				end
			end
		end
	end
end


--------------------------------------------------------------------------------
-- Moving bars: /ab move shows a green handle on every shown bar.
-- Drag the handle with the left mouse button.
--------------------------------------------------------------------------------

function ActionBars_UpdateMovers()
	local bar;
	for bar = 1, ACTIONBARS_NUM_BARS do
		local mover = getglobal("ActionBarsBar"..bar.."Mover");
		if ( ActionBars_MoveMode ) then
			getglobal("ActionBarsBar"..bar.."MoverLabel"):SetText(ACTIONBARS_BAR_NAMES[bar]);
			mover:Show();
		else
			mover:Hide();
		end
	end
end

function ActionBars_Mover_OnMouseDown(bar)
	local frame = getglobal("ActionBarsBar"..bar);
	local x, y = GetCursorPosition();
	local cx, cy = frame:GetCenter();
	ActionBars_DragX = x - cx;
	ActionBars_DragY = y - cy;
	ActionBars_DragK = ActionBars_Scale();
	ActionBars_Dragging = bar;
end

function ActionBars_Mover_OnMouseUp(bar)
	if ( ActionBars_Dragging ) then
		local frame = getglobal("ActionBarsBar"..ActionBars_Dragging);
		local cx, cy = frame:GetCenter();
		local k = ActionBars_DragK or 1;
		ActionBars_Pos[ActionBars_Dragging] = { floor(cx * k + 0.5), floor(cy * k + 0.5) };
		ActionBars_Dragging = nil;
		ActionBars_Save();
		ActionBars_UpdateOtherBars();
	end
end

-- Cooldown text on the action buttons: minutes ("2m", "1m") while a minute
-- or more is left, then seconds. The global cooldown (1.5 s) shows nothing.
ACTIONBARS_NUM_CD = 72;            -- main bar, our four bars, stance (bonus) bar
ActionBars_CDTime = 0;

function ActionBars_CDButton(i)
	if ( i <= 12 ) then
		return getglobal("ActionButton"..i);
	end
	if ( i > 60 ) then
		return getglobal("BonusActionButton"..(i - 60));
	end
	local bar = floor((i - 13) / 12);
	local first = { 61, 49, 25, 37 };
	return getglobal("ActionBarsButton"..(first[bar + 1] + mod(i - 13, 12)));
end

function ActionBars_CooldownString(remaining)
	if ( remaining >= 60 ) then
		return ceil(remaining / 60).."m";
	end
	return ceil(remaining);
end

-- The buttons and their number overlays, looked up once (no new strings
-- every update, so less garbage to collect).
ActionBars_CDFrames = nil;
function ActionBars_CDList()
	if ( not ActionBars_CDFrames ) then
		ActionBars_CDFrames = {};
		local i;
		for i = 1, ACTIONBARS_NUM_CD do
			local overlay = getglobal("ActionBarsCD"..i);
			tinsert(ActionBars_CDFrames, { ActionBars_CDButton(i) or 0, overlay or 0, getglobal("ActionBarsCD"..i.."Text") or 0 });
		end
	end
	return ActionBars_CDFrames;
end

function ActionBars_UpdateCooldownText()
	local now = GetTime();
	if ( now - ActionBars_CDTime < 0.2 ) then
		return;
	end
	ActionBars_CDTime = now;
	-- Other addons (AlphaUI) may raise the buttons later: the numbers are
	-- kept above their button (checked once a second).
	local levels = now - (ActionBars_CDLevelTime or 0) > 1;
	if ( levels ) then
		ActionBars_CDLevelTime = now;
	end
	local list = ActionBars_CDList();
	local i;
	for i = 1, getn(list) do
		local entry = list[i];
		local button, overlay, text = entry[1], entry[2], entry[3];
		local shown = nil;
		if ( button ~= 0 and button:IsVisible() ) then
			if ( levels and overlay ~= 0 and overlay.SetFrameLevel and overlay:GetFrameLevel() <= button:GetFrameLevel() ) then
				overlay:SetFrameLevel(button:GetFrameLevel() + 3);
			end
			if ( ActionBars_CooldownText and text ~= 0 ) then
				local start, duration, enable = GetActionCooldown(ActionButton_GetPagedID(button));
				if ( start and duration and start > 0 and duration > 1.6 and enable and enable > 0 ) then
					local remaining = start + duration - now;
					if ( remaining > 0 ) then
						local value = ActionBars_CooldownString(remaining);
						if ( entry[4] ~= value ) then
							entry[4] = value;
							text:SetText(value);
						end
						shown = 1;
					end
				end
			end
		end
		if ( not shown and entry[4] ) then
			entry[4] = nil;
			text:SetText(nil);
		end
	end
end

-- The event frame of an earlier copy (loaded twice) stops itself.
function ActionBars_IsOldFrame()
	if ( this == ActionBarsEventFrame or not this or not this.GetName or this:GetName() ~= "ActionBarsEventFrame" ) then
		return nil;
	end
	this:UnregisterEvent("PLAYER_ENTERING_WORLD");
	this:UnregisterEvent("ACTIONBAR_SLOT_CHANGED");
	this:UnregisterEvent("ACTIONBAR_SHOWGRID");
	this:UnregisterEvent("ACTIONBAR_HIDEGRID");
	this:Hide();
	return 1;
end

function ActionBars_OnUpdate()
	if ( ActionBars_IsOldFrame() ) then
		return;
	end
	if ( SimpleHello_Tick ) then
		SimpleHello_Tick();
	end
	if ( ActionBars_Off ) then
		return;
	end
	ActionBars_UpdateCooldownText();
	if ( ActionBars_ExtraDrag ) then
		ActionBars_ExtraDragUpdate();
	end
	if ( ActionBars_Loaded and GetTime() - ActionBars_HandleTime > 1 ) then
		ActionBars_HandleTime = GetTime();
		ActionBars_UpdateHandles();
		if ( ActionBars_Compact ) then
			-- A bar that changed place: the stance and pet bars follow.
			if ( ActionBars_TopBar() ~= ActionBars_ExtraTop ) then
				ActionBars_PlaceExtra();
			end
			ActionBars_FollowTopBar();
			ActionBars_PlaceCastBar();
		end
	end
	-- The handles follow the mouse ten times a second (all the time while dragged).
	if ( ActionBars_Compact and (ActionBars_ExtraDrag or GetTime() - (ActionBars_HandleAlphaTime or 0) > 0.2) ) then
		ActionBars_HandleAlphaTime = GetTime();
		ActionBars_UpdateHandleAlpha();
	end
	if ( ActionBars_Dragging ) then
		local frame = getglobal("ActionBarsBar"..ActionBars_Dragging);
		local x, y = GetCursorPosition();
		frame:ClearAllPoints();
		local k = ActionBars_DragK or 1;
		frame:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", (x - ActionBars_DragX) * k, (y - ActionBars_DragY) * k);
	end
end


--------------------------------------------------------------------------------
-- Events (ActionBarsEventFrame)
--------------------------------------------------------------------------------

-- 1 if Interface\Bindings.xml knows the command (GetBinding lists the
-- commands of the Key Bindings window; hidden ones are not listed).
function SimpleBindings_Has(command)
	if ( not GetNumBindings or not GetBinding ) then
		return 1;
	end
	local i;
	for i = 1, GetNumBindings() do
		if ( GetBinding(i) == command ) then
			return 1;
		end
	end
	return nil;
end

SIMPLE_BINDINGS_WARNING = "|cffff4040Interface\\Bindings.xml from the zip is missing:|r key bindings for the extra bars and saving with SimpleSave will not work. Copy the Interface folder from the zip into the game folder and restart.";

function ActionBars_CheckBindings()
	ActionBars_BindingsMissing = not SimpleBindings_Has("ACTIONBARS_SLOT61");
	-- Shown once, even when several of our addons notice it.
	if ( ActionBars_BindingsMissing and not SIMPLE_BINDINGS_WARNED ) then
		SIMPLE_BINDINGS_WARNED = 1;
		ActionBars_Print(SIMPLE_BINDINGS_WARNING);
	end
end

-- SimpleQoL can turn this addon off (/qol, Modules). Only while SimpleQoL is
-- installed, so a lone ActionBars can never stay off by an old setting.
function ActionBars_ModuleOff()
	return SIMPLEQOL_VERSION and SimpleSave_Get and SimpleSave_Get("SimpleQoL", "actionbars") == "0";
end

function ActionBars_OnSaveLoaded()
	if ( ActionBars_ModuleOff() ) then
		ActionBars_Off = 1;
		return;
	end
	if ( not ActionBars_Greeted ) then
		ActionBars_Greeted = 1;
		ActionBars_Print("Type /ab for settings");
	end
	ActionBars_Load();
	ActionBars_Loaded = 1;
	ActionBars_ApplyLayout();
end

function ActionBars_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
	this:RegisterEvent("ACTIONBAR_SHOWGRID");
	this:RegisterEvent("ACTIONBAR_HIDEGRID");
end

function ActionBars_OnEvent(event)
	if ( ActionBars_IsOldFrame() ) then
		return;
	end
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not ActionBars_Started ) then
			ActionBars_Started = 1;
			ActionBars_CheckBindings();
			if ( SimpleSave_RegisterLoad ) then
				SimpleSave_RegisterLoad(ActionBars_OnSaveLoaded);
			else
				ActionBars_OnSaveLoaded();
				if ( not SIMPLE_SAVE_WARNED ) then
					SIMPLE_SAVE_WARNED = 1;
					ActionBars_Print("|cffff4040Dependency missing: SimpleSave.|r Hidden bars, moved places and options are not saved between sessions.");
				end
			end
		elseif ( ActionBars_Loaded ) then
			ActionBars_ApplyLayout();
		end
	elseif ( not ActionBars_Loaded ) then
		return;
	elseif ( event == "ACTIONBAR_SHOWGRID" ) then
		ActionBars_DragGrid = 1;
		ActionBars_ApplyLayout();
	elseif ( event == "ACTIONBAR_HIDEGRID" ) then
		ActionBars_DragGrid = nil;
		ActionBars_ApplyLayout();
	elseif ( event == "ACTIONBAR_SLOT_CHANGED" ) then
		ActionBars_ApplyLayout();
	end
end


--------------------------------------------------------------------------------
-- Settings window (/ab)
--------------------------------------------------------------------------------

function ActionBars_ModeShort(bar)
	if ( ActionBars_Mode[bar] == "0" ) then
		return "Hidden";
	end
	return "Shown";
end

function ActionBarsOptions_Update()
	local bar;
	for bar = 1, ACTIONBARS_NUM_BARS do
		getglobal("ActionBarsOptionsBar"..bar.."Label"):SetText(ACTIONBARS_BAR_NAMES[bar]);
		getglobal("ActionBarsOptionsBar"..bar.."Mode"):SetText(ActionBars_ModeShort(bar));
		local state = getglobal("ActionBarsOptionsBar"..bar.."State");
		if ( ActionBars_Shown[bar] and not ActionBars_Visible(bar) ) then
			state:SetText("|cff808080(empty)|r");
		else
			state:SetText("");
		end
	end
	ActionBarsOptionsGrid:SetChecked(ActionBars_Grid and 1 or 0);
	ActionBarsOptionsCooldown:SetChecked(ActionBars_CooldownText and 1 or 0);
	if ( ActionBars_MoveMode ) then
		ActionBarsOptionsMoveButton:SetText("Lock bars");
	else
		ActionBarsOptionsMoveButton:SetText("Move bars");
	end
	if ( ActionBars_BindingsMissing ) then
		ActionBarsOptionsSaveText:SetText(SIMPLE_BINDINGS_WARNING);
	elseif ( ActionBars_HasSave() ) then
		ActionBarsOptionsSaveText:SetText("Spells, items, key bindings and these settings are all saved.");
	else
		ActionBarsOptionsSaveText:SetText("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions. Install SimpleSave to keep them (spells, items and key bindings are always saved).");
	end
end

-- Shown <-> Hidden
function ActionBarsOptions_CycleMode(bar)
	if ( ActionBars_Mode[bar] == "0" ) then
		ActionBars_Mode[bar] = "1";
	else
		ActionBars_Mode[bar] = "0";
	end
	ActionBars_Changed();
end

function ActionBarsOptions_Toggle(which)
	if ( which == "grid" ) then
		ActionBars_Grid = not ActionBars_Grid and 1 or nil;
	elseif ( which == "cooldown" ) then
		ActionBars_CooldownText = not ActionBars_CooldownText and 1 or nil;
		ActionBars_CDTime = 0;
		ActionBars_UpdateCooldownText();
	elseif ( which == "move" ) then
		ActionBars_MoveMode = not ActionBars_MoveMode and 1 or nil;
	elseif ( which == "reset" ) then
		ActionBars_Pos = {};
		ActionBars_ExtraPos = {};
	end
	ActionBars_Changed();
end

function ActionBars_Changed()
	ActionBars_Save();
	ActionBars_ApplyLayout();
	if ( ActionBarsOptionsFrame:IsVisible() ) then
		ActionBarsOptions_Update();
	end
end

function ActionBarsOptions_OnLoad()
	tinsert(UISpecialFrames, "ActionBarsOptionsFrame");
end


--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

function ActionBars_OnOff(value)
	if ( value ) then
		return "|cff00ff00on|r";
	end
	return "|cffff4040off|r";
end

function ActionBars_ModeText(bar)
	if ( ActionBars_Mode[bar] == "0" ) then
		return "|cffff4040hidden|r";
	end
	return "|cff00ff00shown|r";
end

function ActionBars_Status()
	local bar;
	for bar = 1, ACTIONBARS_NUM_BARS do
		ActionBars_Print(ACTIONBARS_BAR_NAMES[bar]..": "..ActionBars_ModeText(bar));
	end
	ActionBars_Print("Empty slots always shown: "..ActionBars_OnOff(ActionBars_Grid));
	if ( ActionBars_HasSave() ) then
		ActionBars_Print("Settings are saved with SimpleSave.");
	else
		ActionBars_Print("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions.");
	end
end

function ActionBars_Help()
	ActionBars_Print("/ab - open the settings window");
	ActionBars_Print("/ab 1, /ab 2, /ab 3, /ab 4 - show or hide a bar");
	ActionBars_Print("/ab move - move the bars (drag the green handles), again to lock");
	ActionBars_Print("/ab reset - put all bars back at their default place");
	ActionBars_Print("/ab grid - always show empty slots on/off");
	ActionBars_Print("/ab status - show the settings");
end

SLASH_ACTIONBARS1 = "/ab";
SLASH_ACTIONBARS2 = "/actionbars";
SlashCmdList["ACTIONBARS"] = function(msg)
	local simpleVersionAsk = strlower(gsub(msg or "", "%s", ""));
	if ( simpleVersionAsk == "v" or simpleVersionAsk == "version" ) then
		ChatFrame:AddMessage("ActionBars "..ACTIONBARS_VERSION, 1.0, 0.82, 0.0);
		return;
	end
	if ( ActionBars_Off ) then
		ActionBars_Print("ActionBars is turned off in /qol (Modules). Turn it on there and log in again.");
		return;
	end
	msg = strlower(msg or "");
	msg = gsub(msg, "^%s+", "");
	msg = gsub(msg, "%s+$", "");
	local bar = tonumber(msg);
	if ( bar and bar >= 1 and bar <= ACTIONBARS_NUM_BARS ) then
		if ( ActionBars_Mode[bar] == "0" ) then
			ActionBars_Mode[bar] = "1";
		else
			ActionBars_Mode[bar] = "0";
		end
		ActionBars_ComputeShown();
		ActionBars_Print(ACTIONBARS_BAR_NAMES[bar]..": "..ActionBars_ModeText(bar));
	elseif ( msg == "move" ) then
		if ( ActionBars_MoveMode ) then
			ActionBars_MoveMode = nil;
			ActionBars_Print("Bars locked.");
		else
			ActionBars_MoveMode = 1;
			ActionBars_Print("Drag the green handles to move the bars. Type /ab move again to lock.");
		end
	elseif ( msg == "reset" ) then
		ActionBars_Pos = {};
		ActionBars_ExtraPos = {};
		ActionBars_Print("All bars are back at their default place.");
	elseif ( msg == "grid" ) then
		ActionBars_Grid = not ActionBars_Grid and 1 or nil;
		ActionBars_Print("Empty slots always shown: "..ActionBars_OnOff(ActionBars_Grid));
	elseif ( msg == "selfcast" or msg == "quitfix" ) then
		ActionBars_Print("Alt self cast is now in SimpleQoL (/qol). The Quit fix is always on.");
		return;
	elseif ( msg == "status" ) then
		ActionBars_Status();
		return;
	elseif ( msg == "help" ) then
		ActionBars_Help();
		return;
	else
		if ( ActionBarsOptionsFrame:IsVisible() ) then
			ActionBarsOptionsFrame:Hide();
		else
			ActionBarsOptionsFrame:Show();
		end
		return;
	end
	ActionBars_Changed();
end
