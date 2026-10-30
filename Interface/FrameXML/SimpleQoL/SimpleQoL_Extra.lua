--------------------------------------------------------------------------------
-- SimpleQoL extras: quest log check marks, FPS/ping display, guild tab,
-- guild online messages and bag sorting. Loaded after SimpleQoL.lua.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Quest log check marks: a box in front of every quest; ticked = tracked.
-- Click it to track or untrack the quest.
--------------------------------------------------------------------------------

function SimpleQoL_QuestOffset()
	if ( FauxScrollFrame_GetOffset and QuestLogListScrollFrame ) then
		return FauxScrollFrame_GetOffset(QuestLogListScrollFrame);
	end
	return 0;
end

function SimpleQoL_UpdateQuestChecks()
	local i;
	local numEntries = GetNumQuestLogEntries();
	local offset = SimpleQoL_QuestOffset();
	for i = 1, (QUESTS_DISPLAYED or 6) do
		local check = getglobal("SimpleQoLQuestCheck"..i);
		if ( check ) then
			local index = i + offset;
			local title, level, tag, isHeader = GetQuestLogTitle(index);
			if ( SimpleQoL_On["tracker"] and index <= numEntries and title and not isHeader ) then
				if ( SimpleQoL_TrackIndex(title) ) then
					check:SetChecked(1);
				else
					check:SetChecked(0);
				end
				check:Show();
			else
				check:Hide();
			end
		end
	end
end

SimpleQoL_Orig_QuestLog_Update = QuestLog_Update;
function QuestLog_Update()
	SimpleQoL_Orig_QuestLog_Update();
	SimpleQoL_UpdateQuestChecks();
end

function SimpleQoL_QuestCheck_OnClick()
	local index = this:GetID() + SimpleQoL_QuestOffset();
	local title, level, tag, isHeader = GetQuestLogTitle(index);
	if ( title and not isHeader ) then
		SimpleQoL_ToggleTrack(title);
	end
	SimpleQoL_UpdateQuestChecks();
end

function SimpleQoL_QuestCheck_OnEnter()
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Quest tracker");
	GameTooltip:AddLine("|cffffffffClick to track or untrack this quest.|r");
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- FPS and ping display (off by default). Shift + drag to move it.
--------------------------------------------------------------------------------

SimpleQoL_PerfTime = 0;
SimpleQoL_PerfX = nil;
SimpleQoL_PerfY = nil;
SimpleQoL_PerfDrag = nil;

function SimpleQoL_PlacePerf()
	SimpleQoLPerf:ClearAllPoints();
	if ( SimpleQoL_PerfX and SimpleQoL_PerfY ) then
		SimpleQoLPerf:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", SimpleQoL_PerfX, SimpleQoL_PerfY);
	else
		SimpleQoLPerf:SetPoint("TOPRIGHT", "UIParent", "TOPRIGHT", -200, -8);
	end
end

-- The time (this computer's clock when the client has date, else the game
-- time), 24 hours.
function SimpleQoL_ClockText()
	if ( date ) then
		return date("%H:%M");
	end
	if ( GetGameTime ) then
		local hour, minute = GetGameTime();
		return format("%02d:%02d", hour, minute);
	end
	return "";
end

function SimpleQoL_UpdatePerf(force)
	local clock = SimpleQoL_On["clock"] and not SimpleQoL_AlphaUIHas("clock");
	if ( not SimpleQoL_On["perf"] and not clock ) then
		SimpleQoLPerf:Hide();
		return;
	end
	if ( not force and GetTime() - SimpleQoL_PerfTime < 1 ) then
		return;
	end
	SimpleQoL_PerfTime = GetTime();
	SimpleQoLPerf:Show();
	local text = "";
	if ( SimpleQoL_On["perf"] ) then
		if ( GetFramerate ) then
			text = floor(GetFramerate() + 0.5).." fps";
		end
		if ( GetNetStats ) then
			local bandwidthIn, bandwidthOut, latency = GetNetStats();
			if ( latency ) then
				text = text.."  "..latency.." ms";
			end
		end
	end
	if ( clock ) then
		if ( text ~= "" ) then
			text = text.."  ";
		end
		text = text..SimpleQoL_ClockText();
	end
	SimpleQoLPerfText:SetText(text);
end

function SimpleQoL_Perf_OnMouseDown(button)
	if ( button ~= "LeftButton" or not IsShiftKeyDown() ) then
		return;
	end
	local cx, cy = GetCursorPosition();
	local px, py = SimpleQoLPerf:GetCenter();
	if ( not px ) then
		return;
	end
	local x, y = SimpleQoL_ToScreen(px, py);
	SimpleQoL_PerfDrag = { cx, cy, x - 1, y - 1, SimpleQoL_Scale() };
end

function SimpleQoL_Perf_OnMouseUp()
	if ( SimpleQoL_PerfDrag ) then
		SimpleQoL_PerfDrag = nil;
		if ( SimpleSave_Set and SimpleQoL_PerfX ) then
			SimpleSave_Set("SimpleQoL", "PerfX", floor(SimpleQoL_PerfX + 0.5));
			SimpleSave_Set("SimpleQoL", "PerfY", floor(SimpleQoL_PerfY + 0.5));
		end
	end
end

function SimpleQoL_PerfDragUpdate()
	local drag = SimpleQoL_PerfDrag;
	local cx, cy = GetCursorPosition();
	SimpleQoL_PerfX = drag[3] + (cx - drag[1]) * drag[5];
	SimpleQoL_PerfY = drag[4] + (cy - drag[2]) * drag[5];
	SimpleQoL_PlacePerf();
end

function SimpleQoL_Perf_OnEnter()
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Frame rate and latency");
	GameTooltip:AddLine("|cffffffffShift + drag to move.|r");
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- Guild roster from the server's addon API (the same one AlphaUI uses):
-- "get_guild_roster <token>" in a password channel starting with "_addon".
-- Answer: "gr,token,guild,motd,online,total" then "gm,name,level,class,rank,online".
-- Used for the guild tab and the online / offline messages.
--------------------------------------------------------------------------------

SIMPLEQOL_API_CHANNEL = "_addonsimpleqol";
SIMPLEQOL_API_PASSWORD = "sQoL7xk2pa";
SIMPLEQOL_GUILD_POLL = 30;           -- seconds between roster requests
SIMPLEQOL_GUILD_POLL_SHOWN = 10;     -- while the guild tab is open

SimpleQoL_Guild = { members = {}, loaded = nil, name = "", motd = "", online = 0, total = 0 };
SimpleQoL_GuildIncoming = nil;       -- roster being received
SimpleQoL_GuildIncomingTime = 0;
SimpleQoL_GuildToken = nil;
SimpleQoL_GuildTokenCount = 0;
SimpleQoL_GuildSentTime = 0;
SimpleQoL_GuildNextTime = 5;
SimpleQoL_GuildFailures = 0;
SimpleQoL_GuildNoAPI = nil;
SimpleQoL_GuildJoinTime = 0;
SimpleQoL_GuildOnlineKnown = nil;    -- name -> 1 for online members (last roster)

function SimpleQoL_InGuild()
	-- 0.5.3 may answer 0 for "no" (0 counts as true in Lua).
	if ( IsInGuild ) then
		local inGuild = IsInGuild();
		if ( inGuild and inGuild ~= 0 ) then
			return 1;
		end
	end
	if ( GetGuildInfo ) then
		local name = GetGuildInfo("player");
		if ( name and name ~= "" ) then
			return 1;
		end
	end
	return nil;
end

function SimpleQoL_GuildChannel()
	local number = GetChannelName and GetChannelName(SIMPLEQOL_API_CHANNEL);
	if ( number and number > 0 ) then
		return number;
	end
	if ( GetTime() - SimpleQoL_GuildJoinTime > 10 ) then
		SimpleQoL_GuildJoinTime = GetTime();
		JoinChannelByName(SIMPLEQOL_API_CHANNEL, SIMPLEQOL_API_PASSWORD);
	end
	return nil;
end

function SimpleQoL_GuildWanted()
	if ( SimpleQoL_GuildNoAPI or not SimpleQoL_InGuild() ) then
		return nil;
	end
	return SimpleQoL_On["guildonline"] or (SimpleQoLGuildFrame and SimpleQoLGuildFrame:IsVisible());
end

function SimpleQoL_GuildRequest()
	local channel = SimpleQoL_GuildChannel();
	if ( not channel ) then
		return;
	end
	SimpleQoL_GuildTokenCount = SimpleQoL_GuildTokenCount + 1;
	SimpleQoL_GuildToken = "sq"..SimpleQoL_GuildTokenCount;
	SimpleQoL_GuildSentTime = GetTime();
	SendChatMessage("get_guild_roster "..SimpleQoL_GuildToken, "CHANNEL", nil, channel);
end

function SimpleQoL_GuildUpdate()
	local now = GetTime();
	-- A complete answer: all member lines arrive together, so wait a moment.
	if ( SimpleQoL_GuildIncoming and now - SimpleQoL_GuildIncomingTime > 0.5 ) then
		SimpleQoL_GuildFinish();
	end
	if ( SimpleQoL_GuildToken and now - SimpleQoL_GuildSentTime > 6 ) then
		-- No answer: the server may not have the addon API.
		SimpleQoL_GuildToken = nil;
		SimpleQoL_GuildFailures = SimpleQoL_GuildFailures + 1;
		if ( SimpleQoL_GuildFailures >= 3 ) then
			SimpleQoL_GuildNoAPI = 1;
			SimpleQoL_GuildFrame_Update();
		end
	end
	if ( not SimpleQoL_GuildToken and SimpleQoL_GuildWanted() and now >= SimpleQoL_GuildNextTime ) then
		local wait = SIMPLEQOL_GUILD_POLL;
		if ( SimpleQoLGuildFrame and SimpleQoLGuildFrame:IsVisible() ) then
			wait = SIMPLEQOL_GUILD_POLL_SHOWN;
		end
		SimpleQoL_GuildNextTime = now + wait;
		SimpleQoL_GuildRequest();
	end
end

-- Messages in our channel (only answers to our own requests count).
function SimpleQoL_GuildMessage(message, sender, channel)
	if ( not message or not channel or not strfind(strlower(channel), SIMPLEQOL_API_CHANNEL, 1, 1) ) then
		return;
	end
	if ( sender and UnitName("player") and strlower(sender) ~= strlower(UnitName("player")) ) then
		return;
	end
	local s, e, token, name, motd, online, total = strfind(message, "^gr,([^,]+),([^,]*),([^,]*),([^,]*),([^,]*)$");
	if ( token ) then
		if ( token ~= SimpleQoL_GuildToken ) then
			return;
		end
		SimpleQoL_GuildToken = nil;
		SimpleQoL_GuildFailures = 0;
		SimpleQoL_GuildIncoming = { members = {}, name = name, motd = motd, online = (online or 0) + 0, total = (total or 0) + 0 };
		SimpleQoL_GuildIncomingTime = GetTime();
		return;
	end
	local member, level, class, rank, isOnline;
	s, e, member, level, class, rank, isOnline = strfind(message, "^gm,([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$");
	if ( member and SimpleQoL_GuildIncoming ) then
		tinsert(SimpleQoL_GuildIncoming.members, { member, level + 0, class + 0, rank + 0, isOnline == "1" });
		SimpleQoL_GuildIncomingTime = GetTime();
		return;
	end
	-- Errors: "-code, unit, token". Try again a bit later.
	if ( strsub(message, 1, 1) == "-" and SimpleQoL_GuildToken and strfind(message, SimpleQoL_GuildToken, 1, 1) ) then
		SimpleQoL_GuildToken = nil;
		SimpleQoL_GuildNextTime = GetTime() + 5;
	end
end

function SimpleQoL_GuildFinish()
	local roster = SimpleQoL_GuildIncoming;
	SimpleQoL_GuildIncoming = nil;
	local now = {};
	local i;
	for i = 1, getn(roster.members) do
		if ( roster.members[i][5] ) then
			now[roster.members[i][1]] = 1;
		end
	end
	-- Online / offline messages (not for the first roster after login).
	if ( SimpleQoL_GuildOnlineKnown and SimpleQoL_On["guildonline"] ) then
		local me = UnitName("player");
		for i = 1, getn(roster.members) do
			local name = roster.members[i][1];
			if ( name ~= me ) then
				if ( now[name] and not SimpleQoL_GuildOnlineKnown[name] ) then
					SimpleQoL_OnlineNotice(name, 1, "[Guild] ");
				elseif ( not now[name] and SimpleQoL_GuildOnlineKnown[name] ) then
					SimpleQoL_OnlineNotice(name, nil, "[Guild] ");
				end
			end
		end
	end
	SimpleQoL_GuildOnlineKnown = now;
	SimpleQoL_Guild = roster;
	SimpleQoL_Guild.loaded = 1;
	SimpleQoL_GuildFrame_Update();
end

-- Our channel never shows in the chat (join messages, requests, answers).
SimpleQoL_Orig_ChatFrame_OnEvent = ChatFrame_OnEvent;
function ChatFrame_OnEvent(event)
	if ( strfind(event, "^CHAT_MSG_CHANNEL") ) then
		local text = strlower((arg4 or "").." "..(arg9 or "").." "..(arg1 or ""));
		if ( strfind(text, SIMPLEQOL_API_CHANNEL, 1, 1) ) then
			return;
		end
	end
	SimpleQoL_Orig_ChatFrame_OnEvent(event);
end


--------------------------------------------------------------------------------
-- Sort bags: /sortbags or the small "Sort" button on the open backpack
-- (stock bags and AlphaUI's merged bags). Arrows go into quivers and bullets
-- into ammo pouches first; nothing else is put there. Items are ordered by
-- quality (best first), then name, then stack size; empty slots end up last. One swap at a
-- time, waiting for the server to unlock the slots in between.
--------------------------------------------------------------------------------

SimpleQoL_Sorting = nil;
SimpleQoL_SortSteps = 0;
SimpleQoL_SortTime = 0;
SIMPLEQOL_SORT_MAX_STEPS = 300;

SimpleQoL_SortTarget = "bags";        -- "bags" or "bank"
SimpleQoL_SortMergeTried = {};        -- merge pairs already tried this sort

-- Slots to sort: { bag, slot }. Bag -1 is the bank's own 24 slots.
function SimpleQoL_SortSlots()
	local slots = {};
	local bag, slot;
	local first, last = 0, 4;
	if ( SimpleQoL_SortTarget == "bank" ) then
		for slot = 1, (NUM_BANKGENERIC_SLOTS or 24) do
			tinsert(slots, { -1, slot });
		end
		first, last = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6);
	end
	for bag = first, last do
		local count = GetContainerNumSlots(bag) or 0;
		for slot = 1, count do
			tinsert(slots, { bag, slot });
		end
	end
	return slots;
end

SIMPLEQOL_LINK_QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 };

-- texture, count, locked, quality, link of a slot (also the bank's own slots).
function SimpleQoL_SortInfo(bag, slot)
	if ( bag == -1 ) then
		local inv = BankButtonIDToInvSlotID(slot);
		local texture = GetInventoryItemTexture("player", inv);
		if ( not texture ) then
			return nil;
		end
		local link = GetInventoryItemLink("player", inv);
		local quality = GetInventoryItemQuality and GetInventoryItemQuality("player", inv);
		if ( not quality and link ) then
			local s, e, color = strfind(link, "|c%x%x(%x%x%x%x%x%x)");
			quality = color and SIMPLEQOL_LINK_QUALITY[strlower(color)];
		end
		return texture, GetInventoryItemCount("player", inv), IsInventoryItemLocked(inv), quality, link;
	end
	local texture, count, locked, quality = GetContainerItemInfo(bag, slot);
	return texture, count, locked, quality, texture and GetContainerItemLink(bag, slot);
end

function SimpleQoL_SortPickup(bag, slot)
	if ( bag == -1 ) then
		PickupBankGenericItem(slot);
	else
		PickupContainerItem(bag, slot);
	end
end

function SimpleQoL_SortAmmoKind(bag, slot)
	local s, e, l, q, link = SimpleQoL_SortInfo(bag, slot);
	local name = SimpleQoL_LinkName(link);
	return name and SIMPLEQOL_AMMO_ITEMS and SIMPLEQOL_AMMO_ITEMS[name];
end

-- Sort key of a slot; "" for an empty slot, nil if it is locked.
function SimpleQoL_SortKey(bag, slot)
	local texture, count, locked, quality, link = SimpleQoL_SortInfo(bag, slot);
	if ( not texture ) then
		return "";
	end
	if ( locked ) then
		return nil;
	end
	local name = SimpleQoL_LinkName(link) or texture;
	if ( not quality or quality < 0 or quality > 9 ) then
		quality = 1;
	end
	count = count or 1;
	-- Lower string = earlier: best quality first, then name, then big stacks first.
	return (9 - quality).."|"..strlower(name).."|"..(9999 - count);
end

function SimpleQoL_SortBags(target)
	if ( SimpleQoL_Sorting ) then
		return;
	end
	SimpleQoL_SortTarget = target or "bags";
	SimpleQoL_Sorting = 1;
	SimpleQoL_SortSteps = 0;
	SimpleQoL_SortTime = 0;
	SimpleQoL_SortMergeTried = {};
	if ( SimpleQoL_SortTarget == "bank" ) then
		SimpleQoL_Print("sorting your bank...");
	else
		SimpleQoL_Print("sorting your bags...");
	end
end

-- The bank and its bags; only while the bank window is open.
function SimpleQoL_SortBank()
	if ( not BankFrame or not BankFrame:IsVisible() ) then
		SimpleQoL_Print("open the bank first.");
		return;
	end
	SimpleQoL_SortBags("bank");
end

-- One step: find the first slot that holds the wrong item and swap the right
-- item into it.
function SimpleQoL_SortStep()
	local slots = SimpleQoL_SortSlots();
	local keys = {};
	local kinds = {};                -- "A" / "B" for arrows / bullets
	local bagKind = {};              -- "A" quiver, "B" ammo pouch, nil other bags
	local i, j;
	for i = 1, getn(slots) do
		local key = SimpleQoL_SortKey(slots[i][1], slots[i][2]);
		if ( key == nil ) then
			return;                  -- something is still locked; wait
		end
		keys[i] = key;
		bagKind[i] = SimpleQoL_AmmoBagKind and SimpleQoL_AmmoBagKind(slots[i][1]);
		if ( key ~= "" ) then
			kinds[i] = SimpleQoL_SortAmmoKind(slots[i][1], slots[i][2]);
		end
	end
	-- Partial stacks of the same item are combined first, smallest into
	-- largest, before the positional sort below. A pair whose counts did
	-- not change after a try (the target was already full) is not tried
	-- again this sort.
	local links, counts = {}, {};
	for i = 1, getn(slots) do
		if ( keys[i] ~= "" ) then
			local texture, count, locked, quality, link = SimpleQoL_SortInfo(slots[i][1], slots[i][2]);
			links[i] = link or texture;
			counts[i] = count or 1;
		end
	end
	for i = 1, getn(slots) do
		if ( links[i] ) then
			for j = i + 1, getn(slots) do
				if ( links[j] == links[i] ) then
					local small, large = i, j;
					if ( counts[large] < counts[small] ) then
						small, large = large, small;
					end
					local sig = links[i].."|"..counts[small].."|"..counts[large];
					if ( not SimpleQoL_SortMergeTried[sig] ) then
						SimpleQoL_SortMergeTried[sig] = 1;
						-- Pick up the smaller stack and drop it onto the bigger one;
						-- the client merges up to the max stack size and leaves any
						-- leftover on the cursor, so place the cursor back on the
						-- (now empty, or partly refilled) source slot last.
						SimpleQoL_SortPickup(slots[small][1], slots[small][2]);
						SimpleQoL_SortPickup(slots[large][1], slots[large][2]);
						SimpleQoL_SortPickup(slots[small][1], slots[small][2]);
						SimpleQoL_SortSteps = SimpleQoL_SortSteps + 1;
						return;
					end
				end
			end
		end
	end
	-- Arrows go to the quiver slots and bullets to the ammo pouch slots first;
	-- the rest (and ammo that does not fit) is sorted into the other bags.
	local sortKeys = function(list)
		local a, b;
		for a = 2, getn(list) do
			local value = list[a];
			b = a - 1;
			while ( b >= 1 and list[b] > value ) do
				list[b + 1] = list[b];
				b = b - 1;
			end
			list[b + 1] = value;
		end
	end;
	local ammo = { A = {}, B = {} };
	local other = {};
	for i = 1, getn(slots) do
		if ( keys[i] ~= "" ) then
			if ( kinds[i] ) then
				tinsert(ammo[kinds[i]], keys[i]);
			else
				tinsert(other, keys[i]);
			end
		end
	end
	sortKeys(ammo.A);
	sortKeys(ammo.B);
	local wanted = {};
	local used = { A = 0, B = 0 };
	for i = 1, getn(slots) do
		local k = bagKind[i];
		if ( k ) then
			used[k] = used[k] + 1;
			wanted[i] = ammo[k][used[k]] or "";
		end
	end
	for i = 1, 2 do
		local k = (i == 1) and "A" or "B";
		for j = used[k] + 1, getn(ammo[k]) do
			tinsert(other, ammo[k][j]);
		end
	end
	sortKeys(other);
	local n = 0;
	for i = 1, getn(slots) do
		if ( not bagKind[i] ) then
			n = n + 1;
			wanted[i] = other[n] or "";
		end
	end
	-- Can the item of slot "from" go into slot "to"?
	local fits = function(from, to)
		return keys[from] == "" or not bagKind[to] or kinds[from] == bagKind[to];
	end;
	for i = 1, getn(slots) do
		if ( keys[i] ~= wanted[i] ) then
			for j = 1, getn(slots) do
				if ( j ~= i and keys[j] == wanted[i] and keys[j] ~= wanted[j] ) then
					if ( fits(i, j) ) then
						-- Pick up the wanted item, drop it on slot i; if slot i
						-- held an item it is now on the cursor: put it where the
						-- wanted item was.
						SimpleQoL_SortPickup(slots[j][1], slots[j][2]);
						SimpleQoL_SortPickup(slots[i][1], slots[i][2]);
						if ( keys[i] ~= "" ) then
							SimpleQoL_SortPickup(slots[j][1], slots[j][2]);
						end
						SimpleQoL_SortSteps = SimpleQoL_SortSteps + 1;
						return;
					end
					-- The item in slot i cannot go there (ammo bag): first move
					-- it to an empty slot where it may go.
					local e;
					for e = 1, getn(slots) do
						if ( keys[e] == "" and e ~= i and fits(i, e) ) then
							SimpleQoL_SortPickup(slots[i][1], slots[i][2]);
							SimpleQoL_SortPickup(slots[e][1], slots[e][2]);
							SimpleQoL_SortSteps = SimpleQoL_SortSteps + 1;
							return;
						end
					end
				end
			end
		end
	end
	SimpleQoL_Sorting = nil;
	if ( SimpleQoL_SortTarget == "bank" ) then
		SimpleQoL_Print("bank sorted.");
	else
		SimpleQoL_Print("bags sorted.");
	end
end

function SimpleQoL_SortUpdate()
	if ( not SimpleQoL_Sorting or GetTime() - SimpleQoL_SortTime < 0.25 ) then
		return;
	end
	SimpleQoL_SortTime = GetTime();
	if ( SimpleQoL_SortTarget == "bank" and not (BankFrame and BankFrame:IsVisible()) ) then
		SimpleQoL_Sorting = nil;
		SimpleQoL_Print("sorting stopped (the bank was closed).");
		return;
	end
	if ( SimpleQoL_SortSteps >= SIMPLEQOL_SORT_MAX_STEPS ) then
		SimpleQoL_Sorting = nil;
		SimpleQoL_Print("sorting stopped (too many moves).");
		return;
	end
	SimpleQoL_SortStep();
end

-- The Sort button sits on whichever backpack window is open.
function SimpleQoL_PlaceSortButton()
	local anchor = nil;
	local merged = getglobal("MainMergedBagsFrame");
	if ( merged and merged:IsVisible() ) then
		anchor = "MainMergedBagsFrameCloseButton";
	else
		-- The frame names are built once, not every 0.2 seconds.
		if ( not SimpleQoL_ContainerNames ) then
			SimpleQoL_ContainerNames = {};
			local n;
			for n = 1, (NUM_CONTAINER_FRAMES or 7) do
				SimpleQoL_ContainerNames[n] = "ContainerFrame"..n;
			end
		end
		local i, frame;
		for i = 1, getn(SimpleQoL_ContainerNames) do
			frame = getglobal(SimpleQoL_ContainerNames[i]);
			if ( frame and frame:IsVisible() and frame:GetID() == 0 ) then
				anchor = SimpleQoL_ContainerNames[i].."CloseButton";
			end
		end
	end
	if ( not anchor or not getglobal(anchor) ) then
		SimpleQoLSortButton:Hide();
		SimpleQoL_SortAnchor = nil;
		return;
	end
	if ( SimpleQoL_SortAnchor ~= anchor ) then
		SimpleQoL_SortAnchor = anchor;
		SimpleQoLSortButton:ClearAllPoints();
		SimpleQoLSortButton:SetPoint("RIGHT", anchor, "LEFT", 2, 0);
	end
	SimpleQoLSortButton:Show();
end

function SimpleQoL_SortButton_OnEnter()
	this:SetAlpha(1.0);
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Sort bags");
	GameTooltip:AddLine("|cffffffffSorts all your bags (also /sortbags).|r");
	GameTooltip:Show();
end

function SimpleQoL_SortButton_OnLeave()
	this:SetAlpha(0.5);
	GameTooltip:Hide();
end

SlashCmdList["SIMPLEQOLSORT"] = function()
	SimpleQoL_SortBags();
end;
SLASH_SIMPLEQOLSORT1 = "/sortbags";

SlashCmdList["SIMPLEQOLSORTBANK"] = function()
	SimpleQoL_SortBank();
end;
SLASH_SIMPLEQOLSORTBANK1 = "/sortbank";

function SimpleQoL_BankSortButton_OnEnter()
	this:SetAlpha(1.0);
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Sort bank");
	GameTooltip:AddLine("|cffffffffSorts the bank and its bags (also /sortbank).|r");
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- Auto dismount. In 0.5.3 a mount is an item (e.g. Grey Ram Harness) that
-- works as a toggle, not a buff. The server's addon API ("sub_mount") tells
-- us when you mount ("mnt,1") or dismount ("mnt,0"); the item or action
-- button used just before mounting is remembered (per character). When an
-- action fails with "Can not use while mounted", that item is used again
-- and the failed button is pressed again once you are off the mount.
--------------------------------------------------------------------------------

SIMPLEQOL_MOUNT_WORDS = { "harness", "bridle", "reins", "ram", "horse", "kodo", "raptor", "wolf", "mechanostrider", "saber", "steed", "mount" };
SimpleQoL_LastActionSlot = nil;
SimpleQoL_LastActionTime = 0;
SimpleQoL_LastItemName = nil;
SimpleQoL_LastItemTime = 0;
SimpleQoL_MountItem = nil;          -- learned mount item name
SimpleQoL_MountAction = nil;        -- or learned action slot
SimpleQoL_Mounted = nil;
SimpleQoL_MountSubscribed = nil;
SimpleQoL_Recast = nil;             -- action slot to press again
SimpleQoL_RecastTime = 0;
SimpleQoL_DismountTime = 0;
SimpleQoL_Internal = nil;           -- 1 while we use an item / action ourselves

SimpleQoL_Orig_Extra_UseAction = UseAction;
function UseAction(id, checkCursor, onSelf)
	if ( not SimpleQoL_Internal ) then
		SimpleQoL_LastActionSlot = id;
		SimpleQoL_LastActionTime = GetTime();
	end
	SimpleQoL_Orig_Extra_UseAction(id, checkCursor, onSelf);
end

SimpleQoL_Orig_UseContainerItem = UseContainerItem;
function UseContainerItem(bag, slot)
	if ( SpellIsTargeting and SpellIsTargeting() ) then
		SimpleQoL_Orig_UseContainerItem(bag, slot);
		return;
	end
	if ( not SimpleQoL_Internal and not (MerchantFrame and MerchantFrame:IsVisible()) ) then
		SimpleQoL_LastItemName = SimpleQoL_LinkName(GetContainerItemLink(bag, slot));
		SimpleQoL_LastItemTime = GetTime();
		SimpleQoL_LastBag = bag;
		SimpleQoL_LastSlot = slot;
	end
	SimpleQoL_Orig_UseContainerItem(bag, slot);
end

function SimpleQoL_MountMessage(message)
	local s, e, state = strfind(message, "^mnt,(%d)");
	if ( not state ) then
		return nil;
	end
	local now = GetTime();
	if ( state == "1" ) then
		SimpleQoL_Mounted = 1;
		-- Learn what was used to mount (within 3 seconds).
		if ( SimpleQoL_LastItemName and now - SimpleQoL_LastItemTime < 3 ) then
			SimpleQoL_MountItem = SimpleQoL_LastItemName;
			SimpleQoL_MountAction = nil;
			SimpleQoL_SaveMount();
		elseif ( SimpleQoL_LastActionSlot and now - SimpleQoL_LastActionTime < 3 ) then
			SimpleQoL_MountAction = SimpleQoL_LastActionSlot;
			SimpleQoL_MountItem = nil;
			SimpleQoL_SaveMount();
		end
	else
		SimpleQoL_Mounted = nil;
		if ( SimpleQoL_Recast or SimpleQoL_RecastItem ) then
			SimpleQoL_DoRecast();
		end
	end
	return 1;
end

function SimpleQoL_SaveMount()
	if ( SimpleSave_SetChar ) then
		SimpleSave_SetChar("SimpleQoL", "MountItem", SimpleQoL_MountItem);
		SimpleSave_SetChar("SimpleQoL", "MountAction", SimpleQoL_MountAction);
	end
end

function SimpleQoL_FindBagItem(match)
	local bag, slot;
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local name = SimpleQoL_LinkName(GetContainerItemLink(bag, slot));
			if ( name and match(name) ) then
				return bag, slot;
			end
		end
	end
	return nil;
end

function SimpleQoL_UseMount()
	-- A bag item wins over a learned action slot: the item is checked live
	-- (right now, in your bags), while the action slot is only a guess from
	-- an earlier login and silently presses the wrong button once your bars
	-- change, with no error to catch it by.
	local bag, slot;
	if ( SimpleQoL_MountItem ) then
		bag, slot = SimpleQoL_FindBagItem(function(name) return name == SimpleQoL_MountItem; end);
	end
	local how;
	if ( not bag ) then
		bag, slot = SimpleQoL_FindBagItem(function(name)
			local lower = strlower(name);
			local i;
			for i = 1, getn(SIMPLEQOL_MOUNT_WORDS) do
				if ( strfind(lower, SIMPLEQOL_MOUNT_WORDS[i], 1, 1) ) then
					return 1;
				end
			end
			return nil;
		end);
		if ( bag ) then
			how = "a bag item matched by name";
		end
	else
		how = "the learned item ("..SimpleQoL_MountItem..")";
	end
	SimpleQoL_Internal = 1;
	SimpleQoL_InternalTime = GetTime();
	if ( bag ) then
		UseContainerItem(bag, slot);
	elseif ( SimpleQoL_MountAction ) then
		UseAction(SimpleQoL_MountAction);
		how = "the learned action slot";
	else
		SimpleQoL_Internal = nil;
		return nil;
	end
	SimpleQoL_Internal = nil;
	return how;
end

SimpleQoL_DismountBusy = nil;

function SimpleQoL_Dismount()
	local now = GetTime();
	-- Using the mount can itself give a "mounted" error at once, which calls
	-- this again from inside: that would never end (C stack overflow). One
	-- run at a time; the mark times out by itself if something went wrong.
	if ( SimpleQoL_DismountBusy and now - SimpleQoL_DismountBusy < 1 ) then
		return;
	end
	-- Our own mark must never stay on after an error.
	if ( SimpleQoL_Internal and now - (SimpleQoL_InternalTime or 0) > 2 ) then
		SimpleQoL_Internal = nil;
	end
	-- Never while you hold a spell or item on the cursor (using the mount
	-- would drop it).
	if ( SimpleQoL_CursorBusy() ) then
		return;
	end
	if ( now - SimpleQoL_DismountTime < 1.5 ) then
		return;
	end
	-- The button that failed (pressed just now), unless it is the mount itself.
	local failed = nil;
	if ( SimpleQoL_LastActionSlot and now - SimpleQoL_LastActionTime < 1 and SimpleQoL_LastActionSlot ~= SimpleQoL_MountAction ) then
		failed = SimpleQoL_LastActionSlot;
	end
	-- Or a bag item (food, drink, potion ...) used just now.
	local failedItem = nil;
	if ( not failed and SimpleQoL_LastBag and now - SimpleQoL_LastItemTime < 1 and SimpleQoL_LastItemName ~= SimpleQoL_MountItem ) then
		failedItem = { SimpleQoL_LastBag, SimpleQoL_LastSlot };
	end
	SimpleQoL_DismountBusy = now;
	local used = SimpleQoL_UseMount();
	SimpleQoL_DismountBusy = nil;
	if ( used ) then
		SimpleQoL_DismountTime = now;
		SimpleQoL_Recast = failed;
		SimpleQoL_RecastItem = failedItem;
		SimpleQoL_RecastTime = now;
	end
end

function SimpleQoL_DoRecast()
	local slot = SimpleQoL_Recast;
	local item = SimpleQoL_RecastItem;
	SimpleQoL_Recast = nil;
	SimpleQoL_RecastItem = nil;
	SimpleQoL_Internal = 1;
	SimpleQoL_InternalTime = GetTime();
	if ( slot ) then
		UseAction(slot, 0);
	elseif ( item ) then
		UseContainerItem(item[1], item[2]);
	end
	SimpleQoL_Internal = nil;
end

-- Without an answer from the server, press the button again after 0.6 s.
function SimpleQoL_MountUpdate()
	if ( (SimpleQoL_Recast or SimpleQoL_RecastItem) and GetTime() - SimpleQoL_RecastTime > 0.6 ) then
		SimpleQoL_DoRecast();
	end
	if ( not SimpleQoL_MountSubscribed and SimpleQoL_On["dismount"] and not SimpleQoL_GuildNoAPI ) then
		local channel = SimpleQoL_GuildChannel();
		if ( channel ) then
			SimpleQoL_MountSubscribed = 1;
			SendChatMessage("sub_mount", "CHANNEL", nil, channel);
		end
	end
end


--------------------------------------------------------------------------------
-- Keep stealth: Stealth, Prowl and Shadowmeld are toggles; pressing them (or
-- Vanish) again while stealthed is ignored. Names come from the tooltip of the
-- action / spell / buff, icons are a second check.
--------------------------------------------------------------------------------

SIMPLEQOL_STEALTH_NAMES = { "Stealth", "Prowl", "Shadowmeld", "Vanish" };
SIMPLEQOL_STEALTH_ICONS = { "ability_stealth", "ability_ambush", "ability_druid_supriseattack", "ability_vanish" };

function SimpleQoL_IsStealthName(name)
	if ( not name ) then
		return nil;
	end
	local i;
	for i = 1, getn(SIMPLEQOL_STEALTH_NAMES) do
		if ( name == SIMPLEQOL_STEALTH_NAMES[i] ) then
			return 1;
		end
	end
	return nil;
end

function SimpleQoL_IsStealthIcon(texture)
	if ( not texture ) then
		return nil;
	end
	local lower = strlower(texture);
	local i;
	for i = 1, getn(SIMPLEQOL_STEALTH_ICONS) do
		if ( strfind(lower, SIMPLEQOL_STEALTH_ICONS[i], 1, 1) ) then
			return 1;
		end
	end
	return nil;
end

-- First tooltip line after a Set... call, then the tooltip is hidden again.
function SimpleQoL_TooltipName(setter, a, b)
	if ( not GameTooltip[setter] or not GameTooltipTextLeft1 ) then
		return nil;
	end
	local owned = GameTooltip:IsVisible();
	if ( owned ) then
		return nil;                  -- do not disturb a tooltip the player is reading
	end
	GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT");
	GameTooltip[setter](GameTooltip, a, b);
	local name = GameTooltipTextLeft1:GetText();
	GameTooltip:Hide();
	return name;
end

-- Returns the buff index of Stealth / Prowl / Shadowmeld (0 is a valid index).
function SimpleQoL_IsStealthed()
	if ( not GetPlayerBuff ) then
		return nil;
	end
	local i;
	for i = 0, 23 do
		local buffIndex = GetPlayerBuff(i, "HELPFUL");
		if ( buffIndex and buffIndex >= 0 ) then
			if ( GetPlayerBuffTexture and SimpleQoL_IsStealthIcon(GetPlayerBuffTexture(buffIndex)) ) then
				return buffIndex;
			end
			if ( SimpleQoL_IsStealthName(SimpleQoL_TooltipName("SetPlayerBuff", buffIndex)) ) then
				return buffIndex;
			end
		end
	end
	return nil;
end

function SimpleQoL_IsStealthAction(slot)
	if ( GetActionTexture and SimpleQoL_IsStealthIcon(GetActionTexture(slot)) ) then
		return 1;
	end
	return SimpleQoL_IsStealthName(SimpleQoL_TooltipName("SetAction", slot));
end

-- alpha-core has no Stealth toggle: casting it again only refreshes the buff.
-- A press while stealthed is ignored; Shift + press removes the buff, which
-- is the reliable way out of Stealth.
function SimpleQoL_StealthPress(isStealthSpell)
	if ( not SimpleQoL_On["keepstealth"] or not isStealthSpell ) then
		return nil;
	end
	local buffIndex = SimpleQoL_IsStealthed();
	if ( not buffIndex ) then
		return nil;
	end
	if ( IsShiftKeyDown() and CancelPlayerBuff ) then
		CancelPlayerBuff(buffIndex);
	end
	return 1;
end

-- 1 = this press is handled here (ignored, or Stealth removed with Shift).
function SimpleQoL_KeepStealthAction(slot)
	-- A click that places a held spell on the button is not a press.
	if ( SimpleQoL_CursorBusy() ) then
		return nil;
	end
	return slot and SimpleQoL_StealthPress(SimpleQoL_IsStealthAction(slot));
end

SimpleQoL_Orig_Stealth_UseAction = UseAction;
function UseAction(id, checkCursor, onSelf)
	if ( SimpleQoL_KeepStealthAction(id) ) then
		return;
	end
	SimpleQoL_Orig_Stealth_UseAction(id, checkCursor, onSelf);
end

-- Spells cast from the spellbook.
SimpleQoL_Orig_CastSpell = CastSpell;
function CastSpell(id, bookType)
	if ( GetSpellName and SimpleQoL_StealthPress(SimpleQoL_IsStealthName(GetSpellName(id, bookType))) ) then
		return;
	end
	SimpleQoL_Orig_CastSpell(id, bookType);
end

-- Stance bar (rogue Stealth, druid Prowl).
if ( CastShapeshiftForm ) then
	SimpleQoL_Orig_CastShapeshiftForm = CastShapeshiftForm;
	function CastShapeshiftForm(id)
		local name = nil;
		local texture = nil;
		if ( GetShapeshiftFormInfo ) then
			texture, name = GetShapeshiftFormInfo(id);
		end
		if ( SimpleQoL_StealthPress(SimpleQoL_IsStealthName(name) or SimpleQoL_IsStealthIcon(texture)) ) then
			return;
		end
		SimpleQoL_Orig_CastShapeshiftForm(id);
	end
end


--------------------------------------------------------------------------------
-- Runs every frame (SimpleQoLExtraFrame).
--------------------------------------------------------------------------------

SimpleQoL_ExtraTime = 0;

--------------------------------------------------------------------------------
-- With AlphaUI: its Class Portraits start off, so the player and target show
-- their normal portraits. Done with AlphaUI's own DisableModule, once per
-- character when AlphaUI keeps its settings on the server (you can turn it
-- back on in AlphaUI). When AlphaUI only keeps settings for the session, it
-- is done at every login.
--------------------------------------------------------------------------------

SimpleQoL_PortraitDone = nil;
SimpleQoL_PortraitSession = nil;

function SimpleQoL_AlphaPortraitDefault()
	if ( SimpleQoL_PortraitDone or not Main or not Main.Initialized or not Main.DisableModule
		or not Main.GetModule or not Main.GetModule("class_portraits") ) then
		return;
	end
	if ( SimpleSave_IsLoaded and not SimpleSave_IsLoaded() ) then
		return;
	end
	local api = Main.API;
	if ( api and api.remoteLoaded ) then
		-- Settings from the server are read: once per character.
		SimpleQoL_PortraitDone = 1;
		if ( SimpleSave_GetChar and SimpleSave_GetChar("SimpleQoL", "AUIPortraits") ) then
			return;
		end
		Main.DisableModule("class_portraits");
		if ( SimpleSave_SetChar ) then
			SimpleSave_SetChar("SimpleQoL", "AUIPortraits", 1);
		end
		return;
	end
	-- Session only (or not read yet): off for this session; keep watching in
	-- case the server settings arrive later.
	if ( not SimpleQoL_PortraitSession ) then
		SimpleQoL_PortraitSession = 1;
		Main.DisableModule("class_portraits");
	end
	if ( api and api.configUnsupported ) then
		SimpleQoL_PortraitDone = 1;
	end
end

-- AlphaUI's clock (a framed window) starts off, once per character; our
-- Clock setting is the discreet one.
SimpleQoL_ClockDone = nil;
SimpleQoL_ClockSession = nil;

function SimpleQoL_AlphaClockDefault()
	if ( SimpleQoL_ClockDone or not Main or not Main.Initialized or not Main.DisableModule
		or not Main.GetModule or not Main.GetModule("clock") ) then
		return;
	end
	if ( SimpleSave_IsLoaded and not SimpleSave_IsLoaded() ) then
		return;
	end
	local api = Main.API;
	if ( api and api.remoteLoaded ) then
		SimpleQoL_ClockDone = 1;
		if ( SimpleSave_GetChar and SimpleSave_GetChar("SimpleQoL", "AUIClock") ) then
			return;
		end
		Main.DisableModule("clock");
		if ( SimpleSave_SetChar ) then
			SimpleSave_SetChar("SimpleQoL", "AUIClock", 1);
		end
		return;
	end
	if ( not SimpleQoL_ClockSession ) then
		SimpleQoL_ClockSession = 1;
		Main.DisableModule("clock");
	end
	if ( api and api.configUnsupported ) then
		SimpleQoL_ClockDone = 1;
	end
end

function SimpleQoL_Extra_OnUpdate()
	if ( not SimpleQoL_Loaded ) then
		return;
	end
	if ( SimpleQoL_PerfDrag ) then
		SimpleQoL_PerfDragUpdate();
	end
	SimpleQoL_SortUpdate();
	SimpleQoL_UpdatePerf();
	SimpleQoL_MountUpdate();
	if ( SimpleQoL_AutoTrackUpdate ) then
		SimpleQoL_AutoTrackUpdate();
	end
	if ( SimpleQoL_BagCDUpdate ) then
		SimpleQoL_BagCDUpdate();
	end
	if ( GetTime() - SimpleQoL_ExtraTime > 0.2 ) then
		SimpleQoL_ExtraTime = GetTime();
		SimpleQoL_PlaceSortButton();
		SimpleQoL_AlphaPortraitDefault();
		SimpleQoL_AlphaClockDefault();
		SimpleQoL_GuildUpdate();
		SimpleQoL_AlphaUIGuildTabCheck();
	end
end

function SimpleQoL_Extra_OnLoad()
	this:RegisterEvent("CHAT_MSG_CHANNEL");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("SPELLS_CHANGED");
end

function SimpleQoL_Extra_OnEvent(event)
	if ( event == "SPELLS_CHANGED" ) then
		SimpleQoL_TrackSlots = nil;
	elseif ( event == "CHAT_MSG_CHANNEL" ) then
		local channel = arg4 or arg9;
		if ( arg1 and channel and strfind(strlower(channel), SIMPLEQOL_API_CHANNEL, 1, 1)
				and (not arg2 or not UnitName("player") or strlower(arg2) == strlower(UnitName("player")))
				and SimpleQoL_MountMessage(arg1) ) then
			return;
		end
		SimpleQoL_GuildMessage(arg1, arg2, channel);
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		-- Subscriptions end when you log out or zone; ask again.
		SimpleQoL_MountSubscribed = nil;
		SimpleQoL_TrackSlots = nil;
	end
end

-- Called by SimpleQoL_Load once the saved settings are read.
function SimpleQoL_ExtraLoaded()
	if ( SimpleSave_GetNumber ) then
		SimpleQoL_PerfX = SimpleSave_GetNumber("SimpleQoL", "PerfX");
		SimpleQoL_PerfY = SimpleSave_GetNumber("SimpleQoL", "PerfY");
		SimpleQoL_MountItem = SimpleSave_GetChar("SimpleQoL", "MountItem");
		SimpleQoL_MountAction = SimpleSave_GetCharNumber and SimpleSave_GetCharNumber("SimpleQoL", "MountAction");
	end
	SimpleQoL_PlacePerf();
	SimpleQoL_UpdatePerf(1);
	SimpleQoL_SetupGuildTab();
	SimpleQoL_GuildNextTime = GetTime() + 5;
end

-- A check box changed (from SimpleQoLOptions_Toggle / Defaults).
function SimpleQoL_ExtraChanged()
	SimpleQoL_UpdatePerf(1);
	SimpleQoL_ApplyGuildTab();
	if ( QuestLogFrame and QuestLogFrame:IsVisible() ) then
		SimpleQoL_UpdateQuestChecks();
	end
end
