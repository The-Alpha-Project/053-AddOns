--------------------------------------------------------------------------------
-- SimpleQoL for WoW 0.5.3
--
-- Small quality-of-life helpers, each with its own check box (/qol):
--   quest tracker (on by default), quick loot, loot window at the mouse,
--   sell grey items, restock items, decline duels, accept group invites,
--   decline guild invites, accept resurrection, quick quests, right-click
--   into the trade window, target health/mana numbers, Alt self cast and
--   auto attack when you are attacked.
-- Everything except the quest tracker is off until you turn it on.
-- Settings are saved with SimpleSave (addon "SimpleQoL").
--
-- Lua 5.0 rules for this client: no string methods, no # or % operators,
-- no pairs/ipairs/type, ASCII only.
--------------------------------------------------------------------------------

SIMPLEQOL_VERSION = "3.07";

-- Feature list: key, label, default (1 = on), tooltip. Order = check boxes.
SIMPLEQOL_FEATURES = {
	{ "tracker",   "Show quest tracker", 1, "Lists tracked quests on screen. Shift-click a quest in the quest log to track it; Shift + drag the title to move the list." },
	{ "questshare", "Show party quest progress", 1, "Shows your party's progress on the selected quest (they need SimpleQoL)." },
	{ "quests",    "Auto accept and finish quests", nil, "Accepts and completes quests at once. Hold Shift to read the quest." },
	{ "quickloot", "Loot everything at once", 1, "Loots everything at once. Hold Shift to choose." },
	{ "sellgrey",  "Sell grey items at merchants", nil, "Sells grey items when you talk to a merchant." },
	{ "restock",   "Restock items at merchants", nil, "Buys what is missing from the list below at merchants." },
	{ "clams",     "Open clams automatically", 1, "Opens and loots clams while you are idle." },
	{ "compare",   "Compare with worn items", 1, "Shows the item you wear next to item tooltips." },
	{ "bagslots",  "Show free bag slots", 1, "Shows free slots on the backpack and ammo on quivers and pouches." },
	{ "trade",     "Right-click to trade items", 1, "Right-click an item in your bags to add it to the trade." },
	{ "res",       "Auto accept resurrection", 1, "Accepts resurrection at once." },
	{ "invfriend", "Auto accept friends' invites", 1, "Accepts group invites from your friends." },
	{ "invall",    "Auto accept all invites", nil, "Accepts every group invite." },
	{ "duel",      "Decline duels and guild invites", nil, "Declines duel requests and guild invites." },
	{ "guildonline", "Show login and logout messages", 1, "Shows when guild members and players with our addons log in or out." },
	{ "guildtab",  "Show Guild tab in Friends", 1, "Adds a Guild tab to the Friends window." },
	{ "share",     "Share position (faction)", 1, "Shares your position with every SimpleQoL user who shares too, and shows theirs on the minimap and map. Wins over the guild setting." },
	{ "attack",    "Auto attack when hit", 1, "Targets the nearest enemy and attacks when you are hit. Never interrupts spells." },
	{ "autotarget", "Auto target nearest enemy", nil, "An attack without a target first targets the nearest enemy." },
	{ "selfcast",  "Self cast without a target", 1, "Heals and buffs go to you when you have no friendly target. Hold Alt to self cast anything." },
	{ "errors",    "Hide repeated error messages", 1, "Hides repeated errors like \"Spell is not ready yet\"; in combat also \"Out of range\"." },
	{ "keepstealth", "Keep stealth on re-press", 1, "Pressing Stealth again does not break it. Shift + press leaves stealth." },
	{ "dismount",  "Auto Dismount", nil, "Dismounts when something fails because you are mounted, then uses it again." },
	{ "weapontimer", "Show buff timers", 1, "Shows the time left under your buffs and debuffs (minutes from a minute up), and poisons, oils and stones on your weapons." },
	{ "autoheal",  "Use Bloodstone at low health", nil, "In combat at the health % in the box: uses a Bloodstone or a healing potion." },
	{ "shield",    "Emergency Shield", nil, "In combat at the health % in the box: casts your emergency spell." },
	{ "evasion",   "Emergency Evasion", nil, "In combat at the health % in the box: casts Evasion." },
	{ "stats",     "Show health and mana numbers", 1, "Shows numbers on the target and party health and mana bars." },
	{ "perf",      "Show FPS and ping", nil, "Shows frame rate and latency. Shift + drag to move." },
	{ "xpkills",   "Show kills to next level", nil, "Shows about how many kills you need to level up." },
	{ "moveframes", "Move frames with Shift + drag", 1, "Shift + drag unit frames, the minimap and AlphaUI's bag to move them." },
	{ "trainer",   "Trainer: select next skill", 1, "After Train, the next skill you can learn is selected." },
	{ "actionbars", "ActionBars (extra bars)", 1, "Extra action bars (settings: /ab). Takes effect at next login." },
	{ "tradeskillplus", "TradeSkillPlus (craft many)", 1, "Craft several items at once. Takes effect at next login." },
	{ "errorframe", "ImprovedErrorFrame (errors)", 1, "Lua errors in one window instead of popups (/errors). Takes effect at next login." },
	{ "nameplates", "Always show name plates", nil, "Shows name plates all the time, so you do not have to hold V." },
	{ "shareguild", "Share position (guild)", 1, "Shares your position with your guild only (SimpleQoL users who share too). Not needed when Share position (faction) is on." },
	{ "clock",     "Show clock", nil, "Shows the time next to FPS and Ping (same place, Shift + drag to move). Not used when AlphaUI's clock is on." },
	{ "targetdist", "Show target distance", 1, "Shows the distance to your target in yards above its portrait. Replaces AlphaUI's Target Distance, which stays off while SimpleQoL is installed." },
	{ "auioff", "Turn off AlphaUI Class Portraits and Clock", 1, "With AlphaUI: turns off its Class Portraits and Clock at login on every character (the normal portraits and our clock setting are used). Turn this off to use them." },
};
SIMPLEQOL_NUM_FEATURES = 40;
SIMPLEQOL_RESTOCK_ROWS = 3;        -- rows shown; more items scroll
SimpleQoL_RestockOffset = 0;
SIMPLEQOL_PCT_MIN = 1;             -- low health percent boxes (Bloodstone, emergency shield)
SIMPLEQOL_PCT_MAX = 100;
SIMPLEQOL_PCT_DEFAULT = 10;
SimpleQoL_Pct = { Heal = 10, Shield = 10, Evasion = 10 };

SimpleQoL_On = {};                 -- SimpleQoL_On[key] = 1 when the feature is on
SimpleQoL_Restock = {};            -- list of { name, amount }
SimpleQoL_Tracked = {};            -- list of quest titles (per character)
SimpleQoL_TrackerX = nil;          -- tracker top left, SetPoint units from the screen's bottom left
SimpleQoL_TrackerY = nil;
SimpleQoL_Loaded = nil;

SimpleQoL_Attacking = nil;
SimpleQoL_AttackTime = 0;
SimpleQoL_TrackerDirty = 1;
SimpleQoL_TrackerTime = 0;
SimpleQoL_TrackerBusy = nil;
SimpleQoL_TrackerDrag = nil;
SimpleQoL_SellPending = nil;
SimpleQoL_MoneyBefore = nil;

SIMPLEQOL_TRACKER_LINES = 40;


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function SimpleQoL_Print(text)
	if ( ChatFrame ) then
		ChatFrame:AddMessage("SimpleQoL: "..text, 1.0, 0.82, 0.0);
	end
end

function SimpleQoL_Abs(value)
	if ( value < 0 ) then
		return -value;
	end
	return value;
end

-- "|cff...|Hitem:..|h[Linen Cloth]|h|r" -> "Linen Cloth"
function SimpleQoL_LinkName(link)
	if ( not link ) then
		return nil;
	end
	local _, _, name = strfind(link, "%[(.-)%]");
	return name;
end

-- Number of an item (by name) in the bags.
function SimpleQoL_CountItem(name)
	local count = 0;
	local bag, slot;
	for bag = 0, 4 do
		local slots = GetContainerNumSlots(bag) or 0;
		for slot = 1, slots do
			if ( SimpleQoL_LinkName(GetContainerItemLink(bag, slot)) == name ) then
				local _, itemCount = GetContainerItemInfo(bag, slot);
				count = count + (itemCount or 1);
			end
		end
	end
	return count;
end

function SimpleQoL_IsFriend(name)
	if ( not GetNumFriends or not name ) then
		return nil;
	end
	local i;
	for i = 1, GetNumFriends() do
		if ( GetFriendInfo(i) == name ) then
			return 1;
		end
	end
	return nil;
end

-- Converts cursor/GetCenter units to SetPoint units with a box of known size
-- (see SimpleMap: 0.5.3 reports positions in another scale).
function SimpleQoL_Scale()
	local x1, y1 = SimpleQoLProbeBoxTopLeft:GetCenter();
	local x2, y2 = SimpleQoLProbeBoxBottomRight:GetCenter();
	if ( not x1 or not x2 or SimpleQoL_Abs(x2 - x1) < 10 ) then
		return 1;
	end
	return 98 / SimpleQoL_Abs(x2 - x1);
end

-- Screen position (cursor units) -> SetPoint units from the bottom left.
function SimpleQoL_ToScreen(x, y)
	local k = SimpleQoL_Scale();
	local sx, sy = SimpleQoLProbeScreen:GetCenter();
	if ( not sx ) then
		return x, y;
	end
	-- The screen probe's center sits 1 unit inside the corner.
	return (x - sx) * k + 1, (y - sy) * k + 1;
end


--------------------------------------------------------------------------------
-- Quit fix
--------------------------------------------------------------------------------

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
-- Saving (SimpleSave)
--------------------------------------------------------------------------------

function SimpleQoL_SetDefaults()
	local i;
	for i = 1, SIMPLEQOL_NUM_FEATURES do
		SimpleQoL_On[SIMPLEQOL_FEATURES[i][1]] = SIMPLEQOL_FEATURES[i][3];
	end
end

function SimpleQoL_Load()
	SimpleQoL_SetDefaults();
	if ( SimpleSave_Get ) then
		local i, key, value;
		for i = 1, SIMPLEQOL_NUM_FEATURES do
			key = SIMPLEQOL_FEATURES[i][1];
			value = SimpleSave_Get("SimpleQoL", key);
			if ( value == "1" ) then
				SimpleQoL_On[key] = 1;
			elseif ( value == "0" ) then
				SimpleQoL_On[key] = nil;
			end
		end
		SimpleQoL_Restock = SimpleQoL_ParseRestock(SimpleSave_Get("SimpleQoL", "Buy", ""));
		-- Tracked quests: "$" and a 5-letter code per quest title (per
		-- character). They are tracked again when the quest log is read.
		local tracked = SimpleSave_GetChar("SimpleQoL", "Track", "");
		SimpleQoL_TrackRestore = nil;
		if ( strsub(tracked, 1, 1) == "$" ) then
			SimpleQoL_TrackRestore = {};
			local k;
			for k = 2, strlen(tracked) - 4, 5 do
				SimpleQoL_TrackRestore[strsub(tracked, k, k + 4)] = 1;
			end
		elseif ( tracked ~= "" ) then
			SimpleSave_SetChar("SimpleQoL", "Track", nil);
		end
		SimpleQoL_Pct.Heal = SimpleQoL_ClampPct(SimpleSave_GetNumber("SimpleQoL", "HealPct", SIMPLEQOL_PCT_DEFAULT));
		SimpleQoL_Pct.Shield = SimpleQoL_ClampPct(SimpleSave_GetNumber("SimpleQoL", "ShieldPct", SIMPLEQOL_PCT_DEFAULT));
		SimpleQoL_Pct.Evasion = SimpleQoL_ClampPct(SimpleSave_GetNumber("SimpleQoL", "EvasionPct", SIMPLEQOL_PCT_DEFAULT));
		SimpleQoL_TrackerX = SimpleSave_GetNumber("SimpleQoL", "TrackX");
		SimpleQoL_TrackerY = SimpleSave_GetNumber("SimpleQoL", "TrackY");
	end
	SimpleQoL_Loaded = 1;
	if ( SimpleQoL_AutoTrackLoad ) then
		SimpleQoL_AutoTrackLoad();
	end
	if ( not SimpleQoL_Greeted ) then
		SimpleQoL_Greeted = 1;
		SimpleQoL_Print("Type /qol for settings");
	end
	if ( SimpleQoL_FramesLoaded ) then
		SimpleQoL_FramesLoaded();
	end
	if ( SimpleQoL_ExtraLoaded ) then
		SimpleQoL_ExtraLoaded();
	end
	if ( SimpleQoL_NameplatesApply ) then
		SimpleQoL_NameplatesApply();
	end
	SimpleQoL_PlaceTracker();
	SimpleQoL_TrackerDirty = 1;
	SimpleQoL_UpdateStats();
end

-- Only a value that differs from the default is saved (saves space; a
-- missing value means the default).
SimpleQoL_FeatureDefault = nil;
function SimpleQoL_SaveFeature(key)
	if ( not SimpleSave_Set ) then
		return;
	end
	if ( not SimpleQoL_FeatureDefault ) then
		SimpleQoL_FeatureDefault = {};
		local i;
		for i = 1, SIMPLEQOL_NUM_FEATURES do
			SimpleQoL_FeatureDefault[SIMPLEQOL_FEATURES[i][1]] = SIMPLEQOL_FEATURES[i][3];
		end
	end
	local on = SimpleQoL_On[key] and 1 or nil;
	if ( on == SimpleQoL_FeatureDefault[key] ) then
		SimpleSave_Set("SimpleQoL", key, nil);
	elseif ( on ) then
		SimpleSave_Set("SimpleQoL", key, "1");
	else
		SimpleSave_Set("SimpleQoL", key, "0");
	end
end

-- "Soul Shard=20;Linen Bandage=10"
function SimpleQoL_ParseRestock(text)
	local list = {};
	local start = 1;
	local stop, part, name, amount, s, e;
	while ( text and start <= strlen(text) ) do
		stop = strfind(text, ";", start, 1);
		if ( stop ) then
			part = strsub(text, start, stop - 1);
			start = stop + 1;
		else
			part = strsub(text, start);
			start = strlen(text) + 1;
		end
		s, e, name, amount = strfind(part, "^(.+)=(%d+)$");
		if ( name ) then
			tinsert(list, { name, amount + 0 });
		end
	end
	return list;
end

function SimpleQoL_SaveRestock()
	if ( not SimpleSave_Set ) then
		return;
	end
	local text = "";
	local i;
	for i = 1, getn(SimpleQoL_Restock) do
		if ( i > 1 ) then
			text = text..";";
		end
		text = text..SimpleQoL_Restock[i][1].."="..SimpleQoL_Restock[i][2];
	end
	if ( text == "" ) then
		SimpleSave_Set("SimpleQoL", "Buy", nil);
	else
		SimpleSave_Set("SimpleQoL", "Buy", text);
	end
end

-- Tracked quests only live for the session (not saved between sessions).
function SimpleQoL_SaveTracked()
	if ( not SimpleSave_SetChar or not SimpleQoL_KnownCode ) then
		return;
	end
	local text = "$";
	local i;
	for i = 1, getn(SimpleQoL_Tracked) do
		text = text..SimpleQoL_KnownCode(SimpleQoL_Tracked[i]);
	end
	if ( text == "$" ) then
		text = nil;
	end
	SimpleSave_SetChar("SimpleQoL", "Track", text);
end


--------------------------------------------------------------------------------
-- Quest tracker
--------------------------------------------------------------------------------

function SimpleQoL_TrackIndex(title)
	local i;
	for i = 1, getn(SimpleQoL_Tracked) do
		if ( SimpleQoL_Tracked[i] == title ) then
			return i;
		end
	end
	return nil;
end

function SimpleQoL_ToggleTrack(title)
	local index = SimpleQoL_TrackIndex(title);
	if ( index ) then
		tremove(SimpleQoL_Tracked, index);
	else
		tinsert(SimpleQoL_Tracked, title);
	end
	SimpleQoL_SaveTracked();
	SimpleQoL_TrackerDirty = 1;
	SimpleQoL_TrackerTime = 0;
	if ( SimpleQoL_UpdateQuestChecks and QuestLogFrame and QuestLogFrame:IsVisible() ) then
		SimpleQoL_UpdateQuestChecks();
	end
end

-- Shift-click a quest in the quest log: track / untrack it.
SimpleQoL_Orig_QuestLogTitleButton_OnClick = QuestLogTitleButton_OnClick;
function QuestLogTitleButton_OnClick(button)
	if ( button == "LeftButton" and IsShiftKeyDown() and SimpleQoL_On["tracker"]
			and not (ChatFrameEditBox and ChatFrameEditBox:IsVisible()) ) then
		-- The button id is the row (1-6); add the scroll offset for the quest.
		local index = this:GetID();
		if ( FauxScrollFrame_GetOffset and QuestLogListScrollFrame ) then
			index = index + FauxScrollFrame_GetOffset(QuestLogListScrollFrame);
		end
		local title, level, tag, isHeader = GetQuestLogTitle(index);
		if ( title and not isHeader ) then
			SimpleQoL_ToggleTrack(title);
		end
	end
	SimpleQoL_Orig_QuestLogTitleButton_OnClick(button);
end

function SimpleQoL_DifficultyColor(level)
	local player = UnitLevel("player") or 1;
	if ( not level or not QuestDifficultyColor ) then
		return 1.0, 0.82, 0.0;
	end
	local color;
	if ( level < player - 5 ) then
		color = QuestDifficultyColor["trivial"];
	elseif ( level <= player ) then
		color = QuestDifficultyColor["standard"];
	elseif ( level <= player + 5 ) then
		color = QuestDifficultyColor["difficult"];
	else
		color = QuestDifficultyColor["verydifficult"];
	end
	if ( not color ) then
		return 1.0, 0.82, 0.0;
	end
	return color.r, color.g, color.b;
end

-- Builds the lines: { text, r, g, b, gapBefore }
function SimpleQoL_TrackerLines()
	local lines = {};
	local numEntries = GetNumQuestLogEntries();
	local selected = GetQuestLogSelection and GetQuestLogSelection();
	local found = {};
	local collapsed = nil;
	local i, j;
	for i = 1, numEntries do
		local title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i);
		if ( isHeader and isCollapsed ) then
			collapsed = 1;
		end
		-- Saved from the last session: tracked again.
		if ( title and not isHeader and SimpleQoL_TrackRestore and SimpleQoL_TrackRestore[SimpleQoL_KnownCode(title)] and not SimpleQoL_TrackIndex(title) ) then
			tinsert(SimpleQoL_Tracked, title);
		end
		if ( title and not isHeader and SimpleQoL_TrackIndex(title) ) then
			found[title] = 1;
			local r, g, b = SimpleQoL_DifficultyColor(level);
			tinsert(lines, { "["..(level or "?").."] "..title, r, g, b, 1 });
			SelectQuestLogEntry(i);
			local count = GetNumQuestLeaderBoards() or 0;
			local done = 0;
			for j = 1, count do
				local text, kind, finished = GetQuestLogLeaderBoard(j);
				if ( not text or text == "" ) then
					text = kind or "";
				end
				if ( finished ) then
					done = done + 1;
					tinsert(lines, { " - "..text, 0.6, 0.6, 0.6 });
				else
					tinsert(lines, { " - "..text, 1.0, 1.0, 1.0 });
				end
			end
			if ( isComplete == 1 or (count > 0 and done == count) ) then
				tinsert(lines, { " - Ready to turn in", 0.2, 1.0, 0.2 });
			end
		end
	end
	-- Put the quest log selection back (0 = nothing was selected).
	if ( selected ) then
		SelectQuestLogEntry(selected);
	end
	-- Quests that left the log (turned in or abandoned) stop being tracked.
	-- Quests under a collapsed header cannot be seen, so then nothing is removed.
	if ( not collapsed ) then
		local changed = SimpleQoL_TrackRestore and 1;
		SimpleQoL_TrackRestore = nil;
		for i = getn(SimpleQoL_Tracked), 1, -1 do
			if ( not found[SimpleQoL_Tracked[i]] ) then
				tremove(SimpleQoL_Tracked, i);
				changed = 1;
			end
		end
		if ( changed ) then
			SimpleQoL_SaveTracked();
		end
	end
	return lines;
end

function SimpleQoL_UpdateTracker()
	SimpleQoL_TrackerDirty = nil;
	SimpleQoL_TrackerTime = GetTime();
	if ( not SimpleQoL_On["tracker"] or (getn(SimpleQoL_Tracked) == 0 and not SimpleQoL_TrackRestore) ) then
		SimpleQoLTracker:Hide();
		return;
	end
	SimpleQoL_TrackerBusy = 1;
	local lines = SimpleQoL_TrackerLines();
	SimpleQoL_TrackerBusy = nil;
	SimpleQoL_TrackerBusyTime = GetTime();
	if ( getn(lines) == 0 ) then
		SimpleQoLTracker:Hide();
		return;
	end
	local quests = 0;
	local numEntries = GetNumQuestLogEntries();
	local i;
	for i = 1, numEntries do
		local title, level, tag, isHeader = GetQuestLogTitle(i);
		if ( title and not isHeader ) then
			quests = quests + 1;
		end
	end
	SimpleQoLTrackerHeaderText:SetText("Quests ("..quests.."/"..(MAX_QUESTS or 16)..")");
	if ( SimpleQoL_TrackerCollapsed ) then
		SimpleQoLTrackerCollapseIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up");
	else
		SimpleQoLTrackerCollapseIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up");
	end
	local previous = "SimpleQoLTrackerHeader";
	local shown = 0;
	for i = 1, SIMPLEQOL_TRACKER_LINES do
		local line = getglobal("SimpleQoLTrackerLine"..i);
		local data = lines[i];
		if ( SimpleQoL_TrackerCollapsed ) then
			data = nil;
		end
		if ( data and i == SIMPLEQOL_TRACKER_LINES and getn(lines) > SIMPLEQOL_TRACKER_LINES ) then
			data = { "...", 1.0, 0.82, 0.0, 1 };
		end
		if ( data ) then
			local gap = -1;
			if ( data[5] ) then
				gap = -8;
			end
			line:ClearAllPoints();
			line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, gap);
			line:SetText(data[1]);
			line:SetTextColor(data[2], data[3], data[4]);
			line:Show();
			previous = "SimpleQoLTrackerLine"..i;
			shown = shown + 1;
		else
			line:Hide();
		end
	end
	SimpleQoLTracker:Show();
end

function SimpleQoL_PlaceTracker()
	SimpleQoLTracker:ClearAllPoints();
	if ( SimpleQoL_TrackerX and SimpleQoL_TrackerY ) then
		SimpleQoLTracker:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", SimpleQoL_TrackerX, SimpleQoL_TrackerY);
	else
		SimpleQoLTracker:SetPoint("TOPRIGHT", "UIParent", "TOPRIGHT", -110, -220);
	end
end

-- Shift + drag the "Quests" line to move the tracker.
-- A plain click on the header line (or its +/-) folds / unfolds the list.
function SimpleQoL_TrackerHeader_OnMouseDown(button)
	SimpleQoL_TrackerClick = nil;
	if ( button ~= "LeftButton" ) then
		return;
	end
	if ( not IsShiftKeyDown() ) then
		SimpleQoL_TrackerToggleCollapse();
		return;
	end
	local cx, cy = GetCursorPosition();
	local tx, ty = SimpleQoLTrackerProbe:GetCenter();
	local x, y = SimpleQoL_ToScreen(tx, ty);
	-- The probe's center is 1 unit right and below the tracker's corner.
	SimpleQoL_TrackerDrag = { cx, cy, x - 1, y + 1, SimpleQoL_Scale() };
end

function SimpleQoL_TrackerHeader_OnMouseUp()
	if ( SimpleQoL_TrackerClick ) then
		SimpleQoL_TrackerClick = nil;
		SimpleQoL_TrackerToggleCollapse();
		return;
	end
	if ( SimpleQoL_TrackerDrag ) then
		SimpleQoL_TrackerDrag = nil;
		if ( SimpleSave_Set and SimpleQoL_TrackerX ) then
			SimpleSave_Set("SimpleQoL", "TrackX", floor(SimpleQoL_TrackerX + 0.5));
			SimpleSave_Set("SimpleQoL", "TrackY", floor(SimpleQoL_TrackerY + 0.5));
		end
	end
end

function SimpleQoL_TrackerDragUpdate()
	local drag = SimpleQoL_TrackerDrag;
	local cx, cy = GetCursorPosition();
	SimpleQoL_TrackerX = drag[3] + (cx - drag[1]) * drag[5];
	SimpleQoL_TrackerY = drag[4] + (cy - drag[2]) * drag[5];
	SimpleQoL_PlaceTracker();
end

-- The +/- button folds the tracker to its header line (not saved).
function SimpleQoL_TrackerToggleCollapse()
	if ( SimpleQoL_TrackerCollapsed ) then
		SimpleQoL_TrackerCollapsed = nil;
	else
		SimpleQoL_TrackerCollapsed = 1;
	end
	SimpleQoL_UpdateTracker();
end

function SimpleQoL_TrackerHeader_OnEnter()
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Quest tracker");
	GameTooltip:AddLine("|cffffffffShift-click a quest in the quest log to track or untrack it.|r");
	GameTooltip:AddLine("|cffffffffClick here to fold or unfold the list.|r");
	GameTooltip:AddLine("|cffffffffShift + drag here to move.|r");
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- Loot
--------------------------------------------------------------------------------

-- 1 when an AlphaUI module (and optionally one of its settings) is on, so the
-- same feature here stays off and nothing is done twice.
function SimpleQoL_AlphaUIHas(module, setting)
	if ( not Main or not Main.IsModuleEnabled or not Main.IsModuleEnabled(module) ) then
		return nil;
	end
	if ( setting and Main.GetBoolSetting ) then
		return Main.GetBoolSetting(setting, true);
	end
	return 1;
end

function SimpleQoL_LootOpened()
	if ( SimpleQoL_ClamLooting ) then
		-- A clam opened by "Open clams automatically": take everything.
		SimpleQoL_ClamLooting = nil;
		if ( not SimpleQoL_AlphaUIHas("client_tweaks", "client_auto_loot") ) then
			local n;
			for n = GetNumLootItems(), 1, -1 do
				LootSlot(n);
			end
		end
		return;
	end
	if ( SimpleQoL_On["quickloot"] and not IsShiftKeyDown() and not SimpleQoL_AlphaUIHas("client_tweaks", "client_auto_loot") ) then
		local i;
		for i = GetNumLootItems(), 1, -1 do
			LootSlot(i);
		end
	end
	if ( SimpleQoL_On["quickloot"] ) then
		SimpleQoL_PendingLootMove = 1;
	end
end

-- One frame after LOOT_OPENED (the stock code places the window first).
function SimpleQoL_MoveLoot()
	SimpleQoL_PendingLootMove = nil;
	if ( not LootFrame:IsVisible() ) then
		return;
	end
	local x, y = SimpleQoL_ToScreen(GetCursorPosition());
	LootFrame:ClearAllPoints();
	-- The first loot button sits about 60 right and 90 down from the corner.
	LootFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", max(0, x - 60), y + 90);
end


--------------------------------------------------------------------------------
-- Merchant: sell grey items, restock
--------------------------------------------------------------------------------

function SimpleQoL_IsGrey(bag, slot)
	local texture, count, locked, quality = GetContainerItemInfo(bag, slot);
	if ( not texture or locked ) then
		return nil;
	end
	if ( quality ) then
		return quality == 0;
	end
	local link = GetContainerItemLink(bag, slot);
	return link and strfind(link, "|cff9d9d9d", 1, 1);
end

function SimpleQoL_SellGrey()
	local sold = 0;
	local bag, slot;
	if ( GetMoney ) then
		SimpleQoL_MoneyBefore = GetMoney();
	end
	for bag = 0, 4 do
		local slots = GetContainerNumSlots(bag) or 0;
		for slot = 1, slots do
			if ( SimpleQoL_IsGrey(bag, slot) ) then
				UseContainerItem(bag, slot);
				sold = sold + 1;
			end
		end
	end
	if ( sold > 0 ) then
		SimpleQoL_SoldCount = sold;
		SimpleQoL_SellPending = GetTime() + 1.5;
	end
end

function SimpleQoL_ReportSale()
	SimpleQoL_SellPending = nil;
	local text = "sold "..SimpleQoL_SoldCount.." grey item(s)";
	if ( GetMoney and SimpleQoL_MoneyBefore ) then
		local gained = GetMoney() - SimpleQoL_MoneyBefore;
		if ( gained > 0 ) then
			text = text.." for "..SimpleQoL_MoneyText(gained);
		end
	end
	SimpleQoL_Print(text..".");
end

function SimpleQoL_MoneyText(copper)
	local gold = floor(copper / 10000);
	local silver = floor((copper - gold * 10000) / 100);
	local rest = copper - gold * 10000 - silver * 100;
	local text = "";
	if ( gold > 0 ) then
		text = gold.."g ";
	end
	if ( gold > 0 or silver > 0 ) then
		text = text..silver.."s ";
	end
	return text..rest.."c";
end

function SimpleQoL_DoRestock()
	if ( getn(SimpleQoL_Restock) == 0 or not GetMerchantNumItems ) then
		return;
	end
	local i, j;
	for i = 1, GetMerchantNumItems() do
		local name, texture, price, quantity, numAvailable = GetMerchantItemInfo(i);
		for j = 1, getn(SimpleQoL_Restock) do
			if ( name and strlower(name) == strlower(SimpleQoL_Restock[j][1]) ) then
				local need = SimpleQoL_Restock[j][2] - SimpleQoL_CountItem(name);
				if ( numAvailable and numAvailable >= 0 and numAvailable < need ) then
					need = numAvailable;
				end
				if ( need > 0 ) then
					BuyMerchantItem(i, need);
					SimpleQoL_Print("bought "..need.." x "..name..".");
				end
			end
		end
	end
end


--------------------------------------------------------------------------------
-- Quick quests: accept, complete and take the only reward. Hold Shift to
-- read the quest yourself.
--------------------------------------------------------------------------------

function SimpleQoL_QuestEvent(event)
	if ( not SimpleQoL_On["quests"] or IsShiftKeyDown() ) then
		return;
	end
	if ( event == "QUEST_DETAIL" ) then
		AcceptQuest();
	elseif ( event == "QUEST_PROGRESS" ) then
		if ( IsQuestCompletable() ) then
			CompleteQuest();
		end
	elseif ( event == "QUEST_COMPLETE" ) then
		local choices = GetNumQuestChoices() or 0;
		if ( choices == 0 ) then
			GetQuestReward(0);
		elseif ( choices == 1 ) then
			GetQuestReward(1);
		end
	elseif ( event == "QUEST_GREETING" ) then
		local active = GetNumActiveQuests() or 0;
		local available = GetNumAvailableQuests() or 0;
		if ( active == 1 and available == 0 ) then
			SelectActiveQuest(1);
		elseif ( active == 0 and available == 1 ) then
			SelectAvailableQuest(1);
		end
	end
end


--------------------------------------------------------------------------------
-- Right-click a bag item while trading: it goes into the trade window.
--------------------------------------------------------------------------------

SimpleQoL_Orig_ContainerClick = ContainerFrameItemButton_OnClick;
function ContainerFrameItemButton_OnClick(button, ignoreShift)
	if ( button == "RightButton" and SimpleQoL_On["trade"] and TradeFrame and TradeFrame:IsVisible() ) then
		local slot = SimpleQoL_FreeTradeSlot();
		if ( slot ) then
			PickupContainerItem(this:GetParent():GetID(), this:GetID());
			ClickTradeButton(slot);
			return;
		end
	end
	SimpleQoL_Orig_ContainerClick(button, ignoreShift);
end

function SimpleQoL_FreeTradeSlot()
	local i;
	-- The last trade slot is "will not be traded"; leave it out.
	for i = 1, (MAX_TRADE_ITEMS or 7) - 1 do
		if ( not GetTradePlayerItemInfo(i) ) then
			return i;
		end
	end
	return nil;
end


--------------------------------------------------------------------------------
-- Target health and mana numbers
--------------------------------------------------------------------------------

function SimpleQoL_StatText(value, maxValue)
	if ( not value or not maxValue or maxValue <= 0 ) then
		return "";
	end
	if ( maxValue == 100 ) then
		return value.."%";
	end
	return value.." / "..maxValue;
end

-- 1 when the target frame already shows its own health text (e.g. AlphaUI),
-- so our numbers are not drawn twice.
function SimpleQoL_StockTargetText()
	local text = TargetFrameHealthBarText;
	return text and text:IsVisible() and text:GetText() and text:GetText() ~= "";
end

-- The texts are only made when a number changed (this runs for every health,
-- mana, energy and combat event of the target: new strings each time are
-- garbage for the collector).
SimpleQoL_StatsDrawn = nil;
function SimpleQoL_UpdateStats()
	if ( not SimpleQoL_On["stats"] or not UnitExists("target") or SimpleQoL_StockTargetText() ) then
		if ( SimpleQoL_StatsDrawn ) then
			SimpleQoL_StatsDrawn = nil;
			SimpleQoLTargetHealth:SetText("");
			SimpleQoLTargetMana:SetText("");
		end
		return;
	end
	local health, healthMax, mana = UnitHealth("target"), UnitHealthMax("target"), UnitMana("target");
	local manaMax = UnitManaMax and UnitManaMax("target");
	if ( SimpleQoL_StatsDrawn and health == SimpleQoL_StatH and healthMax == SimpleQoL_StatHM and mana == SimpleQoL_StatM and manaMax == SimpleQoL_StatMM ) then
		return;
	end
	SimpleQoL_StatsDrawn = 1;
	SimpleQoL_StatH, SimpleQoL_StatHM, SimpleQoL_StatM, SimpleQoL_StatMM = health, healthMax, mana, manaMax;
	SimpleQoLTargetHealth:SetText(SimpleQoL_StatText(health, healthMax));
	SimpleQoLTargetMana:SetText(SimpleQoL_StatText(mana, manaMax));
end


--------------------------------------------------------------------------------
-- Alt self cast: hold Alt when you use an action to cast it on yourself.
--------------------------------------------------------------------------------

SimpleQoL_Orig_UseAction = UseAction;
function UseAction(id, checkCursor, onSelf)
	if ( SimpleQoL_On["selfcast"] and IsAltKeyDown() ) then
		SimpleQoL_Orig_UseAction(id, checkCursor, 1);
		if ( SpellIsTargeting() ) then
			SpellTargetUnit("player");
		end
		return;
	end
	SimpleQoL_Orig_UseAction(id, checkCursor, onSelf);
end


--------------------------------------------------------------------------------
-- Auto attack: when something hits you and you are not attacking, target the
-- nearest enemy (if you have no hostile target) and start auto attack. Auto
-- attack keeps going between spells, as in vanilla; casts are not stopped.
--------------------------------------------------------------------------------

function SimpleQoL_HasEnemyTarget()
	return UnitExists("target") and not UnitIsDead("target") and not UnitIsFriend("player", "target");
end

-- Starting auto attack during a cast interrupts the cast in 0.5.3, so it is
-- only started when you do nothing else: no cast or channel, no spell waiting
-- for a target, and at least 1.5 s after your last cast ended (so casts can
-- be chained).
SimpleQoL_Casting = nil;
SimpleQoL_CastEnd = 0;

function SimpleQoL_Busy()
	if ( SimpleQoL_Casting ) then
		return 1;
	end
	-- A channel ends without its own event; the stock cast bar knows it.
	if ( CastingBarFrame and (CastingBarFrame.casting or CastingBarFrame.channeling) ) then
		SimpleQoL_CastEnd = GetTime();
		return 1;
	end
	if ( SpellIsTargeting and SpellIsTargeting() ) then
		return 1;
	end
	if ( GetTime() - SimpleQoL_CastEnd < 1.5 ) then
		return 1;
	end
	-- An action or item used just now may still be going on (an item with
	-- an effect, a transformation): starting an attack then can cut it off.
	if ( GetTime() - (SimpleQoL_LastActionTime or -10) < 1.5 or GetTime() - (SimpleQoL_LastItemTime or -10) < 1.5 ) then
		return 1;
	end
	return nil;
end

-- In combat with an enemy target in melee range: auto attack back on.
function SimpleQoL_KeepAttacking()
	if ( not SimpleQoL_On["attack"] or not SimpleQoL_InCombat or SimpleQoL_Attacking ) then
		return;
	end
	if ( not SimpleQoL_HasEnemyTarget() or SimpleQoL_Busy() ) then
		return;
	end
	-- 3 = about 10 yards (duel distance); only checked when the client has it.
	if ( CheckInteractDistance and not CheckInteractDistance("target", 3) ) then
		return;
	end
	if ( GetTime() - SimpleQoL_AttackTime < 1 ) then
		return;
	end
	SimpleQoL_AttackTime = GetTime();
	AttackTarget();
end

function SimpleQoL_AutoAttack()
	if ( not SimpleQoL_On["attack"] or SimpleQoL_Attacking or SimpleQoL_Busy() ) then
		return;
	end
	if ( GetTime() - SimpleQoL_AttackTime < 1 ) then
		return;
	end
	SimpleQoL_AttackTime = GetTime();
	if ( not SimpleQoL_HasEnemyTarget() ) then
		TargetNearestEnemy();
	end
	if ( SimpleQoL_HasEnemyTarget() ) then
		AttackTarget();
	end
end


--------------------------------------------------------------------------------
-- Hide red error messages (UIErrorsFrame), except ones about full bags.
--------------------------------------------------------------------------------

-- Only combat spam is hidden; the texts come from the client's GlobalStrings
-- (with the English text as a fallback).
-- "Another action is in progress" is not hidden: it is the only sign that
-- the game still waits for an earlier action.
SimpleQoL_SpamErrors = nil;            -- message -> 1, made once
function SimpleQoL_IsSpamError(message)
	if ( not message ) then
		return nil;
	end
	if ( not SimpleQoL_SpamErrors ) then
		SimpleQoL_SpamErrors = {};
		local list = { INTERRUPTED, SPELL_FAILED_INTERRUPTED, SPELL_FAILED_INTERRUPTED_COMBAT, ERR_SPELL_COOLDOWN,
			ERR_ABILITY_COOLDOWN, ERR_ITEM_COOLDOWN, SPELL_FAILED_ITEM_NOT_READY,
			"Interrupted", "Spell is not ready yet", "Ability is not ready yet", "Item is not ready yet" };
		local i;
		for i = 1, getn(list) do
			if ( list[i] ) then
				SimpleQoL_SpamErrors[list[i]] = 1;
			end
		end
	end
	return SimpleQoL_SpamErrors[message];
end

SimpleQoL_Orig_UIErrorsFrame_OnEvent = UIErrorsFrame_OnEvent;
function SimpleQoL_IsResourceError(message)
	if ( not message ) then
		return nil;
	end
	if ( not SimpleQoL_ResourceErrors ) then
		SimpleQoL_ResourceErrors = {};
		local list = { ERR_OUT_OF_RAGE, ERR_OUT_OF_ENERGY, ERR_OUT_OF_MANA, ERR_OUT_OF_FOCUS,
			"Not enough rage", "Not enough energy", "Not enough mana", "Not enough focus" };
		local i;
		for i = 1, getn(list) do
			if ( list[i] ) then
				SimpleQoL_ResourceErrors[list[i]] = 1;
			end
		end
	end
	return SimpleQoL_ResourceErrors[message];
end

-- Combat-only spam (rogue and melee): hidden while in combat only.
function SimpleQoL_IsCombatSpamError(message)
	if ( not message ) then
		return nil;
	end
	if ( not SimpleQoL_CombatSpamErrors ) then
		SimpleQoL_CombatSpamErrors = {};
		local list = { SPELL_FAILED_NO_COMBO_POINTS, ERR_NO_ATTACK_TARGET, ERR_BADATTACKTARGET, SPELL_FAILED_BAD_TARGETS,
			ERR_OUT_OF_RANGE, SPELL_FAILED_OUT_OF_RANGE,
			"That ability requires combo points", "There is nothing to attack", "You cannot attack that target", "Out of range" };
		local i;
		for i = 1, getn(list) do
			if ( list[i] ) then
				SimpleQoL_CombatSpamErrors[list[i]] = 1;
			end
		end
	end
	return SimpleQoL_CombatSpamErrors[message];
end

-- Any "you are mounted" error: spells, items (food, drink), flight masters
-- ("You are already mounted! Dismount first."). Not the opposite messages.
function SimpleQoL_IsMountedError(message)
	if ( not message ) then
		return nil;
	end
	local lower = strlower(message);
	if ( not strfind(lower, "mounted", 1, 1) ) then
		return nil;
	end
	if ( strfind(lower, "not mounted", 1, 1) or strfind(lower, "only use while mounted", 1, 1) or strfind(lower, "can't be mounted", 1, 1) ) then
		return nil;
	end
	return 1;
end

SimpleQoL_LastError = nil;
SimpleQoL_LastErrorTime = 0;

function UIErrorsFrame_OnEvent(event, message)
	if ( event == "UI_ERROR_MESSAGE" and SimpleQoL_IsMountedError(message) and SimpleQoL_TrackingCastRecent and SimpleQoL_TrackingCastRecent() ) then
		-- Caused by an automatic tracking recast (AlphaUI Always Track): no
		-- dismount and no message.
		return;
	end
	-- Sitting: Auto Track pauses until the character moves (no message spam).
	if ( event == "UI_ERROR_MESSAGE" and message and strfind(strlower(message), "standing up", 1, 1) and SimpleQoL_TrackingCastRecent and SimpleQoL_TrackingCastRecent() ) then
		SimpleQoL_AutoTrackSitPause();
		return;
	end
	if ( event == "UI_ERROR_MESSAGE" and SimpleQoL_On["dismount"] and SimpleQoL_IsMountedError(message) and SimpleQoL_Dismount ) then
		SimpleQoL_Dismount();
	end
	if ( event == "UI_ERROR_MESSAGE" and SimpleQoL_On["errors"] and SimpleQoL_IsSpamError(message) ) then
		return;
	end
	if ( event == "UI_ERROR_MESSAGE" and SimpleQoL_On["errors"] and SimpleQoL_InCombat and (SimpleQoL_IsResourceError(message) or SimpleQoL_IsCombatSpamError(message)) ) then
		return;
	end
	-- "You have no target" right after an attack press: the nearest enemy was
	-- targeted and the action pressed again (SimpleQoL_More.lua).
	if ( event == "UI_ERROR_MESSAGE" and SimpleQoL_NoTargetError and SimpleQoL_NoTargetError(message) ) then
		return;
	end
	-- The same error again while it is still shown: skip it.
	if ( event == "UI_ERROR_MESSAGE" and SimpleQoL_On["errors"] ) then
		if ( message == SimpleQoL_LastError and GetTime() - SimpleQoL_LastErrorTime < (UIERRORS_HOLD_TIME or 5) ) then
			return;
		end
		SimpleQoL_LastError = message;
		SimpleQoL_LastErrorTime = GetTime();
	end
	SimpleQoL_Orig_UIErrorsFrame_OnEvent(event, message);
end


--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function SimpleQoL_OnLoad()
	SimpleQoL_SetDefaults();
	local events = { "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "LOOT_OPENED", "MERCHANT_SHOW",
		"DUEL_REQUESTED", "PARTY_INVITE_REQUEST", "GUILD_INVITE_REQUEST", "RESURRECT_REQUEST",
		"QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
		"PLAYER_TARGET_CHANGED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_MANA", "UNIT_MAXMANA",
		"UNIT_RAGE", "UNIT_ENERGY", "UNIT_COMBAT", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "PLAYER_LEVEL_UP",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLCAST_START", "SPELLCAST_STOP",
		"SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "SPELLCAST_CHANNEL_START" };
	local i;
	for i = 1, getn(events) do
		this:RegisterEvent(events[i]);
	end
	SlashCmdList["SIMPLEQOL"] = SimpleQoL_Slash;
	SLASH_SIMPLEQOL1 = "/qol";
	SLASH_SIMPLEQOL2 = "/simpleqol";
	SlashCmdList["SIMPLEQOLDEBUG"] = SimpleQoL_DebugSlash;
	SLASH_SIMPLEQOLDEBUG1 = "/debug";
end

function SimpleQoL_DebugSlash(msg)
	local ps, pe, psecs = strfind(msg or "", "^%s*(%d*)%s*$");
	SimpleQoL_ProfStartRun(psecs and psecs ~= "" and psecs + 0 or nil);
end

function SimpleQoL_OnEvent(event)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not SimpleQoL_Started ) then
			SimpleQoL_Started = 1;
			if ( SimpleQoL_ModCheck ) then
				SimpleQoL_ModCheck();
			end
			if ( SimpleQoL_AdjustGameMenu ) then
				SimpleQoL_AdjustGameMenu();
			end
			if ( SimpleSave_RegisterLoad ) then
				SimpleSave_RegisterLoad(SimpleQoL_Load);
			else
				SimpleQoL_Load();
				if ( not SIMPLE_SAVE_WARNED ) then
					SIMPLE_SAVE_WARNED = 1;
					SimpleQoL_Print("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions. Install SimpleSave (its own line in FrameXML.toc).");
				end
			end
		end
		SimpleQoL_TrackerDirty = 1;
	elseif ( not SimpleQoL_Loaded ) then
		return;
	elseif ( event == "QUEST_LOG_UPDATE" or event == "PLAYER_LEVEL_UP" ) then
		-- Our own SelectQuestLogEntry calls may cause updates; skip those.
		if ( not SimpleQoL_TrackerBusy and GetTime() - (SimpleQoL_TrackerBusyTime or 0) > 0.2 ) then
			SimpleQoL_TrackerDirty = 1;
		end
	elseif ( event == "LOOT_OPENED" ) then
		SimpleQoL_LootOpened();
	elseif ( event == "MERCHANT_SHOW" ) then
		if ( SimpleQoL_On["sellgrey"] ) then
			SimpleQoL_SellGrey();
		end
		if ( SimpleQoL_On["restock"] ) then
			SimpleQoL_DoRestock();
		end
	elseif ( event == "DUEL_REQUESTED" ) then
		if ( SimpleQoL_On["duel"] ) then
			CancelDuel();
			StaticPopup_Hide("DUEL_REQUESTED");
			SimpleQoL_Print("declined a duel from "..(arg1 or "?")..".");
		end
	elseif ( event == "PARTY_INVITE_REQUEST" ) then
		if ( SimpleQoL_On["invall"] or (SimpleQoL_On["invfriend"] and SimpleQoL_IsFriend(arg1)) ) then
			AcceptGroup();
			StaticPopup_Hide("PARTY_INVITE");
			SimpleQoL_Print("joined the group of "..(arg1 or "?")..".");
		end
	elseif ( event == "GUILD_INVITE_REQUEST" ) then
		if ( SimpleQoL_On["duel"] ) then
			DeclineGuild();
			StaticPopup_Hide("GUILD_INVITE");
			SimpleQoL_Print("declined a guild invite from "..(arg1 or "?")..".");
		end
	elseif ( event == "RESURRECT_REQUEST" ) then
		if ( SimpleQoL_On["res"] ) then
			AcceptResurrect();
			StaticPopup_Hide("RESURRECT");
		end
	elseif ( event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" or event == "QUEST_GREETING" ) then
		SimpleQoL_QuestEvent(event);
	elseif ( event == "PLAYER_TARGET_CHANGED" ) then
		SimpleQoL_UpdateStats();
	elseif ( event == "SPELLCAST_START" ) then
		SimpleQoL_Casting = 1;
	elseif ( event == "SPELLCAST_CHANNEL_START" ) then
		SimpleQoL_CastEnd = GetTime();
	elseif ( event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" ) then
		SimpleQoL_Casting = nil;
		SimpleQoL_CastEnd = GetTime();
	elseif ( event == "PLAYER_REGEN_DISABLED" ) then
		SimpleQoL_InCombat = 1;
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		SimpleQoL_InCombat = nil;
	elseif ( event == "PLAYER_ENTER_COMBAT" ) then
		SimpleQoL_Attacking = 1;
	elseif ( event == "PLAYER_LEAVE_COMBAT" ) then
		SimpleQoL_Attacking = nil;
	elseif ( event == "UNIT_COMBAT" ) then
		-- arg1 = unit, arg2 = what happened (WOUND, BLOCK, DODGE, HEAL, ...)
		if ( arg1 == "player" and arg2 ~= "HEAL" ) then
			SimpleQoL_AutoAttack();
		end
	elseif ( arg1 == "target" ) then
		SimpleQoL_UpdateStats();
	end
end

-- /qol prof [seconds] (or /debug [seconds]): measures frame time and tries to
-- tell what causes the slow frames. Nothing runs before it is started and
-- everything is put back when it ends. GetTime has millisecond steps, so
-- very small things read as 0 ms.
SIMPLEQOL_PROF_DEFAULT = 60;
SIMPLEQOL_PROF_MIN = 10;
SIMPLEQOL_PROF_MAX = 600;
SIMPLEQOL_PROF_SPIKE = 0.05;       -- a frame this slow (seconds) counts as a spike
SIMPLEQOL_PROF_KEEP = 5;           -- spikes written out in the result

SIMPLEQOL_PROF_FUNCS = {
	"SimpleQoL_OnUpdate", "SimpleQoL_Extra_OnUpdate", "SimpleQoL_More_OnUpdate", "SimpleQoL_Items_OnUpdate",
	"SimpleQoL_Frames_OnUpdate", "SimpleQoL_Weapon_OnUpdate", "SimpleQoL_Social_OnUpdate", "SimpleQoLGuildFrame_OnUpdate",
	"ActionBars_OnUpdate", "TradeSkillPlus_OnUpdate", "IEF_OnUpdate",
	"SimpleChat_OnUpdate", "SimpleChat_Settings_OnUpdate", "SimpleMap_OnUpdate", "SimpleMap_MinimapCoords_OnUpdate",
	"SimpleMapOptions_OnUpdate", "SimpleSave_OnUpdate", "SimpleWalk_OnUpdate", "SimpleGM_OnUpdate",
	"SimpleMacrosSlots_OnUpdate", "SimpleMacrosCarry_Follow",
	"SimpleQoL_OnEvent", "SimpleQoL_Extra_OnEvent", "SimpleQoL_More_OnEvent", "SimpleQoL_Items_OnEvent",
	"SimpleQoL_Frames_OnEvent", "SimpleQoL_Weapon_OnEvent", "SimpleQoL_Social_OnEvent", "SimpleQoLGuildFrame_OnEvent",
	"ActionBars_OnEvent", "TradeSkillPlus_OnEvent", "IEF_OnEvent",
	"SimpleChat_OnEvent", "SimpleMap_OnEvent", "SimpleMap_MinimapCoords_OnEvent", "SimpleMap_GatherEvent",
	"SimpleSave_OnEvent", "SimpleWalk_OnEvent", "SimpleGM_OnEvent", "SimpleMacros_OnEvent",
};

SIMPLEQOL_PROF_EVENTS = {
	"UNIT_HEALTH", "UNIT_MANA", "UNIT_AURA", "UNIT_COMBAT", "UNIT_INVENTORY_CHANGED", "UNIT_NAME_UPDATE",
	"PLAYER_AURAS_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_XP_UPDATE", "BAG_UPDATE", "UPDATE_MOUSEOVER_UNIT",
	"ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_USABLE",
	"SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_DELAYED", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY",
	"CHAT_MSG_GUILD", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_WHISPER", "CHAT_MSG_COMBAT_SELF_HITS",
	"CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_AURA_GONE_SELF",
	"WORLD_MAP_UPDATE", "MINIMAP_UPDATE_ZOOM", "UPDATE_FACTION", "SKILL_LINES_CHANGED", "PARTY_MEMBERS_CHANGED",
	"GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "UPDATE_BINDINGS", "UPDATE_INVENTORY_ALERTS", "CURSOR_UPDATE",
};

SimpleQoL_ProfOrig = {};           -- name -> the real function
SimpleQoL_ProfWrapper = {};        -- name -> our timing function
SimpleQoL_ProfTime = {};           -- name -> total seconds
SimpleQoL_ProfWorst = {};          -- name -> slowest single call
SimpleQoL_ProfEvTotal = {};        -- event -> times seen
SimpleQoL_ProfEv = {};             -- events seen since the last frame
SimpleQoL_ProfEvN = 0;
SimpleQoL_ProfSpikes = {};
SimpleQoL_ProfFrameMs = 0;
SimpleQoL_ProfFrameName = nil;

function SimpleQoL_ProfSetGlobal(name, fn)
	if ( setglobal ) then
		setglobal(name, fn);
	elseif ( RunScript ) then
		SimpleQoL_ProfTmp = fn;
		RunScript(name.." = SimpleQoL_ProfTmp");
		SimpleQoL_ProfTmp = nil;
	end
end

function SimpleQoL_ProfWrap(name)
	local orig = getglobal(name);
	if ( not orig or SimpleQoL_ProfOrig[name] ) then
		return;
	end
	SimpleQoL_ProfOrig[name] = orig;
	SimpleQoL_ProfTime[name] = 0;
	SimpleQoL_ProfWorst[name] = 0;
	local wrapper = function(a, b, c, d, e)
		local t = GetTime();
		orig(a, b, c, d, e);
		local dt = GetTime() - t;
		SimpleQoL_ProfTime[name] = SimpleQoL_ProfTime[name] + dt;
		if ( dt > SimpleQoL_ProfWorst[name] ) then
			SimpleQoL_ProfWorst[name] = dt;
		end
		if ( dt > SimpleQoL_ProfFrameMs ) then
			SimpleQoL_ProfFrameMs = dt;
			SimpleQoL_ProfFrameName = name;
		end
	end;
	SimpleQoL_ProfWrapper[name] = wrapper;
	SimpleQoL_ProfSetGlobal(name, wrapper);
end

function SimpleQoL_ProfEvent()
	SimpleQoL_ProfEvN = SimpleQoL_ProfEvN + 1;
	if ( SimpleQoL_ProfEvN <= 12 ) then
		SimpleQoL_ProfEv[SimpleQoL_ProfEvN] = event;
	end
	SimpleQoL_ProfEvTotal[event] = (SimpleQoL_ProfEvTotal[event] or 0) + 1;
end

-- What the events of a slow frame were: "UNIT_AURA x3, BAG_UPDATE".
function SimpleQoL_ProfEventText()
	local n = SimpleQoL_ProfEvN;
	if ( n > 12 ) then
		n = 12;
	end
	local text = "";
	local i, j, same, seen;
	for i = 1, n do
		seen = nil;
		for j = 1, i - 1 do
			if ( SimpleQoL_ProfEv[j] == SimpleQoL_ProfEv[i] ) then
				seen = 1;
			end
		end
		if ( not seen ) then
			same = 0;
			for j = 1, n do
				if ( SimpleQoL_ProfEv[j] == SimpleQoL_ProfEv[i] ) then
					same = same + 1;
				end
			end
			if ( text ~= "" ) then
				text = text..", ";
			end
			text = text..SimpleQoL_ProfEv[i];
			if ( same > 1 ) then
				text = text.." x"..same;
			end
		end
	end
	return text;
end

function SimpleQoL_ProfSpike(dt, now, gcKb)
	local what = "";
	local kind = "other";
	if ( gcKb and gcKb > 0 ) then
		what = format("memory dropped %d KB (garbage collection)", gcKb);
		kind = "gc";
	end
	if ( SimpleQoL_ProfFrameName and SimpleQoL_ProfFrameMs >= 0.005 ) then
		if ( what ~= "" ) then
			what = what..", ";
		end
		what = what..format("%s took %.0f ms", SimpleQoL_ProfFrameName, SimpleQoL_ProfFrameMs * 1000);
		if ( kind == "other" ) then
			kind = "ours";
		end
	end
	if ( SimpleQoL_ProfEvN > 0 ) then
		if ( what ~= "" ) then
			what = what.."; ";
		end
		what = what.."events: "..SimpleQoL_ProfEventText();
	end
	if ( what == "" ) then
		what = "nothing of ours seen (client, graphics, network, AlphaUI)";
	end
	SimpleQoL_ProfKinds[kind] = (SimpleQoL_ProfKinds[kind] or 0) + 1;
	-- Keep the worst few, slowest first.
	local list = SimpleQoL_ProfSpikes;
	local n = getn(list);
	if ( n >= SIMPLEQOL_PROF_KEEP and dt <= list[n][1] ) then
		return;
	end
	local entry = { dt, now - SimpleQoL_ProfStart, what };
	if ( n >= SIMPLEQOL_PROF_KEEP ) then
		list[n] = entry;
	else
		tinsert(list, entry);
		n = n + 1;
	end
	local i = n;
	while ( i > 1 and list[i][1] > list[i - 1][1] ) do
		list[i], list[i - 1] = list[i - 1], list[i];
		i = i - 1;
	end
end

function SimpleQoL_ProfTick()
	local now = GetTime();
	if ( SimpleQoL_ProfLast ) then
		local dt = now - SimpleQoL_ProfLast;
		SimpleQoL_ProfCount = SimpleQoL_ProfCount + 1;
		SimpleQoL_ProfSum = SimpleQoL_ProfSum + dt;
		if ( dt > SimpleQoL_ProfMax ) then
			SimpleQoL_ProfMax = dt;
		end
		local gcKb = nil;
		if ( gcinfo ) then
			local mem = gcinfo();
			local change = mem - SimpleQoL_ProfMem;
			SimpleQoL_ProfMem = mem;
			if ( change < 0 ) then
				gcKb = -change;
				SimpleQoL_ProfGcN = SimpleQoL_ProfGcN + 1;
			else
				SimpleQoL_ProfAlloc = SimpleQoL_ProfAlloc + change;
			end
		end
		if ( dt >= SIMPLEQOL_PROF_SPIKE ) then
			SimpleQoL_ProfSpikeN = SimpleQoL_ProfSpikeN + 1;
			SimpleQoL_ProfSpike(dt, now, gcKb);
		end
		SimpleQoL_ProfFrameMs = 0;
		SimpleQoL_ProfFrameName = nil;
		SimpleQoL_ProfEvN = 0;
	elseif ( gcinfo ) then
		SimpleQoL_ProfMem = gcinfo();
	end
	SimpleQoL_ProfLast = now;
	if ( now - SimpleQoL_ProfStart >= SimpleQoL_ProfLen and SimpleQoL_ProfCount > 0 ) then
		SimpleQoL_ProfFinish(now);
	end
end

function SimpleQoL_ProfFinish(now)
	SimpleQoL_ProfOn = nil;
	-- Put everything back (only where nobody changed the function meanwhile).
	local i, name;
	for i = 1, getn(SIMPLEQOL_PROF_FUNCS) do
		name = SIMPLEQOL_PROF_FUNCS[i];
		if ( SimpleQoL_ProfOrig[name] and getglobal(name) == SimpleQoL_ProfWrapper[name] ) then
			SimpleQoL_ProfSetGlobal(name, SimpleQoL_ProfOrig[name]);
		end
	end
	if ( SimpleQoLProfFrame ) then
		for i = 1, getn(SIMPLEQOL_PROF_EVENTS) do
			SimpleQoLProfFrame:UnregisterEvent(SIMPLEQOL_PROF_EVENTS[i]);
		end
	end
	local secs = now - SimpleQoL_ProfStart;
	local avg = SimpleQoL_ProfSum / SimpleQoL_ProfCount;
	SimpleQoL_Print(format("frame time over %.0f s: average %.1f ms (about %.0f fps), worst %.0f ms, %d frames.", secs, avg * 1000, 1 / avg, SimpleQoL_ProfMax * 1000, SimpleQoL_ProfCount));
	-- Slowest single calls of our addons.
	local top = {};
	local total = 0;
	local k, best, bestName, taken;
	for i = 1, getn(SIMPLEQOL_PROF_FUNCS) do
		name = SIMPLEQOL_PROF_FUNCS[i];
		if ( SimpleQoL_ProfTime[name] ) then
			total = total + SimpleQoL_ProfTime[name];
		end
	end
	local text = "";
	for k = 1, 3 do
		best = 0.0005;
		bestName = nil;
		for i = 1, getn(SIMPLEQOL_PROF_FUNCS) do
			name = SIMPLEQOL_PROF_FUNCS[i];
			if ( SimpleQoL_ProfWorst[name] and SimpleQoL_ProfWorst[name] > best and not top[name] ) then
				best = SimpleQoL_ProfWorst[name];
				bestName = name;
			end
		end
		if ( bestName ) then
			top[bestName] = 1;
			text = text..(text ~= "" and ", " or "")..format("%s %.0f ms", bestName, best * 1000);
		end
	end
	SimpleQoL_Print(format("our addons: about %.1f%% of the time. Slowest single calls: %s.", total / secs * 100, text ~= "" and text or "all under 1 ms"));
	if ( gcinfo ) then
		SimpleQoL_Print(format("garbage: about %.0f KB per second, collected %d times in %.0f s.", SimpleQoL_ProfAlloc / secs, SimpleQoL_ProfGcN, secs));
	else
		SimpleQoL_Print("garbage: cannot be measured in this client.");
	end
	if ( SimpleQoL_ProfSpikeN == 0 ) then
		SimpleQoL_Print("no frame slower than 50 ms.");
	else
		SimpleQoL_Print(format("%d frames slower than 50 ms: %d garbage collection, %d one of our addons took the time, %d unknown (client, graphics, network, AlphaUI). Worst:", SimpleQoL_ProfSpikeN, SimpleQoL_ProfKinds["gc"] or 0, SimpleQoL_ProfKinds["ours"] or 0, SimpleQoL_ProfKinds["other"] or 0));
		local entry;
		for i = 1, getn(SimpleQoL_ProfSpikes) do
			entry = SimpleQoL_ProfSpikes[i];
			SimpleQoL_Print(format("  %.0f ms at %.0f s: %s", entry[1] * 1000, entry[2], entry[3]));
		end
	end
	-- Most common events.
	local evText = "";
	local shown = {};
	for k = 1, 3 do
		best = 0;
		bestName = nil;
		for i = 1, getn(SIMPLEQOL_PROF_EVENTS) do
			name = SIMPLEQOL_PROF_EVENTS[i];
			if ( (SimpleQoL_ProfEvTotal[name] or 0) > best and not shown[name] ) then
				best = SimpleQoL_ProfEvTotal[name];
				bestName = name;
			end
		end
		if ( bestName ) then
			shown[bestName] = 1;
			evText = evText..(evText ~= "" and ", " or "")..bestName.." "..best;
		end
	end
	if ( evText ~= "" ) then
		SimpleQoL_Print("most events: "..evText..".");
	end
	SimpleQoL_Print("The cause is a best guess from what ran in the same frame.");
end

function SimpleQoL_ProfStartRun(seconds)
	if ( SimpleQoL_ProfOn ) then
		SimpleQoL_Print("the measurement is already running.");
		return;
	end
	seconds = seconds or SIMPLEQOL_PROF_DEFAULT;
	if ( seconds < SIMPLEQOL_PROF_MIN ) then
		seconds = SIMPLEQOL_PROF_MIN;
	elseif ( seconds > SIMPLEQOL_PROF_MAX ) then
		seconds = SIMPLEQOL_PROF_MAX;
	end
	SimpleQoL_ProfLen = seconds;
	SimpleQoL_ProfLast = nil;
	SimpleQoL_ProfCount = 0;
	SimpleQoL_ProfSum = 0;
	SimpleQoL_ProfMax = 0;
	SimpleQoL_ProfMem = 0;
	SimpleQoL_ProfAlloc = 0;
	SimpleQoL_ProfGcN = 0;
	SimpleQoL_ProfSpikeN = 0;
	SimpleQoL_ProfSpikes = {};
	SimpleQoL_ProfKinds = {};
	SimpleQoL_ProfEvTotal = {};
	SimpleQoL_ProfEvN = 0;
	SimpleQoL_ProfFrameMs = 0;
	SimpleQoL_ProfFrameName = nil;
	local i;
	for i = 1, getn(SIMPLEQOL_PROF_FUNCS) do
		SimpleQoL_ProfWrap(SIMPLEQOL_PROF_FUNCS[i]);
	end
	if ( SimpleQoLProfFrame ) then
		for i = 1, getn(SIMPLEQOL_PROF_EVENTS) do
			SimpleQoLProfFrame:RegisterEvent(SIMPLEQOL_PROF_EVENTS[i]);
		end
	end
	SimpleQoL_ProfStart = GetTime();
	SimpleQoL_ProfOn = 1;
	SimpleQoL_Print(format("measuring for %d seconds, play as usual.", seconds));
end

function SimpleQoL_OnUpdate()
	if ( SimpleQoL_ProfOn ) then
		SimpleQoL_ProfTick();
	end
	if ( SimpleHello_Tick ) then
		SimpleHello_Tick();
	end
	if ( SimpleQoL_TrackerDrag ) then
		SimpleQoL_TrackerDragUpdate();
	end
	if ( SimpleQoL_InCombat and not SimpleQoL_Attacking and GetTime() - (SimpleQoL_KeepAttackTime or 0) > 0.2 ) then
		SimpleQoL_KeepAttackTime = GetTime();
		SimpleQoL_KeepAttacking();
	end
	if ( SimpleQoL_PendingLootMove ) then
		SimpleQoL_MoveLoot();
	end
	if ( SimpleQoL_SellPending and GetTime() > SimpleQoL_SellPending ) then
		SimpleQoL_ReportSale();
	end
	if ( SimpleQoL_TrackerDirty and SimpleQoL_Loaded and GetTime() - SimpleQoL_TrackerTime > 0.3 ) then
		SimpleQoL_UpdateTracker();
	end	if ( SimpleQoL_NodeColor ) then
		SimpleQoL_NodeColor();
	end
end


--------------------------------------------------------------------------------
-- Settings window (/qol)
--------------------------------------------------------------------------------

-- A feature that needs something missing cannot be ticked.
function SimpleQoL_FeatureUsable(key)
	return SimpleQoL_ModuleInstalled(key);
end

-- Modules: our other addons, shipped with SimpleQoL. They read their on/off
-- setting themselves at login (SimpleSave "SimpleQoL" key = "0" means off).
SIMPLEQOL_MODULES = {
	actionbars = { "ACTIONBARS_VERSION", "ActionBars_Off" },
	tradeskillplus = { "TRADESKILLPLUS_VERSION", "TradeSkillPlus_Off" },
	errorframe = { "IEF_VERSION", "IEF_Off" },
};

-- 1 for a feature that is not a module or a module that is installed.
function SimpleQoL_ModuleInstalled(key)
	local module = SIMPLEQOL_MODULES[key];
	if ( not module ) then
		return 1;
	end
	return getglobal(module[1]);
end

-- Settings buttons next to the modules (only while the module runs).
function SimpleQoLOptions_ModuleSettings(key)
	local module = SIMPLEQOL_MODULES[key];
	if ( not SimpleQoL_ModuleInstalled(key) or getglobal(module[2]) ) then
		SimpleQoL_Print("that module is off or not installed.");
		return;
	end
	if ( key == "actionbars" and ActionBarsOptionsFrame ) then
		SimpleQoLOptionsFrame:Hide();
		ActionBarsOptionsFrame:Show();
	elseif ( key == "errorframe" and IEF_Toggle ) then
		SimpleQoLOptionsFrame:Hide();
		IEF_Toggle();
	end
end

-- Classes with an emergency spell (SIMPLEQOL_SHIELD_SPELLS); hunters from
-- level 30 (Feign Death).
function SimpleQoL_ShieldClass()
	local class = UnitClass and UnitClass("player");
	class = class and strlower(class);
	if ( not class or not SIMPLEQOL_SHIELD_SPELLS or not SIMPLEQOL_SHIELD_SPELLS[class] ) then
		return nil;
	end
	if ( class == "hunter" and (UnitLevel("player") or 0) < 30 ) then
		return nil;
	end
	return class;
end

-- Option names per class.
SIMPLEQOL_SHIELD_LABELS = { priest = "Emergency Shield", paladin = "Emergency Shield", rogue = "Emergency Vanish",
	warrior = "Emergency Shield Wall", mage = "Emergency Frost Nova", hunter = "Emergency Feign Death",
	warlock = "Emergency Sacrifice", shaman = "Emergency Ethereal Form" };
-- Tooltip of the emergency option: only your own class.
SIMPLEQOL_SHIELD_TIPS = { priest = "casts Holy Word: Shield on you.",
	paladin = "casts Divine Shield, Lay on Hands or Divine Favor (the first one ready).",
	rogue = "casts Vanish.", warrior = "casts Shield Wall.", mage = "casts Frost Nova.",
	hunter = "casts Feign Death.", warlock = "your Voidwalker casts Sacrificial Shield.",
	shaman = "casts Ethereal Form." };

-- Rows below the emergency rows move up by the rows hidden for your class
-- (SIMPLEQOL_OPTIONS_SHIFT is made by dev/gen_qol_xml.py).
function SimpleQoLOptions_ShiftRows(dy)
	if ( not SIMPLEQOL_OPTIONS_SHIFT or dy == SimpleQoL_OptionsShift ) then
		return;
	end
	SimpleQoL_OptionsShift = dy;
	local i;
	for i = 1, getn(SIMPLEQOL_OPTIONS_SHIFT) do
		local item = SIMPLEQOL_OPTIONS_SHIFT[i];
		local frame = getglobal(item[1]);
		if ( frame ) then
			frame:ClearAllPoints();
			frame:SetPoint("TOPLEFT", "SimpleQoLOptionsFrame", "TOPLEFT", item[2], item[3] + dy);
		end
	end
end

function SimpleQoL_ClampPct(value)
	value = tonumber(value) or SIMPLEQOL_PCT_DEFAULT;
	return max(SIMPLEQOL_PCT_MIN, min(SIMPLEQOL_PCT_MAX, floor(value + 0.5)));
end

-- Percent boxes: a number from 1 to 100 is used at once; Enter fixes the rest.
function SimpleQoLOptions_PctChanged(which)
	local box = getglobal("SimpleQoLOptions"..which.."Pct");
	local value = tonumber(box:GetText() or "");
	if ( value and value >= SIMPLEQOL_PCT_MIN and value <= SIMPLEQOL_PCT_MAX and value ~= SimpleQoL_Pct[which] ) then
		SimpleQoL_Pct[which] = floor(value);
		if ( SimpleSave_Set ) then
			SimpleSave_Set("SimpleQoL", which.."Pct", SimpleQoL_Pct[which]);
		end
	end
end

function SimpleQoLOptions_PctEnter(which)
	local box = getglobal("SimpleQoLOptions"..which.."Pct");
	local value = SimpleQoL_ClampPct(tonumber(box:GetText() or "") or SimpleQoL_Pct[which]);
	SimpleQoL_Pct[which] = value;
	if ( SimpleSave_Set ) then
		SimpleSave_Set("SimpleQoL", which.."Pct", value);
	end
	box:SetText(value);
	box:ClearFocus();
end

function SimpleQoLOptions_Update()
	if ( SimpleQoL_TrackOptionsUpdate ) then
		SimpleQoL_TrackOptionsUpdate();
	end
	local i;
	for i = 1, SIMPLEQOL_NUM_FEATURES do
		local key = SIMPLEQOL_FEATURES[i][1];
		local check = getglobal("SimpleQoLOption"..i);
		local text = getglobal("SimpleQoLOption"..i.."Text");
		if ( SimpleQoL_On[key] and SimpleQoL_FeatureUsable(key) ) then
			check:SetChecked(1);
		else
			check:SetChecked(0);
		end
		if ( SimpleQoL_FeatureUsable(key) ) then
			check:Enable();
			if ( text ) then
				text:SetTextColor(1.0, 0.82, 0);
			end
		else
			check:Disable();
			if ( text ) then
				text:SetTextColor(0.5, 0.5, 0.5);
			end
		end
		-- With AlphaUI its own guild tab is used: no setting here (last row
		-- of its group, so no gap).
		if ( key == "guildtab" ) then
			if ( Main and Main.IsModuleEnabled ) then
				check:Hide();
			else
				check:Show();
			end
		end
		if ( key == "auioff" ) then
			local present = SimpleQoL_AlphaPresent();
			if ( present ) then
				check:Show();
			else
				check:Hide();
			end
			SimpleQoLOptions_AlphaRow(present);
		end
		if ( key == "shield" ) then
			local class = SimpleQoL_ShieldClass();
			if ( class ) then
				check:Show();
			else
				check:Hide();
			end
			if ( text ) then
				text:SetText(SIMPLEQOL_SHIELD_LABELS[class or ""] or "Emergency Shield");
			end
		end
		if ( key == "evasion" ) then
			if ( SimpleQoL_ShieldClass() == "rogue" ) then
				check:Show();
			else
				check:Hide();
			end
		end
	end
	SimpleQoLOptionsHealPct:SetText(SimpleQoL_Pct.Heal);
	SimpleQoLOptionsShieldPct:SetText(SimpleQoL_Pct.Shield);
	SimpleQoLOptionsEvasionPct:SetText(SimpleQoL_Pct.Evasion);
	local shieldClass = SimpleQoL_ShieldClass();
	local hidden = 0;
	if ( shieldClass ) then
		SimpleQoLOptionsShieldPct:Show();
		SimpleQoLOptionsShieldPctSign:Show();
	else
		SimpleQoLOptionsShieldPct:Hide();
		SimpleQoLOptionsShieldPctSign:Hide();
		hidden = hidden + 1;
	end
	if ( shieldClass == "rogue" ) then
		SimpleQoLOptionsEvasionPct:Show();
		SimpleQoLOptionsEvasionPctSign:Show();
	else
		SimpleQoLOptionsEvasionPct:Hide();
		SimpleQoLOptionsEvasionPctSign:Hide();
		hidden = hidden + 1;
	end
	SimpleQoLOptions_ShiftRows(hidden * 20);
	local count = getn(SimpleQoL_Restock);
	local most = max(0, count - SIMPLEQOL_RESTOCK_ROWS);
	SimpleQoL_RestockOffset = max(0, min(SimpleQoL_RestockOffset, most));
	if ( most > 0 ) then
		SimpleQoLRestockUp:Show();
		SimpleQoLRestockDown:Show();
		if ( SimpleQoL_RestockOffset > 0 ) then
			SimpleQoLRestockUp:Enable();
		else
			SimpleQoLRestockUp:Disable();
		end
		if ( SimpleQoL_RestockOffset < most ) then
			SimpleQoLRestockDown:Enable();
		else
			SimpleQoLRestockDown:Disable();
		end
	else
		SimpleQoLRestockUp:Hide();
		SimpleQoLRestockDown:Hide();
	end
	for i = 1, SIMPLEQOL_RESTOCK_ROWS do
		local entry = SimpleQoL_Restock[SimpleQoL_RestockOffset + i];
		if ( entry ) then
			getglobal("SimpleQoLRestockRow"..i.."Text"):SetText(entry[2].." x "..entry[1]);
			getglobal("SimpleQoLRestockRow"..i):Show();
		else
			getglobal("SimpleQoLRestockRow"..i):Hide();
		end
	end
	if ( getn(SimpleQoL_Restock) == 0 ) then
		SimpleQoLOptionsRestockEmpty:SetText("(no items yet)");
	else
		SimpleQoLOptionsRestockEmpty:SetText("");
	end
	if ( SimpleSave_Set ) then
		SimpleQoLOptionsDependency:SetText("");
	else
		SimpleQoLOptionsDependency:SetText("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions. Install SimpleSave to keep them.");
	end
end

-- 1 when AlphaUI is installed with its Class Portraits or Clock module.
function SimpleQoL_AlphaPresent()
	if ( Main and Main.GetModule and (Main.GetModule("class_portraits") or Main.GetModule("clock")) ) then
		return 1;
	end
	return nil;
end

-- The extra row at the bottom of the window (only with AlphaUI): the window
-- is a little taller and the two buttons move down.
SimpleQoL_AlphaRowOn = nil;
function SimpleQoLOptions_AlphaRow(on)
	if ( on == SimpleQoL_AlphaRowOn ) then
		return;
	end
	SimpleQoL_AlphaRowOn = on;
	local dy = on and -24 or 0;
	SimpleQoLOptionsFrame:SetHeight(on and 750 or 726);
	SimpleQoLOptionsDefaults:ClearAllPoints();
	SimpleQoLOptionsDefaults:SetPoint("TOPLEFT", "SimpleQoLOptionsFrame", "TOPLEFT", 20, -682 + dy);
	SimpleQoLOptionsResetFrames:ClearAllPoints();
	SimpleQoLOptionsResetFrames:SetPoint("TOPLEFT", "SimpleQoLOptionsFrame", "TOPLEFT", 120, -682 + dy);
end

function SimpleQoLOptions_Toggle(index)
	local key = SIMPLEQOL_FEATURES[index][1];
	if ( not SimpleQoL_FeatureUsable(key) ) then
		SimpleQoLOptions_Update();
		return;
	end
	if ( SimpleQoL_On[key] ) then
		SimpleQoL_On[key] = nil;
	else
		SimpleQoL_On[key] = 1;
	end
	SimpleQoL_SaveFeature(key);
	if ( key == "auioff" and SimpleQoL_On[key] and SimpleQoL_AlphaAgain ) then
		SimpleQoL_AlphaAgain();
	end
	if ( SIMPLEQOL_MODULES[key] ) then
		SimpleQoL_Print(SIMPLEQOL_FEATURES[index][2].." is turned "..(SimpleQoL_On[key] and "on" or "off").." the next time you log in.");
	end
	if ( SimpleQoL_FramesChanged ) then
		SimpleQoL_FramesChanged();
	end
	if ( SimpleQoL_ExtraChanged ) then
		SimpleQoL_ExtraChanged();
	end
	if ( key == "tracker" ) then
		SimpleQoL_TrackerDirty = 1;
		SimpleQoL_TrackerTime = 0;
	elseif ( key == "stats" ) then
		SimpleQoL_UpdateStats();
	elseif ( key == "nameplates" and SimpleQoL_NameplatesApply ) then
		SimpleQoL_NameplatesApply(1);
	end
end

-- Check box tooltip
function SimpleQoLOptions_OnEnter(index)
	SimpleTooltip_SetOwner(this);
	local key = SIMPLEQOL_FEATURES[index][1];
	local class = key == "shield" and SimpleQoL_ShieldClass();
	if ( class ) then
		GameTooltip:SetText(SIMPLEQOL_SHIELD_LABELS[class] or SIMPLEQOL_FEATURES[index][2]);
		GameTooltip:AddLine("|cffffffffIn combat at the health % in the box: "..(SIMPLEQOL_SHIELD_TIPS[class] or "").."|r");
	else
		GameTooltip:SetText(SIMPLEQOL_FEATURES[index][2]);
		GameTooltip:AddLine("|cffffffff"..SIMPLEQOL_FEATURES[index][4].."|r");
	end
	GameTooltip:Show();
end

-- "Defaults": every feature back to its default (saved).
function SimpleQoLOptions_Defaults()
	local i, key;
	SimpleQoL_SetDefaults();
	for i = 1, SIMPLEQOL_NUM_FEATURES do
		SimpleQoL_SaveFeature(SIMPLEQOL_FEATURES[i][1]);
	end
	if ( SimpleQoL_NameplatesApply ) then
		SimpleQoL_NameplatesApply(1);
	end
	if ( SimpleQoL_TrackReset ) then
		SimpleQoL_TrackReset();
	end
	SimpleQoL_Pct.Heal = SIMPLEQOL_PCT_DEFAULT;
	SimpleQoL_Pct.Shield = SIMPLEQOL_PCT_DEFAULT;
	SimpleQoL_Pct.Evasion = SIMPLEQOL_PCT_DEFAULT;
	if ( SimpleSave_Set ) then
		SimpleSave_Set("SimpleQoL", "HealPct", nil);
		SimpleSave_Set("SimpleQoL", "ShieldPct", nil);
		SimpleSave_Set("SimpleQoL", "EvasionPct", nil);
	end
	SimpleQoL_TrackerDirty = 1;
	SimpleQoL_TrackerTime = 0;
	SimpleQoL_UpdateStats();
	if ( SimpleQoL_FramesChanged ) then
		SimpleQoL_FramesChanged();
	end
	if ( SimpleQoL_ExtraChanged ) then
		SimpleQoL_ExtraChanged();
	end
	SimpleQoLOptions_Update();
	SimpleQoL_Print("all options are back to their defaults.");
end

-- Auto-buy form: item name and amount, Add button, Remove per row.
function SimpleQoLOptions_AddRestock()
	local name = SimpleQoLRestockName:GetText() or "";
	local amount = SimpleQoLRestockAmount:GetText() or "";
	name = gsub(name, "^%s+", "");
	name = gsub(name, "%s+$", "");
	-- An item link pasted with Shift-click becomes its name.
	name = SimpleQoL_LinkName(name) or name;
	local s, e, number = strfind(amount, "^%s*(%d+)%s*$");
	if ( name == "" or not number ) then
		SimpleQoL_Print("type an item name and an amount, e.g. Soul Shard and 20.");
		return;
	end
	SimpleQoL_SetRestock(number + 0, name);
	SimpleQoL_RestockOffset = 1000;
	SimpleQoLOptions_Update();
	SimpleQoLRestockName:SetText("");
	SimpleQoLRestockAmount:SetText("");
	SimpleQoLRestockName:ClearFocus();
	SimpleQoLRestockAmount:ClearFocus();
end

-- The list shows 3 items; the arrows and the mouse wheel scroll it.
function SimpleQoLOptions_RestockScroll(step)
	SimpleQoL_RestockOffset = SimpleQoL_RestockOffset + step;
	SimpleQoLOptions_Update();
end

function SimpleQoLOptions_RemoveRestock(row)
	local entry = SimpleQoL_Restock[SimpleQoL_RestockOffset + row];
	if ( entry ) then
		SimpleQoL_SetRestock(0, entry[1]);
	end
end

function SimpleQoL_SetRestock(amount, name)
	local i;
	for i = getn(SimpleQoL_Restock), 1, -1 do
		if ( strlower(SimpleQoL_Restock[i][1]) == strlower(name) ) then
			tremove(SimpleQoL_Restock, i);
		end
	end
	if ( amount > 0 ) then
		tinsert(SimpleQoL_Restock, { name, amount });
		SimpleQoL_Print("restock: keep "..amount.." x "..name.." in your bags.");
	else
		SimpleQoL_Print("restock: "..name.." removed.");
	end
	SimpleQoL_SaveRestock();
	if ( SimpleQoLOptionsFrame:IsVisible() ) then
		SimpleQoLOptions_Update();
	end
end

-- /qol diag: what is needed for a bug report.
function SimpleQoL_Diag()
	local function v(value)
		return value or "not loaded";
	end
	ChatFrame:AddMessage("--- SimpleQoL diag ---", 1.0, 0.82, 0.0);
	ChatFrame:AddMessage("SimpleQoL "..v(SIMPLEQOL_VERSION)..", SimpleMap "..v(SIMPLEMAP_VERSION)..", ActionBars "..v(ACTIONBARS_VERSION)
		..", SimpleChat "..v(SIMPLECHAT_VERSION)..", ImprovedErrorFrame "..v(IEF_VERSION)..", SimpleSave "..v(SIMPLESAVE_VERSION), 1.0, 1.0, 1.0);
	local save = "missing";
	if ( SimpleSave_Set ) then
		save = "loaded";
		if ( SimpleSave_Blocked ) then
			save = "blocked: "..SimpleSave_Blocked;
		elseif ( not SimpleSave_Loaded ) then
			save = "not read yet";
		end
	end
	local alpha = "no";
	if ( Main and Main.IsModuleEnabled ) then
		alpha = "yes";
	end
	ChatFrame:AddMessage("SimpleSave: "..save..". AlphaUI: "..alpha..".", 1.0, 1.0, 1.0);
	ChatFrame:AddMessage((UnitName("player") or "?")..", level "..(UnitLevel("player") or "?").." "..(UnitRace and UnitRace("player") or "").." "
		..(UnitClass("player") or "")..", "..(GetZoneText() or "")..", map "..(GetMapInfo() or "?"), 1.0, 1.0, 1.0);
	local known = {};
	if ( SimpleQoL_KnownProfs ) then
		foreach(SimpleQoL_KnownProfs, function(prof, set)
			local n = 0;
			foreach(set, function() n = n + 1; end);
			tinsert(known, prof.." "..n);
		end);
	end
	local text = "none";
	if ( getn(known) > 0 ) then
		text = SimpleQoL_JoinBars(known);
	end
	ChatFrame:AddMessage("Known recipes: "..text..". Last profession window: "..(SimpleQoL_KnownLast or "not seen")..".", 1.0, 1.0, 1.0);
	local saved = SimpleSave_GetChar and SimpleSave_GetChar("SimpleQoL", "KnownProfs", "") or "";
	ChatFrame:AddMessage("Saved professions: "..(saved ~= "" and saved or "none")..".", 1.0, 1.0, 1.0);
end

function SimpleQoL_Slash(msg)
	local simpleVersionAsk = strlower(gsub(msg or "", "%s", ""));
	if ( simpleVersionAsk == "v" or simpleVersionAsk == "version" ) then
		ChatFrame:AddMessage("SimpleQoL "..SIMPLEQOL_VERSION, 1.0, 0.82, 0.0);
		return;
	end
	msg = msg or "";
	local s, e, amount, name = strfind(msg, "^%s*[Bb][Uu][Yy]%s+(%d+)%s+(.-)%s*$");
	if ( amount ) then
		SimpleQoL_SetRestock(amount + 0, name);
		return;
	end
	msg = strlower(msg);
	local ps, pe, psecs = strfind(msg, "^prof%s*(%d*)$");
	if ( ps ) then
		SimpleQoL_ProfStartRun(psecs ~= "" and psecs + 0 or nil);
		return;
	end
	if ( msg == "diag" ) then
		SimpleQoL_Diag();
		return;
	end
	if ( strlower(msg) == "autotrack" ) then
		SimpleQoL_AutoTrackToggle();
		return;
	end
	local s2, e2, level = strfind(msg, "^maxlevel%s*(%d*)$");
	if ( s2 ) then
		if ( level ~= "" and SimpleQoL_SetMaxLevel ) then
			SimpleQoL_SetMaxLevel(level + 0);
		end
		SimpleQoL_Print("Talent Calculator max level: "..(SIMPLEQOL_MAX_LEVEL or 25)..". /qol maxlevel <level> changes it.");
		return;
	end
	if ( msg == "frames reset" and SimpleQoL_ResetFrames ) then
		SimpleQoL_ResetFrames();
		return;
	end
	if ( msg == "tracker reset" ) then
		SimpleQoL_TrackerX = nil;
		SimpleQoL_TrackerY = nil;
		if ( SimpleSave_Set ) then
			SimpleSave_Set("SimpleQoL", "TrackX", nil);
			SimpleSave_Set("SimpleQoL", "TrackY", nil);
		end
		SimpleQoL_PlaceTracker();
		SimpleQoL_Print("quest tracker back at its place.");
	elseif ( msg == "help" ) then
		SimpleQoL_Print("version "..SIMPLEQOL_VERSION..". /qol = settings, /qol buy <amount> <item>, /qol autotrack, /qol tracker reset, /qol frames reset, /qol maxlevel <level>, /qol diag, /position, /cinfo");
	else
		if ( SimpleQoLOptionsFrame:IsVisible() ) then
			SimpleQoLOptionsFrame:Hide();
		else
			SimpleQoLOptionsFrame:Show();
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
