-- Stand-ins for base functions the 0.5.3 client lacks (AlphaUI normally supplies them).
-- The client has no type() either, so none is used here.
if ( not tostring ) then
	tostring = function(value)
		if ( value == nil ) then
			return "";
		end
		if ( value == true ) then
			return "true";
		end
		if ( value == false ) then
			return "false";
		end
		return format("%s", value);
	end
end
if ( not tonumber ) then
	tonumber = function(value)
		if ( value == nil or value == true or value == false ) then
			return nil;
		end
		value = gsub(format("%s", value), "^%s+", "");
		value = gsub(value, "%s+$", "");
		if ( strfind(value, "^[-+]?%d+%.?%d*$") or strfind(value, "^[-+]?%d*%.%d+$") ) then
			return value + 0;
		end
		return nil;
	end
end
--------------------------------------------------------------------------------
-- SimpleChat for WoW 0.5.3
--
-- Chat tabs (General, Whispers, Guild), a movable and resizable chat window,
-- an optional dark background, mouse wheel scrolling, 1.12-style settings per
-- tab and a discreet "Copy" button. Settings are saved with SimpleSave.
--
-- How it works
--   * The stock ChatFrame stays where it is and keeps doing all the work
--     (events, formatting, sounds, the edit box and its buttons). Its own text
--     is not drawn: every line it gets (ChatFrame:AddMessage) is sent to our
--     three message frames instead, which sit on top of it.
--   * ChatFrame_OnEvent is wrapped to know the message type (SAY, GUILD, ...)
--     while a line is added, so each tab can filter by type.
--   * Moving and resizing change the stock ChatFrame; our frames, the edit
--     box and the stock buttons are anchored to it and follow.
--------------------------------------------------------------------------------

SIMPLECHAT_VERSION = "1.64";
SIMPLECHAT_NUM_TABS = 4;
SIMPLECHAT_COMBAT_TAB = 4;          -- the Combat Log tab: gets the stock combat log lines
SIMPLECHAT_DEFAULT_NAMES = { "General", "Whispers", "Guild", "Combat Log" };
-- The names in use (they can be changed in the tab's settings, max 10 letters).
SimpleChat_TabNames = { "General", "Whispers", "Guild", "Combat Log" };
SIMPLECHAT_HISTORY = 200;           -- lines per tab for the Copy window
SIMPLECHAT_COPY_ROWS = 14;
SIMPLECHAT_MIN_WIDTH = 229;       -- 260 (narrow input line) - 31
SIMPLECHAT_MIN_HEIGHT = 60;
SIMPLECHAT_MAX_WIDTH = 1300;
SIMPLECHAT_MAX_HEIGHT = 700;
SIMPLECHAT_WHEEL_LINES = 3;
SIMPLECHAT_FADED_ALPHA = 0;        -- tabs, Copy and grip when the mouse is away
SIMPLECHAT_FADE_DELAY = 1.5;       -- seconds after the mouse left the chat
SIMPLECHAT_FADE_SPEED = 3.0;       -- alpha per second

-- Message groups shown as check boxes (in this order).
SIMPLECHAT_GROUPS = { "Say", "Yell", "Emote", "Party", "Guild", "Officer", "Whisper", "Channels", "NPC speech", "System", "Loot", "Skill" };
SIMPLECHAT_NUM_GROUPS = 12;
SIMPLECHAT_SYSTEM_GROUP = 10;
SIMPLECHAT_TYPE_GROUP = {
	SAY = 1, YELL = 2, EMOTE = 3, TEXT_EMOTE = 3, PARTY = 4, GUILD = 5, OFFICER = 6,
	WHISPER = 7, WHISPER_INFORM = 7, REPLY = 7, AFK = 7, DND = 7, IGNORED = 7,
	CHANNEL = 8, CHANNEL_JOIN = 8, CHANNEL_LEAVE = 8, CHANNEL_LIST = 8, CHANNEL_NOTICE = 8, CHANNEL_NOTICE_USER = 8,
	MONSTER_SAY = 9, MONSTER_YELL = 9, MONSTER_EMOTE = 9,
	SYSTEM = 10, LOOT = 11, SKILL = 12,
};
-- Default filters ("1" = shown): General shows everything.
SIMPLECHAT_DEFAULT_FILTERS = { "111111111111", "000000100000", "000011000000", "000000000000" };

-- Settings (saved with SimpleSave as addon "SimpleChat")
SimpleChat_Enabled = 1;
SimpleChat_Tab = 1;
SimpleChat_Filters = {};
SimpleChat_Background = 0;         -- 0..100 (%), 0 = fully transparent
SimpleChat_Locked = nil;
SimpleChat_NoFade = nil;
SimpleChat_FlashWhispers = nil;    -- 1 = the Whispers tab flashes on new whispers
SimpleChat_Moved = nil;            -- 1 once the user moved or resized the chat
SimpleChat_X = 32;
SimpleChat_Y = 82;
SimpleChat_Width = 608;            -- stock ChatFrame size
SimpleChat_Height = 128;

-- Runtime state
SimpleChat_EventType = nil;
SimpleChat_Sender = nil;           -- name of the sender while the stock chat handles an event
SimpleChat_History = { {}, {}, {}, {} };
SimpleChat_Flash = {};
SimpleChat_FlashTime = 0;
SimpleChat_FlashOn = nil;
SimpleChat_Drag = nil;             -- { mode, cursorX, cursorY, x, y, w, h, kx, ky }
SimpleChat_TabPress = nil;         -- { tab, button, cursorX, cursorY }
SimpleChat_Placing = nil;
SimpleChat_SettingsTab = 1;
SimpleChat_ActiveSlider = nil;
SimpleChat_CopyOffset = 0;
SimpleChat_CopyLines = {};
SimpleChat_Hover = nil;            -- 1 while the mouse is over the chat
SimpleChat_LeaveTime = 0;
SimpleChat_UIAlpha = 1.0;          -- current alpha of tabs, Copy and grip
SimpleChat_ClearTime = 0;

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

-- The older Interface\Bindings.xml (053-AddOns) hides "ChatFrameCopyButton"
-- when the interface is toggled (Toggle UI key), a frame no addon here has:
-- error "attempt to index global ChatFrameCopyButton". A stand-in with empty
-- Hide and Show stops it. The real copy buttons are children of UIParent and
-- hide by themselves.
if ( not ChatFrameCopyButton ) then
	ChatFrameCopyButton = {};
	function ChatFrameCopyButton.Hide() end
	function ChatFrameCopyButton.Show() end
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
-- Helpers
--------------------------------------------------------------------------------

function SimpleChat_Print(text)
	SimpleChat_Write(1, "SimpleChat: "..text, 1.0, 0.82, 0.0);
end

-- A tab frame lays a line out at the size it has when the line is added, and
-- never again. At login the saved chat size is applied after the first lines
-- (guild message of the day) have arrived, so those were laid out at the wrong
-- size and cut off. Until the size is applied lines wait here, in order.
SimpleChat_Pending = {};
SimpleChat_Ready = nil;
SimpleChat_FlushAt = nil;
function SimpleChat_ToFrame(tab, text, r, g, b)
	if ( not SimpleChat_Ready ) then
		tinsert(SimpleChat_Pending, { tab, text, r, g, b });
		return;
	end
	local frame = getglobal("SimpleChatFrame"..tab);
	frame:AddMessage(text, r, g, b);
	frame.laidWidth = frame.simpleWidth;
end

function SimpleChat_Flush()
	SimpleChat_FlushAt = nil;
	SimpleChat_Ready = 1;
	local i, line;
	for i = 1, getn(SimpleChat_Pending) do
		line = SimpleChat_Pending[i];
		SimpleChat_ToFrame(line[1], line[2], line[3], line[4], line[5]);
	end
	SimpleChat_Pending = {};
end

-- Writes to a tab's frame directly (not through the filters).
function SimpleChat_Write(tab, text, r, g, b)
	local frame = getglobal("SimpleChatFrame"..tab);
	if ( frame and SimpleChat_Enabled ) then
		SimpleChat_ToFrame(tab, text, r, g, b);
	elseif ( SimpleChat_OrigAddMessage ) then
		SimpleChat_OrigAddMessage(ChatFrame, text, r, g, b);
	end
end

function SimpleChat_ActiveFrame()
	return getglobal("SimpleChatFrame"..SimpleChat_Tab);
end

function SimpleChat_Abs(value)
	if ( value < 0 ) then
		return -value;
	end
	return value;
end

function SimpleChat_Clamp(value, low, high)
	return max(low, min(value, high));
end

function SimpleChat_ParseFilter(text, default)
	local list = {};
	local i;
	if ( not text or strlen(text) ~= SIMPLECHAT_NUM_GROUPS ) then
		text = default;
	end
	for i = 1, SIMPLECHAT_NUM_GROUPS do
		if ( strsub(text, i, i) == "1" ) then
			list[i] = 1;
		end
	end
	return list;
end

function SimpleChat_FilterString(list)
	local text = "";
	local i;
	for i = 1, SIMPLECHAT_NUM_GROUPS do
		if ( list[i] ) then
			text = text.."1";
		else
			text = text.."0";
		end
	end
	return text;
end

-- Removes colour codes and link codes: "|cff..[Item]|r" -> "[Item]".
function SimpleChat_PlainText(text)
	text = gsub(text, "|c%x%x%x%x%x%x%x%x", "");
	text = gsub(text, "|r", "");
	text = gsub(text, "|H.-|h(.-)|h", "%1");
	text = gsub(text, "[\r\n\t]+", " ");
	return text;
end


--------------------------------------------------------------------------------
-- Saving (SimpleSave)
--------------------------------------------------------------------------------

function SimpleChat_Save(name, value)
	if ( SimpleSave_Set ) then
		SimpleSave_Set("SimpleChat", name, value);
	end
end

function SimpleChat_SaveFlag(name, value)
	if ( value ) then
		SimpleChat_Save(name, 1);
	else
		SimpleChat_Save(name, nil);
	end
end

function SimpleChat_SavePosition()
	SimpleChat_SaveFlag("Moved", SimpleChat_Moved);
	if ( SimpleChat_Moved ) then
		SimpleChat_Save("X", floor(SimpleChat_X + 0.5));
		SimpleChat_Save("Y", floor(SimpleChat_Y + 0.5));
		SimpleChat_Save("W", floor(SimpleChat_Width + 0.5));
		SimpleChat_Save("H", floor(SimpleChat_Height + 0.5));
	else
		SimpleChat_Save("X", nil);
		SimpleChat_Save("Y", nil);
		SimpleChat_Save("W", nil);
		SimpleChat_Save("H", nil);
	end
end

-- Sets the shown name of a tab (empty or nil = the default name).
function SimpleChat_SetTabName(tab, name)
	if ( name ) then
		name = gsub(name, "|", "");
		name = gsub(name, "^%s+", "");
		name = gsub(name, "%s+$", "");
		name = strsub(name, 1, 10);
	end
	if ( not name or name == "" ) then
		name = SIMPLECHAT_DEFAULT_NAMES[tab];
	end
	SimpleChat_TabNames[tab] = name;
	local text = getglobal("SimpleChatTab"..tab.."Text");
	if ( text ) then
		text:SetText(name);
	end
end

function SimpleChat_LoadSettings()
	local i;
	for i = 1, SIMPLECHAT_NUM_TABS do
		SimpleChat_Filters[i] = SimpleChat_ParseFilter(nil, SIMPLECHAT_DEFAULT_FILTERS[i]);
	end
	if ( not SimpleSave_Get ) then
		SimpleChat_ApplyAll();
		SimpleChat_FlushAt = GetTime() + 0.3;
		return;
	end
	for i = 1, SIMPLECHAT_NUM_TABS do
		SimpleChat_Filters[i] = SimpleChat_ParseFilter(SimpleSave_Get("SimpleChat", "F"..i), SIMPLECHAT_DEFAULT_FILTERS[i]);
	end
	for i = 1, SIMPLECHAT_NUM_TABS do
		SimpleChat_SetTabName(i, SimpleSave_Get("SimpleChat", "Name"..i));
	end
	SimpleChat_Background = SimpleChat_Clamp(SimpleSave_GetNumber("SimpleChat", "Bg", 0), 0, 100);
	SimpleChat_Locked = SimpleSave_Get("SimpleChat", "Lock");
	SimpleChat_NoFade = SimpleSave_Get("SimpleChat", "NoFade");
	SimpleChat_FlashWhispers = SimpleSave_Get("SimpleChat", "Flash");
	SimpleChat_Tab = SimpleChat_Clamp(SimpleSave_GetNumber("SimpleChat", "Tab", 1), 1, SIMPLECHAT_NUM_TABS);
	if ( SimpleSave_Get("SimpleChat", "Moved") ) then
		SimpleChat_Moved = 1;
		SimpleChat_X = SimpleSave_GetNumber("SimpleChat", "X", 32);
		SimpleChat_Y = SimpleSave_GetNumber("SimpleChat", "Y", 82);
		SimpleChat_Width = SimpleChat_Clamp(SimpleSave_GetNumber("SimpleChat", "W", 608), SIMPLECHAT_MIN_WIDTH, SIMPLECHAT_MAX_WIDTH);
		SimpleChat_Height = SimpleChat_Clamp(SimpleSave_GetNumber("SimpleChat", "H", 128), SIMPLECHAT_MIN_HEIGHT, SIMPLECHAT_MAX_HEIGHT);
	end
	SimpleChat_ApplyAll();
	SimpleChat_FlushAt = GetTime() + 0.3;
end

function SimpleChat_ApplyAll()
	SimpleChat_ApplyPosition();
	SimpleChat_ApplyBackground();
	SimpleChat_ApplyFade();
	SimpleChat_ApplyLock();
	SimpleChat_HookCombatLog();
	SimpleChat_ApplyCombatLog();
	SimpleChat_SelectTab(SimpleChat_Tab);
end


--------------------------------------------------------------------------------
-- Hooks into the stock chat
--------------------------------------------------------------------------------

-- The chat box keeps the last whisper target, channel and officer chat after
-- a message, like Say, Party and Guild already do. Yell and emotes do not stay.
if ( ChatTypeInfo ) then
	if ( ChatTypeInfo["WHISPER"] ) then
		ChatTypeInfo["WHISPER"].sticky = 1;
	end
	if ( ChatTypeInfo["CHANNEL"] ) then
		ChatTypeInfo["CHANNEL"].sticky = 1;
	end
	if ( ChatTypeInfo["OFFICER"] ) then
		ChatTypeInfo["OFFICER"].sticky = 1;
	end
end

-- Remember the message type while the stock ChatFrame handles an event.
SimpleChat_TypeCache = {};
SimpleChat_OrigOnEvent = ChatFrame_OnEvent;
function ChatFrame_OnEvent(event)
	local outer = SimpleChat_EventType;
	if ( this == ChatFrame ) then
		-- The type name is cut out once per event name, not for every event.
		local kind = SimpleChat_TypeCache[event];
		if ( kind == nil ) then
			if ( strfind(event, "^CHAT_MSG_") ) then
				kind = strsub(event, 10);
			else
				kind = false;
			end
			SimpleChat_TypeCache[event] = kind;
		end
		if ( kind ) then
			SimpleChat_EventType = kind;
			SimpleChat_Sender = arg2;
		else
			SimpleChat_EventType = "SYSTEM";
		end
	end
	SimpleChat_OrigOnEvent(event);
	SimpleChat_EventType = outer;
end

-- Group number for a message type; 0 = not from a chat event (addon text).
function SimpleChat_GroupOf(chatType)
	if ( not chatType ) then
		return 0;
	end
	return SIMPLECHAT_TYPE_GROUP[chatType] or SIMPLECHAT_SYSTEM_GROUP;
end

function SimpleChat_AddHistory(tab, text, r, g, b, shown)
	local list = SimpleChat_History[tab];
	tinsert(list, { text, r or 1, g or 1, b or 1, shown });
	if ( getn(list) > SIMPLECHAT_HISTORY ) then
		tremove(list, 1);
	end
end

-- Player names in chat are links (|Hplayer:Name|h): click = whisper,
-- Shift+click = /who, Ctrl+click or right-click = menu (invite, add friend...).
-- The link is light blue and the rest of the line keeps the message colour.
SIMPLECHAT_LINK_TYPES = { WHISPER = 1, WHISPER_INFORM = 1, SAY = 1, YELL = 1, PARTY = 1, GUILD = 1, OFFICER = 1, RAID = 1, CHANNEL = 1, EMOTE = 1, AFK = 1, DND = 1 };

-- System lines that start with a player name: online and offline messages,
-- /who results, party messages.
SIMPLECHAT_SYSTEM_TAILS = { " has come online", " has gone offline", ": Level ", " joins the party", " has left the party", " is already in a group", " declines your group invitation", " declines your guild invitation", " has joined the guild", " has left the guild", " has been kicked out of the party", " is not in your party" };

function SimpleChat_SystemLink(text, r, g, b)
	local s, e, name = strfind(text or "", "^(%a+)");
	if ( not name or strlen(name) < 2 or strlen(name) > 12 ) then
		return text;
	end
	local rest = strsub(text, e + 1);
	local i;
	for i = 1, getn(SIMPLECHAT_SYSTEM_TAILS) do
		local tail = SIMPLECHAT_SYSTEM_TAILS[i];
		if ( strfind(rest, tail, 1, 1) == 1 ) then
			local back = format("|cff%02x%02x%02x", floor((r or 1) * 255 + 0.5), floor((g or 1) * 255 + 0.5), floor((b or 1) * 255 + 0.5));
			return "|cff9fd0ff|Hplayer:"..name.."|h"..name.."|h"..back..rest;
		end
	end
	return text;
end

function SimpleChat_NameLink(text, r, g, b)
	local kind = SimpleChat_EventType;
	if ( kind == "SYSTEM" ) then
		return SimpleChat_SystemLink(text, r, g, b);
	end
	local name = SimpleChat_Sender;
	if ( not kind or not SIMPLECHAT_LINK_TYPES[kind] or not name or name == "" or strfind(name, "[|:%s]") ) then
		return text;
	end
	if ( name == UnitName("player") and kind ~= "WHISPER_INFORM" ) then
		return text;
	end
	local s, e = strfind(text, name, 1, true);
	if ( not s or s > 40 ) then
		return text;
	end
	local back = format("|cff%02x%02x%02x", floor((r or 1) * 255 + 0.5), floor((g or 1) * 255 + 0.5), floor((b or 1) * 255 + 0.5));
	return strsub(text, 1, s - 1).."|cff9fd0ff|Hplayer:"..name.."|h"..name.."|h"..back..strsub(text, e + 1);
end

-- Replaces ChatFrame:AddMessage: the line goes to every tab that shows its type.
function SimpleChat_AddMessage(self, text, r, g, b, id)
	if ( not SimpleChat_Enabled or self ~= ChatFrame ) then
		SimpleChat_OrigAddMessage(self, text, r, g, b, id);
		return;
	end
	if ( not text ) then
		return;
	end
	local group = SimpleChat_GroupOf(SimpleChat_EventType);
	local shown = SimpleChat_NameLink(text, r, g, b);
	local tab, filter;
	for tab = 1, SIMPLECHAT_NUM_TABS do
		filter = SimpleChat_Filters[tab];
		if ( (group == 0 and tab == 1) or (group > 0 and filter and filter[group]) ) then
			SimpleChat_ToFrame(tab, shown, r, g, b);
			SimpleChat_AddHistory(tab, text, r, g, b, shown);
			-- Only the Whispers tab flashes, only for whispers you get, and
			-- only when that setting is on.
			if ( tab == 2 and tab ~= SimpleChat_Tab and SimpleChat_FlashWhispers and SimpleChat_EventType == "WHISPER" ) then
				SimpleChat_Flash[tab] = 1;
			end
		end
	end
end

SimpleChat_OrigAddMessage = ChatFrame.AddMessage;
ChatFrame.AddMessage = SimpleChat_AddMessage;

-- Combat log: the 0.5.3 client writes its combat text (hits, misses, spells,
-- deaths ...) to a window of its own, CombatLog. The lines go to the Combat Log
-- tab instead and that window stays closed. Switched off with /sc off.
-- No line history is kept for this tab (it would be copied for every hit).
SimpleChat_OrigCombatAdd = nil;
SimpleChat_OrigToggleCombatLog = nil;
function SimpleChat_CombatAdd(self, text, r, g, b, id)
	if ( not SimpleChat_Enabled ) then
		SimpleChat_OrigCombatAdd(self, text, r, g, b, id);
		return;
	end
	if ( text ) then
		SimpleChat_ToFrame(SIMPLECHAT_COMBAT_TAB, text, r, g, b);
	end
end

function SimpleChat_ToggleCombatLog()
	if ( SimpleChat_Enabled ) then
		if ( SimpleChat_Tab == SIMPLECHAT_COMBAT_TAB ) then
			SimpleChat_SelectTab(1);
		else
			SimpleChat_SelectTab(SIMPLECHAT_COMBAT_TAB);
		end
		SimpleChat_Save("Tab", SimpleChat_Tab);
	else
		SimpleChat_OrigToggleCombatLog();
	end
end

-- The stock window is closed while SimpleChat is on and comes back with /sc off
-- if the game setting has it on.
function SimpleChat_ApplyCombatLog()
	if ( not CombatLog or not SimpleChat_OrigCombatAdd ) then
		return;
	end
	if ( SimpleChat_Enabled ) then
		if ( CombatLog:IsVisible() ) then
			CombatLog:Hide();
		end
		-- the game only sends the combat text while its setting is on
		if ( GetCVar and SetCVar and GetCVar("combatLogOn") == "0" ) then
			SetCVar("combatLogOn", "1");
		end
	elseif ( GetCVar and GetCVar("combatLogOn") ~= "0" and not CombatLog:IsVisible() ) then
		CombatLog:Show();
	end
end

function SimpleChat_HookCombatLog()
	if ( SimpleChat_OrigCombatAdd or not CombatLog or not CombatLog.AddMessage ) then
		return;
	end
	SimpleChat_OrigCombatAdd = CombatLog.AddMessage;
	CombatLog.AddMessage = SimpleChat_CombatAdd;
	if ( ToggleCombatLog ) then
		SimpleChat_OrigToggleCombatLog = ToggleCombatLog;
		ToggleCombatLog = SimpleChat_ToggleCombatLog;
	end
end
SimpleChat_HookCombatLog();

-- The stock scroll buttons, page keys and the "new text below" flash work on
-- ChatFrame; send them to the visible tab instead.
SimpleChat_OrigScrollUp = ChatFrame.ScrollUp;
SimpleChat_OrigScrollDown = ChatFrame.ScrollDown;
SimpleChat_OrigScrollToBottom = ChatFrame.ScrollToBottom;
SimpleChat_OrigAtBottom = ChatFrame.AtBottom;
SimpleChat_OrigPageUp = ChatFrame.PageUp;
SimpleChat_OrigPageDown = ChatFrame.PageDown;

ChatFrame.ScrollUp = function(self)
	if ( SimpleChat_Enabled ) then
		SimpleChat_ActiveFrame():ScrollUp();
	else
		SimpleChat_OrigScrollUp(self);
	end
end
ChatFrame.ScrollDown = function(self)
	if ( SimpleChat_Enabled ) then
		SimpleChat_ActiveFrame():ScrollDown();
	else
		SimpleChat_OrigScrollDown(self);
	end
end
ChatFrame.ScrollToBottom = function(self)
	if ( SimpleChat_Enabled ) then
		SimpleChat_ActiveFrame():ScrollToBottom();
	else
		SimpleChat_OrigScrollToBottom(self);
	end
end
ChatFrame.AtBottom = function(self)
	if ( SimpleChat_Enabled ) then
		return SimpleChat_ActiveFrame():AtBottom();
	end
	return SimpleChat_OrigAtBottom(self);
end
if ( SimpleChat_OrigPageUp ) then
	ChatFrame.PageUp = function(self)
		if ( SimpleChat_Enabled ) then
			SimpleChat_ActiveFrame():PageUp();
		else
			SimpleChat_OrigPageUp(self);
		end
	end
end
if ( SimpleChat_OrigPageDown ) then
	ChatFrame.PageDown = function(self)
		if ( SimpleChat_Enabled ) then
			SimpleChat_ActiveFrame():PageDown();
		else
			SimpleChat_OrigPageDown(self);
		end
	end
end

-- Once the user has placed the chat, other UI code (AlphaUI moves the chat
-- when the pet bar appears) may not move it back.
SimpleChat_OrigSetPoint = ChatFrame.SetPoint;
SimpleChat_OrigClearAllPoints = ChatFrame.ClearAllPoints;
ChatFrame.SetPoint = function(self, a, b, c, d, e)
	if ( SimpleChat_Moved and SimpleChat_Enabled and not SimpleChat_Placing ) then
		return;
	end
	SimpleChat_OrigSetPoint(self, a, b, c, d, e);
end
ChatFrame.ClearAllPoints = function(self)
	if ( SimpleChat_Moved and SimpleChat_Enabled and not SimpleChat_Placing ) then
		return;
	end
	SimpleChat_OrigClearAllPoints(self);
end


--------------------------------------------------------------------------------
-- Position, size, background, fading, lock
--------------------------------------------------------------------------------

function SimpleChat_ApplyPosition()
	if ( SimpleChat_Moved and SimpleChat_Enabled ) then
		SimpleChat_Placing = 1;
		ChatFrame:ClearAllPoints();
		ChatFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", SimpleChat_X, SimpleChat_Y);
		SimpleChat_Placing = nil;
		ChatFrame:SetWidth(SimpleChat_Width);
		ChatFrame:SetHeight(SimpleChat_Height);
	end
	SimpleChat_ApplyFrameSizes();
end

-- A ScrollingMessageFrame in 0.5.3 only lays its lines out again when it
-- changes (a new line arrived, tested), not when it is resized. Scrolling one
-- line away and back makes it redraw for the new size without adding lines.
function SimpleChat_Relayout(frame)
	if ( not frame.ScrollUp or not frame.ScrollDown ) then
		return;
	end
	if ( frame.AtBottom and frame:AtBottom() ) then
		frame:ScrollUp();
		frame:ScrollDown();
	else
		frame:ScrollDown();
		frame:ScrollUp();
	end
end

-- A line that was added at another width stays cut off (not wrapped) when the
-- chat changes size. Empty the tab and add its lines again: they wrap at the
-- current width. Needs Clear; without it nothing is done.
SimpleChat_RebuildAt = nil;
function SimpleChat_Rebuild(index)
	local frame = getglobal("SimpleChatFrame"..index);
	local list = SimpleChat_History[index];
	if ( not frame or not list or getn(list) == 0 or not SimpleChat_Ready ) then
		return;
	end
	if ( not frame.Clear ) then
		-- No Clear in this client: a new line makes the frame lay everything
		-- out again. Only needed when the frame got narrower since its lines
		-- were laid out (else nothing is cut off), so gaps stay rare.
		if ( not frame.laidWidth or ( frame.simpleWidth and frame.simpleWidth < frame.laidWidth - 1 ) ) then
			frame.laidWidth = frame.simpleWidth;
			frame:AddMessage(" ", 1, 1, 1);
		end
		return;
	end
	frame:Clear();
	local i, line;
	for i = 1, getn(list) do
		line = list[i];
		frame:AddMessage(line[5] or line[1], line[2], line[3], line[4]);
	end
end

function SimpleChat_RebuildAll()
	local i;
	for i = 1, SIMPLECHAT_NUM_TABS do
		SimpleChat_Rebuild(i);
	end
end

-- The tab frames are sized explicitly: a ScrollingMessageFrame that only
-- follows two anchors keeps its old line layout when the chat gets smaller,
-- so text was drawn outside the box.
function SimpleChat_ApplyFrameSizes()
	local width = SimpleChat_Width;
	local height = SimpleChat_Height;
	if ( not ( SimpleChat_Moved and SimpleChat_Enabled ) ) then
		width = ChatFrame:GetWidth();
		height = ChatFrame:GetHeight();
	end
	if ( not width or not height or width < 10 or height < 10 ) then
		return;
	end
	-- The input line follows the chat width (at most 512, at least 260). Its
	-- art is two halves of 256 that overlap in a narrower line and would show
	-- a dark patch; SimpleChatInputBack (a dark solid bar behind the line, see
	-- SimpleChat_UpdateInputBack) makes that even.
	if ( ChatFrameEditBox ) then
		local boxWidth = width + 31;
		if ( boxWidth > 512 ) then
			boxWidth = 512;
		elseif ( boxWidth < 260 ) then
			boxWidth = 260;
		end
		ChatFrameEditBox:SetWidth(boxWidth);
	end
	local i;
	for i = 1, SIMPLECHAT_NUM_TABS do
		local frame = getglobal("SimpleChatFrame"..i);
		if ( frame and ( frame.simpleWidth ~= width or frame.simpleHeight ~= height ) ) then
			frame.simpleWidth = width;
			frame.simpleHeight = height;
			frame:SetWidth(width);
			frame:SetHeight(height);
			SimpleChat_Relayout(frame);
			if ( not SimpleChat_Drag ) then
				SimpleChat_RebuildAt = GetTime() + 0.5;
			end
		end
	end
end

function SimpleChat_ApplyBackground()
	local alpha = SimpleChat_Background / 100;
	SimpleChatBackground:SetAlpha(alpha);
	if ( alpha > 0 and SimpleChat_Enabled ) then
		SimpleChatBackground:Show();
	else
		SimpleChatBackground:Hide();
	end
end

function SimpleChat_CanFade()
	return SimpleChatFrame1.SetFading;
end

function SimpleChat_ApplyFade()
	if ( not SimpleChat_CanFade() ) then
		return;
	end
	local i;
	for i = 1, SIMPLECHAT_NUM_TABS do
		if ( SimpleChat_NoFade ) then
			getglobal("SimpleChatFrame"..i):SetFading(false);
		else
			getglobal("SimpleChatFrame"..i):SetFading(true);
		end
	end
end

function SimpleChat_ApplyLock()
	if ( SimpleChat_Locked or not SimpleChat_Enabled ) then
		SimpleChatResizeGrip:Hide();
	else
		SimpleChatResizeGrip:Show();
	end
end


--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

function SimpleChat_SelectTab(tab)
	SimpleChat_Tab = tab;
	SimpleChat_Flash[tab] = nil;
	local i;
	for i = 1, SIMPLECHAT_NUM_TABS do
		if ( i == tab and SimpleChat_Enabled ) then
			getglobal("SimpleChatFrame"..i):Show();
		else
			getglobal("SimpleChatFrame"..i):Hide();
		end
	end
	SimpleChat_UpdateTabs();
	if ( SimpleChatCopyFrame:IsVisible() ) then
		SimpleChat_Copy_Refresh(1);
	end
end

function SimpleChat_UpdateTabs()
	local i, tab, text;
	for i = 1, SIMPLECHAT_NUM_TABS do
		tab = getglobal("SimpleChatTab"..i);
		text = getglobal("SimpleChatTab"..i.."Text");
		if ( not SimpleChat_Enabled ) then
			tab:Hide();
		else
			tab:Show();
			if ( i == SimpleChat_Tab ) then
				tab:SetAlpha(SimpleChat_UIAlpha);
				tab:SetBackdropBorderColor(1.0, 0.82, 0.0);
				text:SetTextColor(1.0, 1.0, 1.0);
			elseif ( SimpleChat_Flash[i] and SimpleChat_FlashOn ) then
				-- A flashing tab is always visible.
				tab:SetAlpha(1.0);
				tab:SetBackdropBorderColor(1.0, 0.5, 0.0);
				text:SetTextColor(1.0, 0.6, 0.1);
			else
				tab:SetAlpha(SimpleChat_UIAlpha * 0.75);
				tab:SetBackdropBorderColor(0.4, 0.4, 0.4);
				text:SetTextColor(1.0, 0.82, 0.0);
			end
		end
	end
	if ( SimpleChat_Enabled ) then
		SimpleChatCopyButton:Show();
		if ( not SimpleChat_CopyHover ) then
			SimpleChatCopyButton:SetAlpha(SimpleChat_UIAlpha * 0.6);
		end
		SimpleChatResizeGrip:SetAlpha(SimpleChat_UIAlpha * 0.6);
	else
		SimpleChatCopyButton:Hide();
	end
end

-- Mouse over the chat (message frames, tabs, Copy, grip): tabs fade in.
function SimpleChat_OnEnterChat()
	SimpleChat_Hover = 1;
end

function SimpleChat_OnLeaveChat()
	SimpleChat_Hover = nil;
	SimpleChat_LeaveTime = GetTime();
end

-- Tabs are fully shown while the mouse is over the chat, you type, move it
-- or a SimpleChat window is open; otherwise they fade almost out.
function SimpleChat_WantTabs()
	if ( SimpleChat_Hover or SimpleChat_Drag or SimpleChat_TabPress ) then
		return 1;
	end
	if ( GetTime() - SimpleChat_LeaveTime < SIMPLECHAT_FADE_DELAY ) then
		return 1;
	end
	if ( ChatFrameEditBox and ChatFrameEditBox:IsVisible() ) then
		return 1;
	end
	if ( SimpleChatSettingsFrame:IsVisible() or SimpleChatCopyFrame:IsVisible() ) then
		return 1;
	end
	return nil;
end

function SimpleChat_UpdateFade(elapsed)
	local target = SIMPLECHAT_FADED_ALPHA;
	if ( SimpleChat_WantTabs() ) then
		target = 1.0;
	end
	if ( SimpleChat_UIAlpha == target ) then
		return nil;
	end
	local step = SIMPLECHAT_FADE_SPEED * (elapsed or 0);
	if ( SimpleChat_UIAlpha < target ) then
		SimpleChat_UIAlpha = min(target, SimpleChat_UIAlpha + step);
	else
		SimpleChat_UIAlpha = max(target, SimpleChat_UIAlpha - step);
	end
	return 1;
end

-- The stock ChatFrame should never draw text itself. Lines it got before
-- SimpleChat was loaded (or from code that kept the original AddMessage)
-- are cleared away, so nothing shows behind the tabs' text.
function SimpleChat_ClearStock()
	if ( not SimpleChat_Enabled ) then
		return;
	end
	if ( ChatFrame.Clear ) then
		ChatFrame:Clear();
	elseif ( not SimpleChat_BlankDone ) then
		-- No Clear in this client: push old lines out of view once.
		SimpleChat_BlankDone = 1;
		local i;
		for i = 1, 60 do
			SimpleChat_OrigAddMessage(ChatFrame, " ", 1, 1, 1);
		end
	end
end

function SimpleChat_Tab_OnLoad()
	this:SetBackdropColor(0, 0, 0, 0.6);
	getglobal(this:GetName().."Text"):SetText(SimpleChat_TabNames[this:GetID()]);
end

function SimpleChat_Tab_OnMouseDown(button)
	local x, y = GetCursorPosition();
	SimpleChat_TabPress = { this:GetID(), button, x, y };
end

function SimpleChat_Tab_OnMouseUp(button)
	local press = SimpleChat_TabPress;
	SimpleChat_TabPress = nil;
	if ( SimpleChat_Drag ) then
		SimpleChat_EndDrag();
		return;
	end
	if ( not press ) then
		return;
	end
	if ( press[2] == "RightButton" ) then
		SimpleChat_ShowSettings(press[1]);
	else
		PlaySound("igChatBottom");
		SimpleChat_SelectTab(press[1]);
		SimpleChat_Save("Tab", SimpleChat_Tab);
	end
end

function SimpleChat_Tab_OnEnter()
	SimpleChat_OnEnterChat();
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText(SimpleChat_TabNames[this:GetID()]);
	if ( SimpleChat_Locked ) then
		GameTooltip:AddLine("|cffffffffRight-click: settings|r");
	else
		GameTooltip:AddLine("|cffffffffDrag: move the chat. Right-click: settings|r");
	end
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- Moving and resizing. Cursor movement is converted to SetPoint units with
-- probe frames (see SimpleMap): 0.5.3 reports positions in another scale.
--------------------------------------------------------------------------------

-- Returns kx, ky (SetPoint units per cursor unit) and the chat's current
-- bottom left corner in SetPoint units.
function SimpleChat_Measure()
	local sx, sy = SimpleChatProbeScreen:GetCenter();
	local tx, ty = SimpleChatProbeTopLeft:GetCenter();
	local bx, by = SimpleChatProbeBottomRight:GetCenter();
	if ( not sx or not tx or not bx or SimpleChat_Abs(bx - tx) < 10 or SimpleChat_Abs(ty - by) < 10 ) then
		return 1, 1, SimpleChat_X, SimpleChat_Y;
	end
	-- The size in SetWidth units is known: the stock size, or the one we set.
	local width = SimpleChat_Width;
	local height = SimpleChat_Height;
	-- Probe centers sit 1 unit inside each corner.
	local kx = (width - 2) / SimpleChat_Abs(bx - tx);
	local ky = (height - 2) / SimpleChat_Abs(ty - by);
	return kx, ky, (tx - sx) * kx, (by - sy) * ky;
end

function SimpleChat_StartDrag(mode)
	if ( SimpleChat_Locked ) then
		return;
	end
	local x, y = GetCursorPosition();
	local kx, ky, left, bottom = SimpleChat_Measure();
	local width = SimpleChat_Width;
	local height = SimpleChat_Height;
	SimpleChat_Drag = { mode, x, y, left, bottom, width, height, kx, ky };
	SimpleChat_X = left;
	SimpleChat_Y = bottom;
	SimpleChat_Width = width;
	SimpleChat_Height = height;
	SimpleChat_Moved = 1;
	SimpleChat_ApplyPosition();
end

function SimpleChat_UpdateDrag()
	local drag = SimpleChat_Drag;
	local x, y = GetCursorPosition();
	local dx = (x - drag[2]) * drag[8];
	local dy = (y - drag[3]) * drag[9];
	if ( drag[1] == "move" ) then
		SimpleChat_X = max(0, drag[4] + dx);
		SimpleChat_Y = max(0, drag[5] + dy);
	else
		SimpleChat_Width = SimpleChat_Clamp(drag[6] + dx, SIMPLECHAT_MIN_WIDTH, SIMPLECHAT_MAX_WIDTH);
		-- The bottom edge follows the mouse: the frame grows downwards.
		local height = SimpleChat_Clamp(drag[7] - dy, SIMPLECHAT_MIN_HEIGHT, SIMPLECHAT_MAX_HEIGHT);
		SimpleChat_Y = max(0, drag[5] + drag[7] - height);
		SimpleChat_Height = height;
	end
	SimpleChat_ApplyPosition();
end

function SimpleChat_EndDrag()
	local mode = SimpleChat_Drag[1];
	SimpleChat_Drag = nil;
	SimpleChat_SavePosition();
	if ( mode == "size" ) then
		-- Lay the lines out again for the new size.
		SimpleChat_RebuildAll();
		local i;
		for i = 1, SIMPLECHAT_NUM_TABS do
			getglobal("SimpleChatFrame"..i):ScrollToBottom();
		end
	end
end

function SimpleChat_Grip_OnMouseDown()
	SimpleChat_StartDrag("size");
end

function SimpleChat_Grip_OnMouseUp()
	if ( SimpleChat_Drag ) then
		SimpleChat_EndDrag();
	end
end

function SimpleChat_Grip_SetColor(bright)
	local r, g, b = 0.6, 0.6, 0.6;
	if ( bright ) then
		r, g, b = 1.0, 0.82, 0.0;
	end
	local i;
	for i = 1, 3 do
		getglobal("SimpleChatResizeGripStep"..i):SetVertexColor(r, g, b);
	end
end

function SimpleChat_ResetPosition()
	SimpleChat_Moved = nil;
	SimpleChat_X = 32;
	SimpleChat_Y = 82;
	SimpleChat_Width = 608;
	SimpleChat_Height = 128;
	SimpleChat_Placing = 1;
	ChatFrame:SetWidth(608);
	ChatFrame:SetHeight(128);
	ChatFrame:ClearAllPoints();
	ChatFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 32, 82);
	SimpleChat_Placing = nil;
	SimpleChat_SavePosition();
end


--------------------------------------------------------------------------------
-- Mouse wheel and links on the message frames
--------------------------------------------------------------------------------

function SimpleChat_OnMouseWheel(value)
	local frame = this;
	local i;
	if ( IsShiftKeyDown() ) then
		if ( value > 0 ) then
			if ( frame.ScrollToTop ) then
				frame:ScrollToTop();
			else
				for i = 1, 500 do
					frame:ScrollUp();
				end
			end
		else
			frame:ScrollToBottom();
		end
		return;
	end
	for i = 1, SIMPLECHAT_WHEEL_LINES do
		if ( value > 0 ) then
			frame:ScrollUp();
		else
			frame:ScrollDown();
		end
	end
end

-- Names in chat: click = whisper, Shift + click = /who, Ctrl or Alt + click =
-- a menu (Whisper, Invite to group, Add friend, Who, Ignore). The client does
-- not send right-clicks on links, so the menu is on Ctrl or Alt + click.
function SimpleChat_OnHyperlinkClick(link, text, button)
	if ( strsub(link, 1, 7) == "player:" ) then
		local name = strsub(link, 8);
		if ( name == "" ) then
			return;
		end
		if ( IsControlKeyDown() or IsAltKeyDown() ) then
			SimpleChat_NameMenu(name);
		elseif ( IsShiftKeyDown() ) then
			SimpleChat_Who(name);
		else
			SimpleChat_Whisper(name);
		end
		return;
	end
	ChatFrame_OnHyperlinkShow(link);
end

-- A click anywhere closes the name menu: an invisible full-screen frame is
-- shown a moment after the menu opens (so the opening click cannot hit it).
function SimpleChat_CloseMenu()
	if ( UnitPopup and UnitPopup.which == "CHATNAME" ) then
		UnitPopup:Hide();
	end
	if ( SimpleChatMenuCatcher ) then
		SimpleChatMenuCatcher:Hide();
	end
end

function SimpleChat_Whisper(name)
	if ( not ChatFrameEditBox ) then
		return;
	end
	ChatFrameEditBox.chatType = "WHISPER";
	ChatFrameEditBox.tellTarget = name;
	if ( ChatEdit_UpdateHeader ) then
		ChatEdit_UpdateHeader();
	end
	if ( not ChatFrameEditBox:IsVisible() ) then
		ChatFrame_OpenChat("");
	end
end

-- Same as typing /who name.
function SimpleChat_Who(name)
	if ( SlashCmdList and SlashCmdList["WHO"] ) then
		SlashCmdList["WHO"](name);
	elseif ( SendWho ) then
		SendWho(name);
	end
end

-- The player menu of a name in chat: it uses the stock unit menu frame.
SimpleChat_MenuName = nil;
if ( UnitPopupButtons and UnitPopupMenus ) then
	UnitPopupButtons["CHAT_WHISPER"] = { text = "Whisper", dist = 0 };
	UnitPopupButtons["CHAT_INVITE"] = { text = "Invite to group", dist = 0 };
	UnitPopupButtons["CHAT_FRIEND"] = { text = "Add friend", dist = 0 };
	UnitPopupButtons["CHAT_WHO"] = { text = "Who", dist = 0 };
	UnitPopupButtons["CHAT_IGNORE"] = { text = "Ignore", dist = 0 };
	UnitPopupMenus["CHATNAME"] = { "CHAT_WHISPER", "CHAT_INVITE", "CHAT_FRIEND", "CHAT_WHO", "CHAT_IGNORE", "CANCEL" };
end

function SimpleChat_NameMenu(name)
	if ( not UnitPopupMenus or not UnitPopupMenus["CHATNAME"] ) then
		SimpleChat_Whisper(name);
		return;
	end
	SimpleChat_MenuName = name;
	UnitPopup_ShowMenu("CHATNAME", "player");
	UnitPopupTitle:SetText(name);
	local width = max(UnitPopup:GetWidth(), UnitPopupTitle:GetWidth() + 40);
	UnitPopup:SetWidth(width);
	-- At the cursor, kept inside the screen.
	-- (0.5.3 has no GetEffectiveScale; the probe frames give the scale)
	local kx, ky = SimpleChat_Measure();
	local x, y = GetCursorPosition();
	x = x * kx;
	y = y * ky;
	local height = UnitPopup:GetHeight();
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight();
	if ( x + width > sw ) then
		x = sw - width;
	end
	if ( y - height < 0 ) then
		y = height;
	end
	UnitPopup:ClearAllPoints();
	UnitPopup:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", x, y);
	SimpleChat_CatcherAt = GetTime() + 0.45;
end

SimpleChat_Orig_UnitPopup_OnClick = UnitPopup_OnClick;
function UnitPopup_OnClick(index)
	local which = UnitPopup and UnitPopup.which;
	local menu = which and UnitPopupMenus[which];
	local button = menu and menu[index];
	local name = SimpleChat_MenuName;
	if ( which == "CHATNAME" and button and name ) then
		if ( button == "CHAT_WHISPER" ) then
			SimpleChat_Whisper(name);
		elseif ( button == "CHAT_INVITE" ) then
			InviteByName(name);
		elseif ( button == "CHAT_FRIEND" ) then
			AddFriend(name);
		elseif ( button == "CHAT_WHO" ) then
			SimpleChat_Who(name);
		elseif ( button == "CHAT_IGNORE" ) then
			if ( SlashCmdList and SlashCmdList["IGNORE"] ) then
				SlashCmdList["IGNORE"](name);
			end
		end
		UnitPopup:Hide();
		return;
	end
	SimpleChat_Orig_UnitPopup_OnClick(index);
end


--------------------------------------------------------------------------------
-- Settings window (/sc or right-click a tab)
--------------------------------------------------------------------------------

function SimpleChat_ShowSettings(tab)
	SimpleChat_SettingsTab = tab or SimpleChat_Tab;
	SimpleChatSettingsFrame:Show();
	SimpleChat_Settings_Update();
end

function SimpleChat_Settings_Update()
	local tab = SimpleChat_SettingsTab;
	SimpleChatSettingsFrameTitle:SetText("Chat Settings: "..SimpleChat_TabNames[tab]);
	local i;
	for i = 1, SIMPLECHAT_NUM_GROUPS do
		local box = getglobal("SimpleChatSettingsGroup"..i);
		if ( tab == SIMPLECHAT_COMBAT_TAB ) then
			-- the Combat Log tab only shows the combat log
			box:Hide();
		else
			box:Show();
			if ( SimpleChat_Filters[tab][i] ) then
				box:SetChecked(1);
			else
				box:SetChecked(0);
			end
		end
	end
	SimpleChat_NameOld = SimpleChat_TabNames[tab];
	SimpleChatSettingsName:SetText(SimpleChat_TabNames[tab]);
	if ( SimpleChat_Locked ) then
		SimpleChatSettingsLock:SetChecked(1);
	else
		SimpleChatSettingsLock:SetChecked(0);
	end
	if ( SimpleChat_FlashWhispers ) then
		SimpleChatSettingsFlash:SetChecked(1);
	else
		SimpleChatSettingsFlash:SetChecked(0);
	end
	SimpleChat_DrawSlider();
	if ( SimpleSave_Set ) then
		SimpleChatSettingsDependency:SetText("");
	else
		SimpleChatSettingsDependency:SetText("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions. Install SimpleSave to keep them.");
	end
end

-- The name box: 0.5.3 has no OnEditFocusLost, so the name is taken (and
-- saved) with every letter typed; Enter also tidies the box, Esc gives the
-- old name back.
SimpleChat_NameOld = nil;
function SimpleChat_Settings_NameTyped()
	local tab = SimpleChat_SettingsTab;
	if ( not tab ) then
		return;
	end
	SimpleChat_SetTabName(tab, SimpleChatSettingsName:GetText());
	if ( SimpleChat_TabNames[tab] == SIMPLECHAT_DEFAULT_NAMES[tab] ) then
		SimpleChat_Save("Name"..tab, nil);
	else
		SimpleChat_Save("Name"..tab, SimpleChat_TabNames[tab]);
	end
	SimpleChatSettingsFrameTitle:SetText("Chat Settings: "..SimpleChat_TabNames[tab]);
end

function SimpleChat_Settings_NameApply()
	local tab = SimpleChat_SettingsTab;
	local name = SimpleChatSettingsName:GetText();
	SimpleChat_SetTabName(tab, name);
	if ( SimpleChat_TabNames[tab] == SIMPLECHAT_DEFAULT_NAMES[tab] ) then
		SimpleChat_Save("Name"..tab, nil);
	else
		SimpleChat_Save("Name"..tab, SimpleChat_TabNames[tab]);
	end
	SimpleChatSettingsName:SetText(SimpleChat_TabNames[tab]);
	SimpleChatSettingsFrameTitle:SetText("Chat Settings: "..SimpleChat_TabNames[tab]);
end

function SimpleChat_Settings_NameCancel()
	SimpleChatSettingsName:SetText(SimpleChat_NameOld or SimpleChat_TabNames[SimpleChat_SettingsTab]);
	SimpleChat_Settings_NameTyped();
	SimpleChatSettingsName:ClearFocus();
end

function SimpleChat_Settings_ToggleGroup(group)
	local tab = SimpleChat_SettingsTab;
	if ( SimpleChat_Filters[tab][group] ) then
		SimpleChat_Filters[tab][group] = nil;
	else
		SimpleChat_Filters[tab][group] = 1;
	end
	SimpleChat_Save("F"..tab, SimpleChat_FilterString(SimpleChat_Filters[tab]));
end

function SimpleChat_Settings_ToggleLock()
	if ( SimpleChat_Locked ) then
		SimpleChat_Locked = nil;
	else
		SimpleChat_Locked = 1;
	end
	SimpleChat_ApplyLock();
	SimpleChat_SaveFlag("Lock", SimpleChat_Locked);
end

function SimpleChat_Settings_ToggleFlash()
	if ( SimpleChat_FlashWhispers ) then
		SimpleChat_FlashWhispers = nil;
		SimpleChat_Flash[2] = nil;
	else
		SimpleChat_FlashWhispers = 1;
	end
	SimpleChat_SaveFlag("Flash", SimpleChat_FlashWhispers);
	SimpleChat_UpdateTabs();
end

-- Background slider (drawn by the addon, like SimpleMap's sliders).
SIMPLECHAT_SLIDER_PAD = 8;

function SimpleChat_DrawSlider()
	local bar = SimpleChatSettingsSlider;
	local travel = bar:GetWidth() - SIMPLECHAT_SLIDER_PAD * 2;
	SimpleChatSettingsSliderKnob:ClearAllPoints();
	SimpleChatSettingsSliderKnob:SetPoint("CENTER", "SimpleChatSettingsSlider", "LEFT", SIMPLECHAT_SLIDER_PAD + SimpleChat_Background / 100 * travel, 0);
	SimpleChatSettingsSliderValue:SetText(floor(SimpleChat_Background + 0.5).."%");
end

function SimpleChat_SliderCursorValue()
	local bar = SimpleChatSettingsSlider;
	local x = GetCursorPosition();
	local centerX = bar:GetCenter();
	local left = centerX - bar:GetWidth() / 2 + SIMPLECHAT_SLIDER_PAD;
	local travel = bar:GetWidth() - SIMPLECHAT_SLIDER_PAD * 2;
	if ( travel <= 0 ) then
		return 0;
	end
	return max(0, min(1, (x - left) / travel));
end

function SimpleChat_Slider_OnMouseDown()
	SimpleChat_ActiveSlider = 1;
	SimpleChat_Slider_Apply();
end

function SimpleChat_Slider_OnMouseUp()
	if ( SimpleChat_ActiveSlider ) then
		SimpleChat_ActiveSlider = nil;
		SimpleChat_Save("Bg", floor(SimpleChat_Background + 0.5));
	end
end

function SimpleChat_Slider_Apply()
	SimpleChat_Background = floor(SimpleChat_SliderCursorValue() * 100 + 0.5);
	SimpleChat_ApplyBackground();
	SimpleChat_DrawSlider();
	if ( SimpleSave_Set ) then
		SimpleChatSettingsDependency:SetText("");
	else
		SimpleChatSettingsDependency:SetText("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions. Install SimpleSave to keep them.");
	end
end

function SimpleChat_Settings_OnUpdate()
	if ( SimpleChat_ActiveSlider ) then
		SimpleChat_Slider_Apply();
	end
end


--------------------------------------------------------------------------------
-- Copy window: the last lines of the visible tab. Click a line to put it in
-- the copy box, then Ctrl+A and Ctrl+C.
--------------------------------------------------------------------------------

function SimpleChat_CopyButton_OnEnter()
	SimpleChat_OnEnterChat();
	SimpleChat_CopyHover = 1;
	this:SetAlpha(1.0);
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Copy chat lines");
	GameTooltip:Show();
end

function SimpleChat_CopyButton_OnLeave()
	SimpleChat_OnLeaveChat();
	SimpleChat_CopyHover = nil;
	this:SetAlpha(SimpleChat_UIAlpha * 0.6);
	GameTooltip:Hide();
end

function SimpleChat_ToggleCopy()
	if ( SimpleChatCopyFrame:IsVisible() ) then
		SimpleChatCopyFrame:Hide();
	else
		SimpleChatCopyFrame:Show();
		SimpleChat_Copy_Refresh(1);
	end
end

function SimpleChat_Copy_Refresh(toBottom)
	SimpleChat_CopyLines = SimpleChat_History[SimpleChat_Tab];
	local count = getn(SimpleChat_CopyLines);
	local maxOffset = max(0, count - SIMPLECHAT_COPY_ROWS);
	if ( toBottom ) then
		SimpleChat_CopyOffset = maxOffset;
	end
	SimpleChat_CopyOffset = SimpleChat_Clamp(SimpleChat_CopyOffset, 0, maxOffset);
	SimpleChatCopyFrameTitle:SetText("Copy: "..SimpleChat_TabNames[SimpleChat_Tab]);
	local i, row, line, index;
	for i = 1, SIMPLECHAT_COPY_ROWS do
		row = getglobal("SimpleChatCopyRow"..i);
		index = SimpleChat_CopyOffset + i;
		line = SimpleChat_CopyLines[index];
		if ( line ) then
			row.index = index;
			getglobal("SimpleChatCopyRow"..i.."Text"):SetText(SimpleChat_PlainText(line[1]));
			getglobal("SimpleChatCopyRow"..i.."Text"):SetTextColor(line[2], line[3], line[4]);
			row:Show();
		else
			row.index = nil;
			row:Hide();
		end
	end
	if ( count == 0 ) then
		SimpleChatCopyFrameInfo:SetText("No lines in this tab yet.");
	else
		SimpleChatCopyFrameInfo:SetText("Lines "..(SimpleChat_CopyOffset + 1).."-"..min(count, SimpleChat_CopyOffset + SIMPLECHAT_COPY_ROWS).." of "..count..". Mouse wheel scrolls. Click a line to copy it.");
	end
end

function SimpleChat_Copy_OnMouseWheel(value)
	if ( value > 0 ) then
		SimpleChat_CopyOffset = SimpleChat_CopyOffset - 3;
	else
		SimpleChat_CopyOffset = SimpleChat_CopyOffset + 3;
	end
	SimpleChat_Copy_Refresh();
end

function SimpleChat_CopyRow_OnClick()
	local line = this.index and SimpleChat_CopyLines[this.index];
	if ( not line ) then
		return;
	end
	SimpleChatCopyBox:SetText(SimpleChat_PlainText(line[1]));
	SimpleChatCopyBox:SetFocus();
	SimpleChatCopyHint:SetText("Ctrl+A, then Ctrl+C to copy");
end


--------------------------------------------------------------------------------
-- Turning SimpleChat off shows the stock chat again (for this session).
--------------------------------------------------------------------------------

function SimpleChat_SetEnabled(on)
	SimpleChat_Enabled = on;
	if ( not on ) then
		SimpleChat_Drag = nil;
		SimpleChatSettingsFrame:Hide();
		SimpleChatCopyFrame:Hide();
	end
	SimpleChat_ApplyAll();
	if ( on ) then
		SimpleChat_Print("on.");
	else
		SimpleChat_Print("off for this session (stock chat). /sc on turns it back on.");
	end
end


--------------------------------------------------------------------------------
-- Events, update, slash command
--------------------------------------------------------------------------------

function SimpleChat_OnLoad()
	local i;
	for i = 1, SIMPLECHAT_NUM_TABS do
		SimpleChat_Filters[i] = SimpleChat_ParseFilter(nil, SIMPLECHAT_DEFAULT_FILTERS[i]);
	end
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	SlashCmdList["SIMPLECHAT"] = SimpleChat_Slash;
	SLASH_SIMPLECHAT1 = "/sc";
	SLASH_SIMPLECHAT2 = "/simplechat";
end

-- With AlphaUI: our Copy button replaces AlphaUI's Chat Copy "+" button, and
-- AlphaUI stops keeping its own copy of the chat. AlphaUI's setting is not
-- changed; without SimpleChat its button is back.
function SimpleChat_HideAlphaUICopy()
	if ( MainChatCopyButton and not SimpleChat_AlphaCopyHidden ) then
		SimpleChat_AlphaCopyHidden = 1;
		MainChatCopyButton:Hide();
		MainChatCopyButton.Show = function() end;
		if ( MainChatCopyFrame ) then
			MainChatCopyFrame:Hide();
		end
	end
	if ( Main and Main.IsModuleEnabled and not SimpleChat_AlphaEnabledWrapped ) then
		SimpleChat_AlphaEnabledWrapped = 1;
		local original = Main.IsModuleEnabled;
		Main.IsModuleEnabled = function(id)
			if ( id == "chat_copy" ) then
				return false;
			end
			return original(id);
		end;
		Main.ChatCopyContents = nil;
	end
end

function SimpleChat_OnEvent(event)
	if ( event == "PLAYER_ENTERING_WORLD" and not SimpleChat_Started ) then
		SimpleChat_Started = 1;
		SimpleChat_HideAlphaUICopy();
		SimpleChat_ClearStock();
		SimpleChat_ClearTime = GetTime();
		SimpleChat_RebuildAt = GetTime() + 3;
		-- Safety: lines wait at most 10 seconds for the saved size.
		SimpleChat_FlushAt = GetTime() + 10;
		-- Show the General tab at once; saved settings follow when read.
		SimpleChat_SelectTab(1);
		if ( SimpleSave_RegisterLoad ) then
			SimpleSave_RegisterLoad(SimpleChat_LoadSettings);
		else
			SimpleChat_LoadSettings();
			SimpleChat_Print("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions.");
		end
	end
end

-- The dark bar behind the input line is shown while the line is.
function SimpleChat_UpdateInputBack()
	if ( not SimpleChatInputBack or not ChatFrameEditBox ) then
		return;
	end
	if ( ChatFrameEditBox:IsVisible() ) then
		if ( not SimpleChatInputBack:IsVisible() ) then
			SimpleChatInputBack:Show();
		end
	elseif ( SimpleChatInputBack:IsVisible() ) then
		SimpleChatInputBack:Hide();
	end
end

function SimpleChat_OnUpdate(elapsed)
	SimpleChat_UpdateInputBack();
	if ( SimpleChat_FlushAt and GetTime() >= SimpleChat_FlushAt ) then
		SimpleChat_Flush();
	end
	if ( SimpleChat_RebuildAt and GetTime() >= SimpleChat_RebuildAt ) then
		SimpleChat_RebuildAt = nil;
		SimpleChat_RebuildAll();
	end
	if ( SimpleChat_CatcherAt and GetTime() >= SimpleChat_CatcherAt ) then
		SimpleChat_CatcherAt = nil;
		if ( SimpleChatMenuCatcher and UnitPopup and UnitPopup:IsVisible() and UnitPopup.which == "CHATNAME" ) then
			SimpleChatMenuCatcher:Show();
		end
	end
	if ( SimpleChatMenuCatcher and SimpleChatMenuCatcher:IsVisible() and not (UnitPopup and UnitPopup:IsVisible()) ) then
		SimpleChatMenuCatcher:Hide();
	end
	if ( SimpleHello_Tick ) then
		SimpleHello_Tick();
	end
	if ( SimpleChat_TabPress and not SimpleChat_Drag and SimpleChat_TabPress[2] == "LeftButton" and not SimpleChat_Locked ) then
		local x, y = GetCursorPosition();
		if ( SimpleChat_Abs(x - SimpleChat_TabPress[3]) + SimpleChat_Abs(y - SimpleChat_TabPress[4]) > 6 ) then
			SimpleChat_StartDrag("move");
			-- Keep the starting point, so the chat does not jump.
			SimpleChat_Drag[2] = SimpleChat_TabPress[3];
			SimpleChat_Drag[3] = SimpleChat_TabPress[4];
		end
	end
	if ( SimpleChat_Drag ) then
		SimpleChat_UpdateDrag();
	end
	if ( SimpleChat_Started and GetTime() - SimpleChat_ClearTime > 2 ) then
		SimpleChat_ClearTime = GetTime();
		if ( ChatFrame.Clear ) then
			SimpleChat_ClearStock();
		end
		-- Follow size changes made by other addons (only does work on a change).
		SimpleChat_ApplyFrameSizes();
	end
	if ( SimpleChat_UpdateFade(elapsed) ) then
		SimpleChat_UpdateTabs();
	end
	SimpleChat_FlashTime = SimpleChat_FlashTime + (elapsed or 0);
	if ( SimpleChat_FlashTime >= 0.5 ) then
		SimpleChat_FlashTime = 0;
		-- The tabs are only redrawn for a blinking tab, not twice a second
		-- for nothing.
		local flashing, i = nil, 1;
		while ( i <= SIMPLECHAT_NUM_TABS ) do
			if ( SimpleChat_Flash[i] ) then
				flashing = 1;
				break;
			end
			i = i + 1;
		end
		if ( flashing ) then
			if ( SimpleChat_FlashOn ) then
				SimpleChat_FlashOn = nil;
			else
				SimpleChat_FlashOn = 1;
			end
			SimpleChat_UpdateTabs();
		elseif ( SimpleChat_FlashOn ) then
			SimpleChat_FlashOn = nil;
			SimpleChat_UpdateTabs();
		end
	end
end

function SimpleChat_Slash(msg)
	local simpleVersionAsk = strlower(gsub(msg or "", "%s", ""));
	if ( simpleVersionAsk == "v" or simpleVersionAsk == "version" ) then
		ChatFrame:AddMessage("SimpleChat "..SIMPLECHAT_VERSION, 1.0, 0.82, 0.0);
		return;
	end
	msg = strlower(msg or "");
	if ( msg == "copy" ) then
		SimpleChat_ToggleCopy();
	elseif ( msg == "reset" ) then
		SimpleChat_ResetPosition();
		SimpleChat_Print("position and size reset.");
	elseif ( msg == "off" ) then
		SimpleChat_SetEnabled(nil);
	elseif ( msg == "on" ) then
		SimpleChat_SetEnabled(1);
	elseif ( msg == "lock" ) then
		SimpleChat_Settings_ToggleLock();
		if ( SimpleChat_Locked ) then
			SimpleChat_Print("chat locked.");
		else
			SimpleChat_Print("chat unlocked.");
		end
	elseif ( msg == "help" ) then
		SimpleChat_Print("version "..SIMPLECHAT_VERSION..". /sc = settings, /sc copy, /sc lock, /sc reset (position and size), /sc off, /sc on");
	else
		if ( SimpleChatSettingsFrame:IsVisible() ) then
			SimpleChatSettingsFrame:Hide();
		else
			SimpleChat_ShowSettings(SimpleChat_Tab);
		end
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
