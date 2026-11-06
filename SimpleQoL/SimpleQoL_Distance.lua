--------------------------------------------------------------------------------
-- Target Distance: the distance to your target in yards above its portrait.
--
-- Worked out from the map positions of you and your target on the map of the
-- zone you are in (the map SimpleMap keeps on your zone). Unlike AlphaUI's
-- Target Distance it never switches the world map back and forth (that made
-- two map updates every second and short lag spikes), and it only runs while
-- you have a target. AlphaUI's Target Distance is turned off while SimpleQoL is
-- installed; this one is the "Show target distance" check box (on by default).
--------------------------------------------------------------------------------

SIMPLEQOL_DIST_RATE = 0.05;        -- seconds between updates (cheap: no map switching)
SIMPLEQOL_DIST_MAPFIX = 5;         -- seconds between putting the map back on your zone

-- Map size in yards (zone maps, and the two continents).
SIMPLEQOL_MAP_YARDS = {
	Durotar = { 6400, 4267 }, Mulgore = { 6400, 4267 }, Barrens = { 12800, 8533 }, Kalimdor = { 33600, 22400 }, Azeroth = { 30400, 20267 }, Alterac = { 3200, 2133 }, Arathi = { 4800, 3200 }, Badlands = { 4800, 3200 }, Blackrock = { 3200, 2133 }, BlastedLands = { 4800, 3200 }, Tirisfal = { 4800, 3200 }, Silverpine = { 4800, 3200 }, WesternPlaguelands = { 4800, 3200 }, EasternPlaguelands = { 6400, 4267 }, Hilsbrad = { 4800, 3200 }, Hinterlands = { 4800, 3200 }, DunMorogh = { 4800, 3200 }, SearingGorge = { 4800, 3200 }, BurningSteppes = { 3200, 2133 }, Elwynn = { 4800, 3200 }, DarrowmereLake = { 3200, 2133 }, DeadwindPass = { 3200, 2133 }, Duskwood = { 3200, 2133 }, LochModan = { 4800, 3200 }, Redridge = { 3200, 2133 }, Stranglethorn = { 6400, 4267 }, SwampOfSorrows = { 3200, 2133 }, Westfall = { 4800, 3200 }, Wetlands = { 4800, 3200 },
};

SimpleQoL_DistTime = 0;
SimpleQoL_DistMapFix = -100;

-- Distance in yards, or nil when it cannot be worked out right now.
function SimpleQoL_TargetDistance()
	if ( not UnitExists("target") or UnitIsUnit("target", "player") ) then
		return nil;
	end
	local px, py = GetPlayerMapPosition("player");
	if ( not px or (px == 0 and py == 0) ) then
		-- The map does not show where you are: put it back on your zone now
		-- and then (never while a map window is open, at most every 5 s).
		local now = GetTime();
		if ( SetMapToCurrentZone and now - SimpleQoL_DistMapFix >= SIMPLEQOL_DIST_MAPFIX
				and not (WorldMapFrame and WorldMapFrame:IsVisible())
				and not (SimpleMapFrame and SimpleMapFrame:IsVisible()) ) then
			SimpleQoL_DistMapFix = now;
			SetMapToCurrentZone();
		end
		return nil;
	end
	local tx, ty = GetPlayerMapPosition("target");
	if ( not tx or (tx == 0 and ty == 0) ) then
		return nil;
	end
	local size = SIMPLEQOL_MAP_YARDS[GetMapInfo() or ""];
	if ( not size ) then
		return nil;
	end
	local dx = (tx - px) * size[1];
	local dy = (ty - py) * size[2];
	return floor(sqrt(dx * dx + dy * dy) + 0.5);
end

function SimpleQoL_DistAnchor()
	SimpleQoLTargetDist:ClearAllPoints();
	if ( TargetName and TargetName:IsVisible() and TargetName:GetText() and TargetName:GetText() ~= "" ) then
		SimpleQoLTargetDist:SetPoint("BOTTOM", "TargetPortrait", "TOP", 0, 16);
	else
		SimpleQoLTargetDist:SetPoint("BOTTOM", "TargetPortrait", "TOP", 0, 4);
	end
end

-- The frame sits on the target frame, so this only runs while you have a target.
-- It is drawn below every window (bags, map ...).
function SimpleQoL_Dist_OnUpdate(elapsed)
	SimpleQoL_DistTime = SimpleQoL_DistTime - (elapsed or 0);
	if ( SimpleQoL_DistTime > 0 ) then
		return;
	end
	SimpleQoL_DistTime = SIMPLEQOL_DIST_RATE;
	local yards = SimpleQoL_On["targetdist"] and SimpleQoL_TargetDistance();
	if ( yards ) then
		SimpleQoL_DistAnchor();
		SimpleQoLTargetDistText:SetText(yards.." yds");
	else
		SimpleQoLTargetDistText:SetText("");
	end
end

-- AlphaUI's Target Distance off for good (its handlers do nothing, its module
-- cannot show it again). Done at load and again when entering the world.
function SimpleQoL_AlphaDistOff()
	if ( MainTargetDistanceFrame ) then
		MainTargetDistanceFrame:Hide();
		MainTargetDistanceFrame_OnUpdate = function() end;
		MainTargetDistanceFrame_OnEvent = function() end;
	end
	local module = Main and Main.GetModule and Main.GetModule("target_distance");
	if ( module ) then
		module.Enable = function()
			if ( MainTargetDistanceFrame ) then
				MainTargetDistanceFrame:Hide();
			end
		end;
		module.OnUILayoutChanged = function() end;
	end
end
SimpleQoL_AlphaDistOff();

function SimpleQoL_Dist_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	SimpleQoLTargetDistText:SetText("");
end

function SimpleQoL_Dist_OnEvent(event)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		SimpleQoL_AlphaDistOff();
	end
	-- New target: show its distance at once.
	SimpleQoL_DistTime = 0;
	SimpleQoLTargetDistText:SetText("");
end
