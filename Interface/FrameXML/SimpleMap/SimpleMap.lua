--------------------------------------------------------------------------------
-- SimpleMap for WoW 0.5.3
-- The world map in a movable window instead of the full screen map, so you can
-- keep moving and fighting while it is open.
--
--   * cursor and player coordinates, landmarks, party members, area names
--   * Continent / Zone menus; the Continent menu also has "Dungeons"
--   * mouse wheel zooms in and out inside a map, drag a zoomed map to move it
--   * dungeon maps (shipped with SimpleMap), found automatically inside
--   * Options panel: size, transparency, coordinates under the minimap, ...
--
-- Uses the same map functions as the stock WorldMapFrame (GetMapInfo,
-- SetMapZoom, ProcessMapClick, UpdateMapHighlight, GetPlayerMapPosition).
--
-- Lua 5.0 rules for this client: no string methods, no # or % operators,
-- no pairs/ipairs/type, ASCII only. A frame's OnLoad runs before its child
-- frames exist, so layout is done on the first OnShow.
--------------------------------------------------------------------------------

SIMPLEMAP_VERSION = "4.67";
SIMPLEMAP_BLACK_TILE = "Interface\\Buttons\\WHITE8X8"; -- tinted black, see SimpleMap_UpdateMap
SIMPLEMAP_MAP_WIDTH = 1002;          -- stock map size at scale 1
SIMPLEMAP_MAP_HEIGHT = 668;
SIMPLEMAP_TILE = 256;
SIMPLEMAP_NUM_TILES = 12;            -- 4 x 3
SIMPLEMAP_NUM_POIS = 16;
SIMPLEMAP_SIDE = 12;                 -- left/right border
SIMPLEMAP_TOP = 72;                  -- title band + menu row
SIMPLEMAP_BOTTOM = 12;
SIMPLEMAP_MIN_SCALE = 0.55;
SIMPLEMAP_MAX_SCALE = 0.8;
SIMPLEMAP_MIN_ALPHA = 0.3;
SIMPLEMAP_MAX_ZOOM = 4;
SIMPLEMAP_MINI_SCALE = 0.32;         -- small map: map width at scale 1 times this
SIMPLEMAP_MINI_TOP = 12;             -- small map: only the border; zone name plate,
SIMPLEMAP_MINI_BOTTOM = 12;          -- buttons and coordinates sit on the map
SIMPLEMAP_MINI_CAVE_ZOOM = 3;        -- small map indoors (caves): zoomed in on you

-- Settings (kept for the session)
SIMPLEMAP_DEFAULT_SCALE = 0.6;
SimpleMap_Scale = SIMPLEMAP_DEFAULT_SCALE;
SIMPLEMAP_DEFAULT_ALPHA = 0.85;
SimpleMap_Alpha = SIMPLEMAP_DEFAULT_ALPHA;
SimpleMap_GoToZone = 1;              -- open on your current zone
SimpleMap_MinimapCoords = nil;       -- coordinates under the minimap (off by default)
SimpleMap_AreaNames = 1;             -- light up area names under the cursor
SimpleMap_ShowBinders = 1;
SimpleMap_ShowTrainers = 1;
SimpleMap_ShowTravel = 1;            -- flight masters, boats, zeppelins
SimpleMap_ShowNPCs = 1;              -- any of the three (kept in step by SimpleMap_NPCSync)
SimpleMap_ShowRares = nil;           -- rare mobs (off by default)
SIMPLEMAP_NUM_NPCS = 200;            -- marker frames in the XML
SIMPLEMAP_NUM_OTHERS = 20;           -- other SimpleQoL users
SimpleMap_OthersTime = 0;

-- State
SimpleMap_Sized = nil;
SimpleMap_CoordTimer = 0;
SimpleMap_Zoom = 1;                  -- 1 = whole map
SimpleMap_ViewLeft = 0;              -- view start, fraction 0..1 of the map
SimpleMap_ViewTop = 0;
SimpleMap_DragStart = nil;
SimpleMap_Dragged = nil;
SimpleMap_LastMap = nil;
SimpleMap_Dungeon = nil;             -- dungeon entry shown, or nil
SimpleMap_DungeonMenu = nil;         -- 1 = Continent menu is on "Dungeons"
SimpleMap_WarnedZone = nil;

-- Dungeon maps, all shipped with SimpleMap (Interface\FrameXML\SimpleMap\Maps);
-- the first six come from AlphaUI's AtlasLoot.
-- { texture, name, { zone names that mean "inside this dungeon" } }
-- In 0.5.3 the zone text inside an instance is an area name of that instance
-- (from the 0.5.3 AreaTable: Deadmines = "Ironclad Cove", Shadowfang Keep =
-- "Shadowfang", Razorfen Kraul = "Razorfen Kraul"; the Stockade, Wailing
-- Caverns and Blackfathom Deeps maps have no area names of their own, so
-- their usual names are listed). Only checked when no world zone matches.
SIMPLEMAP_DUNGEON_PATH = "Interface\\FrameXML\\SimpleMap\\Maps\\";
SIMPLEMAP_DUNGEONS = {
	{ "Deadmines", "The Deadmines", { "ironclad cove", "deadmines", "the deadmines", "deadminesinstance" } },
	{ "TheStockade", "The Stockade", { "the stockade", "stockade", "stockades", "stormwind stockade", "stormwindjail", "stormwindprison", "stormwind jail", "stormwind prison" } },
	{ "WailingCaverns", "Wailing Caverns", { "wailing caverns", "wailingcaverns" } },
	{ "ShadowfangKeep", "Shadowfang Keep", { "shadowfang", "shadowfang keep" } },
	{ "BlackfathomDeeps", "Blackfathom Deeps", { "blackfathom deeps", "blackfathom" } },
	{ "RazorfenKraul", "Razorfen Kraul", { "razorfen kraul", "razorfenkraul" } },
	-- Shipped with SimpleMap (Interface\FrameXML\SimpleMap\Maps). The 0.5.3
	-- AreaTable has no area names for these instances, so their map names
	-- from Map.dbc are listed as well.
	{ "Uldaman", "Uldaman", { "uldaman", "uldaman instance" }, "Interface\\FrameXML\\SimpleMap\\Maps\\" },
	{ "SunkenTemple", "Sunken Temple", { "sunken temple", "the sunken temple", "sunkentemple", "sunkentempleinstance", "temple of atal'hakkar", "the temple of atal'hakkar" }, "Interface\\FrameXML\\SimpleMap\\Maps\\" },
	-- Other maps (5th value = tile folder; kept so they still sort into the
	-- "Other" menu, see the split below). Plains of Snow is map PVPZone02 and
	-- Programmer Isle area 22 in the alpha-core DBC. This client has no real
	-- WorldMap tile art for any of the three, so a 6th value (single shipped
	-- image, same as a dungeon map) is used to draw them instead of tiles.
	{ "PVPZone02", "Plains of Snow", { "plains of snow" }, nil, "Interface\\WorldMap\\PVPZone02\\PVPZone02", SIMPLEMAP_DUNGEON_PATH },
	{ "ProgrammerIsle", "Programmer Isle", { "programmer isle" }, nil, "Interface\\WorldMap\\ProgrammerIsle\\ProgrammerIsle", SIMPLEMAP_DUNGEON_PATH },
	-- Map 17 in the alpha-core DBC; no area/zone text, so it can only be
	-- opened by hand from the Other menu, never auto-detected like the two above.
	{ "Kalidar", "Kalidar", {}, nil, "Interface\\WorldMap\\Kalidar\\Kalidar", SIMPLEMAP_DUNGEON_PATH },
	{ "ScarletMonastery", "Scarlet Monastery", { "scarlet monastery", "the scarlet monastery", "monastery", "monasteryinterior" }, "Interface\\FrameXML\\SimpleMap\\Maps\\" },
};

-- Split once: real dungeons (own menu) vs. "other" tile maps (their own
-- "Other" menu, 5th value present).
SimpleMap_RealDungeons = {};
SimpleMap_OtherMaps = {};
do
	local d;
	for d = 1, getn(SIMPLEMAP_DUNGEONS) do
		if ( SIMPLEMAP_DUNGEONS[d][5] ) then
			tinsert(SimpleMap_OtherMaps, SIMPLEMAP_DUNGEONS[d]);
		else
			tinsert(SimpleMap_RealDungeons, SIMPLEMAP_DUNGEONS[d]);
		end
	end
end

-- The list shown in the Zone menu while on "Dungeons" (1) or "Other" (2).
function SimpleMap_DungeonList()
	if ( SimpleMap_DungeonMenu == 2 ) then
		return SimpleMap_OtherMaps;
	end
	return SimpleMap_RealDungeons;
end


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function SimpleMap_Print(text)
	if ( ChatFrame ) then
		ChatFrame:AddMessage("SimpleMap: "..text, 1.0, 0.82, 0.0);
	end
end

-- Returns argument number n of a variable argument list (Lua 5.0 "arg").
function SimpleMap_Nth(n, ...)
	if ( n and n >= 1 and n <= arg.n ) then
		return arg[n];
	end
	return nil;
end

function SimpleMap_Count(...)
	return arg.n;
end

function SimpleMap_HasPosition()
	local x, y = GetPlayerMapPosition("player");
	return x and not (x == 0 and y == 0);
end

-- Cursor position over the map area as 0..1 fractions, or nil when outside.
-- Same math as the stock WorldMapButton_OnUpdate (it uses GetCenter).
function SimpleMap_CursorFraction()
	local x, y = GetCursorPosition();
	local centerX, centerY = SimpleMapButton:GetCenter();
	local width = SimpleMapButton:GetWidth();
	local height = SimpleMapButton:GetHeight();
	if ( not centerX or width <= 0 or height <= 0 ) then
		return nil;
	end
	local fx = (x - (centerX - width / 2)) / width;
	local fy = (centerY + height / 2 - y) / height;
	if ( fx < 0 or fx > 1 or fy < 0 or fy > 1 ) then
		return nil;
	end
	return fx, fy;
end

-- Cursor position as a fraction of the whole map (zoom included), or nil.
function SimpleMap_CursorMapFraction()
	local vx, vy = SimpleMap_CursorFraction();
	if ( not vx ) then
		return nil, nil;
	end
	return SimpleMap_ViewLeft + vx / SimpleMap_Zoom, SimpleMap_ViewTop + vy / SimpleMap_Zoom;
end

function SimpleMap_CoordText(fx, fy)
	if ( not fx or (fx == 0 and fy == 0) ) then
		return "--";
	end
	return format("%.1f, %.1f", fx * 100, fy * 100);
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
-- Size, transparency and zoom
--------------------------------------------------------------------------------

function SimpleMap_Resize()
	if ( not SimpleMapDetail or not SimpleMapButton or not SimpleMapDungeonTexture ) then
		return;
	end
	SimpleMap_Sized = 1;
	if ( SimpleMap_Fullscreen ) then
		SimpleMap_FullscreenTries = 0;
		SimpleMap_FullscreenPending = 1;
		return;
	end
	local scale = SimpleMap_Scale;
	local top, bottom = SIMPLEMAP_TOP, SIMPLEMAP_BOTTOM;
	if ( SimpleMap_Mini ) then
		scale, top, bottom = SIMPLEMAP_MINI_SCALE, SIMPLEMAP_MINI_TOP, SIMPLEMAP_MINI_BOTTOM;
	end
	local mapWidth = floor(SIMPLEMAP_MAP_WIDTH * scale + 0.5);
	local mapHeight = floor(SIMPLEMAP_MAP_HEIGHT * scale + 0.5);
	SimpleMapFrame:SetWidth(mapWidth + SIMPLEMAP_SIDE * 2);
	SimpleMapFrame:SetHeight(mapHeight + top + bottom);
	SimpleMapDetail:ClearAllPoints();
	SimpleMapDetail:SetPoint("TOPLEFT", "SimpleMapFrame", "TOPLEFT", SIMPLEMAP_SIDE, -top);
	SimpleMap_SizeMapArea(mapWidth, mapHeight);
end

-- Sizes the map area. Width and height may have different scales (fullscreen
-- stretches the map to the screen like the stock map); all positions are
-- fractions of width and height, so they stay right.
function SimpleMap_SizeMapArea(mapWidth, mapHeight)
	SimpleMap_AreaWidth = mapWidth;
	SimpleMap_AreaHeight = mapHeight;
	SimpleMapDetail:SetWidth(mapWidth);
	SimpleMapDetail:SetHeight(mapHeight);
	SimpleMapButton:SetWidth(mapWidth);
	SimpleMapButton:SetHeight(mapHeight);
	SimpleMapDungeonTexture:SetWidth(mapHeight);
	SimpleMapDungeonTexture:SetHeight(mapHeight);
	SimpleMap_LayoutTiles();
	SimpleMap_UpdatePOIs();
end

function SimpleMap_SetScale(value)
	-- In fullscreen the size follows the screen; the window size is kept for later.
	if ( SimpleMap_Fullscreen ) then
		SimpleMap_WindowScale = max(SIMPLEMAP_MIN_SCALE, min(value, SIMPLEMAP_MAX_SCALE));
		return;
	end
	if ( value < SIMPLEMAP_MIN_SCALE ) then
		value = SIMPLEMAP_MIN_SCALE;
	end
	if ( value > SIMPLEMAP_MAX_SCALE ) then
		value = SIMPLEMAP_MAX_SCALE;
	end
	SimpleMap_Scale = value;
	SimpleMap_Resize();
end

function SimpleMap_SetAlpha(value)
	if ( value < SIMPLEMAP_MIN_ALPHA ) then
		value = SIMPLEMAP_MIN_ALPHA;
	end
	if ( value > 1.0 ) then
		value = 1.0;
	end
	SimpleMap_Alpha = value;
	SimpleMapFrame:SetAlpha(value);
	SimpleMap_ApplyDetailAlpha();
end

-- This client does not hand the frame's transparency down to its children,
-- so the map tiles get it themselves (the Options panel dims them while it
-- is open and gives the set value back when it closes).
SimpleMap_Dimmed = nil;
function SimpleMap_ApplyDetailAlpha()
	if ( SimpleMapDetail and not SimpleMap_Dimmed ) then
		SimpleMapDetail:SetAlpha(SimpleMap_Alpha);
	end
end

--------------------------------------------------------------------------------
-- Sliders. The stock 0.5.3 slider stops its knob short of the ends, so these
-- are drawn by the addon: a bar with a knob texture that follows the mouse.
-- Values run 0..1 and are converted to size / transparency.
--------------------------------------------------------------------------------

SIMPLEMAP_SLIDER_PAD = 8;            -- half the knob width: knob stays inside the bar
SimpleMap_ActiveSlider = nil;
SimpleMap_PendingSize = nil;         -- slider value (0..1) shown while dragging Size

function SimpleMap_SliderValue(name)
	if ( name == "SimpleMapSizeSlider" ) then
		return (SimpleMap_Scale - SIMPLEMAP_MIN_SCALE) / (SIMPLEMAP_MAX_SCALE - SIMPLEMAP_MIN_SCALE);
	end
	return (SimpleMap_Alpha - SIMPLEMAP_MIN_ALPHA) / (1.0 - SIMPLEMAP_MIN_ALPHA);
end

-- Puts the knob of a slider at value v (0..1) and shows the percentage.
function SimpleMap_DrawSlider(name, v)
	local bar = getglobal(name);
	local knob = getglobal(name.."Knob");
	local travel = bar:GetWidth() - SIMPLEMAP_SLIDER_PAD * 2;
	knob:ClearAllPoints();
	knob:SetPoint("CENTER", name, "LEFT", SIMPLEMAP_SLIDER_PAD + v * travel, 0);
	local percent;
	if ( name == "SimpleMapSizeSlider" ) then
		percent = (SIMPLEMAP_MIN_SCALE + v * (SIMPLEMAP_MAX_SCALE - SIMPLEMAP_MIN_SCALE)) * 100;
	else
		percent = SimpleMap_Alpha * 100;
	end
	getglobal(name.."Value"):SetText(floor(percent + 0.5).."%");
end

function SimpleMap_UpdateSliders()
	SimpleMap_DrawSlider("SimpleMapSizeSlider", SimpleMap_SliderValue("SimpleMapSizeSlider"));
	SimpleMap_DrawSlider("SimpleMapAlphaSlider", SimpleMap_SliderValue("SimpleMapAlphaSlider"));
end

-- Value under the cursor for a slider bar (0..1).
function SimpleMap_SliderCursorValue(name)
	local bar = getglobal(name);
	local x = GetCursorPosition();
	local centerX = bar:GetCenter();
	local left = centerX - bar:GetWidth() / 2 + SIMPLEMAP_SLIDER_PAD;
	local travel = bar:GetWidth() - SIMPLEMAP_SLIDER_PAD * 2;
	if ( travel <= 0 ) then
		return 0;
	end
	return max(0, min(1, (x - left) / travel));
end

-- Size is only applied when the mouse button is released: resizing moves the
-- Options panel, and a moving slider under the mouse made the size jump.
function SimpleMap_ApplySlider(name, v)
	if ( name == "SimpleMapSizeSlider" ) then
		SimpleMap_PendingSize = v;
	else
		SimpleMap_SetAlpha(SIMPLEMAP_MIN_ALPHA + v * (1.0 - SIMPLEMAP_MIN_ALPHA));
	end
	SimpleMap_DrawSlider(name, v);
end

function SimpleMap_Slider_OnMouseDown(name)
	SimpleMap_ActiveSlider = name;
	SimpleMap_ApplySlider(name, SimpleMap_SliderCursorValue(name));
end

function SimpleMap_Slider_OnMouseUp()
	if ( SimpleMap_ActiveSlider == "SimpleMapSizeSlider" and SimpleMap_PendingSize ) then
		SimpleMap_SetScale(SIMPLEMAP_MIN_SCALE + SimpleMap_PendingSize * (SIMPLEMAP_MAX_SCALE - SIMPLEMAP_MIN_SCALE));
		SimpleMap_DrawSlider("SimpleMapSizeSlider", SimpleMap_SliderValue("SimpleMapSizeSlider"));
	end
	if ( SimpleMap_ActiveSlider ) then
		SimpleMap_SaveSettings();
	end
	SimpleMap_PendingSize = nil;
	SimpleMap_ActiveSlider = nil;
end

-- OnUpdate of the Options panel.
function SimpleMapOptions_OnUpdate()
	if ( SimpleMap_ActiveSlider ) then
		SimpleMap_ApplySlider(SimpleMap_ActiveSlider, SimpleMap_SliderCursorValue(SimpleMap_ActiveSlider));
	end
end

-- Places the 12 tiles for the current zoom and view. Tiles are cut with
-- SetTexCoord so nothing is drawn outside the map area.
SimpleMap_TileFrames = {};
function SimpleMap_LayoutTiles()
	if ( not SimpleMapDetail ) then
		return;
	end
	local width = SimpleMapDetail:GetWidth();
	local height = SimpleMapDetail:GetHeight();
	local view = 1 / SimpleMap_Zoom;
	local left = SimpleMap_ViewLeft;
	local top = SimpleMap_ViewTop;
	local tileW = SIMPLEMAP_TILE / SIMPLEMAP_MAP_WIDTH;
	local tileH = SIMPLEMAP_TILE / SIMPLEMAP_MAP_HEIGHT;
	local i;
	for i = 1, SIMPLEMAP_NUM_TILES do
		local texture = SimpleMap_TileFrames[i];
		if ( not texture ) then
			texture = getglobal("SimpleMapTile"..i);
			SimpleMap_TileFrames[i] = texture;
		end
		local x0 = mod(i - 1, 4) * tileW;
		local y0 = floor((i - 1) / 4) * tileH;
		local ix0 = max(x0, left);
		local ix1 = min(x0 + tileW, left + view);
		local iy0 = max(y0, top);
		local iy1 = min(y0 + tileH, top + view);
		if ( (SimpleMap_Dungeon and not SimpleMap_Dungeon[5]) or ix1 <= ix0 or iy1 <= iy0 ) then
			texture:Hide();
		else
			texture:SetTexCoord((ix0 - x0) / tileW, (ix1 - x0) / tileW, (iy0 - y0) / tileH, (iy1 - y0) / tileH);
			texture:SetWidth((ix1 - ix0) / view * width);
			texture:SetHeight((iy1 - iy0) / view * height);
			texture:ClearAllPoints();
			texture:SetPoint("TOPLEFT", "SimpleMapDetail", "TOPLEFT", (ix0 - left) / view * width, -(iy0 - top) / view * height);
			texture:Show();
		end
	end
end

-- Map fraction -> position in the map area, or nil when outside the view.
function SimpleMap_ToView(fx, fy)
	local vx = (fx - SimpleMap_ViewLeft) * SimpleMap_Zoom;
	local vy = (fy - SimpleMap_ViewTop) * SimpleMap_Zoom;
	if ( vx < 0 or vx > 1 or vy < 0 or vy > 1 ) then
		return nil, nil;
	end
	return vx * SimpleMapButton:GetWidth(), -vy * SimpleMapButton:GetHeight();
end

function SimpleMap_ClampView()
	local view = 1 / SimpleMap_Zoom;
	SimpleMap_ViewLeft = max(0, min(SimpleMap_ViewLeft, 1 - view));
	SimpleMap_ViewTop = max(0, min(SimpleMap_ViewTop, 1 - view));
end

-- Zoom to a level, keeping the map point (fx, fy) at the same place.
function SimpleMap_SetZoom(zoom, fx, fy)
	zoom = max(1, min(zoom, SIMPLEMAP_MAX_ZOOM));
	if ( not fx ) then
		fx = SimpleMap_ViewLeft + 0.5 / SimpleMap_Zoom;
		fy = SimpleMap_ViewTop + 0.5 / SimpleMap_Zoom;
	end
	local vx = (fx - SimpleMap_ViewLeft) * SimpleMap_Zoom;
	local vy = (fy - SimpleMap_ViewTop) * SimpleMap_Zoom;
	SimpleMap_Zoom = zoom;
	SimpleMap_ViewLeft = fx - vx / zoom;
	SimpleMap_ViewTop = fy - vy / zoom;
	SimpleMap_ClampView();
	SimpleMap_LayoutTiles();
	SimpleMap_UpdatePOIs();
	SimpleMap_UpdateZoomText();
end

-- Centers the view on a map point (used for your own position).
function SimpleMap_CenterOn(fx, fy)
	SimpleMap_ViewLeft = fx - 0.5 / SimpleMap_Zoom;
	SimpleMap_ViewTop = fy - 0.5 / SimpleMap_Zoom;
	SimpleMap_ClampView();
	SimpleMap_LayoutTiles();
	SimpleMap_UpdatePOIs();
end

function SimpleMap_UpdateZoomText()
	if ( SimpleMap_Zoom > 1 and not SimpleMap_Mini ) then
		SimpleMapZoomText:SetText(format("Zoom x%.1f", SimpleMap_Zoom));
	else
		SimpleMapZoomText:SetText("");
	end
end

-- Mouse wheel over the map: zoom in/out at the cursor.
function SimpleMap_OnMouseWheel(delta)
	if ( SimpleMap_Dungeon ) then
		return;
	end
	local fx, fy = SimpleMap_CursorMapFraction();
	SimpleMap_SetZoom(SimpleMap_Zoom + delta * 0.5, fx, fy);
end


--------------------------------------------------------------------------------
-- Resize grip in the bottom right corner. The new size comes from how far the
-- mouse moved since the button went down (not from the window position),
-- so the window cannot jump. The map grows from its center, so the width
-- changes twice the mouse movement and the grip stays near the mouse.
--------------------------------------------------------------------------------

SimpleMap_GripStart = nil;

-- Full-screen, normally invisible and mouse-transparent frame shown and
-- enabled only while a drag (window move, zoomed-map pan or resize grip) is
-- running. 0.5.3 only delivers OnMouseUp to whichever frame the cursor is
-- still over at release, so a quick drag ending off the small source frame
-- (or off the window) left it "stuck", panning or resizing on mouse move
-- with no button held. This frame is always under the cursor at release, so
-- its OnMouseUp is the one that is never missed.
function SimpleMap_DragCatcher_Engage()
	SimpleMapDragCatcher:EnableMouse(1);
	SimpleMapDragCatcher:Show();
end

function SimpleMap_DragCatcher_Disengage()
	SimpleMapDragCatcher:Hide();
	SimpleMapDragCatcher:EnableMouse(0);
end

-- Safety net: clears every drag state unconditionally, in case the frame
-- that started the drag never got its own OnMouseUp.
function SimpleMap_DragCatcher_OnMouseUp()
	SimpleMap_DragCatcher_Disengage();
	if ( SimpleMap_Moving ) then
		SimpleMap_MoveStop();
	end
	SimpleMap_DragStart = nil;
	if ( SimpleMap_GripStart ) then
		SimpleMap_Grip_OnMouseUp();
	end
end

function SimpleMap_Grip_OnMouseDown()
	local x = GetCursorPosition();
	SimpleMap_GripStart = { x, SimpleMap_Scale };
	SimpleMap_DragCatcher_Engage();
end

function SimpleMap_Grip_OnMouseUp()
	if ( SimpleMap_GripStart ) then
		SimpleMap_GripStart = nil;
		SimpleMap_SaveSettings();
	end
	SimpleMap_DragCatcher_Disengage();
end

function SimpleMap_Grip_OnUpdate()
	local x = GetCursorPosition();
	local scale = SimpleMap_GripStart[2] + 2 * (x - SimpleMap_GripStart[1]) / SIMPLEMAP_MAP_WIDTH;
	scale = max(SIMPLEMAP_MIN_SCALE, min(scale, SIMPLEMAP_MAX_SCALE));
	if ( SimpleMap_AbsDiff(scale, SimpleMap_Scale) > 0.004 ) then
		SimpleMap_SetScale(scale);
		if ( SimpleMapOptionsFrame:IsVisible() ) then
			SimpleMap_DrawSlider("SimpleMapSizeSlider", SimpleMap_SliderValue("SimpleMapSizeSlider"));
		end
	end
end

function SimpleMap_AbsDiff(a, b)
	if ( a > b ) then
		return a - b;
	end
	return b - a;
end

function SimpleMap_Grip_SetColor(bright)
	local r, g, b = 0.75, 0.6, 0.2;
	if ( bright ) then
		r, g, b = 1.0, 0.85, 0.3;
	end
	local i;
	for i = 1, 4 do
		getglobal("SimpleMapResizeGripStep"..i):SetVertexColor(r, g, b);
	end
end


--------------------------------------------------------------------------------
-- Small map ("-" / "+" button): only the map, its coordinates under it (you
-- bottom left, cursor bottom right) and the close and "+" buttons. It follows
-- your own zone, closes itself in a zone that has no zone map and opens again
-- when you come to one, and zooms in on you indoors (caves). Shift + drag moves
-- the map (also the normal one).
--------------------------------------------------------------------------------

SimpleMap_Mini = nil;
SimpleMap_MiniZone = nil;
SimpleMap_MiniAuto = nil;            -- closed by the small map itself
SimpleMap_MiniCave = nil;
SimpleMap_MiniPlayer = nil;

-- The parts that belong to the full window.
SIMPLEMAP_MINI_HIDE = { "SimpleMapCoords", "SimpleMapOptionsButton", "SimpleMapZoomOutButton", "SimpleMapZoneButton", "SimpleMapFullscreenButton", "SimpleMapContinentDropDown", "SimpleMapZoneDropDown", "SimpleMapResizeGrip", "SimpleMapAtlasButton" };

function SimpleMap_ApplyMini()
	if ( not SimpleMapDetail ) then
		return;
	end
	local i;
	for i = 1, getn(SIMPLEMAP_MINI_HIDE) do
		local frame = getglobal(SIMPLEMAP_MINI_HIDE[i]);
		if ( SimpleMap_Mini ) then
			frame:Hide();
		elseif ( SIMPLEMAP_MINI_HIDE[i] ~= "SimpleMapAtlasButton" ) then
			frame:Show();
		end
	end
	if ( SimpleMap_Mini ) then
		SimpleMapOptionsFrame:Hide();
		SimpleMapCoordsPlayer:Show();
		SimpleMapCoordsCursor:Show();
		SimpleMapMiniHeader:Show();
		SimpleMapDungeonName:Hide();
		SimpleMapAreaLabel:SetText("");
		SimpleMapHighlight:Hide();
	else
		SimpleMapCoordsPlayer:Hide();
		SimpleMapCoordsCursor:Hide();
		SimpleMapMiniHeader:Hide();
		SimpleMapDungeonName:Show();
		-- AtlasLoot's button comes back only if it is wanted
		SimpleMap_AtlasShown = nil;
		SimpleMap_UpdateAtlas();
		-- leaving the cave zoom
		if ( SimpleMap_MiniCave ) then
			SimpleMap_MiniCave = nil;
			SimpleMap_SetZoom(1);
		end
	end
	SimpleMap_UpdateMinButton();
	SimpleMap_UpdateZoomText();
	SimpleMap_Resize();
	SimpleMap_LastFull = 0;
end

-- Zone names that have a zone map (lower case). Read again whenever the
-- cached list turns out empty: built once too early (before the client's
-- own map data was ready) it would otherwise stay wrong for the session,
-- greying "Minimize" in zones that do have a map.
SimpleMap_ZoneMapNames = nil;
function SimpleMap_ZoneHasMap(zone)
	zone = SimpleMap_LowerName(zone);
	if ( zone == "" or SimpleMap_FindDungeon() ) then
		return 1;
	end
	if ( not SimpleMap_ZoneMapNames or not next(SimpleMap_ZoneMapNames) ) then
		local names = {};
		local c, z;
		for c = 1, SimpleMap_Count(GetMapContinents()) do
			local zones = { GetMapZones(c) };
			for z = 1, getn(zones) do
				names[SimpleMap_LowerName(zones[z])] = 1;
			end
		end
		SimpleMap_ZoneMapNames = names;
	end
	return SimpleMap_ZoneMapNames[zone];
end

-- "Minimize" (normal window) is grey where your zone has no zone map;
-- "M" (small map) brings the normal window back.
SimpleMap_MinZone = nil;
function SimpleMap_UpdateMinButton()
	if ( SimpleMap_Mini ) then
		SimpleMapMinButton:SetWidth(22);
		SimpleMapMinButton:SetText("M");
		SimpleMapMinButton:Enable();
		return;
	end
	SimpleMapMinButton:SetWidth(72);
	SimpleMapMinButton:SetText("Minimize");
	SimpleMap_MinZone = GetZoneText();
	if ( SimpleMap_ZoneHasMap(SimpleMap_MinZone) ) then
		SimpleMapMinButton:Enable();
	else
		SimpleMapMinButton:Disable();
	end
end

function SimpleMap_ToggleMini()
	if ( SimpleMap_Fullscreen ) then
		SimpleMap_SetFullscreen(nil);
	end
	if ( SimpleMap_Mini ) then
		SimpleMap_Mini = nil;
		-- Maximize: re-center on screen instead of growing from wherever the
		-- small map was dragged to.
		SimpleMapFrame:ClearAllPoints();
		SimpleMapFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);
	else
		SimpleMap_Mini = 1;
		SimpleMap_MiniZone = nil;
		SimpleMap_MiniAuto = nil;
	end
	SimpleMap_ApplyMini();
	SimpleMap_SaveSettings();
end

function SimpleMap_MinButton_OnEnter()
	SimpleTooltip_SetOwner(this);
	if ( SimpleMap_Mini ) then
		GameTooltip:SetText("Maximize");
	else
		GameTooltip:SetText("Minimize");
		GameTooltip:AddLine("|cffffffffSmall map of your zone. Closes in zones without a zone map.|r");
	end
	GameTooltip:Show();
end

-- Shift + drag moves the window (the title bar moves it as before). 0.5.3
-- has no StartMoving, so the window follows the mouse by hand: GetCenter and
-- GetCursorPosition are in screen units, SetPoint in interface units; the
-- factor comes from the map area, whose size in interface units is known.
SimpleMap_Moving = nil;
SimpleMap_Moved = nil;               -- this click moved the window (no map click)

-- Interface units per screen unit, or nil.
function SimpleMap_UnitFactor()
	local mapX = SimpleMap_ProbeSpan(SimpleMapProbeMapTL, SimpleMapProbeMapBR);
	if ( not mapX or mapX < 10 or not SimpleMap_AreaWidth ) then
		return nil;
	end
	return (SimpleMap_AreaWidth - 2) / mapX;
end

function SimpleMap_MoveStart()
	if ( not IsShiftKeyDown() or IsControlKeyDown() or SimpleMap_Fullscreen ) then
		return;
	end
	local k = SimpleMap_UnitFactor();
	local fx, fy = SimpleMapFrame:GetCenter();
	local x1, y1 = SimpleMapProbeScreenTL:GetCenter();
	local x2, y2 = SimpleMapProbeScreenBR:GetCenter();
	if ( not k or not fx or not x1 or not x2 ) then
		return;
	end
	local cx, cy = GetCursorPosition();
	-- window center from the screen center, in interface units
	SimpleMap_Moving = { cx, cy, (fx - (x1 + x2) / 2) * k, (fy - (y1 + y2) / 2) * k, k };
	SimpleMap_Moved = 1;
	SimpleMap_DragStart = nil;
	SimpleMap_DragCatcher_Engage();
end

function SimpleMap_MoveUpdate()
	local m = SimpleMap_Moving;
	local cx, cy = GetCursorPosition();
	local x = m[3] + (cx - m[1]) * m[5];
	local y = m[4] + (cy - m[2]) * m[5];
	if ( x ~= m[6] or y ~= m[7] ) then
		m[6], m[7] = x, y;
		-- No ClearAllPoints here: the frame only ever has this one point, and
		-- clearing it every frame doubled the anchor-reflow cost during drag.
		SimpleMapFrame:SetPoint("CENTER", "UIParent", "CENTER", x, y);
	end
end

function SimpleMap_MoveStop()
	SimpleMap_Moving = nil;
	SimpleMap_DragCatcher_Disengage();
end

-- Called every 0.2 s. Mini mode: follow the zone, close / open with it, zoom
-- in indoors.
function SimpleMap_MiniUpdate()
	local zone = GetZoneText();
	if ( zone ~= SimpleMap_MiniZone ) then
		SimpleMap_MiniZone = zone;
		if ( SimpleMapFrame:IsVisible() ) then
			SimpleMap_ShowCurrentZone(1);
			if ( not SimpleMap_Dungeon and GetCurrentMapZone() == 0 ) then
				SimpleMap_MiniAuto = 1;
				SimpleMapFrame:Hide();
			end
		elseif ( SimpleMap_MiniAuto ) then
			if ( SimpleMap_FindWorldZone() and GetCurrentMapZone() ~= 0 ) then
				SimpleMap_MiniAuto = nil;
				SimpleMapFrame:Show();
			end
		end
		return;
	end
	if ( not SimpleMapFrame:IsVisible() or SimpleMap_Dungeon or GetCurrentMapZone() == 0 ) then
		return;
	end
	local inside = SimpleMap_MinimapIsInside();
	if ( inside ) then
		local fx, fy = GetPlayerMapPosition("player");
		if ( fx and not (fx == 0 and fy == 0) ) then
			if ( not SimpleMap_MiniCave ) then
				SimpleMap_MiniCave = 1;
				SimpleMap_SetZoom(SIMPLEMAP_MINI_CAVE_ZOOM, fx, fy);
				SimpleMap_MiniPlayer = nil;
			end
			if ( SimpleMap_MiniPlayer ~= fx + fy * 2 ) then
				SimpleMap_MiniPlayer = fx + fy * 2;
				SimpleMap_CenterOn(fx, fy);
			end
		end
	elseif ( SimpleMap_MiniCave ) then
		SimpleMap_MiniCave = nil;
		SimpleMap_SetZoom(1);
	end
end


--------------------------------------------------------------------------------
-- Fullscreen: the map fills the screen (centered), the world behind it is
-- dimmed. Turning it off restores the window size, centered on the screen.
--------------------------------------------------------------------------------

SimpleMap_Fullscreen = nil;
SimpleMap_WindowScale = nil;

-- Fullscreen: 0.5.3 reports frame sizes and positions (GetWidth, GetCenter)
-- in another scale than SetWidth/SetPoint use, and GetWidth keeps the old
-- size after two-point anchoring. So the screen is measured instead: two tiny
-- probe frames sit in the screen corners and two in the map area corners.
-- Both pairs are read with GetCenter (same scale), and the map area pair has
-- a known size in SetWidth units, which gives the conversion factor.
SimpleMap_FullscreenPending = nil;
SimpleMap_AreaWidth = nil;
SimpleMap_AreaHeight = nil;

-- Distance between the centers of two probes, or nil if not readable.
function SimpleMap_ProbeSpan(first, second)
	local x1, y1 = first:GetCenter();
	local x2, y2 = second:GetCenter();
	if ( not x1 or not y1 or not x2 or not y2 ) then
		return nil, nil;
	end
	local dx = x2 - x1;
	local dy = y2 - y1;
	if ( dx < 0 ) then
		dx = -dx;
	end
	if ( dy < 0 ) then
		dy = -dy;
	end
	return dx, dy;
end

-- Returns the screen size in SetWidth units, or nil.
function SimpleMap_MeasureScreen()
	if ( not SimpleMap_AreaWidth or not SimpleMap_AreaHeight ) then
		return nil, nil;
	end
	local screenX, screenY = SimpleMap_ProbeSpan(SimpleMapProbeScreenTL, SimpleMapProbeScreenBR);
	local mapX, mapY = SimpleMap_ProbeSpan(SimpleMapProbeMapTL, SimpleMapProbeMapBR);
	if ( not screenX or not mapX or mapX < 10 or mapY < 10 ) then
		return nil, nil;
	end
	-- The probes are 2 units wide; centers sit 1 unit inside each corner.
	local factorX = (SimpleMap_AreaWidth - 2) / mapX;
	local factorY = (SimpleMap_AreaHeight - 2) / mapY;
	local width = floor(screenX * factorX + 2.5);
	local height = floor(screenY * factorY + 2.5);
	if ( width < 400 or height < 300 ) then
		return nil, nil;
	end
	return width, height;
end

SimpleMap_FullscreenTries = 0;

function SimpleMap_ApplyFullscreenSize()
	local width, height = SimpleMap_MeasureScreen();
	if ( not width ) then
		-- Give the layout a few frames; then fall back to the window.
		SimpleMap_FullscreenTries = SimpleMap_FullscreenTries + 1;
		if ( SimpleMap_FullscreenTries > 10 ) then
			SimpleMap_FullscreenPending = nil;
			SimpleMap_Print("Fullscreen could not measure the screen.");
			SimpleMap_SetFullscreen(nil);
		end
		return;
	end
	SimpleMap_FullscreenPending = nil;
	SimpleMapFrame:ClearAllPoints();
	SimpleMapFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);
	SimpleMapFrame:SetWidth(width);
	SimpleMapFrame:SetHeight(height);
	SimpleMap_SizeMapArea(width - SIMPLEMAP_SIDE * 2, height - SIMPLEMAP_TOP - SIMPLEMAP_BOTTOM);
end

function SimpleMap_SetFullscreen(on)
	if ( on and not SimpleMap_Fullscreen ) then
		SimpleMap_WindowScale = SimpleMap_Scale;
		SimpleMap_Fullscreen = 1;
		SimpleMapResizeGrip:Hide();
		SimpleMapDimFrame:Show();
		SimpleMapFullscreenButton:SetText("Window");
	elseif ( not on and SimpleMap_Fullscreen ) then
		SimpleMap_Fullscreen = nil;
		SimpleMap_Scale = SimpleMap_WindowScale or SIMPLEMAP_DEFAULT_SCALE;
		SimpleMapResizeGrip:Show();
		SimpleMapDimFrame:Hide();
		SimpleMapFullscreenButton:SetText("Fullscreen");
	else
		return;
	end
	SimpleMap_GripStart = nil;
	if ( SimpleMap_Fullscreen ) then
		-- Measured on the next frame, while the map area still has a known size.
		SimpleMap_FullscreenTries = 0;
		SimpleMap_FullscreenPending = 1;
	else
		SimpleMap_FullscreenPending = nil;
		SimpleMapFrame:ClearAllPoints();
		SimpleMapFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);
		SimpleMap_Resize();
	end
	if ( SimpleMapOptionsFrame:IsVisible() ) then
		SimpleMapOptions_Update();
	end
end

function SimpleMap_ToggleFullscreen()
	if ( SimpleMap_Mini ) then
		return;
	end
	SimpleMap_SetFullscreen(not SimpleMap_Fullscreen);
end

function SimpleMap_FullscreenButton_OnEnter()
	SimpleTooltip_SetOwner(this);
	if ( SimpleMap_Fullscreen ) then
		GameTooltip:SetText("Back to the window");
	else
		GameTooltip:SetText("Fullscreen map");
	end
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- Map content
--------------------------------------------------------------------------------

-- WORLD_MAP_UPDATE is not handled at once but on the next frame, and only
-- when the selected map really changed. Other addons switch the selected map
-- for a moment and back (AlphaUI's target distance does it every second while
-- you have a target); redrawing for each of those switches swapped all tiles
-- twice a second, reset the zoom and could leave the symbols of the probed
-- continent on the map you are looking at.
SimpleMap_MapDirty = nil;
SimpleMap_ShownKey = nil;            -- map, continent, zone and dungeon last drawn
SimpleMap_ShownMap = nil;            -- map file whose symbols are shown (nil: none)

function SimpleMap_MapKey()
	local key = (GetMapInfo() or "World").."/"..GetCurrentMapContinent().."/"..GetCurrentMapZone().."/"..(SimpleMap_DungeonMenu or 0);
	if ( SimpleMap_Dungeon ) then
		key = key.."/"..SimpleMap_Dungeon[1];
	end
	return key;
end

function SimpleMap_CheckMap()
	SimpleMap_MapDirty = nil;
	if ( SimpleMap_MapKey() ~= SimpleMap_ShownKey ) then
		SimpleMap_UpdateMap();
	end
end

-- The Zone menu is filled again only when its list changes (continent, or
-- Dungeons / Other).
SimpleMap_ZoneFilledFor = nil;
function SimpleMap_RefillZones()
	local key = GetCurrentMapContinent();
	if ( SimpleMap_DungeonMenu ) then
		key = "D"..SimpleMap_DungeonMenu;
	end
	if ( key == SimpleMap_ZoneFilledFor ) then
		return;
	end
	SimpleMap_ZoneFilledFor = key;
	-- The drop-down functions work on "this": fill, then put it back.
	local frame = this;
	this = SimpleMapZoneDropDown;
	SimpleMap_ZoneDropDown_Fill();
	this = frame;
end

-- Name of the map shown (small map's name plate).
function SimpleMap_ShownName()
	if ( SimpleMap_Dungeon ) then
		return SimpleMap_Dungeon[2];
	end
	local c, z = GetCurrentMapContinent(), GetCurrentMapZone();
	if ( c > 0 and z > 0 ) then
		return SimpleMap_Nth(z, GetMapZones(c)) or "";
	elseif ( c > 0 ) then
		return SimpleMap_Nth(c, GetMapContinents()) or "";
	end
	return "";
end

function SimpleMap_UpdateMap()
	SimpleMap_MapDirty = nil;
	SimpleMap_ShownKey = SimpleMap_MapKey();
	local mapFileName = GetMapInfo();
	local i;
	-- Symbols belong to a zone or continent map only (never the world view or
	-- a dungeon / "other" map), and always to the map whose tiles are drawn.
	if ( SimpleMap_Dungeon or GetCurrentMapContinent() == 0 ) then
		SimpleMap_ShownMap = nil;
	else
		SimpleMap_ShownMap = mapFileName;
	end
	if ( SimpleMap_Dungeon and SimpleMap_Dungeon[6] ) then
		-- an "other" map with real shipped art: single image, same as a dungeon.
		SimpleMapDungeonTexture:SetTexture(SimpleMap_Dungeon[6]..SimpleMap_Dungeon[1]);
		SimpleMapDungeonTexture:Show();
		SimpleMapDungeonName:SetText(SimpleMap_Dungeon[2]);
	elseif ( SimpleMap_Dungeon and SimpleMap_Dungeon[5] ) then
		-- an "other" map: tiles like a zone map (no shipped art)
		SimpleMapDungeonTexture:Hide();
		SimpleMapDungeonName:SetText(SimpleMap_Dungeon[2]);
		mapFileName = SimpleMap_Dungeon[1];
	elseif ( SimpleMap_Dungeon ) then
		SimpleMapDungeonTexture:SetTexture((SimpleMap_Dungeon[4] or SIMPLEMAP_DUNGEON_PATH)..SimpleMap_Dungeon[1]);
		SimpleMapDungeonTexture:Show();
		SimpleMapDungeonName:SetText(SimpleMap_Dungeon[2]);
	else
		SimpleMapDungeonTexture:Hide();
		SimpleMapDungeonName:SetText("");
	end
	if ( not mapFileName ) then
		mapFileName = "World";
	end
	for i = 1, SIMPLEMAP_NUM_TILES do
		local tile = getglobal("SimpleMapTile"..i);
		if ( SimpleMap_Dungeon and SimpleMap_Dungeon[6] ) then
			-- Covered by the single image above; black behind it, never the
			-- engine's bright green "missing texture" look at the edges.
			tile:SetTexture(SIMPLEMAP_BLACK_TILE);
			tile:SetVertexColor(0, 0, 0, 1);
		elseif ( SimpleMap_Dungeon and SimpleMap_Dungeon[5] ) then
			tile:SetVertexColor(1, 1, 1, 1);
			tile:SetTexture(SimpleMap_Dungeon[5]..i);
		else
			tile:SetVertexColor(1, 1, 1, 1);
			tile:SetTexture("Interface\\WorldMap\\"..mapFileName.."\\"..mapFileName..i);
		end
	end
	SimpleMapHighlight:Hide();
	if ( GetCurrentMapContinent() == 0 and not SimpleMap_Dungeon ) then
		SimpleMapZoomOutButton:Disable();
	else
		SimpleMapZoomOutButton:Enable();
	end
	-- A new map starts unzoomed.
	if ( SimpleMap_LastMap ~= mapFileName ) then
		SimpleMap_LastMap = mapFileName;
		SimpleMap_Zoom = 1;
		SimpleMap_ViewLeft = 0;
		SimpleMap_ViewTop = 0;
		SimpleMap_UpdateZoomText();
	end
	SimpleMap_LayoutTiles();
	SimpleMap_UpdatePOIs();
	SimpleMap_RefillZones();
	SimpleMap_UpdateDropDowns();
	SimpleMapMiniHeaderText:SetText(SimpleMap_ShownName());
	SimpleMap_LastFull = 0;
end

SimpleMap_POIFrames = {};
SimpleMap_POITextures = {};
function SimpleMap_UpdatePOIs()
	if ( not SimpleMapButton ) then
		return;
	end
	local numPOIs = GetNumMapLandmarks();
	local i;
	-- Landmarks come from the selected map: none on the world view (their
	-- places would be continent fractions, in the ocean), in dungeons, or when
	-- the selected map is not the one drawn.
	if ( not SimpleMap_ShownMap or GetMapInfo() ~= SimpleMap_ShownMap ) then
		numPOIs = 0;
	end
	for i = 1, SIMPLEMAP_NUM_POIS do
		local poi = SimpleMap_POIFrames[i];
		if ( not poi ) then
			poi = getglobal("SimpleMapPOI"..i);
			SimpleMap_POIFrames[i] = poi;
			SimpleMap_POITextures[i] = getglobal("SimpleMapPOI"..i.."Texture");
		end
		local x, y;
		if ( i <= numPOIs ) then
			local name, textureIndex, fx, fy = GetMapLandmarkInfo(i);
			x, y = SimpleMap_ToView(fx, fy);
			if ( x ) then
				local x1, x2, y1, y2 = SimpleMap_POICoords(textureIndex);
				SimpleMap_POITextures[i]:SetTexCoord(x1, x2, y1, y2);
				poi:ClearAllPoints();
				poi:SetPoint("CENTER", "SimpleMapButton", "TOPLEFT", x, y);
				poi.name = name;
			end
		end
		if ( x ) then
			poi:Show();
		else
			poi:Hide();
		end
	end
	SimpleMap_UpdateNPCs();
end

-- Map info from SimpleMap_NPCs.lua: flight paths, boats, zeppelins, dungeon
-- entrances, hunter pet trainers, class trainers and binders on zone and
-- continent maps (the continents also cover zones that have no map of their own).
SIMPLEMAP_MEDIA = "Interface\\FrameXML\\SimpleMap\\Media\\";
SIMPLEMAP_NPC_ICONS = { F = "Flight", B = "Boat", Z = "Zeppelin", N = "Binder", P = "PetTrainer", D = "Dungeon", R = "Rare" };

-- The symbols of a map: travel / trainers and rare mobs, as switched on.
-- Both together are joined once per map and kept.
SimpleMap_ListCache = {};
function SimpleMap_NPCList(map)
	if ( not map ) then
		return nil;
	end
	local npcs = SimpleMap_ShowNPCs and SIMPLEMAP_NPCS and SIMPLEMAP_NPCS[map];
	local rares = SimpleMap_ShowRares and SIMPLEMAP_RARES and SIMPLEMAP_RARES[map];
	if ( not rares ) then
		return npcs;
	end
	if ( not npcs ) then
		return rares;
	end
	local list = SimpleMap_ListCache[map];
	if ( not list ) then
		list = {};
		local i;
		for i = 1, getn(npcs) do
			tinsert(list, npcs[i]);
		end
		for i = 1, getn(rares) do
			tinsert(list, rares[i]);
		end
		SimpleMap_ListCache[map] = list;
	end
	return list;
end
-- Class trainers use the class shields in ClassShields.blp (4 x 4 grid of
-- 32 px cells): column, row.
SIMPLEMAP_CLASS_CELLS = {
	[1] = { 0, 0 }, [2] = { 1, 0 }, [3] = { 2, 0 }, [4] = { 3, 0 }, [5] = { 0, 1 },
	[7] = { 1, 1 }, [8] = { 2, 1 }, [9] = { 3, 1 }, [11] = { 0, 2 },
};

-- Class trainers: only for the class you play.
SIMPLEMAP_CLASS_IDS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 };

function SimpleMap_PlayerClassId()
	local name = UnitClass and UnitClass("player");
	return name and SIMPLEMAP_CLASS_IDS[strupper(name)];
end

-- "A" for Alliance, "H" for Horde (0.5.3 has no UnitFactionGroup).
SIMPLEMAP_ALLIANCE_RACES = { HUMAN = 1, DWARF = 1, GNOME = 1, ["NIGHT ELF"] = 1, NIGHTELF = 1 };
function SimpleMap_PlayerSide()
	local race = UnitRace and UnitRace("player");
	if ( race and SIMPLEMAP_ALLIANCE_RACES[strupper(race)] ) then
		return "A";
	end
	return "H";
end

-- Which symbols you see: binders and dungeons always; trainers, pet trainers
-- (hunters only) and flight paths of your own faction; your own class
-- trainers only; boats for Alliance, zeppelins for Horde.
function SimpleMap_NPCSync()
	if ( SimpleMap_ShowBinders or SimpleMap_ShowTrainers or SimpleMap_ShowTravel ) then
		SimpleMap_ShowNPCs = 1;
	else
		SimpleMap_ShowNPCs = nil;
	end
end

function SimpleMap_NPCVisible(entry, myClass, side)
	local kind = entry[1];
	if ( kind == "N" and not SimpleMap_ShowBinders ) then
		return nil;
	end
	if ( (kind == "C" or kind == "P") and not SimpleMap_ShowTrainers ) then
		return nil;
	end
	if ( (kind == "F" or kind == "B" or kind == "Z") and not SimpleMap_ShowTravel ) then
		return nil;
	end
	if ( kind == "C" and entry[6] ~= myClass ) then
		return nil;
	end
	if ( kind == "P" and myClass ~= 3 ) then
		return nil;
	end
	if ( (kind == "C" or kind == "P" or kind == "F") and entry[7] and entry[7] ~= "" and entry[7] ~= side ) then
		return nil;
	end
	if ( (kind == "B" and side ~= "A") or (kind == "Z" and side ~= "H") ) then
		return nil;
	end
	return 1;
end

function SimpleMap_SetNPCIcon(icon, entry)
	local cell = entry[1] == "C" and SIMPLEMAP_CLASS_CELLS[entry[6]];
	if ( cell ) then
		icon:SetTexture(SIMPLEMAP_MEDIA.."ClassShields");
		icon:SetTexCoord(cell[1] * 0.25, cell[1] * 0.25 + 0.25, cell[2] * 0.25, cell[2] * 0.25 + 0.25);
	else
		icon:SetTexture(SIMPLEMAP_MEDIA..(SIMPLEMAP_NPC_ICONS[entry[1]] or "Binder"));
		icon:SetTexCoord(0, 1, 0, 1);
	end
end

SimpleMap_NPCFrames = {};
SimpleMap_NPCIconFrames = {};
SimpleMap_NPCShownCount = SIMPLEMAP_NUM_NPCS;

function SimpleMap_UpdateNPCs()
	local myClass = SimpleMap_PlayerClassId();
	local side = SimpleMap_PlayerSide();
	local list = SimpleMap_NPCList(SimpleMap_ShownMap);
	local shown = 0;
	local i;
	if ( list ) then
		for i = 1, getn(list) do
			if ( shown >= SIMPLEMAP_NUM_NPCS ) then
				break
			end
			local entry = list[i];
			local x, y = nil, nil;
			if ( SimpleMap_NPCVisible(entry, myClass, side) ) then
				x, y = SimpleMap_ToView(entry[2], entry[3]);
			end
			if ( x ) then
				shown = shown + 1;
				local marker = SimpleMap_NPCFrames[shown];
				if ( not marker ) then
					marker = getglobal("SimpleMapNPC"..shown);
					SimpleMap_NPCFrames[shown] = marker;
					SimpleMap_NPCIconFrames[shown] = getglobal("SimpleMapNPC"..shown.."Icon");
				end
				-- Texture only when the marker shows another entry than before
				if ( marker.entry ~= entry ) then
					SimpleMap_SetNPCIcon(SimpleMap_NPCIconFrames[shown], entry);
					marker.entry = entry;
				end
				marker:ClearAllPoints();
				marker:SetPoint("CENTER", "SimpleMapButton", "TOPLEFT", x, y);
				marker:Show();
			end
		end
	end
	-- Hide only the ones that were shown before. Cache both frame and icon
	-- here too (not just frame) - otherwise a slot hidden this way and later
	-- reused by SimpleMap_UpdateNPCs skips its "not marker" branch and never
	-- gets an icon frame, crashing SimpleMap_SetNPCIcon on a nil icon.
	for i = shown + 1, SimpleMap_NPCShownCount do
		local marker = SimpleMap_NPCFrames[i];
		if ( not marker ) then
			marker = getglobal("SimpleMapNPC"..i);
			SimpleMap_NPCFrames[i] = marker;
			SimpleMap_NPCIconFrames[i] = getglobal("SimpleMapNPC"..i.."Icon");
		end
		marker:Hide();
	end
	SimpleMap_NPCShownCount = shown;
end

function SimpleMap_NPC_OnEnter()
	local entry = this.entry;
	if ( not entry ) then
		return;
	end
	SimpleTooltip_SetOwner(this);
	if ( entry[1] == "R" ) then
		GameTooltip:SetText(entry[5], 0.85, 0.85, 0.95);
		GameTooltip:AddLine("|cffffffff"..entry[4].."|r");
		if ( entry[8] and entry[8] ~= "" ) then
			GameTooltip:AddLine("|cffffffffRespawn: "..entry[8].."|r");
		end
	else
		GameTooltip:SetText(entry[4]);
		GameTooltip:AddLine("|cffffffff"..entry[5].."|r");
		if ( entry[1] == "N" ) then
			GameTooltip:AddLine("Current binder location: |cffffffff"..(SimpleMap_BindZone or "unknown").."|r");
		end
		-- Dungeons: their rare mobs while rare mobs are switched on.
		local rares = entry[1] == "D" and SimpleMap_ShowRares and SIMPLEMAP_DUNGEON_RARES and SIMPLEMAP_DUNGEON_RARES[entry[5]];
		if ( rares ) then
			GameTooltip:AddLine("Rare mobs:");
			local i;
			for i = 1, getn(rares) do
				GameTooltip:AddLine("|cffffffff"..rares[i].."|r");
			end
		end
	end
	GameTooltip:Show();
end

-- The same symbols on the minimap. The map must show the zone you are in
-- (kept so by SimpleMap_MinimapCoords_OnEvent while no map window is open).
SIMPLEMAP_ZONE_YARDS = {
	Durotar = { 6400, 4267 }, Mulgore = { 6400, 4267 }, Barrens = { 12800, 8533 }, Kalimdor = { 33600, 22400 }, Azeroth = { 30400, 20267 }, Alterac = { 3200, 2133 }, Arathi = { 4800, 3200 }, Badlands = { 4800, 3200 }, Blackrock = { 3200, 2133 }, BlastedLands = { 4800, 3200 }, Tirisfal = { 4800, 3200 }, Silverpine = { 4800, 3200 }, WesternPlaguelands = { 4800, 3200 }, EasternPlaguelands = { 6400, 4267 }, Hilsbrad = { 4800, 3200 }, Hinterlands = { 4800, 3200 }, DunMorogh = { 4800, 3200 }, SearingGorge = { 4800, 3200 }, BurningSteppes = { 3200, 2133 }, Elwynn = { 4800, 3200 }, DarrowmereLake = { 3200, 2133 }, DeadwindPass = { 3200, 2133 }, Duskwood = { 3200, 2133 }, LochModan = { 4800, 3200 }, Redridge = { 3200, 2133 }, Stranglethorn = { 6400, 4267 }, SwampOfSorrows = { 3200, 2133 }, Westfall = { 4800, 3200 }, Wetlands = { 4800, 3200 },
};
-- Minimap diameter in yards per zoom level (outdoor values of the later
-- clients; to be confirmed in 0.5.3).
SIMPLEMAP_MINIMAP_YARDS = { 466.67, 400, 333.33, 266.67, 200, 133.33 };

-- Minimap diameter in yards (read from the 0.5.3 client code): outdoors
-- 466.67, 400, 333.33, 266.67, 200, 133.33 and indoors 300, 240, 180, 120,
-- 80, 50 for zoom 0..5. Indoors is found with the two zoom settings:
-- the minimap shows the "inside" zoom when you are indoors (cities and
-- buildings count as indoors).
SIMPLEMAP_MINIMAP_INDOOR = { 300, 240, 180, 120, 80, 50 };
SimpleMap_MinimapInside = nil;
SimpleMap_MinimapInsideTime = -10;

function SimpleMap_MinimapIsInside()
	if ( GetTime() - SimpleMap_MinimapInsideTime < 1 ) then
		return SimpleMap_MinimapInside;
	end
	SimpleMap_MinimapInsideTime = GetTime();
	if ( not Minimap or not Minimap.GetZoom ) then
		return nil;
	end
	local zoom = Minimap:GetZoom();
	local outZoom = GetCVar and tonumber(GetCVar("minimapZoom"));
	local inZoom = GetCVar and tonumber(GetCVar("minimapInsideZoom"));
	local inside = nil;
	if ( outZoom and inZoom ) then
		if ( outZoom ~= inZoom ) then
			inside = (zoom == inZoom);
		else
			-- Both settings equal: change the zoom for a moment and see which
			-- of the two follows.
			local other = zoom;
			if ( zoom < 2 ) then
				other = zoom + 1;
			else
				other = zoom - 1;
			end
			Minimap:SetZoom(other);
			inside = (tonumber(GetCVar("minimapZoom")) ~= Minimap:GetZoom());
			Minimap:SetZoom(zoom);
		end
	end
	SimpleMap_MinimapInside = inside;
	return inside;
end

function SimpleMap_MinimapYards()
	local zoom = 0;
	if ( Minimap.GetZoom ) then
		zoom = Minimap:GetZoom();
	end
	if ( SimpleMap_MinimapIsInside() ) then
		return SIMPLEMAP_MINIMAP_INDOOR[zoom + 1] or SIMPLEMAP_MINIMAP_INDOOR[1];
	end
	return SIMPLEMAP_MINIMAP_YARDS[zoom + 1] or SIMPLEMAP_MINIMAP_YARDS[1];
end
SIMPLEMAP_NUM_MINI = 30;
-- The marker frames and their icons, looked up once when first needed (the
-- frames are made by the XML after this file is read).
SimpleMap_MiniFrames = nil;
SimpleMap_MiniIcons = nil;
SimpleMap_MiniShown = SIMPLEMAP_NUM_MINI;     -- unknown at the start: the first pass hides all
function SimpleMap_MiniLookup()
	local frames, icons = {}, {};
	local n;
	for n = 1, SIMPLEMAP_NUM_MINI do
		frames[n] = getglobal("SimpleMapMini"..n);
		icons[n] = getglobal("SimpleMapMini"..n.."Icon");
	end
	SimpleMap_MiniFrames, SimpleMap_MiniIcons = frames, icons;
end

function SimpleMap_UpdateMinimapNPCs()
	local shown = 0;
	if ( not SimpleMap_MiniFrames ) then
		SimpleMap_MiniLookup();
	end
	local x, y = GetPlayerMapPosition("player");
	local map = GetMapInfo();
	local list = SimpleMap_NPCList(map);
	local size = map and SIMPLEMAP_ZONE_YARDS[map];
	if ( (SimpleMap_ShowNPCs or SimpleMap_ShowRares) and (not x or (x == 0 and y == 0)) ) then
		return;                      -- not your zone on the map: keep what is shown
	end
	-- Nothing changed (standing still, same zoom): the markers stay.
	local zoomNow = 0;
	if ( Minimap and Minimap.GetZoom ) then
		zoomNow = Minimap:GetZoom();
	end
	local flags = (SimpleMap_ShowNPCs and 1 or 0) + (SimpleMap_ShowRares and 2 or 0) + (SimpleMap_MinimapIsInside() and 4 or 0);
	if ( x == SimpleMap_MiniX and y == SimpleMap_MiniY and map == SimpleMap_MiniMap and zoomNow == SimpleMap_MiniZoom and flags == SimpleMap_MiniFlags ) then
		return;
	end
	SimpleMap_MiniX, SimpleMap_MiniY, SimpleMap_MiniMap, SimpleMap_MiniZoom, SimpleMap_MiniFlags = x, y, map, zoomNow, flags;
	if ( list and size and Minimap ) then
		local myClass = SimpleMap_PlayerClassId();
		local side = SimpleMap_PlayerSide();
		local yards = SimpleMap_MinimapYards();
		local radius = Minimap:GetWidth() / 2;
		local scale = Minimap:GetWidth() / yards;
		local i;
		for i = 1, getn(list) do
			local entry = list[i];
			if ( shown < SIMPLEMAP_NUM_MINI and SimpleMap_NPCVisible(entry, myClass, side) ) then
				local dx = (entry[2] - x) * size[1] * scale;
				local dy = (entry[3] - y) * size[2] * scale;
				if ( dx * dx + dy * dy < (radius - 5) * (radius - 5) ) then
					shown = shown + 1;
					local marker = SimpleMap_MiniFrames[shown];
					SimpleMap_SetNPCIcon(SimpleMap_MiniIcons[shown], entry);
					marker.entry = entry;
					marker:ClearAllPoints();
					marker:SetPoint("CENTER", "Minimap", "CENTER", dx, -dy);
					marker:Show();
				end
			end
		end
	end
	-- Only the markers that were shown before are hidden (before, all 30 were
	-- looked up and hidden every time you moved).
	local i;
	for i = shown + 1, SimpleMap_MiniShown do
		SimpleMap_MiniFrames[i]:Hide();
	end
	SimpleMap_MiniShown = shown;
end

-- Other players with SimpleQoL's "Share position" (SimpleQoL_Players), when
-- they are on the map shown.
-- Positions from one map on another: zone and continent maps through world
-- yards (WorldMapArea bounds: left, right, top, bottom tile, map id; they are
-- inclusive tile indices), the world view (both continents) through where
-- each continent is drawn on it (measured in game: offset x, offset y, scale).
SIMPLEMAP_MAP_BOUNDS = {
	Durotar = { 35, 46, 28, 35, 1 }, Mulgore = { 27, 38, 32, 39, 1 }, Barrens = { 25, 48, 29, 44, 1 }, Kalimdor = { 1, 63, 10, 51, 1 },
	Azeroth = { 5, 61, 23, 60, 0 }, Alterac = { 30, 35, 29, 32, 0 }, Arathi = { 33, 41, 32, 37, 0 }, Badlands = { 35, 43, 42, 47, 0 },
	Blackrock = { 31, 36, 44, 47, 0 }, BlastedLands = { 33, 41, 51, 56, 0 }, Tirisfal = { 27, 35, 25, 30, 0 }, Silverpine = { 25, 33, 29, 34, 0 },
	WesternPlaguelands = { 31, 39, 25, 30, 0 }, EasternPlaguelands = { 34, 45, 23, 30, 0 }, Hilsbrad = { 29, 37, 31, 36, 0 }, Hinterlands = { 34, 42, 29, 34, 0 },
	DunMorogh = { 29, 37, 39, 44, 0 }, SearingGorge = { 29, 37, 42, 47, 0 }, BurningSteppes = { 32, 37, 45, 48, 0 }, Elwynn = { 28, 36, 46, 51, 0 },
	DarrowmereLake = { 34, 39, 28, 31, 0 }, DeadwindPass = { 33, 38, 50, 53, 0 }, Duskwood = { 30, 35, 50, 53, 0 }, LochModan = { 35, 43, 39, 44, 0 },
	Redridge = { 35, 40, 48, 51, 0 }, Stranglethorn = { 27, 38, 53, 60, 0 }, SwampOfSorrows = { 36, 41, 50, 53, 0 }, Westfall = { 25, 33, 48, 53, 0 },
	Wetlands = { 33, 41, 36, 41, 0 },
};
SIMPLEMAP_TILE_YARDS = 1600 / 3;
SIMPLEMAP_WORLD_PLACE = { [0] = { 0.2914168, 0.0883229, 0.910180 }, [1] = { -0.3373254, 0.0134731, 1.005988 } };
SIMPLEMAP_CONTINENT_FILES = { [0] = "Azeroth", [1] = "Kalimdor" };

-- fx, fy on map "from" -> fraction on map "to" (or on the world view when
-- toWorld is set); nil when it is not on that map (unless outside is set).
function SimpleMap_ConvertPos(from, fx, fy, to, toWorld, outside)
	if ( not toWorld and from == to ) then
		return fx, fy;
	end
	local a = SIMPLEMAP_MAP_BOUNDS[from or ""];
	if ( not a ) then
		return nil;
	end
	local t = SIMPLEMAP_TILE_YARDS;
	local worldY = (32 - a[1]) * t - fx * (a[2] - a[1] + 1) * t;
	local worldX = (32 - a[3]) * t - fy * (a[4] - a[3] + 1) * t;
	local b;
	if ( toWorld ) then
		b = SIMPLEMAP_MAP_BOUNDS[SIMPLEMAP_CONTINENT_FILES[a[5]] or ""];
	else
		b = SIMPLEMAP_MAP_BOUNDS[to or ""];
	end
	if ( not b or b[5] ~= a[5] ) then
		return nil;
	end
	local x = ((32 - b[1]) * t - worldY) / ((b[2] - b[1] + 1) * t);
	local y = ((32 - b[3]) * t - worldX) / ((b[4] - b[3] + 1) * t);
	if ( toWorld ) then
		local place = SIMPLEMAP_WORLD_PLACE[a[5]];
		x = place[1] + x * place[3];
		y = place[2] + y * place[3];
	end
	-- outside: also beyond the map's edge (for a point on the edge).
	if ( not outside and (x < 0 or x > 1 or y < 0 or y > 1) ) then
		return nil;
	end
	return x, y;
end

-- Map position -> server world coordinates (X north, Y west), for /position.
function SimpleMap_WorldPos(map, fx, fy)
	local a = SIMPLEMAP_MAP_BOUNDS[map or ""];
	if ( not a ) then
		return nil;
	end
	local t = SIMPLEMAP_TILE_YARDS;
	return (32 - a[3]) * t - fy * (a[4] - a[3] + 1) * t, (32 - a[1]) * t - fx * (a[2] - a[1] + 1) * t, a[5];
end

function SimpleMap_IsWorldView()
	return GetCurrentMapContinent and GetCurrentMapContinent() == 0 and GetCurrentMapZone and GetCurrentMapZone() == 0;
end

function SimpleMap_UpdateOthers()
	local shown = 0;
	local i;
	if ( SimpleQoL_Players and not SimpleMap_Dungeon and SimpleQoL_PlayersOn and SimpleQoL_PlayersOn() ) then
		local map = GetMapInfo() or "";
		local world = SimpleMap_IsWorldView();
		local now = GetTime();
		for i = 1, getn(SimpleQoL_Players) do
			local p = SimpleQoL_Players[i];
			local px, py = nil, nil;
			if ( shown < SIMPLEMAP_NUM_OTHERS and now - p.time < 30 and not (SimpleQoL_InMyParty and SimpleQoL_InMyParty(p.name)) and (not SimpleQoL_PosVisible or SimpleQoL_PosVisible(p)) ) then
				px, py = SimpleMap_ConvertPos(p.map, p.x, p.y, map, world);
			end
			if ( px ) then
				local x, y = SimpleMap_ToView(px, py);
				if ( x ) then
					shown = shown + 1;
					local dot = getglobal("SimpleMapOther"..shown);
					dot.name = p.name;
					dot:ClearAllPoints();
					dot:SetPoint("CENTER", "SimpleMapButton", "TOPLEFT", x, y);
					dot:Show();
				end
			end
		end
	end
	for i = shown + 1, SIMPLEMAP_NUM_OTHERS do
		getglobal("SimpleMapOther"..i):Hide();
	end
end

function SimpleMap_Other_OnEnter()
	SimpleMap_ShowTooltip(this.name);
end

-- Same icon sheet as the stock map: 4 columns of 16x16 icons in a 64x64 texture.
function SimpleMap_POICoords(index)
	local step = 16 / 64;
	local x1 = mod(index, 4) * step;
	local y1 = floor(index / 4) * step;
	return x1, x1 + step, y1, y1 + step;
end

function SimpleMap_PlaceUnit(frame, unit)
	local fx, fy = GetPlayerMapPosition(unit);
	if ( SimpleMap_Dungeon or not fx or (fx == 0 and fy == 0) ) then
		frame:Hide();
		return nil, nil;
	end
	local x, y = SimpleMap_ToView(fx, fy);
	if ( x ) then
		frame:ClearAllPoints();
		frame:SetPoint("CENTER", "SimpleMapButton", "TOPLEFT", x, y);
		frame:Show();
	else
		frame:Hide();
	end
	return fx, fy;
end

function SimpleMap_OnUpdate()
	if ( SimpleMap_FullscreenPending ) then
		SimpleMap_ApplyFullscreenSize();
	end
	if ( SimpleMap_GripStart ) then
		SimpleMap_Grip_OnUpdate();
	end
	if ( SimpleMap_MapDirty ) then
		SimpleMap_CheckMap();
	end
	if ( SimpleMap_Moving ) then
		SimpleMap_MoveUpdate();
	end
	SimpleMap_RouteUpdate();
	SimpleMap_NodeUpdate();
	-- Panning while the left button is held down on a zoomed map
	if ( SimpleMap_DragStart ) then
		local x, y = GetCursorPosition();
		local dx = x - SimpleMap_DragStart[1];
		local dy = y - SimpleMap_DragStart[2];
		if ( SimpleMap_Dragged or dx * dx + dy * dy > 25 ) then
			SimpleMap_Dragged = 1;
			SimpleMap_ViewLeft = SimpleMap_DragStart[3] - dx / SimpleMapButton:GetWidth() / SimpleMap_Zoom;
			SimpleMap_ViewTop = SimpleMap_DragStart[4] + dy / SimpleMapButton:GetHeight() / SimpleMap_Zoom;
			SimpleMap_ClampView();
			SimpleMap_LayoutTiles();
			-- UpdatePOIs also walks up to 200 NPC entries; doing that every single
			-- frame while panning was the main lag. Tiles still move every frame
			-- (cheap, keeps the drag feeling smooth); the symbols catch up several
			-- times a second (close enough to look like they track the pan,
			-- instead of visibly lagging behind and "jumping" into place) and
			-- once more the instant the drag ends.
			if ( not SimpleMap_PanPOITime or GetTime() - SimpleMap_PanPOITime >= 0.03 ) then
				SimpleMap_PanPOITime = GetTime();
				SimpleMap_UpdatePOIs();
			end
		end
	end

	-- Player and party
	local px, py = SimpleMap_PlaceUnit(SimpleMapPlayer, "player");
	if ( GetTime() - SimpleMap_OthersTime > 0.5 ) then
		SimpleMap_OthersTime = GetTime();
		SimpleMap_UpdateOthers();
	end
	local i;
	if ( not SimpleMap_PartyFrames ) then
		SimpleMap_PartyFrames = {};
		for i = 1, 4 do
			SimpleMap_PartyFrames[i] = { getglobal("SimpleMapParty"..i), "party"..i };
		end
	end
	for i = 1, 4 do
		SimpleMap_PlaceUnit(SimpleMap_PartyFrames[i][1], SimpleMap_PartyFrames[i][2]);
	end

	-- Area highlight, name and coordinates: only redone when something
	-- actually changed (no new strings every frame).
	local cx, cy = SimpleMap_CursorMapFraction();
	local moved = ( cx ~= SimpleMap_LastCX or cy ~= SimpleMap_LastCY or px ~= SimpleMap_LastPX or py ~= SimpleMap_LastPY
		or SimpleMap_ViewLeft ~= SimpleMap_LastLeft or SimpleMap_ViewTop ~= SimpleMap_LastTop );
	local structural = ( SimpleMap_Zoom ~= SimpleMap_LastZoom or SimpleMap_Dungeon ~= SimpleMap_LastDungeon or SimpleMap_ShownKey ~= SimpleMap_HLKey );
	if ( not moved and not structural and GetTime() - (SimpleMap_LastFull or 0) < 1 ) then
		return;
	end
	-- Walking (or just moving the cursor) changes px/py or cx/cy on almost
	-- every frame, and panning a zoomed map changes ViewLeft/ViewTop on
	-- almost every frame too -- all three used to defeat the check above
	-- every single time and rebuild the area highlight, name and coordinate
	-- text every frame (the big lag spike while panning, or just walking
	-- with the map open). A real structural change -- zoom, dungeon, the
	-- highlighted area -- still redraws at once; mere position/view drift is
	-- capped to a few times a second.
	if ( moved and not structural and SimpleMap_LastFull and GetTime() - SimpleMap_LastFull < 0.15 ) then
		return;
	end
	SimpleMap_HLKey = SimpleMap_ShownKey;
	SimpleMap_LastCX, SimpleMap_LastCY, SimpleMap_LastPX, SimpleMap_LastPY = cx, cy, px, py;
	SimpleMap_LastZoom, SimpleMap_LastLeft, SimpleMap_LastTop, SimpleMap_LastDungeon = SimpleMap_Zoom, SimpleMap_ViewLeft, SimpleMap_ViewTop, SimpleMap_Dungeon;
	SimpleMap_LastFull = GetTime();
	local name, fileName, texX, texY, textureX, textureY, childX, childY;
	if ( cx and SimpleMap_AreaNames and SimpleMap_Zoom == 1 and not SimpleMap_Dungeon and not SimpleMap_Mini ) then
		name, fileName, texX, texY, textureX, textureY, childX, childY = UpdateMapHighlight(cx, cy);
	end
	if ( fileName and textureX and textureX > 0 and textureY > 0 ) then
		local width = SimpleMapButton:GetWidth();
		local height = SimpleMapButton:GetHeight();
		SimpleMapHighlight:SetTexCoord(0, texX, 0, texY);
		if ( fileName ~= SimpleMap_HighlightFile ) then
			SimpleMap_HighlightFile = fileName;
			SimpleMapHighlight:SetTexture("Interface\\WorldMap\\"..fileName.."\\"..fileName.."Highlight");
		end
		SimpleMapHighlight:SetWidth(textureX * width);
		SimpleMapHighlight:SetHeight(textureY * height);
		SimpleMapHighlight:ClearAllPoints();
		SimpleMapHighlight:SetPoint("TOPLEFT", "SimpleMapDetail", "TOPLEFT", childX * width, -childY * height);
		SimpleMapHighlight:Show();
		SimpleMapAreaLabel:SetText(name);
	else
		SimpleMapHighlight:Hide();
		SimpleMapAreaLabel:SetText("");
	end

	if ( SimpleMap_Dungeon ) then
		cx = nil;
	end
	if ( SimpleMap_Mini ) then
		SimpleMapCoordsPlayer:SetText("Player: |cffffffff"..SimpleMap_CoordText(px, py).."|r");
		SimpleMapCoordsCursor:SetText("Cursor: |cffffffff"..SimpleMap_CoordText(cx, cy).."|r");
	else
		SimpleMapCoords:SetText("Cursor: |cffffffff"..SimpleMap_CoordText(cx, cy).."|r     Player: |cffffffff"..SimpleMap_CoordText(px, py).."|r");
	end
end


--------------------------------------------------------------------------------
-- Mouse: left click on the world or a continent opens the area under the
-- cursor (like the stock map); inside a zone a left click does nothing.
-- Right click zooms out one step. The mouse wheel zooms. Drag a zoomed map
-- to move it.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Route lines: Ctrl+drag draws a line (not necessarily straight) that becomes
-- many evenly spaced points; Ctrl+Shift+click sets points one by one (let go
-- of the keys to finish); Ctrl+click marks a single spot. The points are
-- shown on the map while drawing and while the route is active.
--------------------------------------------------------------------------------

SIMPLEMAP_ROUTE_MAX = 120;           -- dots on the map (the dot pool); a longer route shows every few points
SIMPLEMAP_ROUTE_POINTS = 300;        -- points of a route at most
SIMPLEMAP_ROUTE_SAMPLE = 4;          -- pixels between recorded drag points
SIMPLEMAP_ROUTE_SPACING = 4;         -- pixels between route points, at least
SimpleMap_Draw = nil;                -- raw points {fx, fy} while the drag is on
SimpleMap_Manual = nil;              -- points set with Ctrl+Shift+click

function SimpleMap_PointTo(fx, fy)
	if ( SimpleWalk_To ) then
		SimpleWalk_To(fx, fy, GetMapInfo());
	elseif ( SimpleQoL_WalkTo ) then
		SimpleQoL_WalkTo(fx, fy, GetMapInfo());
	end
end

-- Distance in map pixels (zoom 1) between two map fractions.
function SimpleMap_PixelDist(ax, ay, bx, by)
	local dx = (bx - ax) * SimpleMapButton:GetWidth();
	local dy = (by - ay) * SimpleMapButton:GetHeight();
	return sqrt(dx * dx + dy * dy);
end

-- Records the drag; ends it when the cursor leaves the map.
function SimpleMap_RouteSample()
	local fx, fy = SimpleMap_CursorMapFraction();
	if ( not fx ) then
		SimpleMap_DrawFinish();
		return;
	end
	local last = SimpleMap_Draw[getn(SimpleMap_Draw)];
	if ( SimpleMap_PixelDist(last[1], last[2], fx, fy) * SimpleMap_Zoom >= SIMPLEMAP_ROUTE_SAMPLE and getn(SimpleMap_Draw) < 2400 ) then
		tinsert(SimpleMap_Draw, { fx, fy });
	end
end

-- Even spacing along the drawn line: at most SIMPLEMAP_ROUTE_MAX points, the
-- last one always included.
function SimpleMap_Resample(raw)
	local n = getn(raw);
	local total = 0;
	local i;
	for i = 2, n do
		total = total + SimpleMap_PixelDist(raw[i - 1][1], raw[i - 1][2], raw[i][1], raw[i][2]);
	end
	local spacing = max(SIMPLEMAP_ROUTE_SPACING, total / (SIMPLEMAP_ROUTE_POINTS - 1));
	local points = { { raw[1][1], raw[1][2] } };
	local carry = 0;
	for i = 2, n do
		local a, b = raw[i - 1], raw[i];
		local seg = SimpleMap_PixelDist(a[1], a[2], b[1], b[2]);
		local at = spacing - carry;
		while ( seg > 0 and at <= seg ) do
			local t = at / seg;
			tinsert(points, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t });
			at = at + spacing;
		end
		carry = seg - (at - spacing);
	end
	local last = raw[n];
	local p = points[getn(points)];
	if ( SimpleMap_PixelDist(p[1], p[2], last[1], last[2]) < spacing * 0.4 and getn(points) > 1 ) then
		points[getn(points)] = { last[1], last[2] };
	elseif ( getn(points) < SIMPLEMAP_ROUTE_POINTS ) then
		tinsert(points, { last[1], last[2] });
	else
		points[getn(points)] = { last[1], last[2] };
	end
	return points;
end

function SimpleMap_DrawFinish()
	local raw = SimpleMap_Draw;
	SimpleMap_Draw = nil;
	if ( not raw ) then
		return;
	end
	local fx, fy = SimpleMap_CursorMapFraction();
	if ( getn(raw) < 4 ) then
		-- A click, not a drag.
		if ( fx ) then
			SimpleMap_PointTo(fx, fy);
		else
			SimpleMap_PointTo(raw[1][1], raw[1][2]);
		end
		return;
	end
	if ( not SimpleWalk_Route ) then
		return;
	end
	SimpleWalk_Route(SimpleMap_Resample(raw), GetMapInfo());
end

-- The dots: grey = passed, gold = the next point, blue = coming, red
-- = the end. Only redone when something changed.
function SimpleMap_RouteUpdate()
	local list, ri, count;
	if ( SimpleMap_Draw ) then
		SimpleMap_RouteSample();
	end
	-- Ctrl or Shift let go: the points set so far are the route.
	if ( SimpleMap_Manual and not (IsControlKeyDown() and IsShiftKeyDown()) ) then
		local points = SimpleMap_Manual;
		SimpleMap_Manual = nil;
		if ( getn(points) == 1 ) then
			SimpleMap_PointTo(points[1][1], points[1][2]);
		elseif ( SimpleWalk_Route ) then
			SimpleWalk_Route(SimpleMap_Resample(points), GetMapInfo());
		end
	end
	if ( SimpleMap_Draw ) then
		list, ri = SimpleMap_Draw, 0;
	elseif ( SimpleMap_Manual ) then
		list, ri = SimpleMap_Manual, 0;
	else
		local walk = SimpleWalk_Current;
		if ( walk and walk.route and walk.map == GetMapInfo() and not SimpleMap_Dungeon ) then
			list, ri = walk.route, walk.ri;
		end
	end
	if ( not list ) then
		if ( SimpleMap_RouteShown ) then
			local i;
			for i = 1, SIMPLEMAP_ROUTE_MAX do
				getglobal("SimpleMapRouteDot"..i):Hide();
			end
			SimpleMap_RouteShown = nil;
			SimpleMap_RouteList = nil;
		end
		return;
	end
	count = getn(list);
	if ( list == SimpleMap_RouteList and count == SimpleMap_RouteCount and ri == SimpleMap_RouteRi and SimpleMap_Zoom == SimpleMap_RouteZoom
		and SimpleMap_ViewLeft == SimpleMap_RouteLeft and SimpleMap_ViewTop == SimpleMap_RouteTop ) then
		return;
	end
	SimpleMap_RouteList, SimpleMap_RouteCount, SimpleMap_RouteRi = list, count, ri;
	SimpleMap_RouteZoom, SimpleMap_RouteLeft, SimpleMap_RouteTop = SimpleMap_Zoom, SimpleMap_ViewLeft, SimpleMap_ViewTop;
	SimpleMap_RouteShown = 1;
	local step = 1;
	if ( count > SIMPLEMAP_ROUTE_MAX ) then
		step = count / SIMPLEMAP_ROUTE_MAX;
	end
	local i;
	for i = 1, SIMPLEMAP_ROUTE_MAX do
		local dot = getglobal("SimpleMapRouteDot"..i);
		local k = floor((i - 1) * step + 1.5);
		if ( step > 1 and i == SIMPLEMAP_ROUTE_MAX ) then
			k = count;
		end
		local p = list[k];
		local x, y;
		if ( p and k <= count ) then
			x, y = SimpleMap_ToView(p[1], p[2]);
		end
		if ( not x ) then
			dot:Hide();
		else
			dot:ClearAllPoints();
			dot:SetPoint("CENTER", "SimpleMapButton", "TOPLEFT", x, y);
			if ( ri == 0 ) then
				dot:SetVertexColor(1.0, 1.0, 1.0);
				dot:SetWidth(4);
				dot:SetHeight(4);
			elseif ( k == count ) then
				dot:SetVertexColor(1.0, 0.1, 0.1);
				dot:SetWidth(8);
				dot:SetHeight(8);
			elseif ( k <= ri and ri < k + step ) then
				dot:SetVertexColor(1.0, 0.82, 0.0);
				dot:SetWidth(8);
				dot:SetHeight(8);
			elseif ( k + step <= ri ) then
				dot:SetVertexColor(0.5, 0.5, 0.5);
				dot:SetWidth(4);
				dot:SetHeight(4);
			else
				dot:SetVertexColor(0.3, 0.6, 1.0);
				dot:SetWidth(5);
				dot:SetHeight(5);
			end
			dot:Show();
		end
	end
end

function SimpleMap_OnMouseDown(mouseButton)
	SimpleMap_Dragged = nil;
	SimpleMap_DragStart = nil;
	SimpleMap_Draw = nil;
	SimpleMap_ManualClick = nil;
	SimpleMap_Moved = nil;
	-- Ctrl+Shift+click: one more point of the route (finished in SimpleMap_RouteUpdate).
	if ( mouseButton == "LeftButton" and IsControlKeyDown() and IsShiftKeyDown() and not SimpleMap_Dungeon ) then
		local fx, fy = SimpleMap_CursorMapFraction();
		if ( fx ) then
			SimpleMap_Manual = SimpleMap_Manual or {};
			tinsert(SimpleMap_Manual, { fx, fy });
			SimpleMap_ManualClick = 1;
		end
		return;
	end
	-- Ctrl+drag: draws a route (see SimpleMap_RouteUpdate).
	if ( mouseButton == "LeftButton" and IsControlKeyDown() and not SimpleMap_Dungeon ) then
		local fx, fy = SimpleMap_CursorMapFraction();
		if ( fx ) then
			SimpleMap_Draw = { { fx, fy } };
		end
		return;
	end
	-- Shift + drag moves the window instead. Started here (not through
	-- RegisterForDrag/OnDragStart): mixing 0.5.3's native drag with our own
	-- mouse tracking on the same button left the panel "holding" the cursor
	-- after a plain click, panning on mouse move with no button held.
	if ( mouseButton == "LeftButton" and IsShiftKeyDown() ) then
		SimpleMap_MoveStart();
		return;
	end
	if ( mouseButton == "LeftButton" and SimpleMap_Zoom > 1 ) then
		local x, y = GetCursorPosition();
		SimpleMap_DragStart = { x, y, SimpleMap_ViewLeft, SimpleMap_ViewTop };
		SimpleMap_DragCatcher_Engage();
	end
end

function SimpleMap_OnClick(mouseButton)
	SimpleMap_DragStart = nil;
	SimpleMap_MoveStop();
	SimpleMap_DragCatcher_Disengage();
	if ( SimpleMap_Moved ) then
		SimpleMap_Moved = nil;
		return;
	end
	if ( SimpleMap_ManualClick ) then
		SimpleMap_ManualClick = nil;
		return;
	end
	if ( SimpleMap_Draw ) then
		SimpleMap_DrawFinish();
		return;
	end
	if ( SimpleMap_Dragged ) then
		SimpleMap_Dragged = nil;
		SimpleMap_UpdatePOIs();
		return;
	end
	local fx, fy = SimpleMap_CursorMapFraction();
	-- Ctrl+click: mark a spot.
	if ( mouseButton == "LeftButton" and IsControlKeyDown() and fx and not SimpleMap_Dungeon ) then
		SimpleMap_PointTo(fx, fy);
		return;
	end
	if ( mouseButton == "LeftButton" ) then
		if ( fx and not SimpleMap_Dungeon and GetCurrentMapZone() == 0 ) then
			ProcessMapClick(fx, fy);
		end
	else
		if ( SimpleMap_Zoom > 1 ) then
			SimpleMap_SetZoom(SimpleMap_Zoom - 1, fx, fy);
		else
			SimpleMap_ZoomOut();
		end
	end
end

function SimpleMap_ZoomOut()
	if ( SimpleMap_Dungeon ) then
		SimpleMap_Dungeon = nil;
		SimpleMap_DungeonMenu = nil;
		SimpleMap_UpdateMap();
		return;
	end
	if ( GetCurrentMapZone() ~= 0 ) then
		SetMapZoom(GetCurrentMapContinent());
	else
		SetMapZoom(0);
	end
end


--------------------------------------------------------------------------------
-- Finding your own map. 0.5.3 has no working SetMapToCurrentZone, so the
-- zone name is looked up in the continents' zone lists. If you are on none of
-- the world maps you are inside an instance, and the dungeon list is used.
--------------------------------------------------------------------------------

function SimpleMap_LowerName(text)
	return strlower(text or "");
end

-- Returns 1 when the map now shows the zone you are in.
function SimpleMap_FindWorldZone()
	if ( SetMapToCurrentZone ) then
		SetMapToCurrentZone();
		-- Only a zone map counts: with no working SetMapToCurrentZone the map
		-- stays on whatever it showed, and a continent has a position too.
		if ( SimpleMap_HasPosition() and GetCurrentMapZone and GetCurrentMapZone() ~= 0 ) then
			return 1;
		end
	end
	local zone = SimpleMap_LowerName(GetZoneText and GetZoneText());
	local numContinents = SimpleMap_Count(GetMapContinents());
	local c, z;
	for c = 1, numContinents do
		local numZones = SimpleMap_Count(GetMapZones(c));
		for z = 1, numZones do
			if ( zone ~= "" and SimpleMap_LowerName(SimpleMap_Nth(z, GetMapZones(c))) == zone ) then
				SetMapZoom(c, z);
				return 1;
			end
		end
	end
	-- Last try: the continent map, for zones without a map of their own.
	for c = 1, numContinents do
		SetMapZoom(c);
		if ( SimpleMap_HasPosition() ) then
			return 1;
		end
	end
	return nil;
end

function SimpleMap_FindDungeon()
	local zone = SimpleMap_LowerName(GetZoneText and GetZoneText());
	local d, k;
	for d = 1, getn(SIMPLEMAP_DUNGEONS) do
		local list = SIMPLEMAP_DUNGEONS[d][3];
		for k = 1, getn(list) do
			if ( zone ~= "" and zone == list[k] ) then
				return SIMPLEMAP_DUNGEONS[d];
			end
		end
	end
	return nil;
end

-- "Current Zone": your zone (or dungeon); when zoomed in, centered on you.
function SimpleMap_ShowCurrentZone(quiet)
	SimpleMap_Dungeon = nil;
	SimpleMap_DungeonMenu = nil;
	-- A zone that only has an "other" map (Plains of Snow ...)
	local other = SimpleMap_FindDungeon();
	if ( other and other[5] ) then
		SimpleMap_Dungeon = other;
		SimpleMap_DungeonMenu = 2;
		SimpleMap_UpdateMap();
		return nil;
	end
	if ( SimpleMap_FindWorldZone() ) then
		SimpleMap_UpdateMap();
		if ( SimpleMap_Zoom > 1 ) then
			local fx, fy = GetPlayerMapPosition("player");
			SimpleMap_CenterOn(fx, fy);
		end
		return 1;
	end
	SimpleMap_Dungeon = SimpleMap_FindDungeon();
	if ( SimpleMap_Dungeon ) then
		SimpleMap_DungeonMenu = 1;
	elseif ( not quiet and GetZoneText() and GetZoneText() ~= "" and SimpleMap_WarnedZone ~= GetZoneText() ) then
		SimpleMap_WarnedZone = GetZoneText();
		SimpleMap_Print("No map found for '"..(GetZoneText() or "?").."'. Choose it in the menus (Dungeons/Other are under Continent).");
	end
	SimpleMap_UpdateMap();
	return nil;
end


--------------------------------------------------------------------------------
-- Continent and zone menus (same drop-down API as the stock world map).
-- The Continent menu has one extra entry, "Dungeons"; the Zone menu then
-- lists the dungeon maps.
--------------------------------------------------------------------------------

function SimpleMap_LoadList(func, ...)
	local i;
	for i = 1, arg.n do
		UIDropDownMenu_AddButton(arg[i], func);
	end
end

function SimpleMap_ContinentDropDown_OnLoad()
	UIDropDownMenu_SetWidth(100);
	-- The template's text box is width 0 ("auto"), which 0.5.3 does not
	-- handle: it wraps mid-word instead. Give it a real width.
	getglobal(this:GetName().."Text"):SetWidth(85);
	UIDropDownMenu_Initialize();
	SimpleMap_LoadList(SimpleMap_ContinentButton_OnClick, GetMapContinents());
	UIDropDownMenu_AddButton("Dungeons", SimpleMap_ContinentButton_OnClick);
	UIDropDownMenu_AddButton("Other", SimpleMap_ContinentButton_OnClick);
	UIDropDownMenu_Refresh();
end

function SimpleMap_ZoneDropDown_OnLoad()
	this:RegisterEvent("WORLD_MAP_UPDATE");
	UIDropDownMenu_SetWidth(130);
	getglobal(this:GetName().."Text"):SetWidth(115);
	SimpleMap_ZoneDropDown_Fill();
end

-- The Zone menu is only needed while the map is open: with it closed the
-- refill (a list of buttons each time) is skipped and done when it opens.
-- (Refilled by SimpleMap_RefillZones when the map really changed.)
function SimpleMap_ZoneDropDown_Event()
end

function SimpleMap_ZoneDropDown_Fill()
	UIDropDownMenu_Initialize();
	if ( SimpleMap_DungeonMenu ) then
		local list = SimpleMap_DungeonList();
		local d;
		for d = 1, getn(list) do
			UIDropDownMenu_AddButton(list[d][2], SimpleMap_ZoneButton_OnClick);
		end
	else
		SimpleMap_LoadList(SimpleMap_ZoneButton_OnClick, GetMapZones(GetCurrentMapContinent()));
	end
	UIDropDownMenu_Refresh();
end

function SimpleMap_ContinentButton_OnClick()
	local id = this:GetID();
	local numContinents = SimpleMap_Count(GetMapContinents());
	UIDropDownMenu_SetSelectedID(SimpleMapContinentDropDown, id);
	if ( id > numContinents ) then
		SimpleMap_DungeonMenu = (id == numContinents + 2) and 2 or 1;
		-- The drop-down functions work on "this"; fill the Zone menu, then put it back.
		SimpleMap_RefillZones();
		UIDropDownMenu_ClearAll(SimpleMapZoneDropDown);
		return;
	end
	SimpleMap_DungeonMenu = nil;
	SimpleMap_Dungeon = nil;
	SetMapZoom(id);
end

function SimpleMap_ZoneButton_OnClick()
	local id = this:GetID();
	UIDropDownMenu_SetSelectedID(SimpleMapZoneDropDown, id);
	if ( SimpleMap_DungeonMenu ) then
		SimpleMap_Dungeon = SimpleMap_DungeonList()[id];
		SimpleMap_UpdateMap();
		return;
	end
	SimpleMap_Dungeon = nil;
	SetMapZoom(GetCurrentMapContinent(), id);
end

function SimpleMap_UpdateDropDowns()
	if ( SimpleMap_DungeonMenu ) then
		UIDropDownMenu_SetSelectedID(SimpleMapContinentDropDown, SimpleMap_Count(GetMapContinents()) + SimpleMap_DungeonMenu);
		UIDropDownMenu_Refresh(SimpleMapContinentDropDown);
		local list = SimpleMap_DungeonList();
		local d;
		UIDropDownMenu_ClearAll(SimpleMapZoneDropDown);
		for d = 1, getn(list) do
			if ( list[d] == SimpleMap_Dungeon ) then
				UIDropDownMenu_SetSelectedID(SimpleMapZoneDropDown, d);
			end
		end
		return;
	end
	if ( GetCurrentMapContinent() == 0 ) then
		UIDropDownMenu_ClearAll(SimpleMapContinentDropDown);
	else
		UIDropDownMenu_SetSelectedID(SimpleMapContinentDropDown, GetCurrentMapContinent());
	end
	UIDropDownMenu_Refresh(SimpleMapContinentDropDown);
	if ( GetCurrentMapZone() == 0 ) then
		UIDropDownMenu_ClearAll(SimpleMapZoneDropDown);
	else
		UIDropDownMenu_SetSelectedID(SimpleMapZoneDropDown, GetCurrentMapZone());
	end
end


--------------------------------------------------------------------------------
-- Coordinates under the minimap. The position is only known for the map that
-- is selected, so while the big map is closed it is kept on your own zone.
--------------------------------------------------------------------------------

function SimpleMap_MinimapCoords_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("ZONE_CHANGED");
	this:RegisterEvent("MINIMAP_ZONE_CHANGED");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("UI_INFO_MESSAGE");
	this:RegisterEvent("PLAYER_ALIVE");
end

--------------------------------------------------------------------------------
-- Where you are bound (shown on binder symbols): asked from the server at
-- login ("You are bound in ..."), and noted when you bind at a binder ("Your
-- soul is bound to this place.") and when you release your spirit and wake
-- up at your binder. Saved per character.
--------------------------------------------------------------------------------

SimpleMap_BindZone = nil;
SimpleMap_BindAsked = nil;            -- GetTime() of our own question (its answer is not shown)
SimpleMap_Released = nil;             -- GetTime() of releasing the spirit

function SimpleMap_BindPattern()
	if ( SimpleMap_BindPat ) then
		return SimpleMap_BindPat;
	end
	local text = BIND_ZONE_DISPLAY or "You are bound in %s.";
	text = gsub(text, "([%.%(%)%-%+%*%?%[%]%^%$])", "%%%1");
	text = gsub(text, "%%s", "(.+)");
	SimpleMap_BindPat = "^"..text.."$";
	return SimpleMap_BindPat;
end

function SimpleMap_SetBindZone(zone)
	if ( not zone or zone == "" ) then
		return;
	end
	SimpleMap_BindZone = zone;
	if ( SimpleSave_SetChar ) then
		SimpleSave_SetChar("SimpleMap", "Bind", zone);
	end
end

function SimpleMap_AskBindZone()
	if ( GetBindZone ) then
		SimpleMap_BindAsked = GetTime();
		GetBindZone();
	end
end

-- The area you stand in ("Goldshire", "Thunder Bluff" ...).
function SimpleMap_HereText()
	local here = GetMinimapZoneText and GetMinimapZoneText();
	if ( not here or here == "" ) then
		here = GetZoneText and GetZoneText();
	end
	return here;
end

function SimpleMap_BindEvent(event, message)
	if ( event == "CHAT_MSG_SYSTEM" and message ) then
		local s, e, zone = strfind(message, SimpleMap_BindPattern());
		if ( zone ) then
			SimpleMap_SetBindZone(zone);
			return;
		end
	end
	if ( (event == "CHAT_MSG_SYSTEM" or event == "UI_INFO_MESSAGE") and message and message == (DEATHBIND_SUCCESSFUL or "Your soul is bound to this place.") ) then
		SimpleMap_SetBindZone(SimpleMap_HereText());
		SimpleMap_AskBindZone();
	elseif ( event == "PLAYER_ALIVE" and SimpleMap_Released and GetTime() - SimpleMap_Released < 120 ) then
		-- Back alive after releasing: you are at your binder.
		SimpleMap_Released = nil;
		SimpleMap_BindCheckTime = GetTime() + 2;
	elseif ( event == "PLAYER_ENTERING_WORLD" and not SimpleMap_BindStarted ) then
		SimpleMap_BindStarted = 1;
		SimpleMap_BindCheckTime = nil;
		SimpleMap_AskTime = GetTime() + 3;
	end
end

if ( RepopMe ) then
	SimpleMap_Orig_RepopMe = RepopMe;
	function RepopMe()
		SimpleMap_Released = GetTime();
		SimpleMap_Orig_RepopMe();
	end
end

-- Our own question's answer does not show in the chat.
SimpleMap_Orig_ChatFrame_OnEvent = ChatFrame_OnEvent;
function ChatFrame_OnEvent(event)
	if ( event == "CHAT_MSG_SYSTEM" and SimpleMap_BindAsked and GetTime() - SimpleMap_BindAsked < 5 and arg1 and strfind(arg1, SimpleMap_BindPattern()) ) then
		SimpleMap_BindAsked = nil;
		return;
	end
	SimpleMap_Orig_ChatFrame_OnEvent(event);
end

function SimpleMap_BindUpdate()
	local now = GetTime();
	if ( SimpleMap_AskTime and now >= SimpleMap_AskTime ) then
		SimpleMap_AskTime = nil;
		SimpleMap_AskBindZone();
	end
	if ( SimpleMap_BindCheckTime and now >= SimpleMap_BindCheckTime ) then
		SimpleMap_BindCheckTime = nil;
		SimpleMap_SetBindZone(SimpleMap_HereText());
		SimpleMap_AskBindZone();
	end
end

function SimpleMap_MinimapCoords_OnEvent()
	SimpleMap_BindEvent(event, arg1);
	if ( event == "CHAT_MSG_SYSTEM" or event == "UI_INFO_MESSAGE" or event == "PLAYER_ALIVE" ) then
		return;
	end
	if ( (SimpleMap_MinimapCoords or SimpleMap_ShowNPCs or SimpleMap_ShowRares) and not SimpleMapFrame:IsVisible() and not SimpleMap_HasPosition() ) then
		SimpleMap_FindWorldZone();
	end
end

-- AlphaUI's AtlasLoot: its loose launcher button is hidden and the map's
-- menu row gets the icon instead (only while AlphaUI's AtlasLoot is on).
function SimpleMap_AtlasOn()
	return MainAtlasLootLauncherButton_OnClick and Main and Main.IsModuleEnabled and Main.IsModuleEnabled("atlas_loot");
end

function SimpleMap_UpdateAtlas()
	if ( SimpleMap_AtlasOn() ) then
		if ( MainAtlasLootButton and MainAtlasLootButton:IsVisible() ) then
			MainAtlasLootButton:Hide();
		end
		if ( not SimpleMap_AtlasShown ) then
			SimpleMap_AtlasShown = 1;
			SimpleMapAtlasButton:Show();
		end
	elseif ( SimpleMap_AtlasShown ) then
		SimpleMap_AtlasShown = nil;
		SimpleMapAtlasButton:Hide();
	end
end

function SimpleMap_Atlas_OnClick()
	if ( SimpleMap_AtlasOn() ) then
		MainAtlasLootLauncherButton_OnClick();
	end
end

function SimpleMap_MinimapCoords_OnUpdate(elapsed)
	if ( SimpleHello_Tick ) then
		SimpleHello_Tick();
	end
	SimpleMap_CoordTimer = SimpleMap_CoordTimer - (elapsed or 0);
	if ( SimpleMap_CoordTimer > 0 ) then
		return;
	end
	SimpleMap_BindUpdate();
	SimpleMap_CoordTimer = 0.2;
	if ( SimpleMap_Mini ) then
		SimpleMap_MiniUpdate();
	elseif ( SimpleMapFrame:IsVisible() and GetZoneText() ~= SimpleMap_MinZone ) then
		SimpleMap_UpdateMinButton();
	end
	SimpleMap_UpdateMinimapNPCs();
	-- AlphaUI's AtlasLoot switch is looked at once a second.
	if ( GetTime() - (SimpleMap_AtlasTime or 0) > 1 ) then
		SimpleMap_AtlasTime = GetTime();
		SimpleMap_UpdateAtlas();
	end
	local x, y = GetPlayerMapPosition("player");
	if ( not SimpleMap_MinimapCoords or not x or (x == 0 and y == 0) ) then
		if ( SimpleMap_CoordShown ) then
			SimpleMap_CoordShown = nil;
			SimpleMapMinimapCoordsText:SetText("");
		end
	elseif ( not SimpleMap_CoordShown or x ~= SimpleMap_CoordX or y ~= SimpleMap_CoordY ) then
		-- Only a new text when you moved (less garbage to collect).
		SimpleMap_CoordShown = 1;
		SimpleMap_CoordX, SimpleMap_CoordY = x, y;
		SimpleMapMinimapCoordsText:SetText(format("%.1f, %.1f", x * 100, y * 100));
	end
end


--------------------------------------------------------------------------------
-- Options panel
--------------------------------------------------------------------------------

function SimpleMapOptions_Toggle()
	if ( SimpleMapOptionsFrame:IsVisible() ) then
		SimpleMapOptionsFrame:Hide();
	else
		SimpleMapOptionsFrame:Show();
	end
end

-- While the options are open the map behind them is dimmed, so the text is
-- easy to read and the map is still there.
SIMPLEMAP_OPTIONS_DIM = 0.4;
SIMPLEMAP_OPTIONS_ICON_DIM = 0.3;
SIMPLEMAP_ICON_FAMILIES = { { "SimpleMapNPC", 150 }, { "SimpleMapNode", 25 }, { "SimpleMapPOI", 16 },
	{ "SimpleMapOther", 20 }, { "SimpleMapParty", 4 } };
function SimpleMapOptions_DimIcons(alpha)
	local f, i, frame;
	for f = 1, getn(SIMPLEMAP_ICON_FAMILIES) do
		for i = 1, SIMPLEMAP_ICON_FAMILIES[f][2] do
			frame = getglobal(SIMPLEMAP_ICON_FAMILIES[f][1]..i);
			if ( frame ) then
				frame:SetAlpha(alpha);
			end
		end
	end
end

function SimpleMapOptions_Dim(on)
	SimpleMap_Dimmed = on;
	if ( on ) then
		SimpleMapOptions_DimIcons(SIMPLEMAP_OPTIONS_ICON_DIM);
	else
		SimpleMapOptions_DimIcons(1.0);
	end
	-- The map tiles live in SimpleMapDetail. Black behind the half see-through
	-- tiles makes the map darker.
	if ( on ) then
		SimpleMapDetail:SetAlpha(SIMPLEMAP_OPTIONS_DIM);
		SimpleMapDarkBack:ClearAllPoints();
		SimpleMapDarkBack:SetPoint("TOPLEFT", "SimpleMapDetail", "TOPLEFT", 0, 0);
		SimpleMapDarkBack:SetPoint("BOTTOMRIGHT", "SimpleMapDetail", "BOTTOMRIGHT", 0, 0);
		SimpleMapDarkBack:Show();
	else
		SimpleMapDetail:SetAlpha(SimpleMap_Alpha);
		SimpleMapDarkBack:Hide();
	end
end

-- Check box label: one line, left aligned, wide enough (the automatic width
-- cut the last word of some labels).
function SimpleMapOptions_Label(button, text)
	local label = getglobal(button:GetName().."Text");
	label:SetText(text);
	label:SetJustifyH("LEFT");
	label:SetWidth(190);
	label:SetHeight(14);
end

function SimpleMapOptions_Update()
	SimpleMapOptionsMinimapCoords:SetChecked(SimpleMap_MinimapCoords and 1 or 0);
	SimpleMapOptionsGoToZone:SetChecked(SimpleMap_GoToZone and 1 or 0);
	SimpleMapOptionsAreaNames:SetChecked(SimpleMap_AreaNames and 1 or 0);
	SimpleMapOptionsBinders:SetChecked(SimpleMap_ShowBinders and 1 or 0);
	SimpleMapOptionsTrainers:SetChecked(SimpleMap_ShowTrainers and 1 or 0);
	SimpleMapOptionsTravel:SetChecked(SimpleMap_ShowTravel and 1 or 0);
	SimpleMapOptionsRares:SetChecked(SimpleMap_ShowRares and 1 or 0);
	SimpleMapOptionsOre:SetChecked(SimpleMap_RememberOre and 1 or 0);
	SimpleMapOptionsHerbs:SetChecked(SimpleMap_RememberHerbs and 1 or 0);
	SimpleMapOptionsChests:SetChecked(SimpleMap_RememberChests and 1 or 0);
	SimpleMap_UpdateSliders();
	if ( SimpleSave_Set ) then
		SimpleMapOptionsDependency:SetText("");
	else
		SimpleMapOptionsDependency:SetText("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions.");
	end
end

function SimpleMapOptions_Toggle_Setting(which)
	if ( which == "coords" ) then
		SimpleMap_MinimapCoords = not SimpleMap_MinimapCoords and 1 or nil;
	elseif ( which == "zone" ) then
		SimpleMap_GoToZone = not SimpleMap_GoToZone and 1 or nil;
	elseif ( which == "areas" ) then
		SimpleMap_AreaNames = not SimpleMap_AreaNames and 1 or nil;
	elseif ( which == "binders" ) then
		SimpleMap_ShowBinders = not SimpleMap_ShowBinders and 1 or nil;
		SimpleMap_NPCSync();
		SimpleMap_UpdateNPCs();
	elseif ( which == "trainers" ) then
		SimpleMap_ShowTrainers = not SimpleMap_ShowTrainers and 1 or nil;
		SimpleMap_NPCSync();
		SimpleMap_UpdateNPCs();
	elseif ( which == "travel" ) then
		SimpleMap_ShowTravel = not SimpleMap_ShowTravel and 1 or nil;
		SimpleMap_NPCSync();
		SimpleMap_UpdateNPCs();
	elseif ( which == "rares" ) then
		SimpleMap_ShowRares = not SimpleMap_ShowRares and 1 or nil;
		SimpleMap_UpdateNPCs();
	elseif ( which == "ore" ) then
		SimpleMap_RememberOre = not SimpleMap_RememberOre and 1 or nil;
		SimpleMap_NodesRefresh();
	elseif ( which == "herbs" ) then
		SimpleMap_RememberHerbs = not SimpleMap_RememberHerbs and 1 or nil;
		SimpleMap_NodesRefresh();
	elseif ( which == "chests" ) then
		SimpleMap_RememberChests = not SimpleMap_RememberChests and 1 or nil;
		SimpleMap_NodesRefresh();
	end
	SimpleMapOptions_Update();
	SimpleMap_SaveSettings();
end


--------------------------------------------------------------------------------
-- Saving with SimpleSave (addon "SimpleMap"). Without SimpleSave the map
-- works, but settings are back to default after a restart.
--------------------------------------------------------------------------------

function SimpleMap_FlagText(value)
	if ( value ) then
		return "1";
	end
	return "0";
end

function SimpleMap_SaveSettings()
	if ( not SimpleSave_Set or not SimpleMap_SettingsLoaded ) then
		return;
	end
	local scale = SimpleMap_Scale;
	if ( SimpleMap_Fullscreen and SimpleMap_WindowScale ) then
		scale = SimpleMap_WindowScale;
	end
	SimpleSave_Set("SimpleMap", "Size", floor(scale * 100 + 0.5));
	SimpleSave_Set("SimpleMap", "Alpha", floor(SimpleMap_Alpha * 100 + 0.5));
	SimpleSave_Set("SimpleMap", "Coords", SimpleMap_FlagText(SimpleMap_MinimapCoords));
	SimpleSave_Set("SimpleMap", "Zone", SimpleMap_FlagText(SimpleMap_GoToZone));
	SimpleSave_Set("SimpleMap", "Areas", SimpleMap_FlagText(SimpleMap_AreaNames));
	SimpleSave_Set("SimpleMap", "Binders", SimpleMap_FlagText(SimpleMap_ShowBinders));
	SimpleSave_Set("SimpleMap", "Trainers", SimpleMap_FlagText(SimpleMap_ShowTrainers));
	SimpleSave_Set("SimpleMap", "Travel", SimpleMap_FlagText(SimpleMap_ShowTravel));
	SimpleSave_Set("SimpleMap", "Rares", SimpleMap_FlagText(SimpleMap_ShowRares));
	SimpleSave_Set("SimpleMap", "Ore", SimpleMap_FlagText(SimpleMap_RememberOre));
	SimpleSave_Set("SimpleMap", "Herbs", SimpleMap_FlagText(SimpleMap_RememberHerbs));
	SimpleSave_Set("SimpleMap", "Chests", SimpleMap_FlagText(SimpleMap_RememberChests));
end

function SimpleMap_LoadFlag(name, default)
	local value = SimpleSave_Get("SimpleMap", name);
	if ( value == "1" ) then
		return 1;
	elseif ( value == "0" ) then
		return nil;
	end
	return default;
end

function SimpleMap_LoadSettings()
	SimpleMap_SettingsLoaded = 1;
	if ( not SimpleSave_Get ) then
		return;
	end
	SimpleMap_MinimapCoords = SimpleMap_LoadFlag("Coords", SimpleMap_MinimapCoords);
	SimpleMap_GoToZone = SimpleMap_LoadFlag("Zone", SimpleMap_GoToZone);
	SimpleMap_AreaNames = SimpleMap_LoadFlag("Areas", SimpleMap_AreaNames);
	-- The old single setting "NPCs" is the start value of the three.
	local oldNPCs = SimpleMap_LoadFlag("NPCs", 1);
	SimpleMap_ShowBinders = SimpleMap_LoadFlag("Binders", oldNPCs);
	SimpleMap_ShowTrainers = SimpleMap_LoadFlag("Trainers", oldNPCs);
	SimpleMap_ShowTravel = SimpleMap_LoadFlag("Travel", oldNPCs);
	SimpleMap_NPCSync();
	SimpleMap_ShowRares = SimpleMap_LoadFlag("Rares", SimpleMap_ShowRares);
	-- The old single setting "Nodes" is the start value of the three.
	local oldNodes = SimpleMap_LoadFlag("Nodes", nil);
	SimpleMap_RememberOre = SimpleMap_LoadFlag("Ore", oldNodes);
	SimpleMap_RememberHerbs = SimpleMap_LoadFlag("Herbs", oldNodes);
	SimpleMap_RememberChests = SimpleMap_LoadFlag("Chests", oldNodes);
	SimpleMap_NodesRefresh();
	if ( SimpleSave_GetChar ) then
		SimpleMap_BindZone = SimpleSave_GetChar("SimpleMap", "Bind") or SimpleMap_BindZone;
	end
	-- Minimize/Maximize and Fullscreen are never remembered: the map always
	-- opens in its normal (not mini, not fullscreen) size.
	SimpleMap_Mini = nil;
	SimpleMap_SetAlpha(SimpleSave_GetNumber("SimpleMap", "Alpha", SimpleMap_Alpha * 100) / 100);
	SimpleMap_SetScale(SimpleSave_GetNumber("SimpleMap", "Size", SimpleMap_Scale * 100) / 100);
	if ( SimpleMap_Mini ) then
		SimpleMap_ApplyMini();
	end
	if ( SimpleMapOptionsFrame:IsVisible() ) then
		SimpleMapOptions_Update();
	end
end


--------------------------------------------------------------------------------
-- Tooltips for landmarks and party members
--------------------------------------------------------------------------------

function SimpleMap_ShowTooltip(text)
	if ( not text or text == "" ) then
		return;
	end
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText(text);
	GameTooltip:Show();
end

function SimpleMap_Unit_OnEnter()
	SimpleMap_ShowTooltip(UnitName(this.unit));
end


--------------------------------------------------------------------------------
-- Opening and closing. ToggleWorldMap is used by the M key and the
-- World Map micro button.
--------------------------------------------------------------------------------

function ToggleWorldMap()
	if ( SimpleMapFrame:IsVisible() ) then
		SimpleMapFrame:Hide();
	else
		SimpleMapFrame:Show();
	end
end

function SimpleMap_OnShow()
	SimpleMap_MoveStop();
	if ( not SimpleMap_Sized ) then
		SimpleMap_Resize();
	end
	SimpleMap_ApplyDetailAlpha();
	if ( WorldMapFrame and WorldMapFrame:IsVisible() ) then
		HideUIPanel(WorldMapFrame);
	end
	if ( SimpleMap_GoToZone ) then
		SimpleMap_ShowCurrentZone();
	else
		SimpleMap_UpdateMap();
	end
	SimpleMap_UpdateMinButton();
	if ( UpdateMicroButtons ) then
		UpdateMicroButtons();
	end
end

function SimpleMap_OnHide()
	GameTooltip:Hide();
	SimpleMap_Draw = nil;
	SimpleMap_Manual = nil;
	if ( SimpleMap_ActiveSlider ) then
		SimpleMap_Slider_OnMouseUp();
	end
	SimpleMap_GripStart = nil;
	SimpleMapOptionsFrame:Hide();
	SimpleMap_DragStart = nil;
	SimpleMap_MoveStop();
	-- Closing the map (also with Esc or M) always leaves fullscreen,
	-- minimized and wherever it was dragged to behind, so the next M always
	-- opens the normal, default map, centered on screen.
	if ( SimpleMap_Fullscreen ) then
		SimpleMap_SetFullscreen(nil);
	end
	if ( SimpleMap_Mini ) then
		SimpleMap_Mini = nil;
		SimpleMap_ApplyMini();
	end
	SimpleMapFrame:ClearAllPoints();
	SimpleMapFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);
	-- Back to your own zone, so the minimap coordinates keep working.
	if ( SimpleMap_MinimapCoords ) then
		SimpleMap_FindWorldZone();
	end
	if ( UpdateMicroButtons ) then
		UpdateMicroButtons();
	end
end

function SimpleMap_OnLoad()
	this:RegisterEvent("WORLD_MAP_UPDATE");
	this:RegisterEvent("CLOSE_WORLD_MAP");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	tinsert(UISpecialFrames, "SimpleMapFrame");
	this:SetAlpha(SimpleMap_Alpha);
end

function SimpleMap_OnEvent(event)
	if ( event == "WORLD_MAP_UPDATE" ) then
		-- drawn on the next frame, if the map really changed (SimpleMap_CheckMap)
		if ( this:IsVisible() ) then
			SimpleMap_MapDirty = 1;
		end
	elseif ( event == "CLOSE_WORLD_MAP" ) then
		this:Hide();
	elseif ( event == "PLAYER_ENTERING_WORLD" and not SimpleMap_Started ) then
		SimpleMap_Started = 1;
		if ( SimpleSave_RegisterLoad ) then
			SimpleSave_RegisterLoad(SimpleMap_LoadSettings);
		else
			SimpleMap_LoadSettings();
			SimpleMap_Print("|cffff4040Dependency missing: SimpleSave.|r Settings are not saved between sessions.");
		end
	end
end

-- The micro button shows "pushed" while a map is open.
SimpleMap_Orig_UpdateMicroButtons = UpdateMicroButtons;
function UpdateMicroButtons()
	if ( SimpleMap_Orig_UpdateMicroButtons ) then
		SimpleMap_Orig_UpdateMicroButtons();
	end
	if ( WorldMapMicroButton and SimpleMapFrame and SimpleMapFrame:IsVisible() ) then
		WorldMapMicroButton:SetButtonState("PUSHED", 1);
	end
end


--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

SLASH_SIMPLEMAP1 = "/smap";
SLASH_SIMPLEMAP2 = "/simplemap";
SlashCmdList["SIMPLEMAP"] = function(msg)
	local simpleVersionAsk = strlower(gsub(msg or "", "%s", ""));
	if ( simpleVersionAsk == "v" or simpleVersionAsk == "version" ) then
		ChatFrame:AddMessage("SimpleMap "..SIMPLEMAP_VERSION, 1.0, 0.82, 0.0);
		return;
	end
	msg = strlower(msg or "");
	msg = gsub(msg, "^%s+", "");
	msg = gsub(msg, "%s+$", "");
	if ( msg == "options" ) then
		if ( not SimpleMapFrame:IsVisible() ) then
			SimpleMapFrame:Show();
		end
		SimpleMapOptionsFrame:Show();
	elseif ( msg == "reset" ) then
		SimpleMap_SetScale(SIMPLEMAP_DEFAULT_SCALE);
		SimpleMap_SetAlpha(SIMPLEMAP_DEFAULT_ALPHA);
		SimpleMapFrame:ClearAllPoints();
		SimpleMapFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 40);
		SimpleMap_Print("Size, transparency and place reset.");
	elseif ( msg == "help" ) then
		SimpleMap_Print("M or /smap - open or close the map");
		SimpleMap_Print("Mouse wheel: zoom. Drag a zoomed map to move it. Right click: zoom out");
		SimpleMap_Print("Left click on the world or a continent: open that area");
		SimpleMap_Print("/smap options - settings (also the Options button)");
		SimpleMap_Print("/smap reset - reset size, transparency and place");
	else
		if ( SimpleMapFrame:IsVisible() ) then
			SimpleMapFrame:Hide();
		else
			SimpleMapFrame:Show();
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
