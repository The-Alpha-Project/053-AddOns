--------------------------------------------------------------------------------
-- SimpleQoL, part 7: free bag slots on the backpack, kills to the next level
-- on the experience bar, Shift + drag to move the unit frames and AlphaUI's
-- bag, and the Talent Calculator next to the Talents window.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Free bag slots: the number of empty slots in all bags on the backpack.
--------------------------------------------------------------------------------

SimpleQoL_BagDirty = 1;

function SimpleQoL_FreeSlots()
	local free = 0;
	local bag, slot;
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			if ( not GetContainerItemInfo(bag, slot) ) then
				free = free + 1;
			end
		end
	end
	return free;
end

function SimpleQoL_UpdateBagSlots()
	SimpleQoL_BagDirty = nil;
	if ( not SimpleQoLBagSlotsText ) then
		return;
	end
	if ( SimpleQoL_On["bagslots"] ) then
		SimpleQoLBagSlotsText:SetText(SimpleQoL_FreeSlots());
	else
		SimpleQoLBagSlotsText:SetText("");
	end
end


--------------------------------------------------------------------------------
-- Kills to the next level: experience gained in combat (or right after it)
-- counts as kill experience; the average of the last 10 gives the estimate,
-- shown after the experience numbers, e.g. "1200 / 4500 (~42 kills)".
--------------------------------------------------------------------------------

SimpleQoL_KillXP = {};                -- last kill experience gains
SimpleQoL_LastXP = nil;
SimpleQoL_CombatEndTime = -10;

function SimpleQoL_XPChanged()
	local xp = UnitXP("player");
	if ( SimpleQoL_LastXP and xp > SimpleQoL_LastXP ) then
		if ( SimpleQoL_InCombat or GetTime() - SimpleQoL_CombatEndTime < 3 ) then
			tinsert(SimpleQoL_KillXP, xp - SimpleQoL_LastXP);
			if ( getn(SimpleQoL_KillXP) > 10 ) then
				tremove(SimpleQoL_KillXP, 1);
			end
		end
	end
	-- After a level up the count starts from the new value.
	SimpleQoL_LastXP = xp;
end

function SimpleQoL_KillsText()
	local n = getn(SimpleQoL_KillXP);
	if ( not SimpleQoL_On["xpkills"] or n == 0 ) then
		return nil;
	end
	local total = 0;
	local i;
	for i = 1, n do
		total = total + SimpleQoL_KillXP[i];
	end
	local left = UnitXPMax("player") - UnitXP("player");
	if ( total <= 0 or left <= 0 ) then
		return nil;
	end
	return "(~"..ceil(left / (total / n)).." kills)";
end

SimpleQoL_Orig_TextStatusBar_UpdateTextString = TextStatusBar_UpdateTextString;
function TextStatusBar_UpdateTextString()
	SimpleQoL_Orig_TextStatusBar_UpdateTextString();
	if ( this == MainMenuExpBar and this.TextString and not this.isZero ) then
		local kills = SimpleQoL_KillsText();
		local text = this.TextString:GetText();
		if ( kills and text ) then
			this.TextString:SetText(text.." "..kills);
		end
	end
end


--------------------------------------------------------------------------------
-- Move frames: while Shift is held, invisible handles lie over the player,
-- target and party frames, AlphaUI's bag and the minimap (round or square);
-- drag one to move that frame.
-- Positions are saved (SimpleSave); "Reset frames" in /qol puts them back.
--------------------------------------------------------------------------------

-- { frame to move, frame under the handle, corner it is anchored by, save key }
SIMPLEQOL_MOVERS = {
	{ "PlayerFrame", "PlayerFrame", "TOPLEFT", "PosPlayer" },
	{ "TargetFrame", "TargetFrame", "TOPLEFT", "PosTarget" },
	{ "PartyMemberFrame1", "PartyMemberFrame1", "TOPLEFT", "PosParty" },
	{ "PartyMemberFrame1", "PartyMemberFrame2", "TOPLEFT", "PosParty" },
	{ "PartyMemberFrame1", "PartyMemberFrame3", "TOPLEFT", "PosParty" },
	{ "PartyMemberFrame1", "PartyMemberFrame4", "TOPLEFT", "PosParty" },
	{ "MainMergedBagsFrame", "MainMergedBagsFrame", "BOTTOMRIGHT", "PosBags" },
	{ "MinimapCluster", "Minimap", "TOPRIGHT", "PosMinimap" },
	{ "MainAtlasLootButton", "MainAtlasLootButton", "TOPLEFT", "PosAtlasLoot" },
};
SimpleQoL_MoverDrag = nil;            -- { mover index, cursor x, y, center x, y, scale }
SimpleQoL_MoversShown = nil;
SimpleQoL_FramePos = {};              -- save key -> { x, y } (corner, SetPoint units)

-- Where a frame's anchor corner is, in SetPoint units from the bottom left.
function SimpleQoL_FrameCorner(frame, corner, cx, cy)
	local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0;
	if ( corner == "TOPLEFT" ) then
		return cx - w / 2, cy + h / 2;
	end
	if ( corner == "TOPRIGHT" ) then
		return cx + w / 2, cy + h / 2;
	end
	return cx + w / 2, cy - h / 2;
end

-- The screen size in SetPoint units (probe in the top right corner).
function SimpleQoL_ScreenSize()
	if ( not SimpleQoLProbeScreenTR ) then
		return nil;
	end
	local cx, cy = SimpleQoLProbeScreenTR:GetCenter();
	if ( not cx ) then
		return nil;
	end
	local w, h = SimpleQoL_ToScreen(cx, cy);
	return w + 1, h + 1;
end

-- Frames are kept fully on the screen. A minimap partly outside the screen
-- crashes the 0.5.3 client (GxApi.cpp "minX >= 0.0f && maxX <= 1.0f", seen
-- while dragging the minimap).
function SimpleQoL_ClampCorner(frame, corner, x, y)
	local sw, sh = SimpleQoL_ScreenSize();
	if ( not sw or sw < 100 or sh < 100 ) then
		return x, y;
	end
	local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0;
	local left, top;
	if ( corner == "TOPLEFT" ) then
		left, top = x, y;
	elseif ( corner == "TOPRIGHT" ) then
		left, top = x - w, y;
	else
		left, top = x - w, y + h;
	end
	left = max(2, min(left, sw - w - 2));
	top = max(h + 2, min(top, sh - 2));
	if ( corner == "TOPLEFT" ) then
		return left, top;
	elseif ( corner == "TOPRIGHT" ) then
		return left + w, top;
	end
	return left + w, top - h;
end

function SimpleQoL_PlaceFrame(name, corner, x, y)
	local frame = getglobal(name);
	if ( not frame ) then
		return;
	end
	x, y = SimpleQoL_ClampCorner(frame, corner, x, y);
	frame:ClearAllPoints();
	frame:SetPoint(corner, "UIParent", "BOTTOMLEFT", x, y);
end

function SimpleQoL_ApplyFramePositions()
	if ( not SimpleQoL_On["moveframes"] ) then
		return;
	end
	local done = {};
	local i;
	for i = 1, getn(SIMPLEQOL_MOVERS) do
		local m = SIMPLEQOL_MOVERS[i];
		local pos = SimpleQoL_FramePos[m[4]];
		if ( pos and not done[m[4]] ) then
			done[m[4]] = 1;
			SimpleQoL_PlaceFrame(m[1], m[3], pos[1], pos[2]);
		end
	end
end

function SimpleQoL_LoadFramePositions()
	SimpleQoL_FramePos = {};
	if ( not SimpleSave_Get ) then
		return;
	end
	local i;
	for i = 1, getn(SIMPLEQOL_MOVERS) do
		local key = SIMPLEQOL_MOVERS[i][4];
		local s, e, x, y = strfind(SimpleSave_Get("SimpleQoL", key, "") or "", "^(-?%d+),(-?%d+)$");
		if ( x ) then
			SimpleQoL_FramePos[key] = { x + 0, y + 0 };
		end
	end
end

-- Stock (or AlphaUI) positions back, and the saved ones forgotten.
function SimpleQoL_ResetFrames()
	local i;
	for i = 1, getn(SIMPLEQOL_MOVERS) do
		local key = SIMPLEQOL_MOVERS[i][4];
		SimpleQoL_FramePos[key] = nil;
		if ( SimpleSave_Set ) then
			SimpleSave_Set("SimpleQoL", key, nil);
		end
	end
	local x, y = 6, -4;
	if ( PlayerFrame and TargetFrame ) then
		if ( SimpleQoL_AlphaUIHas("unit_frames") and Main.GetNumberSetting ) then
			x = Main.GetNumberSetting("unitframes_x_offset", -250);
			y = Main.GetNumberSetting("unitframes_y_offset", 320);
			PlayerFrame:ClearAllPoints();
			PlayerFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", x, y);
			TargetFrame:ClearAllPoints();
			TargetFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", -x, y);
		else
			PlayerFrame:ClearAllPoints();
			PlayerFrame:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", 6, -4);
			TargetFrame:ClearAllPoints();
			TargetFrame:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", 230, -4);
		end
	end
	if ( PartyMemberFrame1 ) then
		PartyMemberFrame1:ClearAllPoints();
		PartyMemberFrame1:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", 0, -128);
	end
	if ( MainMergedBagsFrame ) then
		MainMergedBagsFrame:ClearAllPoints();
		MainMergedBagsFrame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -12, 98);
	end
	if ( MainAtlasLootButton and CombatLogUpButton ) then
		MainAtlasLootButton:ClearAllPoints();
		MainAtlasLootButton:SetPoint("BOTTOM", "CombatLogUpButton", "TOP", 0, 4);
	end
	if ( MinimapCluster ) then
		MinimapCluster:ClearAllPoints();
		MinimapCluster:SetPoint("TOPRIGHT", "UIParent", "TOPRIGHT", 0, 0);
	end
	SimpleQoL_Print("frames are back in their places.");
end

function SimpleQoL_UpdateMovers()
	local want = SimpleQoL_On["moveframes"] and IsShiftKeyDown() and not SimpleQoL_CursorBusy();
	if ( SimpleQoL_MoverDrag ) then
		want = 1;
	end
	if ( not want and not SimpleQoL_MoversShown ) then
		return;
	end
	SimpleQoL_MoversShown = want;
	local i;
	for i = 1, getn(SIMPLEQOL_MOVERS) do
		local handle = getglobal("SimpleQoLMover"..i);
		local target = getglobal(SIMPLEQOL_MOVERS[i][2]);
		if ( want and target and target:IsVisible() ) then
			if ( not handle:IsVisible() ) then
				handle:ClearAllPoints();
				handle:SetPoint("TOPLEFT", SIMPLEQOL_MOVERS[i][2], "TOPLEFT", 0, 0);
				if ( SIMPLEQOL_MOVERS[i][2] == "MainMergedBagsFrame" ) then
					-- Only the title strip of the bag moves it, so the items below
					-- stay clickable with Shift held (to link them in chat).
					-- (22 high, and not over the Sort and close buttons at the right)
					handle:SetPoint("BOTTOMRIGHT", SIMPLEQOL_MOVERS[i][2], "TOPRIGHT", -90, -22);
				else
					handle:SetPoint("BOTTOMRIGHT", SIMPLEQOL_MOVERS[i][2], "BOTTOMRIGHT", 0, 0);
				end
				handle:Show();
			end
		elseif ( handle:IsVisible() and (not SimpleQoL_MoverDrag or SimpleQoL_MoverDrag[1] ~= i) ) then
			handle:Hide();
		end
	end
end

function SimpleQoL_Mover_OnMouseDown(button)
	if ( button ~= "LeftButton" ) then
		return;
	end
	local m = SIMPLEQOL_MOVERS[this:GetID()];
	local frame = getglobal(m[1]);
	if ( not frame ) then
		return;
	end
	local fx, fy = frame:GetCenter();
	if ( not fx ) then
		return;
	end
	local cx, cy = GetCursorPosition();
	local x, y = SimpleQoL_ToScreen(fx, fy);
	SimpleQoL_MoverDrag = { this:GetID(), cx, cy, x, y, SimpleQoL_Scale() };
end

function SimpleQoL_MoverDragUpdate()
	local drag = SimpleQoL_MoverDrag;
	local m = SIMPLEQOL_MOVERS[drag[1]];
	local frame = getglobal(m[1]);
	local cx, cy = GetCursorPosition();
	local x = drag[4] + (cx - drag[2]) * drag[6];
	local y = drag[5] + (cy - drag[3]) * drag[6];
	local ax, ay = SimpleQoL_FrameCorner(frame, m[3], x, y);
	ax, ay = SimpleQoL_ClampCorner(frame, m[3], ax, ay);
	SimpleQoL_FramePos[m[4]] = { floor(ax + 0.5), floor(ay + 0.5) };
	SimpleQoL_PlaceFrame(m[1], m[3], ax, ay);
end

function SimpleQoL_Mover_OnMouseUp()
	local drag = SimpleQoL_MoverDrag;
	if ( not drag ) then
		return;
	end
	SimpleQoL_MoverDrag = nil;
	local key = SIMPLEQOL_MOVERS[drag[1]][4];
	local pos = SimpleQoL_FramePos[key];
	if ( pos and SimpleSave_Set ) then
		SimpleSave_Set("SimpleQoL", key, pos[1]..","..pos[2]);
	end
end

function SimpleQoL_Mover_OnEnter()
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Shift + drag to move");
	GameTooltip:AddLine("\"Reset frames\" in /qol puts it back.", "", 1.0, 1.0, 1.0);
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- Talent Calculator: your talents (the Talents window is a trainer list in
-- 0.5.3) with every later rank from SimpleQoL_Talents.lua, and the talent
-- points you have plus the ones you get until level 25. Pick talents to see
-- the points left and what they add up to, without learning anything.
-- "Set" keeps the picks (they can then only be cleared with Reset).
--------------------------------------------------------------------------------

SIMPLEQOL_CALC_ROWS = 16;
SIMPLEQOL_MAX_LEVEL = 25;             -- 0.5.3's level cap; /qol maxlevel changes it

-- A dev may raise the level cap: your own level is used when it is higher,
-- and /qol maxlevel sets it (saved).
function SimpleQoL_SetMaxLevel(level)
	if ( level and level >= 1 and level <= 255 ) then
		SIMPLEQOL_MAX_LEVEL = level;
		if ( SimpleSave_Set ) then
			SimpleSave_Set("SimpleQoL", "MaxLevel", level);
		end
	end
end

function SimpleQoL_MaxLevel()
	return max(SIMPLEQOL_MAX_LEVEL, UnitLevel("player") or 1);
end
SimpleQoL_CalcList = {};              -- rows: { name, rank, cost, level, desc, base, first, blockedText }
SimpleQoL_CalcPlan = {};              -- row index -> 1 picked, 2 set
SimpleQoL_CalcView = {};              -- shown lines: { header text } or { nil, row index }
SimpleQoL_CalcFresh = nil;            -- 1 after Reset at level 25: all points, nothing learned
SIMPLEQOL_STAT_INDEX = { strength = 1, agility = 2, stamina = 3, intellect = 4, spirit = 5 };

function SimpleQoL_Yes(value)
	return value and value ~= 0;
end

function SimpleQoL_RankOf(sub)
	local s, e, n = strfind(sub or "", "(%d+)");
	if ( n ) then
		return n + 0;
	end
	return 1;
end

-- Talent points from the next level up to level 25 (alpha-core: 10 per level,
-- +5 for every full 10 levels).
function SimpleQoL_FuturePoints(fromLevel)
	local total = 0;
	local level;
	for level = (fromLevel or UnitLevel("player") or 1) + 1, SimpleQoL_MaxLevel() do
		total = total + 10 + floor(level / 10) * 5;
	end
	return total;
end

-- Reads the Talents window (all filters on), then puts filters and folded
-- headers back. Returns name -> { learned rank, first listed entry }.
function SimpleQoL_TalentCalc_ReadClient()
	local chains = {};
	local order = {};
	if ( not GetNumTrainerServices ) then
		return chains, order;
	end
	local types = { "available", "unavailable", "used" };
	local filters = {};
	local i;
	for i = 1, 3 do
		filters[i] = GetTrainerServiceTypeFilter(types[i]);
	end
	local folded = {};
	for i = 1, GetNumTrainerServices() do
		local name, sub, kind, expanded = GetTrainerServiceInfo(i);
		if ( kind == "header" and not SimpleQoL_Yes(expanded) ) then
			folded[name] = 1;
		end
	end
	for i = 1, 3 do
		SetTrainerServiceTypeFilter(types[i], 1);
	end
	ExpandTrainerSkillLine(0);
	local header = "";
	for i = 1, GetNumTrainerServices() do
		local name, sub, kind = GetTrainerServiceInfo(i);
		if ( kind == "header" ) then
			header = name or "";
		elseif ( name ) then
			local chain = chains[name];
			if ( not chain ) then
				chain = { learned = 0, header = header };
				chains[name] = chain;
				tinsert(order, name);
			end
			local rank = SimpleQoL_RankOf(sub);
			if ( kind == "used" ) then
				if ( rank > chain.learned ) then
					chain.learned = rank;
				end
			elseif ( not chain.first or rank < chain.first.rank ) then
				local money, cost = GetTrainerServiceCost(i);
				local entry = { rank = rank, cost = cost or 0, desc = GetTrainerServiceDescription(i) or "",
					level = GetTrainerServiceLevelReq(i) or 0, skillOk = 1, reqs = {} };
				local skill, skillRank, hasSkill = GetTrainerServiceSkillReq(i);
				if ( skill and not SimpleQoL_Yes(hasSkill) ) then
					entry.skillOk = nil;
					entry.skill = skill.." ("..(skillRank or "?")..")";
				end
				local r;
				for r = 1, (GetTrainerServiceNumAbilityReq(i) or 0) do
					local ability, hasReq = GetTrainerServiceAbilityReq(i, r);
					if ( ability and not SimpleQoL_Yes(hasReq) ) then
						tinsert(entry.reqs, ability);
					end
				end
				local step, met = GetTrainerServiceStepReq(i);
				if ( step and not SimpleQoL_Yes(met) ) then
					tinsert(entry.reqs, step);
				end
				chain.first = entry;
			end
		end
	end
	for i = GetNumTrainerServices(), 1, -1 do
		local name, sub, kind = GetTrainerServiceInfo(i);
		if ( kind == "header" and folded[name] ) then
			CollapseTrainerSkillLine(i);
		end
	end
	for i = 1, 3 do
		if ( filters[i] ) then
			SetTrainerServiceTypeFilter(types[i], 1);
		else
			SetTrainerServiceTypeFilter(types[i], 0);
		end
	end
	if ( TalentTrainerFrame_Update ) then
		TalentTrainerFrame_Update();
	end
	return chains, order;
end

-- One row per rank you could still learn: the rank the window offers, then
-- every later rank from the database.
function SimpleQoL_TalentCalc_Read()
	SimpleQoL_CalcList = {};
	SimpleQoL_CalcPlan = {};
	local chains, order = SimpleQoL_TalentCalc_ReadClient();
	local i;
	for i = 1, getn(order) do
		local name = order[i];
		local chain = chains[name];
		local data = SimpleQoL_TalentData(name);
		local first = chain.first;
		local learned = chain.learned;
		if ( SimpleQoL_CalcFresh ) then
			learned = 0;
			if ( first and first.rank > 1 and data and data[1] ) then
				first = nil;
			end
		end
		local start = learned + 1;
		if ( first and first.rank < start ) then
			start = first.rank;
		end
		-- The rank you have is shown too (it cannot be picked).
		if ( learned > 0 ) then
			tinsert(SimpleQoL_CalcList, { name = name, rank = learned, cost = 0, level = 0, reqs = {}, skillOk = 1, owned = 1,
				desc = (data and data[learned] and data[learned][3]) or "", header = chain.header, learned = learned, start = start });
		end
		local rank = start;
		while ( 1 ) do
			local row = nil;
			if ( first and rank == first.rank ) then
				row = { name = name, rank = rank, cost = first.cost, level = first.level, desc = first.desc,
					skillOk = first.skillOk, skill = first.skill, reqs = first.reqs, first = 1 };
			elseif ( data and data[rank] ) then
				row = { name = name, rank = rank, cost = data[rank][1], level = data[rank][2], desc = data[rank][3], reqs = {}, skillOk = 1 };
			end
			if ( not row ) then
				break
			end
			row.learned = learned;
			row.header = chain.header;
			row.start = start;
			tinsert(SimpleQoL_CalcList, row);
			rank = rank + 1;
		end
	end
end

function SimpleQoL_CalcLabel(entry)
	return entry.name.." (Rank "..entry.rank..")";
end

function SimpleQoL_CalcPoints()
	local points;
	if ( SimpleQoL_CalcFresh ) then
		points = SimpleQoL_FuturePoints(1);
	else
		points = (UnitCharacterPoints("player") or 0) + SimpleQoL_FuturePoints();
	end
	local used = 0;
	local i;
	for i = 1, getn(SimpleQoL_CalcList) do
		if ( SimpleQoL_CalcPlan[i] ) then
			used = used + SimpleQoL_CalcList[i].cost;
		end
	end
	return points, used;
end

-- The row of the rank below in the same talent, if it is a row.
function SimpleQoL_CalcPrevious(index)
	local e = SimpleQoL_CalcList[index];
	local p = SimpleQoL_CalcList[index - 1];
	if ( p and not p.owned and p.name == e.name and p.rank == e.rank - 1 ) then
		return index - 1;
	end
	return nil;
end

-- A requirement such as "Dagger Mastery (Rank 1)" met by a picked rank.
function SimpleQoL_CalcReqPicked(req)
	local lower = strlower(req);
	local i;
	for i = 1, getn(SimpleQoL_CalcList) do
		local e = SimpleQoL_CalcList[i];
		if ( SimpleQoL_CalcPlan[i] and strfind(lower, strlower(e.name), 1, 1) and strfind(lower, "rank "..e.rank, 1, 1) ) then
			return 1;
		end
	end
	return nil;
end

-- Returns nil when the rank can be picked, else the reason.
function SimpleQoL_CalcBlocked(index)
	local e = SimpleQoL_CalcList[index];
	if ( e.level > SimpleQoL_MaxLevel() ) then
		return "Requires level "..e.level..".";
	end
	if ( not e.skillOk ) then
		return "Requires "..(e.skill or "a skill")..".";
	end
	local previous = SimpleQoL_CalcPrevious(index);
	if ( previous and not SimpleQoL_CalcPlan[previous] ) then
		return "Requires "..SimpleQoL_CalcLabel(SimpleQoL_CalcList[previous])..".";
	end
	local i;
	for i = 1, getn(e.reqs) do
		local req = e.reqs[i];
		local s, x, reqRank = strfind(strlower(req), "rank (%d+)");
		local own = strfind(strlower(req), strlower(e.name), 1, 1) and reqRank and (reqRank + 0) <= e.learned;
		if ( not own and not SimpleQoL_CalcReqPicked(req) ) then
			return "Requires "..req..".";
		end
	end
	return nil;
end

-- Picked ranks whose requirements are no longer picked are dropped too.
function SimpleQoL_CalcDropOrphans()
	local changed = 1;
	while ( changed ) do
		changed = nil;
		local i;
		for i = 1, getn(SimpleQoL_CalcList) do
			if ( SimpleQoL_CalcPlan[i] == 1 and SimpleQoL_CalcBlocked(i) ) then
				SimpleQoL_CalcPlan[i] = nil;
				changed = 1;
			end
		end
	end
end

-- A talent's data by name; names are also matched without punctuation and
-- case, in case the database spells one differently from the client.
function SimpleQoL_TalentKey(name)
	return strlower(gsub(name or "", "[^%w]", ""));
end

function SimpleQoL_TalentData(name)
	if ( not SIMPLEQOL_TALENTS or not name ) then
		return nil;
	end
	if ( SIMPLEQOL_TALENTS[name] ) then
		return SIMPLEQOL_TALENTS[name];
	end
	if ( not SimpleQoL_TalentIndex ) then
		SimpleQoL_TalentIndex = {};
		foreach(SIMPLEQOL_TALENTS, function(key, data)
			SimpleQoL_TalentIndex[SimpleQoL_TalentKey(key)] = data;
		end);
	end
	return SimpleQoL_TalentIndex[SimpleQoL_TalentKey(name)];
end

-- The server's effects of a talent rank (from SimpleQoL_Talents.lua):
-- { key, value, key, value ... }.
function SimpleQoL_CalcRankEffects(name, rank)
	local data = SimpleQoL_TalentData(name);
	return data and data[rank] and data[rank][4];
end

function SimpleQoL_CalcAdd(sums, effects, sign)
	if ( not effects ) then
		return;
	end
	local i;
	for i = 1, getn(effects), 2 do
		local key = effects[i];
		sums[key] = (sums[key] or 0) + effects[i + 1] * sign;
	end
end

-- have: what your learned ranks give. add: what the picked ranks add on top
-- (per talent the highest picked rank replaces the rank you have).
function SimpleQoL_CalcSums()
	local have = {};
	local add = {};
	local top = {};
	local i;
	for i = 1, getn(SimpleQoL_CalcList) do
		local e = SimpleQoL_CalcList[i];
		if ( e.owned ) then
			SimpleQoL_CalcAdd(have, SimpleQoL_CalcRankEffects(e.name, e.rank), 1);
		elseif ( SimpleQoL_CalcPlan[i] ) then
			top[e.name] = e;
		end
	end
	foreach(top, function(name, e)
		SimpleQoL_CalcAdd(add, SimpleQoL_CalcRankEffects(name, e.rank), 1);
		if ( e.learned and e.learned > 0 ) then
			SimpleQoL_CalcAdd(add, SimpleQoL_CalcRankEffects(name, e.learned), -1);
		end
	end);
	return have, add;
end

-- Result line names, in the order they are shown. "%" marks percentages.
SIMPLEQOL_CALC_GROUPS = {
	{ "SKILL:", "%s skill" }, { "DMG:", "Damage with %s" }, { "CRIT:", "Crit with %s", "%" },
	{ "PARRY:", "Parry with %s", "%" }, { "BLEED:", "Bleed chance with %s", "%" }, { "BLEEDDMG:", "Bleed damage with %s" },
	{ "STUN:", "Stun chance with %s", "%" }, { "STUNSEC:", "Stun seconds with %s" },
	{ "SUNDER:", "Armor reduction chance with %s", "%" }, { "SUNDERARM:", "Armor reduction with %s" },
	{ "SDMG:", "%s spell damage" }, { "SCRIT:", "%s spell crit", "%" }, { "COST:", "%s spell mana cost" },
	{ "RES:", "%s resistance" }, { "REFL:", "%s spell reflect", "%" }, { "SLAY:", "Damage vs %s" },
};
SIMPLEQOL_CALC_SKILL_NAMES = { Defense = "Defense", Stealth = "Stealth" };

-- Small insertion sort (no library sort needed).
function SimpleQoL_CalcSort(list)
	local i, j;
	for i = 2, getn(list) do
		local v = list[i];
		j = i - 1;
		while ( j > 0 and list[j] > v ) do
			list[j + 1] = list[j];
			j = j - 1;
		end
		list[j + 1] = v;
	end
end

function SimpleQoL_CalcSigned(value, pct)
	if ( pct ) then
		if ( floor(value) == value ) then
			return format("%+d%%", value);
		end
		return format("%+.2f%%", value);
	end
	return format("%+d", value);
end

-- "Name +now > +new" for a bonus only the talents give.
function SimpleQoL_CalcBonusLine(lines, label, now, add, pct)
	if ( add ~= 0 ) then
		tinsert(lines, label.." "..SimpleQoL_CalcSigned(now, pct).." > "..SimpleQoL_CalcSigned(now + add, pct));
	end
end

function SimpleQoL_CalcValueLine(lines, label, now, new, pctFormat)
	local a, b;
	if ( pctFormat ) then
		a, b = SimpleQoL_Pct2(now), SimpleQoL_Pct2(new);
	else
		a, b = now, new;
	end
	if ( a ~= b ) then
		tinsert(lines, label.." "..a.." > "..b);
	end
end

-- One line per thing that changes, everything added up: your value now
-- (learned talents included) > with the picked talents.
function SimpleQoL_CalcEffects()
	local have, add = SimpleQoL_CalcSums();
	local function get(t, key)
		return t[key] or 0;
	end
	local lines = {};
	local fresh = SimpleQoL_CalcFresh;
	local class = strupper((UnitClass and UnitClass("player")) or "");
	local level = (UnitLevel and UnitLevel("player")) or 1;
	local keys = { "STR", "AGI", "STA", "INT", "SPI" };
	local names = { "strength", "agility", "stamina", "intellect", "spirit" };
	local labels = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" };
	local stat, stat2 = {}, {};
	local i;
	for i = 1, 5 do
		stat[keys[i]] = (not fresh and SimpleQoL_CalcCurrent(names[i])) or 0;
		stat2[keys[i]] = stat[keys[i]] + get(add, keys[i]);
	end
	local d = {};
	foreach(add, function(key, value)
		if ( value ~= 0 ) then
			d[key] = 1;
		end
	end);
	if ( fresh ) then
		-- After a Reset only what the talents add is known.
		for i = 1, 5 do
			SimpleQoL_CalcBonusLine(lines, labels[i], 0, get(add, keys[i]));
		end
		SimpleQoL_CalcBonusLine(lines, "Health", 0, get(add, "HP"));
		SimpleQoL_CalcBonusLine(lines, "Mana", 0, get(add, "MP"));
		SimpleQoL_CalcBonusLine(lines, "Health regen per minute", 0, get(add, "HREG"));
		SimpleQoL_CalcBonusLine(lines, "Mana regen per minute", 0, get(add, "MREG"));
		SimpleQoL_CalcBonusLine(lines, "Crit", 0, get(add, "CRIT"), 1);
		SimpleQoL_CalcBonusLine(lines, "Dodge", 0, get(add, "DODGE"), 1);
		SimpleQoL_CalcBonusLine(lines, "Block with a Shield", 0, get(add, "BLOCK"), 1);
		SimpleQoL_CalcBonusLine(lines, "Parry", 0, get(add, "PARRY"), 1);
		SimpleQoL_CalcBonusLine(lines, "Armor", 0, get(add, "ARMOR"));
	else
		-- Health: stamina and talents that add health.
		local healthNow = UnitHealthMax and UnitHealthMax("player");
		local gain = SIMPLEQOL_STAMINA_GAIN[class];
		if ( healthNow and gain ) then
			SimpleQoL_CalcValueLine(lines, "Health", healthNow, healthNow + get(add, "HP")
				+ SimpleQoL_StatBonus(stat2.STA, 1, gain) - SimpleQoL_StatBonus(stat.STA, 1, gain));
		end
		-- Mana: intellect and talents that add mana.
		gain = SIMPLEQOL_INTELLECT_GAIN[class];
		local manaNow = UnitManaMax and UnitManaMax("player");
		if ( gain and manaNow and manaNow > 0 ) then
			SimpleQoL_CalcValueLine(lines, "Mana", manaNow, manaNow + get(add, "MP")
				+ SimpleQoL_StatBonus(stat2.INT, 2, gain) - SimpleQoL_StatBonus(stat.INT, 2, gain));
		end
		-- Regeneration per minute: spirit (per 2 s tick, server) plus talents.
		local hp = SIMPLEQOL_REGEN_HEALTH[class];
		if ( hp and (d.SPI or d.HREG) ) then
			local now = max(0, (hp[1] + stat.SPI * hp[2]) * 30) + get(have, "HREG");
			local new = max(0, (hp[1] + stat2.SPI * hp[2]) * 30) + get(have, "HREG") + get(add, "HREG");
			SimpleQoL_CalcValueLine(lines, "Health regen per minute", format("%.1f", now), format("%.1f", new));
		end
		local mp = SIMPLEQOL_REGEN_MANA[class];
		if ( mp and (d.SPI or d.MREG) ) then
			local now = max(0, (mp[1] + stat.SPI * mp[2]) * 30) + get(have, "MREG");
			local new = max(0, (mp[1] + stat2.SPI * mp[2]) * 30) + get(have, "MREG") + get(add, "MREG");
			SimpleQoL_CalcValueLine(lines, "Mana regen per minute", format("%.1f", now), format("%.1f", new));
		end
		for i = 1, 5 do
			SimpleQoL_CalcValueLine(lines, labels[i], stat[keys[i]], stat2[keys[i]]);
		end
		-- Attack power and damage per hit.
		local ap = SimpleQoL_AttackPower(class, level, stat.STR, stat.AGI);
		local ap2 = SimpleQoL_AttackPower(class, level, stat2.STR, stat2.AGI);
		if ( ap2 ~= ap ) then
			tinsert(lines, "Attack power "..ap.." > "..ap2.." ("..format("%+.2f", (ap2 - ap) / 14).." damage per hit)");
		end
		local critScale = SIMPLEQOL_CRIT_SCALING[class];
		local dodgeScale = SIMPLEQOL_DODGE_SCALING[class];
		if ( critScale and dodgeScale ) then
			local critRate = SimpleQoL_ClassRate(critScale, level);
			local dodgeRate = SimpleQoL_ClassRate(dodgeScale, level);
			local crit = stat.STR / critRate + get(have, "CRIT");
			local crit2 = stat2.STR / critRate + get(have, "CRIT") + get(add, "CRIT");
			SimpleQoL_CalcValueLine(lines, "Crit", crit, crit2, 1);
			-- Weapon crit: your crit plus the weapon's talents.
			foreach(add, function(key, value)
				local s, e, weapon = strfind(key, "^CRIT:(.+)");
				if ( weapon and value ~= 0 ) then
					SimpleQoL_CalcValueLine(lines, "Crit with "..weapon, crit + get(have, key), crit2 + get(have, key) + value, 1);
				end
			end);
			local base = SIMPLEQOL_BASE_DODGE[class] or 0;
			SimpleQoL_CalcValueLine(lines, "Dodge", base + stat.AGI / dodgeRate + get(have, "DODGE"),
				base + stat2.AGI / dodgeRate + get(have, "DODGE") + get(add, "DODGE"), 1);
			SimpleQoL_CalcValueLine(lines, "Proc chance", stat.AGI / dodgeRate, stat2.AGI / dodgeRate, 1);
			if ( SIMPLEQOL_BLOCK_CLASSES[class] ) then
				SimpleQoL_CalcValueLine(lines, "Block with a Shield", max(0, stat.STR / dodgeRate - 5) + 5 + get(have, "BLOCK"),
					max(0, stat2.STR / dodgeRate - 5) + 5 + get(have, "BLOCK") + get(add, "BLOCK"), 1);
			else
				SimpleQoL_CalcBonusLine(lines, "Block with a Shield", get(have, "BLOCK"), get(add, "BLOCK"), 1);
			end
		end
		SimpleQoL_CalcBonusLine(lines, "Parry", get(have, "PARRY"), get(add, "PARRY"), 1);
		local armorNow = UnitArmor and UnitArmor("player");
		if ( armorNow ) then
			SimpleQoL_CalcValueLine(lines, "Armor", armorNow, armorNow + get(add, "ARMOR"));
		else
			SimpleQoL_CalcBonusLine(lines, "Armor", get(have, "ARMOR"), get(add, "ARMOR"));
		end
	end
	-- Bonuses only the talents give, grouped and sorted by name.
	local g;
	for g = 1, getn(SIMPLEQOL_CALC_GROUPS) do
		local group = SIMPLEQOL_CALC_GROUPS[g];
		local found = {};
		foreach(add, function(key, value)
			local s, e, what = strfind(key, "^([A-Z]+:)(.+)");
			if ( s and value ~= 0 and strsub(key, 1, strlen(group[1])) == group[1] ) then
				tinsert(found, key);
			end
		end);
		SimpleQoL_CalcSort(found);
		for i = 1, getn(found) do
			local key = found[i];
			local what = strsub(key, strlen(group[1]) + 1);
			local label;
			if ( group[1] == "SKILL:" and SIMPLEQOL_CALC_SKILL_NAMES[what] ) then
				label = what;
			else
				label = format(group[2], what);
			end
			-- Weapon crit is shown above (with your crit) when your stats are known.
			if ( not (group[1] == "CRIT:" and not fresh) ) then
				SimpleQoL_CalcBonusLine(lines, label, get(have, key), get(add, key), group[3]);
			end
		end
	end
	SimpleQoL_CalcBonusLine(lines, "Spell reflect", get(have, "REFL"), get(add, "REFL"), 1);
	SimpleQoL_CalcBonusLine(lines, "Stealth detection", get(have, "DETECT"), get(add, "DETECT"));
	-- Effects that are on or off.
	local flags = {};
	foreach(add, function(key, value)
		local s, e, what = strfind(key, "^TRACK:(.+)");
		if ( what and value > 0 and get(have, key) == 0 ) then
			tinsert(flags, "Tracks "..what.." on the minimap");
		end
	end);
	SimpleQoL_CalcSort(flags);
	for i = 1, getn(flags) do
		tinsert(lines, flags[i]);
	end
	if ( get(add, "IMMUNE:Disease") > 0 and get(have, "IMMUNE:Disease") == 0 ) then
		tinsert(lines, "Immune to disease");
	end
	return lines;
end

-- What stats give you, with the server's formulas (alpha-core StatManager),
-- per class and level: health from stamina, mana from intellect, attack
-- power, damage per hit, crit and block from strength, dodge and proc chance
-- from agility, health and mana regeneration from spirit.
SIMPLEQOL_STAMINA_GAIN = { WARRIOR = 20, PALADIN = 18, HUNTER = 16, ROGUE = 16, PRIEST = 14, SHAMAN = 16, MAGE = 14, WARLOCK = 16, DRUID = 16 };
SIMPLEQOL_INTELLECT_GAIN = { PALADIN = 16, PRIEST = 20, SHAMAN = 18, MAGE = 20, WARLOCK = 20, DRUID = 18 };
SIMPLEQOL_DODGE_SCALING = { DRUID = { 4.6, 20 }, PALADIN = { 4.6, 20 }, SHAMAN = { 4.6, 20 }, MAGE = { 12.9, 20 }, ROGUE = { 1.1, 14.5 },
	HUNTER = { 1.8, 26.5 }, PRIEST = { 11.0, 20 }, WARLOCK = { 8.4, 20 }, WARRIOR = { 3.9, 20 } };
SIMPLEQOL_CRIT_SCALING = { DRUID = { 4.6, 20 }, PALADIN = { 4.6, 20 }, SHAMAN = { 4.6, 20 }, MAGE = { 12.9, 20 }, ROGUE = { 2.2, 29 },
	HUNTER = { 1.8, 26.5 }, PRIEST = { 11.0, 20 }, WARLOCK = { 8.4, 20 }, WARRIOR = { 7.8, 40 } };
SIMPLEQOL_BASE_DODGE = { DRUID = 0.9, MAGE = 3.2, PALADIN = 0.7, PRIEST = 3.0, SHAMAN = 1.7, WARLOCK = 2.0 };
SIMPLEQOL_REGEN_HEALTH = { WARRIOR = { -22.6, 1.26 }, PALADIN = { 0, 0.25 }, HUNTER = { -5.5, 0.43 }, ROGUE = { -13, 0.84 },
	PRIEST = { 1.4, 0.15 }, SHAMAN = { -3.6, 0.28 }, MAGE = { 1.0, 0.11 }, WARLOCK = { 1.5, 0.12 }, DRUID = { 1.0, 0.11 } };
SIMPLEQOL_REGEN_MANA = { PALADIN = { 15, 0.20 }, PRIEST = { 12.5, 0.25 }, SHAMAN = { 17, 0.20 }, MAGE = { 12.5, 0.25 },
	WARLOCK = { 15, 0.2 }, DRUID = { 15, 0.2 } };
SIMPLEQOL_BLOCK_CLASSES = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1 };

function SimpleQoL_StatBonus(value, first, gain)
	local base = min(value, 20);
	return base * first + max(value - 20, 0) * gain;
end

-- Level 1 / level 60 values blended for your level (as the server does).
function SimpleQoL_ClassRate(scaling, level)
	return (scaling[1] * (60 - level) + scaling[2] * (level - 1)) / 59;
end

function SimpleQoL_AttackPower(class, level, str, agi)
	if ( class == "WARRIOR" or class == "PALADIN" ) then
		return str * 2 + level * 3 - 20;
	elseif ( class == "DRUID" ) then
		return str * 2 - 20;
	elseif ( class == "HUNTER" ) then
		return str + agi + level * 2 - 20;
	elseif ( class == "ROGUE" ) then
		return str + (agi * 2 - 20) + level * 2 - 20;
	elseif ( class == "SHAMAN" ) then
		return str - 10 + (agi * 2 - 20) + level * 2;
	end
	return str - 10;
end

function SimpleQoL_Pct2(value)
	return format("%.2f%%", value);
end

-- Your value now, for the stats the client can tell.
function SimpleQoL_CalcCurrent(what)
	if ( what == "health" or what == "maximum health" ) then
		return UnitHealthMax("player");
	end
	if ( what == "mana" or what == "maximum mana" ) then
		return UnitManaMax and UnitManaMax("player");
	end
	if ( what == "armor" ) then
		return UnitArmor and UnitArmor("player");
	end
	local index = SIMPLEQOL_STAT_INDEX[what];
	if ( index and UnitStat ) then
		local base, modifier = UnitStat("player", index);
		return (base or 0) + (modifier or 0);
	end
	return nil;
end

-- Shown: per talent the ranks picked so far and the next one, under the
-- headers of the Talents window.
function SimpleQoL_CalcBuildView()
	SimpleQoL_CalcView = {};
	local header = nil;
	local i;
	for i = 1, getn(SimpleQoL_CalcList) do
		local e = SimpleQoL_CalcList[i];
		local previous = SimpleQoL_CalcPrevious(i);
		if ( e.owned or e.rank == e.start or (previous and SimpleQoL_CalcPlan[previous]) ) then
			if ( e.header and e.header ~= "" and e.header ~= header ) then
				header = e.header;
				tinsert(SimpleQoL_CalcView, { header });
			end
			tinsert(SimpleQoL_CalcView, { nil, i });
		end
	end
end

function SimpleQoL_TalentCalc_Update()
	SimpleQoL_CalcBuildView();
	local total = getn(SimpleQoL_CalcList);
	FauxScrollFrame_Update(SimpleQoLTalentCalcScroll, getn(SimpleQoL_CalcView), SIMPLEQOL_CALC_ROWS, 16);
	local offset = FauxScrollFrame_GetOffset(SimpleQoLTalentCalcScroll) or 0;
	local points, used = SimpleQoL_CalcPoints();
	local label = "Points until level "..SimpleQoL_MaxLevel();
	if ( SimpleQoL_CalcFresh ) then
		label = "Points from level 1 to "..SimpleQoL_MaxLevel();
	end
	SimpleQoLTalentCalcPoints:SetText(label..": "..(points - used).." left of "..points);
	local i;
	for i = 1, SIMPLEQOL_CALC_ROWS do
		local line = SimpleQoL_CalcView[i + offset];
		local row = getglobal("SimpleQoLTalentCalcRow"..i);
		local name = getglobal("SimpleQoLTalentCalcRow"..i.."Name");
		local cost = getglobal("SimpleQoLTalentCalcRow"..i.."Cost");
		local check = getglobal("SimpleQoLTalentCalcRow"..i.."Check");
		row.index = nil;
		if ( line and line[1] ) then
			name:SetText(line[1]);
			name:SetTextColor(1.0, 0.82, 0.0);
			cost:SetText("");
			check:Hide();
			row:Show();
		elseif ( line ) then
			local index = line[2];
			local e = SimpleQoL_CalcList[index];
			row.index = index;
			name:SetText("  "..SimpleQoL_CalcLabel(e));
			cost:SetText(e.cost.." TP");
			if ( e.owned ) then
				cost:SetText("Learned");
				check:Show();
				name:SetTextColor(0.6, 0.8, 0.6);
				cost:SetTextColor(0.6, 0.8, 0.6);
			elseif ( SimpleQoL_CalcPlan[index] == 2 ) then
				check:Show();
				name:SetTextColor(0.6, 0.8, 0.6);
				cost:SetTextColor(0.6, 0.8, 0.6);
			elseif ( SimpleQoL_CalcPlan[index] ) then
				check:Show();
				name:SetTextColor(0.1, 1.0, 0.1);
				cost:SetTextColor(0.1, 1.0, 0.1);
			else
				check:Hide();
				if ( SimpleQoL_CalcBlocked(index) ) then
					name:SetTextColor(0.5, 0.5, 0.5);
					cost:SetTextColor(0.5, 0.5, 0.5);
				elseif ( e.cost > points - used ) then
					name:SetTextColor(1.0, 1.0, 1.0);
					cost:SetTextColor(1.0, 0.1, 0.1);
				else
					name:SetTextColor(1.0, 1.0, 1.0);
					cost:SetTextColor(1.0, 1.0, 1.0);
				end
			end
			row:Show();
		else
			row:Hide();
		end
	end
	local lines = SimpleQoL_CalcEffects();
	local text = "";
	local learnable = 0;
	for i = 1, total do
		if ( not SimpleQoL_CalcList[i].owned ) then
			learnable = learnable + 1;
		end
	end
	if ( learnable == 0 ) then
		text = "No talents to learn.";
	elseif ( getn(lines) == 0 ) then
		text = "Click talents above to try them out.";
	end
	for i = 1, getn(lines) do
		if ( text ~= "" ) then
			text = text.."\n";
		end
		text = text..lines[i];
	end
	-- Everything is shown; the box scrolls when it is longer.
	SimpleQoLTalentCalcResult:SetText(text);
	if ( SimpleQoLTalentCalcResultChild and SimpleQoLTalentCalcResult.GetHeight ) then
		SimpleQoLTalentCalcResultChild:SetHeight(max(20, (SimpleQoLTalentCalcResult:GetHeight() or 0) + 4));
	end
	if ( SimpleQoLTalentCalcResultScroll and SimpleQoLTalentCalcResultScroll.UpdateScrollChildRect ) then
		SimpleQoLTalentCalcResultScroll:UpdateScrollChildRect();
	end
end

function SimpleQoL_TalentCalc_Toggle()
	if ( SimpleQoLTalentCalc:IsVisible() ) then
		SimpleQoLTalentCalc:Hide();
		return;
	end
	SimpleQoL_CalcFresh = nil;
	SimpleQoL_TalentCalc_Read();
	SimpleQoLTalentCalcBuilds:Hide();
	SimpleQoLTalentCalcSaveBox:Hide();
	FauxScrollFrame_SetOffset(SimpleQoLTalentCalcScroll, 0);
	SimpleQoLTalentCalc:Show();
	SimpleQoL_TalentCalc_Update();
end

-- Below level 25: the picks go. At level 25: start over as a new character
-- with all points and nothing learned.
function SimpleQoL_TalentCalc_Reset()
	if ( (UnitLevel("player") or 1) >= SimpleQoL_MaxLevel() ) then
		SimpleQoL_CalcFresh = 1;
		SimpleQoL_TalentCalc_Read();
	end
	SimpleQoL_CalcPlan = {};
	SimpleQoL_TalentCalc_Update();
end

-- Picks are kept: they count as learned in the calculator.
function SimpleQoL_TalentCalc_Set()
	local i;
	for i = 1, getn(SimpleQoL_CalcList) do
		if ( SimpleQoL_CalcPlan[i] ) then
			SimpleQoL_CalcPlan[i] = 2;
		end
	end
	SimpleQoL_TalentCalc_Update();
end

function SimpleQoL_TalentCalc_RowClick(id)
	local index = getglobal("SimpleQoLTalentCalcRow"..id).index;
	local e = index and SimpleQoL_CalcList[index];
	if ( not e or e.owned ) then
		return;
	end
	if ( SimpleQoL_CalcPlan[index] == 2 ) then
		UIErrorsFrame:AddMessage("Set talents can only be cleared with Reset.", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
		return;
	end
	if ( SimpleQoL_CalcPlan[index] ) then
		SimpleQoL_CalcPlan[index] = nil;
		SimpleQoL_CalcDropOrphans();
	else
		local points, used = SimpleQoL_CalcPoints();
		local reason = SimpleQoL_CalcBlocked(index);
		if ( not reason and e.cost > points - used ) then
			reason = "Not enough talent points.";
		end
		if ( reason ) then
			UIErrorsFrame:AddMessage(reason, 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
			return;
		end
		SimpleQoL_CalcPlan[index] = 1;
	end
	SimpleQoL_TalentCalc_Update();
end

function SimpleQoL_TalentCalc_RowEnter(id)
	local index = getglobal("SimpleQoLTalentCalcRow"..id).index;
	local e = index and SimpleQoL_CalcList[index];
	if ( not e ) then
		return;
	end
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText(SimpleQoL_CalcLabel(e));
	if ( e.desc ~= "" ) then
		GameTooltip:AddLine(e.desc, "", 1.0, 1.0, 1.0);
	end
	if ( e.level > 1 ) then
		GameTooltip:AddLine("Level "..e.level, "", 1.0, 0.82, 0.0);
	end
	if ( e.owned ) then
		GameTooltip:AddLine("Learned", "", 0.6, 0.8, 0.6);
		GameTooltip:Show();
		return;
	end
	local reason = SimpleQoL_CalcBlocked(index);
	if ( reason and not SimpleQoL_CalcPlan[index] ) then
		GameTooltip:AddLine(reason, "", 1.0, 0.1, 0.1);
	end
	GameTooltip:Show();
end

--------------------------------------------------------------------------------
-- Saved builds: up to 5 per class for the whole account (SimpleSave key
-- "Build<CLASS>"). A build is each talent's rank, learned or picked.
-- Stored as "name~" + 3 character talent code + 1 character rank per talent;
-- builds are joined with "|".
--------------------------------------------------------------------------------

SIMPLEQOL_MAX_BUILDS = 5;
SIMPLEQOL_BUILD_DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz";
SimpleQoL_BuildCodeIndex = nil;

function SimpleQoL_BuildDigit(n)
	return strsub(SIMPLEQOL_BUILD_DIGITS, n + 1, n + 1);
end

function SimpleQoL_BuildDigitValue(c)
	local s = strfind(SIMPLEQOL_BUILD_DIGITS, c, 1, 1);
	return s and (s - 1);
end

-- A short code from the talent's name (the same on every client).
function SimpleQoL_BuildCode(name)
	local key = SimpleQoL_TalentKey(name);
	local h = 0;
	local i;
	for i = 1, strlen(key) do
		h = mod(h * 31 + strbyte(key, i), 46656);
	end
	return SimpleQoL_BuildDigit(floor(h / 1296))..SimpleQoL_BuildDigit(mod(floor(h / 36), 36))..SimpleQoL_BuildDigit(mod(h, 36));
end

function SimpleQoL_BuildNameOf(code)
	if ( not SimpleQoL_BuildCodeIndex ) then
		SimpleQoL_BuildCodeIndex = {};
		if ( SIMPLEQOL_TALENTS ) then
			foreach(SIMPLEQOL_TALENTS, function(name, data)
				SimpleQoL_BuildCodeIndex[SimpleQoL_BuildCode(name)] = name;
			end);
		end
	end
	return SimpleQoL_BuildCodeIndex[code];
end

function SimpleQoL_BuildSplit(text)
	local list = {};
	local start = 1;
	if ( text == "" ) then
		return list;
	end
	while ( 1 ) do
		local position = strfind(text, "|", start, 1);
		if ( not position ) then
			tinsert(list, strsub(text, start));
			return list;
		end
		tinsert(list, strsub(text, start, position - 1));
		start = position + 1;
	end
end

function SimpleQoL_BuildKey()
	return "Build"..strupper((UnitClass and UnitClass("player")) or "");
end

function SimpleQoL_BuildCanSave()
	if ( not SimpleSave_Get or not SimpleSave_Set ) then
		UIErrorsFrame:AddMessage("Saving builds needs SimpleSave.", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
		return nil;
	end
	if ( SimpleSave_IsLoaded and not SimpleSave_IsLoaded() ) then
		UIErrorsFrame:AddMessage("The save is not read yet. Try again in a moment.", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
		return nil;
	end
	return 1;
end

-- Returns { { name = "...", talents = { { talent name, rank }, ... } }, ... }.
function SimpleQoL_BuildList()
	local list = {};
	local text = (SimpleSave_Get and SimpleSave_Get("SimpleQoL", SimpleQoL_BuildKey(), "")) or "";
	local parts = SimpleQoL_BuildSplit(text);
	local i;
	for i = 1, getn(parts) do
		local s, e, name, data = strfind(parts[i], "^([^~]*)~(.*)$");
		if ( name and name ~= "" ) then
			local build = { name = name, talents = {} };
			local p = 1;
			while ( p + 3 <= strlen(data) ) do
				local talent = SimpleQoL_BuildNameOf(strsub(data, p, p + 2));
				local rank = SimpleQoL_BuildDigitValue(strsub(data, p + 3, p + 3));
				if ( talent and rank and rank > 0 ) then
					tinsert(build.talents, { talent, rank });
				end
				p = p + 4;
			end
			tinsert(list, build);
		end
	end
	return list;
end

function SimpleQoL_BuildStore(list)
	local parts = {};
	local i, k;
	for i = 1, getn(list) do
		local data = "";
		for k = 1, getn(list[i].talents) do
			local t = list[i].talents[k];
			data = data..SimpleQoL_BuildCode(t[1])..SimpleQoL_BuildDigit(min(t[2], 35));
		end
		tinsert(parts, list[i].name.."~"..data);
	end
	local text = "";
	for i = 1, getn(parts) do
		if ( i > 1 ) then
			text = text.."|";
		end
		text = text..parts[i];
	end
	if ( text == "" ) then
		text = nil;
	end
	SimpleSave_Set("SimpleQoL", SimpleQoL_BuildKey(), text);
end

-- Each talent's highest rank, learned or picked.
function SimpleQoL_BuildCurrent()
	local ranks = {};
	local order = {};
	local i;
	for i = 1, getn(SimpleQoL_CalcList) do
		local e = SimpleQoL_CalcList[i];
		if ( e.owned or SimpleQoL_CalcPlan[i] ) then
			if ( not ranks[e.name] ) then
				tinsert(order, e.name);
			end
			ranks[e.name] = max(ranks[e.name] or 0, e.rank);
		end
	end
	local talents = {};
	for i = 1, getn(order) do
		tinsert(talents, { order[i], ranks[order[i]] });
	end
	return talents;
end

-- Talent points for every rank of the build.
function SimpleQoL_BuildCost(build)
	local total = 0;
	local i, r;
	for i = 1, getn(build.talents) do
		local data = SimpleQoL_TalentData(build.talents[i][1]);
		for r = 1, build.talents[i][2] do
			if ( data and data[r] ) then
				total = total + data[r][1];
			end
		end
	end
	return total;
end

-- Puts a popup above the calculator and its content above the popup (in
-- 0.5.3 the content does not follow when only the popup is raised).
function SimpleQoL_BuildRaise(frame, children, grandchildren)
	local base = SimpleQoLTalentCalc:GetFrameLevel() + 20;
	frame:SetFrameLevel(base);
	local i;
	for i = 1, getn(children) do
		getglobal(children[i]):SetFrameLevel(base + 1);
	end
	for i = 1, getn(grandchildren or {}) do
		getglobal(grandchildren[i]):SetFrameLevel(base + 2);
	end
end

function SimpleQoL_TalentCalc_SaveOpen()
	if ( not SimpleQoL_BuildCanSave() ) then
		return;
	end
	SimpleQoLTalentCalcBuilds:Hide();
	SimpleQoLTalentCalcSaveName:SetText("");
	SimpleQoL_BuildRaise(SimpleQoLTalentCalcSaveBox, { "SimpleQoLTalentCalcSaveName", "SimpleQoLTalentCalcSaveOk", "SimpleQoLTalentCalcSaveCancel" });
	SimpleQoLTalentCalcSaveBox:Show();
	SimpleQoLTalentCalcSaveName:SetFocus();
end

function SimpleQoL_TalentCalc_SaveConfirm()
	local name = gsub(SimpleQoLTalentCalcSaveName:GetText() or "", "[~|]", "");
	name = gsub(gsub(name, "^%s+", ""), "%s+$", "");
	if ( name == "" ) then
		UIErrorsFrame:AddMessage("Type a name for the build.", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
		return;
	end
	local talents = SimpleQoL_BuildCurrent();
	if ( getn(talents) == 0 ) then
		UIErrorsFrame:AddMessage("No talents learned or picked.", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
		return;
	end
	local list = SimpleQoL_BuildList();
	local slot = nil;
	local i;
	for i = 1, getn(list) do
		if ( strlower(list[i].name) == strlower(name) ) then
			slot = i;
		end
	end
	if ( not slot ) then
		if ( getn(list) >= SIMPLEQOL_MAX_BUILDS ) then
			UIErrorsFrame:AddMessage("Max "..SIMPLEQOL_MAX_BUILDS.." builds per class. Delete one first.", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
			return;
		end
		slot = getn(list) + 1;
	end
	list[slot] = { name = name, talents = talents };
	SimpleQoL_BuildStore(list);
	SimpleQoLTalentCalcSaveName:ClearFocus();
	SimpleQoLTalentCalcSaveBox:Hide();
	SimpleQoL_Print("Build saved: "..name);
end

function SimpleQoL_TalentCalc_LoadToggle()
	if ( SimpleQoLTalentCalcBuilds:IsVisible() ) then
		SimpleQoLTalentCalcBuilds:Hide();
		return;
	end
	if ( not SimpleQoL_BuildCanSave() ) then
		return;
	end
	SimpleQoLTalentCalcSaveBox:Hide();
	local rows, deletes = {}, {};
	local i;
	for i = 1, SIMPLEQOL_MAX_BUILDS do
		tinsert(rows, "SimpleQoLTalentCalcBuild"..i);
		tinsert(deletes, "SimpleQoLTalentCalcBuild"..i.."Delete");
	end
	SimpleQoL_BuildRaise(SimpleQoLTalentCalcBuilds, rows, deletes);
	SimpleQoLTalentCalcBuilds:Show();
	SimpleQoL_TalentCalc_BuildsUpdate();
end

function SimpleQoL_TalentCalc_BuildsUpdate()
	local class = (UnitClass and UnitClass("player")) or "";
	SimpleQoLTalentCalcBuildsTitle:SetText("Builds ("..class..")");
	local list = SimpleQoL_BuildList();
	local i;
	for i = 1, SIMPLEQOL_MAX_BUILDS do
		local row = getglobal("SimpleQoLTalentCalcBuild"..i);
		local build = list[i];
		if ( build ) then
			getglobal("SimpleQoLTalentCalcBuild"..i.."Name"):SetText(build.name);
			getglobal("SimpleQoLTalentCalcBuild"..i.."Cost"):SetText(SimpleQoL_BuildCost(build).." TP");
			row:Show();
		else
			row:Hide();
		end
	end
	if ( getn(list) == 0 ) then
		SimpleQoLTalentCalcBuildsEmpty:Show();
	else
		SimpleQoLTalentCalcBuildsEmpty:Hide();
	end
end

-- Picks the build's ranks above what you have learned. A rank that cannot
-- be picked yet (level, skill, requirement) stops that talent there.
function SimpleQoL_TalentCalc_LoadBuild(id)
	local build = SimpleQoL_BuildList()[id];
	if ( not build ) then
		return;
	end
	local want = {};
	local i;
	for i = 1, getn(build.talents) do
		want[SimpleQoL_TalentKey(build.talents[i][1])] = build.talents[i][2];
	end
	for i = 1, getn(SimpleQoL_CalcList) do
		if ( SimpleQoL_CalcPlan[i] == 1 ) then
			SimpleQoL_CalcPlan[i] = nil;
		end
	end
	local stopped = {};
	local missing = 0;
	for i = 1, getn(SimpleQoL_CalcList) do
		local e = SimpleQoL_CalcList[i];
		local key = SimpleQoL_TalentKey(e.name);
		local rank = want[key];
		if ( rank and not e.owned and e.rank <= rank and not SimpleQoL_CalcPlan[i] ) then
			if ( stopped[key] or SimpleQoL_CalcBlocked(i) ) then
				stopped[key] = 1;
				missing = missing + 1;
			else
				SimpleQoL_CalcPlan[i] = 1;
			end
		end
	end
	SimpleQoLTalentCalcBuilds:Hide();
	SimpleQoL_TalentCalc_Update();
	local points, used = SimpleQoL_CalcPoints();
	local text = "Build loaded: "..build.name..".";
	if ( missing > 0 ) then
		text = text.." "..missing.." ranks cannot be picked yet (level or requirement).";
	end
	if ( used > points ) then
		text = text.." It needs "..(used - points).." more talent points.";
	end
	SimpleQoL_Print(text);
end

function SimpleQoL_TalentCalc_DeleteBuild(id)
	local list = SimpleQoL_BuildList();
	if ( not list[id] ) then
		return;
	end
	local name = list[id].name;
	tremove(list, id);
	SimpleQoL_BuildStore(list);
	SimpleQoL_TalentCalc_BuildsUpdate();
	SimpleQoL_Print("Build deleted: "..name);
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

SimpleQoL_FramesApplyTime = nil;

function SimpleQoL_Frames_OnLoad()
	this:RegisterEvent("BAG_UPDATE");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_XP_UPDATE");
	this:RegisterEvent("PLAYER_REGEN_ENABLED");
end

function SimpleQoL_Frames_OnEvent(event)
	if ( event == "BAG_UPDATE" ) then
		SimpleQoL_BagDirty = 1;
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		SimpleQoL_BagDirty = 1;
		SimpleQoL_LastXP = UnitXP("player");
		-- After AlphaUI has placed its frames.
		SimpleQoL_FramesApplyTime = GetTime() + 1;
	elseif ( event == "PLAYER_XP_UPDATE" ) then
		SimpleQoL_XPChanged();
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		SimpleQoL_CombatEndTime = GetTime();
	end
end

function SimpleQoL_Frames_OnUpdate()
	if ( not SimpleQoL_Loaded ) then
		return;
	end
	if ( SimpleQoL_BagDirty ) then
		SimpleQoL_UpdateBagSlots();
	end
	if ( SimpleQoL_FramesApplyTime and GetTime() > SimpleQoL_FramesApplyTime ) then
		SimpleQoL_FramesApplyTime = nil;
		SimpleQoL_ApplyFramePositions();
	end
	if ( SimpleQoL_MoverDrag ) then
		SimpleQoL_MoverDragUpdate();
		SimpleQoL_UpdateMovers();
	elseif ( GetTime() - (SimpleQoL_MoversTime or 0) > 0.1 ) then
		SimpleQoL_MoversTime = GetTime();
		SimpleQoL_UpdateMovers();
	end
end

-- Called by SimpleQoL_Load once the saved settings are read.
function SimpleQoL_FramesLoaded()
	if ( SimpleSave_GetNumber ) then
		SIMPLEQOL_MAX_LEVEL = SimpleSave_GetNumber("SimpleQoL", "MaxLevel", 25) or 25;
	end
	if ( SimpleQoL_LoadKnown ) then
		SimpleQoL_LoadKnown();
	end
	SimpleQoL_LoadFramePositions();
	SimpleQoL_FramesApplyTime = GetTime() + 1;
	SimpleQoL_BagDirty = 1;
end

-- A check box changed.
function SimpleQoL_FramesChanged()
	SimpleQoL_BagDirty = 1;
	if ( MainMenuExpBar and MainMenuExpBar_Update ) then
		MainMenuExpBar_Update();
	end
end
