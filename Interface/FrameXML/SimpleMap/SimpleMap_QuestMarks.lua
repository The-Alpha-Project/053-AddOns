--------------------------------------------------------------------------------
-- Quest markers (off by default): a yellow "!" where you can start a quest
-- and a yellow "?" where you hand in a quest that is complete in your log.
-- Data: SimpleMap_Quests.lua (from the alpha-core world database).
--
-- Only quests you can take now are shown: level (min level reached, not grey),
-- class, race, side, and the quest chain. The client cannot tell which quests
-- you have finished, so SimpleMap notes a quest when you hand it in
-- (SimpleSave key "QDone", this character only). A note is forgotten as soon
-- as the quest and everything that follows from it are too low for you to
-- matter, so the key stays tiny. Quests in your log are read from the log.
-- Quests you did before this was on are not known: such a quest can show as
-- available until it is too low, and a follow-up of it waits until you have
-- it in your log.
--------------------------------------------------------------------------------

SimpleMap_ShowQuests = nil;
SimpleMap_QStamp = 0;                -- changes when the quest picture changes
SimpleMap_QDone = {};                -- quest id -> 1 (handed in, still of interest)
SimpleMap_QHide = {};                -- quest id -> 1 (an NPC did not offer it: hidden)
SimpleMap_QActive = {};              -- quest id -> 1 (in the log)
SimpleMap_QReady = {};               -- quest id -> 1 (in the log and complete)
SimpleMap_QTitleIndex = nil;
SimpleMap_QDirty = nil;
SimpleMap_QLoaded = nil;
SimpleMap_QBusyTime = -10;
SimpleMap_QCache = {};
SimpleMap_QCacheStamp = -1;

SIMPLEMAP_QUEST_RACES = { HUMAN = 1, ORC = 2, DWARF = 4, NIGHTELF = 8, UNDEAD = 16, SCOURGE = 16, TAUREN = 32, GNOME = 64, TROLL = 128 };
SimpleMap_QForce = nil;              -- the quest picture must be rebuilt even if the log is the same

-- The level at or below which a quest is grey for a player of this level.
function SimpleMap_QGray(level)
	if ( level <= 5 ) then
		return 0;
	elseif ( level <= 39 ) then
		return level - 5 - floor(level / 10);
	elseif ( level <= 59 ) then
		return level - 1 - floor(level / 5);
	end
	return level - 9;
end

function SimpleMap_QHasBit(mask, bit)
	return mod(floor(mask / bit), 2) == 1;
end

function SimpleMap_QClassBit()
	local id = SimpleMap_PlayerClassId and SimpleMap_PlayerClassId();
	if ( not id ) then
		return nil;
	end
	return 2 ^ (id - 1);
end

function SimpleMap_QRaceBit()
	local race = UnitRace and UnitRace("player");
	if ( not race ) then
		return nil;
	end
	return SIMPLEMAP_QUEST_RACES[strupper(gsub(race, "%s", ""))];
end

-- Colour of a quest compared with your level (as in the quest log).
function SimpleMap_QColor(ql)
	local level = UnitLevel("player") or 1;
	local diff = ql - level;
	if ( diff >= 5 ) then
		return 1.0, 0.1, 0.1;
	elseif ( diff >= 3 ) then
		return 1.0, 0.5, 0.25;
	elseif ( diff >= -2 ) then
		return 1.0, 0.82, 0.0;
	elseif ( ql > SimpleMap_QGray(level) ) then
		return 0.25, 0.75, 0.25;
	end
	return 0.5, 0.5, 0.5;
end

function SimpleMap_QTitleLookup()
	if ( SimpleMap_QTitleIndex ) then
		return SimpleMap_QTitleIndex;
	end
	local index = {};
	foreach(SIMPLEMAP_QUESTS, function(id, q)
		local list = index[q[10]];
		if ( not list ) then
			list = {};
			index[q[10]] = list;
		end
		tinsert(list, id);
	end);
	SimpleMap_QTitleIndex = index;
	return index;
end

-- Can this player ever take the quest (class, race)?
function SimpleMap_QFits(q, classBit, raceBit)
	if ( q[3] ~= 0 and classBit and not SimpleMap_QHasBit(q[3], classBit) ) then
		return nil;
	end
	if ( q[4] ~= 0 and raceBit and not SimpleMap_QHasBit(q[4], raceBit) ) then
		return nil;
	end
	return 1;
end

-- Quest ids for a title in the log (by level, then class and race).
function SimpleMap_QFindId(title, level)
	local list = SimpleMap_QTitleLookup()[title];
	if ( not list ) then
		return nil;
	end
	local classBit, raceBit = SimpleMap_QClassBit(), SimpleMap_QRaceBit();
	local best, i;
	for i = 1, getn(list) do
		local q = SIMPLEMAP_QUESTS[list[i]];
		if ( SimpleMap_QFits(q, classBit, raceBit) ) then
			if ( q[2] == level ) then
				return list[i];
			end
			best = best or list[i];
		end
	end
	return best;
end

-- The quest log: which quests are in it and which are complete.
function SimpleMap_QScanLog()
	local active, ready = {}, {};
	local numEntries = GetNumQuestLogEntries();
	local selected = GetQuestLogSelection and GetQuestLogSelection();
	local touched = nil;
	local i;
	for i = 1, numEntries do
		local title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i);
		if ( title and not isHeader ) then
			local id = SimpleMap_QFindId(title, level);
			if ( id ) then
				active[id] = 1;
				local done = isComplete == 1;
				if ( not done and SelectQuestLogEntry ) then
					-- No "complete" flag: all objectives done?
					touched = 1;
					SelectQuestLogEntry(i);
					local count = GetNumQuestLeaderBoards() or 0;
					if ( count > 0 ) then
						local j, finished = nil, 0;
						for j = 1, count do
							local text, kind, fin = GetQuestLogLeaderBoard(j);
							if ( fin ) then
								finished = finished + 1;
							end
						end
						done = finished == count;
					else
						-- No objectives at all: a "talk to so-and-so" quest the
						-- client only flags complete once you do, so the only
						-- thing left is to see the quest giver.
						done = 1;
					end
				end
				if ( done ) then
					ready[id] = 1;
				end
			end
		end
	end
	if ( touched and selected ) then
		SelectQuestLogEntry(selected);
	end
	SimpleMap_QBusyTime = GetTime();
	local changed = not SimpleMap_QSameSet(active, SimpleMap_QActive) or not SimpleMap_QSameSet(ready, SimpleMap_QReady);
	SimpleMap_QActive, SimpleMap_QReady = active, ready;
	SimpleMap_QImplied = SimpleMap_QImpliedDone(active);
	return changed;
end

-- A quest you have (or had) further down its chain must mean the quests
-- before it are done, even if SimpleMap never saw you hand them in itself.
-- Not saved: recomputed from the log each scan, so it costs nothing extra.
function SimpleMap_QImpliedDone(active)
	local implied = {};
	foreach(active, function(id, v)
		local pid = id;
		local guard = 0;
		while ( guard < 20 ) do
			local q = SIMPLEMAP_QUESTS[pid];
			if ( not q or q[5] <= 0 or SimpleMap_QDone[q[5]] or implied[q[5]] ) then
				break
			end
			pid = q[5];
			implied[pid] = 1;
			guard = guard + 1;
		end
	end);
	return implied;
end

-- Done, either for real (QDone) or because a quest further down the same
-- chain is in the log (QImplied).
function SimpleMap_QIsDone(id)
	return SimpleMap_QDone[id] or (SimpleMap_QImplied and SimpleMap_QImplied[id]);
end

function SimpleMap_QSameSet(a, b)
	local same = 1;
	foreach(a, function(id, v)
		if ( not b[id] ) then
			same = nil;
		end
	end);
	if ( same ) then
		foreach(b, function(id, v)
			if ( not a[id] ) then
				same = nil;
			end
		end);
	end
	return same;
end

-- Forget what no longer matters at your level.
function SimpleMap_QPrune()
	local level = UnitLevel("player") or 1;
	local changed = nil;
	local list, hide = {}, {};
	foreach(SimpleMap_QDone, function(id, v)
		local q = SIMPLEMAP_QUESTS[id];
		if ( not q or level > q[9] ) then
			tinsert(list, id);
		end
	end);
	foreach(SimpleMap_QHide, function(id, v)
		local q = SIMPLEMAP_QUESTS[id];
		if ( not q or level > q[9] ) then
			tinsert(hide, id);
		end
	end);
	local i;
	for i = 1, getn(list) do
		SimpleMap_QDone[list[i]] = nil;
		changed = 1;
	end
	for i = 1, getn(hide) do
		SimpleMap_QHide[hide[i]] = nil;
		changed = 1;
	end
	return changed;
end

SIMPLEMAP_QDIGITS = "0123456789abcdefghijklmnopqrstuvwxyz";

function SimpleMap_QEncode3(n)
	local a = floor(n / 1296);
	local b = floor(mod(n, 1296) / 36);
	local c = mod(n, 36);
	return strsub(SIMPLEMAP_QDIGITS, a + 1, a + 1)..strsub(SIMPLEMAP_QDIGITS, b + 1, b + 1)..strsub(SIMPLEMAP_QDIGITS, c + 1, c + 1);
end

function SimpleMap_QDecode3(s)
	local v, i = 0, 1;
	for i = 1, 3 do
		local d = strfind(SIMPLEMAP_QDIGITS, strsub(s, i, i), 1, 1);
		if ( not d ) then
			return nil;
		end
		v = v * 36 + d - 1;
	end
	return v;
end

function SimpleMap_QSave()
	if ( not SimpleSave_SetChar ) then
		return;
	end
	local text = "";
	foreach(SimpleMap_QDone, function(id, v)
		text = text..SimpleMap_QEncode3(id);
	end);
	if ( text == "" ) then
		text = nil;
	end
	SimpleSave_SetChar("SimpleMap", "QDone", text);
	local hidden = "";
	foreach(SimpleMap_QHide, function(id, v)
		hidden = hidden..SimpleMap_QEncode3(id);
	end);
	if ( hidden == "" ) then
		hidden = nil;
	end
	SimpleSave_SetChar("SimpleMap", "QHide", hidden);
end

function SimpleMap_QDecodeSet(text)
	local set = {};
	if ( text ) then
		local i;
		for i = 1, strlen(text) - 2, 3 do
			local id = SimpleMap_QDecode3(strsub(text, i, i + 2));
			if ( id and SIMPLEMAP_QUESTS[id] ) then
				set[id] = 1;
			end
		end
	end
	return set;
end

function SimpleMap_QLoad()
	SimpleMap_QLoaded = 1;
	SimpleMap_QDone = SimpleMap_QDecodeSet(SimpleSave_GetChar and SimpleSave_GetChar("SimpleMap", "QDone"));
	SimpleMap_QHide = SimpleMap_QDecodeSet(SimpleSave_GetChar and SimpleSave_GetChar("SimpleMap", "QHide"));
	if ( SimpleMap_QPrune() ) then
		SimpleMap_QSave();
	end
end

-- Switched on or off.
function SimpleMap_QuestsChanged()
	if ( SimpleMap_ShowQuests ) then
		if ( not SimpleMap_QLoaded ) then
			SimpleMap_QLoad();
		end
		SimpleMap_QDirty = 1;
	else
		-- Off: the notes are removed from the save.
		SimpleMap_QLoaded = nil;
		SimpleMap_QDone = {};
		SimpleMap_QHide = {};
		if ( SimpleSave_SetChar ) then
			SimpleSave_SetChar("SimpleMap", "QDone", nil);
			SimpleSave_SetChar("SimpleMap", "QHide", nil);
		end
	end
	SimpleMap_QForce = 1;
	SimpleMap_QStamp = SimpleMap_QStamp + 1;
end

function SimpleMap_QuestEvent(event)
	if ( not SimpleMap_ShowQuests ) then
		return;
	end
	if ( event == "QUEST_LOG_UPDATE" ) then
		-- Our own selecting in the log gives this event too.
		if ( GetTime() - SimpleMap_QBusyTime > 0.3 ) then
			SimpleMap_QDirty = 1;
		end
	else
		SimpleMap_QDirty = 1;
		SimpleMap_QForce = 1;
		if ( event == "PLAYER_LEVEL_UP" ) then
			SimpleMap_QLevelDirty = 1;
		end
	end
end

-- Called a few times a second (SimpleMap_MinimapCoords_OnUpdate).
function SimpleMap_QuestUpdate()
	if ( not SimpleMap_ShowQuests or not SimpleMap_QDirty ) then
		return;
	end
	-- At most one look at the log a second, however many updates come.
	if ( not SimpleMap_QForce and GetTime() - SimpleMap_QBusyTime < 1 ) then
		return;
	end
	SimpleMap_QDirty = nil;
	if ( not SimpleMap_QLoaded ) then
		SimpleMap_QLoad();
	end
	local changed = SimpleMap_QScanLog();
	if ( SimpleMap_QLevelDirty ) then
		SimpleMap_QLevelDirty = nil;
		if ( SimpleMap_QPrune() ) then
			SimpleMap_QSave();
		end
	end
	-- Rebuilt only when something changed (the log is also "updated" when
	-- it is only read).
	if ( changed or SimpleMap_QForce ) then
		SimpleMap_QForce = nil;
		SimpleMap_QStamp = SimpleMap_QStamp + 1;
		if ( SimpleMapFrame and SimpleMapFrame:IsVisible() ) then
			SimpleMap_NPCsPending = 1;
		end
	end
end

-- Talking to a quest giver: what he offers is what you can really take. A
-- quest we thought you could take that he does not offer is hidden (you did it
-- before, or something else is missing); asked again at the next visit. A
-- quest he offers comes back, and the quests before it in its chain are done.
SimpleMap_QGreetName = nil;
SimpleMap_QGreetTime = 0;

function SimpleMap_QuestNPCEvent(event)
	if ( not SimpleMap_ShowQuests or not SIMPLEMAP_QGIVE ) then
		return;
	end
	local npc = UnitName and UnitName("npc");
	if ( not npc or npc == "" ) then
		return;
	end
	local now = GetTime();
	if ( event == "QUEST_GREETING" ) then
		SimpleMap_QGreetName, SimpleMap_QGreetTime = npc, now;
	elseif ( SimpleMap_QGreetName == npc and now - SimpleMap_QGreetTime < 300 ) then
		-- A quest picked from the list he just gave: the list was used.
		return;
	end
	local offered = {};
	if ( event == "QUEST_GREETING" ) then
		local i;
		for i = 1, (GetNumAvailableQuests() or 0) do
			local title = GetAvailableTitle(i);
			if ( title ) then
				offered[title] = 1;
			end
		end
	else
		local title = GetTitleText and GetTitleText();
		if ( title and title ~= "" ) then
			offered[title] = 1;
		end
	end
	local map = GetMapInfo and GetMapInfo();
	local given = map and SIMPLEMAP_QGIVE[map];
	if ( not given ) then
		return;
	end
	if ( not SimpleMap_QLoaded ) then
		SimpleMap_QLoad();
	end
	-- His quests: the same name, close to where you stand.
	local px, py = 0, 0;
	if ( GetPlayerMapPosition ) then
		px, py = GetPlayerMapPosition("player");
	end
	local near = (px and py and (px ~= 0 or py ~= 0));
	local ids = {};
	local i, k;
	for i = 1, getn(given) do
		local g = given[i];
		if ( g[4] == npc and (not near or (g[1] - px < 0.03 and px - g[1] < 0.03 and g[2] - py < 0.03 and py - g[2] < 0.03)) ) then
			for k = 1, getn(g[5]) do
				ids[g[5][k]] = 1;
			end
		end
	end
	local level = UnitLevel("player") or 1;
	local classBit, raceBit = SimpleMap_QClassBit(), SimpleMap_QRaceBit();
	local changed = nil;
	foreach(ids, function(id, v)
		local q = SIMPLEMAP_QUESTS[id];
		if ( not q ) then
			return;
		end
		if ( offered[q[10]] ) then
			if ( SimpleMap_QHide[id] ) then
				SimpleMap_QHide[id] = nil;
				changed = 1;
			end
			-- The quests before it in the chain are finished.
			local p, guard = q[5], 0;
			while ( p and p > 0 and SIMPLEMAP_QUESTS[p] and not SimpleMap_QDone[p] and guard < 20 ) do
				SimpleMap_QDone[p] = 1;
				changed = 1;
				p = SIMPLEMAP_QUESTS[p][5];
				guard = guard + 1;
			end
		elseif ( not SimpleMap_QHide[id] and SimpleMap_QAvailable(id, q, level, classBit, raceBit, 1) ) then
			SimpleMap_QHide[id] = 1;
			changed = 1;
		end
	end);
	if ( changed ) then
		SimpleMap_QSave();
		SimpleMap_QForce = 1;
		SimpleMap_QDirty = 1;
	end
end

-- Handing in a quest: it is finished.
if ( GetQuestReward ) then
	SimpleMap_Orig_GetQuestReward = GetQuestReward;
	function GetQuestReward(choice)
		if ( SimpleMap_ShowQuests and GetTitleText ) then
			local title = GetTitleText();
			local list = title and SimpleMap_QTitleLookup()[title];
			if ( list ) then
				local classBit, raceBit = SimpleMap_QClassBit(), SimpleMap_QRaceBit();
				local i, id;
				for i = 1, getn(list) do
					if ( SimpleMap_QActive[list[i]] and SimpleMap_QFits(SIMPLEMAP_QUESTS[list[i]], classBit, raceBit) ) then
						id = list[i];
						break
					end
				end
				if ( id ) then
					SimpleMap_QActive[id] = nil;
					SimpleMap_QReady[id] = nil;
					SimpleMap_QDone[id] = 1;
					SimpleMap_QSave();
					SimpleMap_QDirty = 1;
					SimpleMap_QForce = 1;
				end
			end
		end
		SimpleMap_Orig_GetQuestReward(choice);
	end
end

-- Can the quest be taken now?
function SimpleMap_QAvailable(id, q, level, classBit, raceBit, ignoreHide)
	if ( SimpleMap_QIsDone(id) or SimpleMap_QActive[id] ) then
		return nil;
	end
	if ( SimpleMap_QHide[id] and not ignoreHide ) then
		return nil;
	end
	if ( level < q[1] or q[2] <= SimpleMap_QGray(level) ) then
		return nil;
	end
	if ( not SimpleMap_QFits(q, classBit, raceBit) ) then
		return nil;
	end
	-- Already took or finished the next quest of its chain.
	if ( q[6] ~= 0 and (SimpleMap_QIsDone(q[6]) or SimpleMap_QActive[q[6]]) ) then
		return nil;
	end
	if ( q[5] > 0 and not SimpleMap_QIsDone(q[5]) ) then
		return nil;
	end
	if ( q[5] < 0 and not SimpleMap_QActive[-q[5]] ) then
		return nil;
	end
	-- Other prerequisites (any one of them).
	if ( q[8] ~= 0 ) then
		local ok, i = nil;
		for i = 1, getn(q[8]) do
			local p = q[8][i];
			if ( (p > 0 and SimpleMap_QIsDone(p)) or (p < 0 and SimpleMap_QActive[-p]) ) then
				ok = 1;
				break
			end
		end
		if ( not ok ) then
			return nil;
		end
	end
	-- An alternative quest (exclusive group) taken or finished.
	if ( q[7] ~= 0 ) then
		local i;
		for i = 1, getn(q[7]) do
			if ( SimpleMap_QIsDone(q[7][i]) or SimpleMap_QActive[q[7][i]] ) then
				return nil;
			end
		end
	end
	return 1;
end

-- The markers of one map, rebuilt when the quest picture changes:
-- { "Q" or "A", x, y, name, name, 0, side, { { title, min, level }, ... } }.
function SimpleMap_QuestList(map)
	if ( not map or not SimpleMap_ShowQuests or not SIMPLEMAP_QGIVE ) then
		return nil;
	end
	if ( SimpleMap_QCacheStamp ~= SimpleMap_QStamp ) then
		SimpleMap_QCache = {};
		SimpleMap_QCacheStamp = SimpleMap_QStamp;
	end
	local cached = SimpleMap_QCache[map];
	if ( cached ) then
		return cached;
	end
	-- "!" and "?" entries are built separately: at an NPC with both, the
	-- hand-in ("?") wins and the "!" for that NPC is left out, so the two
	-- markers never stack on top of each other.
	local list = {};
	local qlist = {};
	local level = UnitLevel("player") or 1;
	local classBit, raceBit = SimpleMap_QClassBit(), SimpleMap_QRaceBit();
	local given = SIMPLEMAP_QGIVE[map];
	local i, k;
	if ( given ) then
		for i = 1, getn(given) do
			local g = given[i];
			local lines = nil;
			for k = 1, getn(g[5]) do
				local id = g[5][k];
				local q = SIMPLEMAP_QUESTS[id];
				if ( q and SimpleMap_QAvailable(id, q, level, classBit, raceBit) ) then
					lines = lines or {};
					tinsert(lines, { q[10], q[1], q[2], id });
				end
			end
			if ( lines ) then
				tinsert(qlist, { "Q", g[1], g[2], g[4], g[4], 0, g[3], lines });
			end
		end
	end
	-- Quest lines still offered at the same spot (entry[9]): shown in the
	-- tooltip below "Ready to hand in" instead of a second, hidden marker.
	local qByKey = {};
	for i = 1, getn(qlist) do
		qByKey[qlist[i][2]..":"..qlist[i][3]..":"..qlist[i][4]] = qlist[i];
	end
	local used = {};
	local ends = SIMPLEMAP_QEND and SIMPLEMAP_QEND[map];
	if ( ends and next(SimpleMap_QReady) ) then
		for i = 1, getn(ends) do
			local g = ends[i];
			local lines = nil;
			for k = 1, getn(g[5]) do
				local id = g[5][k];
				if ( SimpleMap_QReady[id] ) then
					local q = SIMPLEMAP_QUESTS[id];
					lines = lines or {};
					tinsert(lines, { q[10], q[1], q[2], id });
				end
			end
			if ( lines ) then
				local key = g[1]..":"..g[2]..":"..g[4];
				local entry = { "A", g[1], g[2], g[4], g[4], 0, g[3], lines };
				local other = qByKey[key];
				if ( other ) then
					entry[9] = other[8];
					used[other] = 1;
				end
				tinsert(list, entry);
			end
		end
	end
	for i = 1, getn(qlist) do
		local e = qlist[i];
		if ( not used[e] ) then
			tinsert(list, e);
		end
	end
	SimpleMap_QCache[map] = list;
	return list;
end

-- Shift-click on a "!" marker: you did that quest already. The first quest
-- of the marker is hidden (the next one shows at the next click).
-- A shift-click must not leave the window "held" by the shift-drag that
-- the map starts on the mouse press.
function SimpleMap_MarkerShiftCleanup()
	SimpleMap_DragStart = nil;
	if ( SimpleMap_MoveStop ) then
		SimpleMap_MoveStop();
	end
	if ( SimpleMap_DragCatcher_Disengage ) then
		SimpleMap_DragCatcher_Disengage();
	end
	SimpleMap_Moved = nil;
end

-- Shift + mouse press over a quest/ore/herb/chest marker: handled right on
-- the press (the shift-drag that the map starts would otherwise take the
-- release and the marker would never get its click).
function SimpleMap_ShiftMarkerDown()
	local h = SimpleMap_Hover;
	if ( not h or not h.entry or not h:IsVisible() or not IsShiftKeyDown() ) then
		return nil;
	end
	local k = h.entry[1];
	if ( k == "Q" ) then
		return SimpleMap_QuestMarkerClick(h);
	elseif ( k == "h" or k == "m" or k == "c" ) then
		SimpleMap_NodeClick(h);
		return 1;
	end
	return nil;
end

function SimpleMap_QuestMarkerClick(btn)
	local b = btn or this;
	local entry = b and b.entry;
	if ( not entry or entry[1] ~= "Q" or not IsShiftKeyDown or not IsShiftKeyDown() ) then
		return nil;
	end
	if ( not btn and SimpleMap_ShiftStamp and GetTime() - SimpleMap_ShiftStamp < 0.6 ) then
		return 1;
	end
	SimpleMap_ShiftStamp = GetTime();
	SimpleMap_MarkerShiftCleanup();
	local line = entry[8][1];
	local id = line and line[4];
	if ( not id ) then
		return 1;
	end
	if ( not SimpleMap_QLoaded ) then
		SimpleMap_QLoad();
	end
	SimpleMap_QHide[id] = 1;
	SimpleMap_QSave();
	SimpleMap_QForce = 1;
	SimpleMap_QDirty = 1;
	GameTooltip:Hide();
	ChatFrame:AddMessage("SimpleMap: hid quest \""..line[1].."\". Talking to the quest giver brings it back if he offers it.", 1.0, 0.82, 0.0);
	return 1;
end

-- Tooltip: the giver, then "[min-level] Title" in the colour of the level.
function SimpleMap_QuestTooltipLines(lines)
	local i;
	for i = 1, getn(lines) do
		local l = lines[i];
		local range;
		if ( l[2] > 0 and l[2] < l[3] ) then
			range = l[2].."-"..l[3];
		else
			range = ""..l[3];
		end
		local r, g, b = SimpleMap_QColor(l[3]);
		GameTooltip:AddLine("["..range.."] "..l[1], "", r, g, b);
	end
end

function SimpleMap_QuestTooltip(entry)
	GameTooltip:SetText(entry[4], 1.0, 1.0, 1.0);
	if ( entry[1] == "A" ) then
		GameTooltip:AddLine("Ready to hand in:", "", 0.7, 0.7, 0.7);
	end
	SimpleMap_QuestTooltipLines(entry[8]);
	if ( entry[1] == "A" and entry[9] ) then
		GameTooltip:AddLine("Also offers:", "", 0.7, 0.7, 0.7);
		SimpleMap_QuestTooltipLines(entry[9]);
	end
	if ( entry[1] == "Q" ) then
		GameTooltip:AddLine("|cff808080Shift-click: hide the first quest (already done)|r");
	end
	GameTooltip:Show();
end
