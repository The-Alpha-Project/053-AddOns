--------------------------------------------------------------------------------
-- SimpleQoL, part 4: online messages for players with our addons, health and
-- mana numbers on the party frames, and party quest progress (QuestShare).
-- All messages use the hidden channel of the shared online signal
-- (SIMPLE_HELLO_CHANNEL, see shared/hello.lua).
--------------------------------------------------------------------------------

SIMPLEQOL_ONLINE_DEDUPE = 120;        -- seconds: one message per player and state
SimpleQoL_OnlineSeen = {};            -- name -> { online (1/nil), GetTime() }
SimpleQoL_OnlinePending = {};         -- list of { name, online, time to show }

--------------------------------------------------------------------------------
-- Online messages
--------------------------------------------------------------------------------

-- 1 when this player's online / offline state was already reported lately
-- (by the game for friends, by the guild roster or by us).
function SimpleQoL_OnlineKnown(name, online)
	local seen = SimpleQoL_OnlineSeen[name];
	return seen and seen[1] == online and GetTime() - seen[2] < SIMPLEQOL_ONLINE_DEDUPE;
end

function SimpleQoL_OnlineRemember(name, online)
	SimpleQoL_OnlineSeen[name] = { online, GetTime() };
end

-- Shows "Name has come online" / "Name has gone offline" like the game's own
-- system message (no prefix), once per player and state.
function SimpleQoL_OnlineNotice(name, online, prefix)
	if ( not name or SimpleQoL_OnlineKnown(name, online) ) then
		return;
	end
	SimpleQoL_OnlineRemember(name, online);
	local text = name.." has gone offline";
	if ( online ) then
		text = name.." has come online";
	end
	local r, g, b = 1.0, 1.0, 0.0;
	if ( ChatTypeInfo and ChatTypeInfo["SYSTEM"] ) then
		r, g, b = ChatTypeInfo["SYSTEM"].r, ChatTypeInfo["SYSTEM"].g, ChatTypeInfo["SYSTEM"].b;
	end
	ChatFrame:AddMessage(text, r, g, b);
end

-- The game's own friend messages: shown when they come first (then ours are
-- skipped), hidden when we already said the same about that player.
-- Returns 1 when the message should be hidden.
-- The server names the inviter, not the player who declined a guild invitation
-- ("chaine declines ..." when you are chaine): the name of the last player you
-- invited to the guild is shown instead.
SimpleQoL_LastGuildInvite = nil;
if ( GuildInviteByName ) then
	SimpleQoL_Orig_GuildInviteByName = GuildInviteByName;
	function GuildInviteByName(name)
		if ( name and name ~= "" ) then
			SimpleQoL_LastGuildInvite = strupper(strsub(name, 1, 1))..strlower(strsub(name, 2));
		end
		return SimpleQoL_Orig_GuildInviteByName(name);
	end
end

function SimpleQoL_FixGuildDecline(message)
	local s, e, name = strfind(message, "^(.+) declines your guild invitation");
	if ( name and SimpleQoL_LastGuildInvite and name == UnitName("player") and name ~= SimpleQoL_LastGuildInvite ) then
		arg1 = SimpleQoL_LastGuildInvite..strsub(message, strlen(name) + 1);
	end
end

function SimpleQoL_SystemMessage(message)
	if ( not message ) then
		return nil;
	end
	SimpleQoL_FixGuildDecline(message);
	local online = 1;
	local s, e, name = strfind(message, "^(.+) has come online");
	if ( not name ) then
		online = nil;
		s, e, name = strfind(message, "^(.+) has gone offline");
	end
	if ( not name ) then
		return nil;
	end
	if ( SimpleQoL_OnlineKnown(name, online) ) then
		return 1;
	end
	SimpleQoL_OnlineRemember(name, online);
	return nil;
end

SimpleQoL_Orig_Social_ChatFrame_OnEvent = ChatFrame_OnEvent;
function ChatFrame_OnEvent(event)
	if ( event == "CHAT_MSG_SYSTEM" and this == ChatFrame and SimpleQoL_SystemMessage(arg1) ) then
		return;
	end
	SimpleQoL_Orig_Social_ChatFrame_OnEvent(event);
end


-- H1 / B1 from the shared channel. Shown after 3 seconds, so a friend or guild
-- message about the same player that arrives first wins.
function SimpleQoL_HelloMessage(message, sender)
	if ( not sender or sender == UnitName("player") ) then
		return;
	end
	if ( message == "H1" ) then
		tinsert(SimpleQoL_OnlinePending, { sender, 1, GetTime() + 3 });
	elseif ( message == "B1" ) then
		tinsert(SimpleQoL_OnlinePending, { sender, nil, GetTime() + 3 });
	end
end

function SimpleQoL_OnlineUpdate()
	local i = 1;
	while ( i <= getn(SimpleQoL_OnlinePending) ) do
		local p = SimpleQoL_OnlinePending[i];
		if ( GetTime() >= p[3] ) then
			tremove(SimpleQoL_OnlinePending, i);
			if ( SimpleQoL_On["guildonline"] ) then
				SimpleQoL_OnlineNotice(p[1], p[2], "[Online] ");
			end
		else
			i = i + 1;
		end
	end
end


--------------------------------------------------------------------------------
-- Health and mana numbers on the party frames ("Health and mana numbers")
--------------------------------------------------------------------------------

-- The names are made once and the texts only when a number changed. This
-- runs for the health and mana of every party member (several times a second
-- in a fight): new strings each time are garbage for the collector.
SimpleQoL_PartyNames = {};
SimpleQoL_PartyLast = {};
function SimpleQoL_UpdatePartyStats()
	local i;
	for i = 1, 4 do
		local names = SimpleQoL_PartyNames[i];
		if ( not names ) then
			names = { "party"..i, "SimpleQoLParty"..i.."Health", "SimpleQoLParty"..i.."Mana", "PartyMemberFrame"..i.."HealthBarText" };
			SimpleQoL_PartyNames[i] = names;
			SimpleQoL_PartyLast[i] = {};
		end
		local unit = names[1];
		local health = getglobal(names[2]);
		local mana = getglobal(names[3]);
		-- The client's own party numbers (shown e.g. by AlphaUI): ours stay empty.
		local stock = getglobal(names[4]);
		local stockShown = stock and stock:IsVisible() and stock:GetText() and stock:GetText() ~= "";
		if ( health and mana ) then
			local last = SimpleQoL_PartyLast[i];
			if ( SimpleQoL_On["stats"] and UnitExists(unit) and not stockShown ) then
				local h, hm, m = UnitHealth(unit), UnitHealthMax(unit), UnitMana(unit);
				local mm = UnitManaMax and UnitManaMax(unit);
				if ( not (last.drawn and h == last[1] and hm == last[2] and m == last[3] and mm == last[4]) ) then
					last.drawn = 1;
					last[1], last[2], last[3], last[4] = h, hm, m, mm;
					health:SetText(SimpleQoL_StatText(h, hm));
					mana:SetText(SimpleQoL_StatText(m, mm));
				end
			elseif ( last.drawn ) then
				last.drawn = nil;
				health:SetText("");
				mana:SetText("");
			end
		end
	end
end


--------------------------------------------------------------------------------
-- Party quest progress (QuestShare). Every player with SimpleQoL sends the
-- progress of the quests in their log ("Q1;title;done;objective|objective")
-- while in a party; party members show it beside the quest log for the
-- selected quest. "Q0;title" = the quest left the log.
--------------------------------------------------------------------------------

SIMPLEQOL_SHARE_LINES = 12;
SimpleQoL_ShareSent = {};             -- title -> last sent text
SimpleQoL_ShareQueue = {};            -- texts waiting to be sent
SimpleQoL_ShareSendTime = 0;
SimpleQoL_ShareScanTime = nil;        -- GetTime() for the next scan of our log
SimpleQoL_ShareData = {};             -- sender -> title -> { done, objectives text }

function SimpleQoL_InParty()
	return UnitExists("party1") or UnitExists("party2") or UnitExists("party3") or UnitExists("party4");
end

function SimpleQoL_IsPartyMember(name)
	local i;
	for i = 1, 4 do
		if ( UnitName("party"..i) == name ) then
			return 1;
		end
	end
	return nil;
end

-- No ";" or "|" inside our fields.
function SimpleQoL_ShareClean(text)
	text = gsub(text or "", ";", ",");
	return gsub(text, "|", "/");
end

-- Reads every quest of our log (the selection is put back afterwards).
function SimpleQoL_ShareScan()
	local quests = {};
	local selected = GetQuestLogSelection and GetQuestLogSelection();
	local i, j;
	for i = 1, GetNumQuestLogEntries() do
		local title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i);
		if ( title and not isHeader ) then
			SelectQuestLogEntry(i);
			local parts = "";
			local count = GetNumQuestLeaderBoards() or 0;
			local done = 0;
			for j = 1, count do
				local text, kind, finished = GetQuestLogLeaderBoard(j);
				if ( finished ) then
					done = done + 1;
				end
				if ( j > 1 ) then
					parts = parts.."|";
				end
				parts = parts..SimpleQoL_ShareClean(text or kind or "");
			end
			local complete = "0";
			if ( isComplete == 1 or (count > 0 and done == count) ) then
				complete = "1";
			end
			quests[title] = strsub("Q1;"..SimpleQoL_ShareClean(title)..";"..complete..";"..parts, 1, 240);
		end
	end
	if ( selected ) then
		SelectQuestLogEntry(selected);
	end
	return quests;
end

-- Queue the quests that changed since they were last sent.
function SimpleQoL_ShareCollect(all)
	local quests = SimpleQoL_ShareScan();
	SimpleQoL_ShareScanned = GetTime();
	foreach(quests, function(title, text)
		if ( all or SimpleQoL_ShareSent[title] ~= text ) then
			SimpleQoL_ShareSent[title] = text;
			tinsert(SimpleQoL_ShareQueue, text);
		end
	end);
	local gone = {};
	foreach(SimpleQoL_ShareSent, function(title, text)
		if ( not quests[title] ) then
			tinsert(gone, title);
		end
	end);
	local i;
	for i = 1, getn(gone) do
		SimpleQoL_ShareSent[gone[i]] = nil;
		tinsert(SimpleQoL_ShareQueue, "Q0;"..SimpleQoL_ShareClean(gone[i]));
	end
end

function SimpleQoL_ShareUpdate()
	if ( not SimpleQoL_On["questshare"] or not SimpleQoL_InParty() ) then
		if ( getn(SimpleQoL_ShareQueue) > 0 ) then
			SimpleQoL_ShareQueue = {};
		end
		return;
	end
	if ( SimpleQoL_ShareScanTime and GetTime() >= SimpleQoL_ShareScanTime ) then
		local all = SimpleQoL_ShareAll;
		SimpleQoL_ShareScanTime = nil;
		SimpleQoL_ShareAll = nil;
		SimpleQoL_ShareCollect(all);
	end
	-- One message every 0.3 s.
	if ( getn(SimpleQoL_ShareQueue) > 0 and GetTime() - SimpleQoL_ShareSendTime > 0.3 ) then
		local channel = SimpleHello_Channel and SimpleHello_Channel(1);
		if ( channel ) then
			SimpleQoL_ShareSendTime = GetTime();
			SendChatMessage(tremove(SimpleQoL_ShareQueue, 1), "CHANNEL", nil, channel);
		end
	end
end

function SimpleQoL_ShareMessage(message, sender)
	if ( not sender or not SimpleQoL_IsPartyMember(sender) ) then
		return;
	end
	local s, e, title, done, parts = strfind(message, "^Q1;([^;]*);([01]);(.*)$");
	if ( title ) then
		if ( not SimpleQoL_ShareData[sender] ) then
			SimpleQoL_ShareData[sender] = {};
		end
		SimpleQoL_ShareData[sender][title] = { done, parts };
		SimpleQoL_ShareRefresh();
		return;
	end
	s, e, title = strfind(message, "^Q0;(.*)$");
	if ( title and SimpleQoL_ShareData[sender] ) then
		SimpleQoL_ShareData[sender][title] = nil;
		SimpleQoL_ShareRefresh();
	end
end

-- The panel beside the quest log: party members' progress on the selected quest.
function SimpleQoL_ShareRefresh()
	local lines = {};
	local selected = GetQuestLogSelection and GetQuestLogSelection();
	local title = selected and selected > 0 and GetQuestLogTitle(selected);
	if ( SimpleQoL_On["questshare"] and title and QuestLogFrame:IsVisible() and SimpleQoL_InParty() ) then
		local key = SimpleQoL_ShareClean(title);
		local i;
		for i = 1, 4 do
			local name = UnitName("party"..i);
			local data = name and SimpleQoL_ShareData[name] and SimpleQoL_ShareData[name][key];
			if ( data ) then
				if ( data[1] == "1" ) then
					tinsert(lines, { name..": ready to turn in", 0.2, 1.0, 0.2 });
				else
					tinsert(lines, { name..":", 1.0, 0.82, 0.0 });
					local rest = data[2];
					while ( rest and rest ~= "" ) do
						local cut = strfind(rest, "|", 1, 1);
						local part = rest;
						if ( cut ) then
							part = strsub(rest, 1, cut - 1);
							rest = strsub(rest, cut + 1);
						else
							rest = nil;
						end
						tinsert(lines, { "  "..part, 1.0, 1.0, 1.0 });
					end
				end
			elseif ( name ) then
				tinsert(lines, { name..": not on this quest", 0.5, 0.5, 0.5 });
			end
		end
	end
	if ( getn(lines) == 0 ) then
		SimpleQoLQuestShare:Hide();
		return;
	end
	local i;
	for i = 1, SIMPLEQOL_SHARE_LINES do
		local line = getglobal("SimpleQoLQuestShareLine"..i);
		local data = lines[i];
		if ( data ) then
			line:SetText(data[1]);
			line:SetTextColor(data[2], data[3], data[4]);
			line:Show();
		else
			line:Hide();
		end
	end
	SimpleQoLQuestShare:SetHeight(30 + min(getn(lines), SIMPLEQOL_SHARE_LINES) * 13);
	SimpleQoLQuestShare:Show();
end


--------------------------------------------------------------------------------
-- Events and update (SimpleQoLSocialFrame)
--------------------------------------------------------------------------------

SimpleQoL_SocialTime = 0;

function SimpleQoL_Social_OnLoad()
	this:RegisterEvent("CHAT_MSG_CHANNEL");
	this:RegisterEvent("UNIT_HEALTH");
	this:RegisterEvent("UNIT_MANA");
	this:RegisterEvent("UNIT_MAXHEALTH");
	this:RegisterEvent("UNIT_MAXMANA");
	this:RegisterEvent("PARTY_MEMBERS_CHANGED");
	this:RegisterEvent("QUEST_LOG_UPDATE");
end

function SimpleQoL_Social_OnEvent(event)
	if ( event == "CHAT_MSG_CHANNEL" ) then
		if ( SIMPLE_HELLO_CHANNEL and not SimpleQoL_HelloChannelLower ) then
			SimpleQoL_HelloChannelLower = strlower(SIMPLE_HELLO_CHANNEL);
		end
		if ( SimpleQoL_HelloChannelLower and strfind(strlower((arg4 or "").." "..(arg9 or "")), SimpleQoL_HelloChannelLower, 1, 1) ) then
			SimpleQoL_HelloMessage(arg1, arg2);
			SimpleQoL_ShareMessage(arg1 or "", arg2);
		end
	elseif ( event == "PARTY_MEMBERS_CHANGED" ) then
		SimpleQoL_UpdatePartyStats();
		-- New party: send all our quests again.
		SimpleQoL_ShareAll = 1;
		SimpleQoL_ShareScanTime = GetTime() + 2;
	elseif ( event == "QUEST_LOG_UPDATE" ) then
		-- Our own scan selects quests, which fires this event again: skip those.
		if ( not SimpleQoL_ShareScanTime and GetTime() - (SimpleQoL_ShareScanned or 0) > 0.5 ) then
			SimpleQoL_ShareScanTime = GetTime() + 2;
		end
		if ( QuestLogFrame:IsVisible() ) then
			SimpleQoL_ShareRefresh();
		end
	elseif ( arg1 and strfind(arg1, "^party") ) then
		SimpleQoL_UpdatePartyStats();
	end
end

function SimpleQoL_Social_OnUpdate()
	if ( not SimpleQoL_Loaded or GetTime() - SimpleQoL_SocialTime < 0.5 ) then
		return;
	end
	SimpleQoL_SocialTime = GetTime();
	SimpleQoL_OnlineUpdate();
	SimpleQoL_ShareUpdate();
	-- Follows the quest selected in the open quest log.
	if ( QuestLogFrame:IsVisible() or SimpleQoLQuestShare:IsVisible() ) then
		SimpleQoL_ShareRefresh();
	end
end
