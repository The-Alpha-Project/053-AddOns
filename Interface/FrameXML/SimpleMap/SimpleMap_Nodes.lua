-- SimpleMap: remembers gathered herbs, ore and opened chests (option, off by default).
-- Saved per map with SimpleSave. Position is where you stood while gathering.

SIMPLEMAP_NODE_MAX = 25;      -- per map, the oldest are dropped
SIMPLEMAP_NODE_NAME = 16;     -- characters of the node name that are kept
SIMPLEMAP_NODE_MERGE = 0.002; -- map fraction, nodes closer than this replace each other
SIMPLEMAP_NODE_SPELLS = { ["Herb Gathering"] = "h", ["Mining"] = "m", ["Opening"] = "c" };
SIMPLEMAP_NODE_KINDS = {
	h = { "Herb", 0.2, 0.9, 0.2 },
	m = { "Ore", 1.0, 0.55, 0.1 },
	c = { "Chest", 1.0, 0.9, 0.1 },
};

-- Node name (lower case, the start of the name is enough) to picture in Media\Node_<key>.
-- Names are the 0.5.3 names. Unknown herbs and ore get the "herb" / "ore" picture.
SIMPLEMAP_NODE_ICONS = {
	{ "peacebloom", "peacebloom" }, { "silverleaf", "silverleaf" }, { "mageroyal", "mageroyal" },
	{ "common magebloom", "mageroyal" }, { "earthroot", "earthroot" }, { "snakeroot", "earthroot" },
	{ "bruiseweed", "bruiseweed" }, { "wild steelbloom", "steelbloom" }, { "grave moss", "gravemoss" },
	{ "liferoot", "liferoot" }, { "fadeleaf", "fadeleaf" }, { "goldthorn", "goldthorn" },
	{ "khadgar", "khadgar" }, { "wintersbite", "wintersbite" }, { "firebloom", "firebloom" },
	{ "crownroyal", "kingsblood" }, { "thornroot", "briarthorn" }, { "stranglekelp", "stranglekelp" },
	{ "copper vein", "copper" }, { "tin vein", "tin" }, { "silver vein", "silver" }, { "gold vein", "gold" },
	{ "iron deposit", "iron" }, { "mithril deposit", "mithril" }, { "truesilver deposit", "truesilver" },
	{ "small thorium vein", "thorium" }, { "thorium lode", "thorium" }, { "rich thorium vein", "richthorium" },
	{ "ooze covered silver", "silver" }, { "ooze covered gold", "gold" }, { "ooze covered mithril", "mithril" },
	{ "ooze covered truesilver", "truesilver" }, { "ooze covered rich thorium", "richthorium" },
	{ "ooze covered thorium", "thorium" },
};

-- Only these chests are remembered (the ordinary treasure chests of the world).
SIMPLEMAP_NODE_CHESTS = { "battered chest", "solid chest", "large solid chest", "large battered chest", "alliance chest", "horde chest" };
SIMPLEMAP_NODE_SIZE = { h = 9, m = 9, c = 10 };   -- picture size on the map

-- The name (maybe cut short when saved) is one of the chests above.
function SimpleMap_ChestOk(name)
	if ( not name or name == "" ) then
		return nil;
	end
	name = strlower(name);
	local len = strlen(name);
	local i;
	for i = 1, getn(SIMPLEMAP_NODE_CHESTS) do
		local chest = SIMPLEMAP_NODE_CHESTS[i];
		if ( strsub(chest, 1, len) == name or strsub(name, 1, strlen(chest)) == chest ) then
			return 1;
		end
	end
	return nil;
end

SimpleMap_RememberOre = nil;     -- options, off by default
SimpleMap_RememberHerbs = nil;
SimpleMap_RememberChests = nil;
SimpleMap_RememberNodes = nil;   -- 1 when any of the three is on

-- Which kinds are remembered: m (ore), h (herbs), c (chests).
function SimpleMap_KindOn(kind)
	if ( kind == "m" ) then
		return SimpleMap_RememberOre;
	elseif ( kind == "h" ) then
		return SimpleMap_RememberHerbs;
	end
	return SimpleMap_RememberChests;
end

function SimpleMap_NodesRefresh()
	SimpleMap_RememberNodes = (SimpleMap_RememberOre or SimpleMap_RememberHerbs or SimpleMap_RememberChests) and 1 or nil;
	SimpleMap_NodeStamp = SimpleMap_NodeStamp + 1;
end
SimpleMap_NodeData = nil;        -- [map] = list of { kind, x, y, name }
SimpleMap_NodeStamp = 0;
SimpleMap_GatherPending = nil;

function SimpleMap_NodeList(map)
	if ( not SimpleMap_NodeData ) then
		SimpleMap_NodeData = {};
	end
	local list = SimpleMap_NodeData[map];
	if ( list ) then
		return list;
	end
	list = {};
	if ( SimpleSave_IsLoaded and not SimpleSave_IsLoaded() ) then
		return list;
	end
	SimpleMap_NodeData[map] = list;
	local text = SimpleSave_Get and SimpleSave_Get("SimpleMap", "N"..map);
	if ( text and text ~= "" ) then
		local pos = 1;
		local len = strlen(text);
		while ( pos <= len ) do
			local stop = strfind(text, ",", pos, true);
			if ( not stop ) then
				stop = len + 1;
			end
			local item = strsub(text, pos, stop - 1);
			pos = stop + 1;
			local a, b, kind, x, y, name = strfind(item, "^(%a)%.(%d+)%.(%d+)%.(.*)$");
			if ( kind and SIMPLEMAP_NODE_KINDS[kind] and (kind ~= "c" or SimpleMap_ChestOk(name)) ) then
				tinsert(list, { kind, tonumber(x) / 10000, tonumber(y) / 10000, name });
			end
		end
	end
	return list;
end

function SimpleMap_NodeSave(map)
	if ( not SimpleSave_Set ) then
		return;
	end
	local list = SimpleMap_NodeList(map);
	local text = "";
	local i;
	for i = 1, getn(list) do
		local e = list[i];
		if ( i > 1 ) then
			text = text..",";
		end
		text = text..e[1].."."..floor(e[2] * 10000 + 0.5).."."..floor(e[3] * 10000 + 0.5).."."..e[4];
	end
	SimpleSave_Set("SimpleMap", "N"..map, text);
end

function SimpleMap_NodeAdd(kind, name, map, x, y)
	local list = SimpleMap_NodeList(map);
	local i = 1;
	while ( i <= getn(list) ) do
		local e = list[i];
		if ( abs(e[2] - x) < SIMPLEMAP_NODE_MERGE and abs(e[3] - y) < SIMPLEMAP_NODE_MERGE ) then
			tremove(list, i);
		else
			i = i + 1;
		end
	end
	tinsert(list, { kind, x, y, name });
	while ( getn(list) > SIMPLEMAP_NODE_MAX ) do
		tremove(list, 1);
	end
	SimpleMap_NodeSave(map);
	SimpleMap_NodeStamp = SimpleMap_NodeStamp + 1;
end

-- The map and position of the player. Does not touch an open map unless it
-- shows another zone (then nothing is recorded).
function SimpleMap_GatherSpot()
	if ( SimpleMapFrame:IsVisible() ) then
		if ( SimpleMap_Dungeon or not SimpleMap_HasPosition() ) then
			return nil;
		end
	elseif ( not SimpleMap_FindWorldZone() ) then
		return nil;
	end
	local x, y = GetPlayerMapPosition("player");
	local map = GetMapInfo();
	if ( not map or not x or (x == 0 and y == 0) ) then
		return nil;
	end
	return map, x, y;
end

function SimpleMap_NodeName(kind)
	local name;
	if ( GameTooltip:IsVisible() and GameTooltipTextLeft1 ) then
		name = GameTooltipTextLeft1:GetText();
		if ( name and strfind(name, "^0x%x+$") and GameTooltipTextLeft2 ) then
			name = GameTooltipTextLeft2:GetText();
		end
	end
	if ( name ) then
		name = gsub(name, "|c%x%x%x%x%x%x%x%x", "");
		name = gsub(name, "|r", "");
		name = gsub(name, "[%.,_]", "");
	end
	if ( not name or name == "" or name == UnitName("player") or strfind(name, "^0x") ) then
		name = SIMPLEMAP_NODE_KINDS[kind][1];
	end
	return strsub(name, 1, SIMPLEMAP_NODE_NAME);
end

function SimpleMap_GatherEvent(event)
	if ( not SimpleMap_RememberNodes ) then
		SimpleMap_GatherPending = nil;
		return;
	end
	if ( event == "SPELLCAST_START" or event == "SPELLCAST_CHANNEL_START" ) then
		SimpleMap_GatherPending = nil;
		local spell = arg1;
		if ( event == "SPELLCAST_CHANNEL_START" ) then
			spell = arg2;
		end
		local kind = spell and SIMPLEMAP_NODE_SPELLS[spell];
		if ( kind and SimpleMap_KindOn(kind) ) then
			local map, x, y = SimpleMap_GatherSpot();
			local name = map and SimpleMap_NodeName(kind);
			if ( map and (kind ~= "c" or SimpleMap_ChestOk(name)) ) then
				SimpleMap_GatherPending = { kind, name, map, x, y, GetTime() };
			end
		end
	elseif ( event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" ) then
		SimpleMap_GatherPending = nil;
	elseif ( event == "LOOT_OPENED" ) then
		local p = SimpleMap_GatherPending;
		SimpleMap_GatherPending = nil;
		if ( p and GetTime() - p[6] < 30 ) then
			SimpleMap_NodeAdd(p[1], p[2], p[3], p[4], p[5]);
		end
	end
end

-- The picture key of a node: its name decides, else the kind.
function SimpleMap_NodeIcon(e)
	if ( e[5] ) then
		return e[5];
	end
	local key;
	if ( e[1] == "c" ) then
		key = "chest";
	else
		local name = strlower(e[4]);
		local len = strlen(name);
		local i;
		for i = 1, getn(SIMPLEMAP_NODE_ICONS) do
			local entry = SIMPLEMAP_NODE_ICONS[i];
			if ( strsub(entry[1], 1, len) == name or strsub(name, 1, strlen(entry[1])) == entry[1] ) then
				key = entry[2];
				break
			end
		end
		if ( not key ) then
			if ( e[1] == "m" ) then
				key = "ore";
			else
				key = "herb";
			end
		end
	end
	e[5] = key;
	return key;
end

function SimpleMap_NodeHideAll()
	local i;
	for i = 1, SIMPLEMAP_NODE_MAX do
		getglobal("SimpleMapNode"..i):Hide();
	end
	SimpleMap_NodeShown = nil;
	SimpleMap_NodeList_Shown = nil;
end

function SimpleMap_NodeUpdate()
	-- Herbs, ore and chests are shown on zone maps only, never on a continent or the world
	if ( not SimpleMap_RememberNodes or SimpleMap_Dungeon or (GetCurrentMapZone and GetCurrentMapZone() == 0) ) then
		if ( SimpleMap_NodeShown ) then
			SimpleMap_NodeHideAll();
		end
		return;
	end
	-- the map whose tiles are drawn (see SimpleMap_UpdateMap)
	local map = SimpleMap_ShownMap;
	if ( not map ) then
		if ( SimpleMap_NodeShown ) then
			SimpleMap_NodeHideAll();
		end
		return;
	end
	local list = SimpleMap_NodeList(map);
	local n = getn(list);
	if ( list == SimpleMap_NodeList_Shown and n == SimpleMap_NodeCount and SimpleMap_NodeStamp == SimpleMap_NodeSeen
		and SimpleMap_Zoom == SimpleMap_NodeZoom and SimpleMap_ViewLeft == SimpleMap_NodeLeft and SimpleMap_ViewTop == SimpleMap_NodeTop ) then
		return;
	end
	SimpleMap_NodeList_Shown, SimpleMap_NodeCount, SimpleMap_NodeSeen = list, n, SimpleMap_NodeStamp;
	SimpleMap_NodeZoom, SimpleMap_NodeLeft, SimpleMap_NodeTop = SimpleMap_Zoom, SimpleMap_ViewLeft, SimpleMap_ViewTop;
	SimpleMap_NodeShown = 1;
	local i;
	local j = 0;
	for i = 1, n do
		local e = list[i];
		if ( j < SIMPLEMAP_NODE_MAX and SimpleMap_KindOn(e[1]) ) then
			local x, y = SimpleMap_ToView(e[2], e[3]);
			if ( x ) then
				j = j + 1;
				local button = getglobal("SimpleMapNode"..j);
				button.entry = e;
				local size = SIMPLEMAP_NODE_SIZE[e[1]] or 9;
				button:SetWidth(size);
				button:SetHeight(size);
				button:ClearAllPoints();
				button:SetPoint("CENTER", "SimpleMapButton", "TOPLEFT", x, y);
				local key = SimpleMap_NodeIcon(e);
				if ( button.key ~= key ) then
					button.key = key;
					getglobal("SimpleMapNode"..j.."Texture"):SetTexture(SIMPLEMAP_MEDIA.."Node_"..key);
				end
				button:Show();
			end
		end
	end
	for i = j + 1, SIMPLEMAP_NODE_MAX do
		local button = getglobal("SimpleMapNode"..i);
		button.entry = nil;
		button:Hide();
	end
end

function SimpleMap_NodeOnEnter()
	local e = this.entry;
	if ( not e ) then
		return;
	end
	local kind = SIMPLEMAP_NODE_KINDS[e[1]];
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText(e[4], kind[2], kind[3], kind[4]);
	GameTooltip:AddLine("|cffffffff"..kind[1].." (gathered)|r");
	GameTooltip:Show();
end
