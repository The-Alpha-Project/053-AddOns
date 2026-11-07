--------------------------------------------------------------------------------
-- SimpleQoL, part 6: keeps automatic tracking recasts out of the way.
-- AlphaUI's Always Track casts Find Herbs / Minerals / Treasure again with
-- CastSpell. Such a cast may drop a spell held on the cursor, break Stealth,
-- cause "Can not use while mounted" (and with it a dismount), or take a
-- global cooldown in combat. Here it only goes through while you do nothing
-- else; AlphaUI tries again by itself a moment later.
-- Loaded last, so these wrappers are the outermost ones.
--------------------------------------------------------------------------------

SIMPLEQOL_TRACKING_SPELLS = { "Find Herbs", "Find Minerals", "Find Treasure" };
SIMPLEQOL_CURSOR_HOLD = 10;          -- seconds a picked up spell counts as held
SimpleQoL_SpellbookPress = nil;      -- 1 while the player clicks a spellbook spell
SimpleQoL_TrackingCastTime = -10;
SimpleQoL_CursorHeldTime = nil;

function SimpleQoL_IsTrackingSpell(name)
	if ( not name ) then
		return nil;
	end
	local i;
	for i = 1, getn(SIMPLEQOL_TRACKING_SPELLS) do
		if ( name == SIMPLEQOL_TRACKING_SPELLS[i] ) then
			return 1;
		end
	end
	return nil;
end

-- A tracking spell was cast automatically a moment ago, and nothing else
-- (an action button, a bag item) happened more recently: the error is from
-- that recast, hidden and never causing a dismount. A short window, and the
-- action/item check, keep this from also swallowing your own "mounted"
-- errors whenever Auto Track happens to be running.
function SimpleQoL_TrackingCastRecent()
	local t = SimpleQoL_TrackingCastTime;
	if ( GetTime() - t >= 0.3 ) then
		return nil;
	end
	if ( SimpleQoL_LastActionTime and SimpleQoL_LastActionTime >= t ) then
		return nil;
	end
	if ( SimpleQoL_LastItemTime and SimpleQoL_LastItemTime >= t ) then
		return nil;
	end
	return 1;
end

-- Something on the cursor: an item, or a spell / action picked up recently
-- (0.5.3 cannot tell whether a spell is still held).
function SimpleQoL_CursorBusy()
	if ( CursorHasItem and CursorHasItem() ) then
		return 1;
	end
	if ( SimpleQoL_CursorHeldTime and GetTime() - SimpleQoL_CursorHeldTime < SIMPLEQOL_CURSOR_HOLD ) then
		return 1;
	end
	return nil;
end

function SimpleQoL_IsMounted()
	if ( SimpleQoL_Mounted ) then
		return 1;
	end
	if ( Main and Main.API and Main.API.IsPlayerMounted and Main.API:IsPlayerMounted() ) then
		return 1;
	end
	return nil;
end

-- Eating or drinking: the food / drink buff icon.
function SimpleQoL_IsEating()
	if ( not GetPlayerBuff or not GetPlayerBuffTexture ) then
		return nil;
	end
	local i;
	for i = 0, 23 do
		local buffIndex = GetPlayerBuff(i, "HELPFUL");
		if ( buffIndex and buffIndex >= 0 ) then
			local texture = GetPlayerBuffTexture(buffIndex);
			if ( texture ) then
				local lower = strlower(texture);
				if ( strfind(lower, "fork", 1, 1) or strfind(lower, "inv_drink", 1, 1) ) then
					return 1;
				end
			end
		end
	end
	return nil;
end

function SimpleQoL_TrackingBlocked()
	return SimpleQoL_CursorBusy() or SimpleQoL_IsMounted() or SimpleQoL_Busy()
		or SimpleQoL_IsEating();
end

-- Cursor: picking up a spell or action; placing it (a swap leaves the old
-- action on the cursor).
SimpleQoL_Orig_PickupAction = PickupAction;
function PickupAction(id)
	if ( HasAction and HasAction(id) ) then
		SimpleQoL_CursorHeldTime = GetTime();
	end
	SimpleQoL_Orig_PickupAction(id);
end

SimpleQoL_Orig_PickupSpell = PickupSpell;
function PickupSpell(id, bookType)
	SimpleQoL_CursorHeldTime = GetTime();
	SimpleQoL_Orig_PickupSpell(id, bookType);
end

SimpleQoL_Orig_PlaceAction = PlaceAction;
function PlaceAction(id)
	local held = SimpleQoL_CursorHeldTime;
	local had = HasAction and HasAction(id);
	SimpleQoL_Orig_PlaceAction(id);
	if ( held ) then
		if ( had ) then
			SimpleQoL_CursorHeldTime = GetTime();
		else
			SimpleQoL_CursorHeldTime = nil;
		end
	end
end

-- A click on an action button while holding a spell places it there.
SimpleQoL_Orig_Guard_UseAction = UseAction;
function UseAction(id, checkCursor, onSelf)
	local held = SimpleQoL_CursorHeldTime and checkCursor and checkCursor ~= 0 and SimpleQoL_CursorBusy();
	local had = held and HasAction and HasAction(id);
	SimpleQoL_Orig_Guard_UseAction(id, checkCursor, onSelf);
	if ( held ) then
		if ( had ) then
			SimpleQoL_CursorHeldTime = GetTime();
		else
			SimpleQoL_CursorHeldTime = nil;
		end
	end
end

-- Spellbook clicks are the player's own casts.
if ( SpellButton_OnClick ) then
	SimpleQoL_Orig_SpellButton_OnClick = SpellButton_OnClick;
	function SpellButton_OnClick(drag)
		SimpleQoL_SpellbookPress = 1;
		SimpleQoL_Orig_SpellButton_OnClick(drag);
		SimpleQoL_SpellbookPress = nil;
	end
end

SimpleQoL_Orig_Guard_CastSpell = CastSpell;
function CastSpell(id, bookType)
	if ( not SimpleQoL_SpellbookPress and GetSpellName and SimpleQoL_IsTrackingSpell(GetSpellName(id, bookType)) ) then
		if ( SimpleQoL_TrackingBlocked() ) then
			return;
		end
		SimpleQoL_TrackingCastTime = GetTime();
	end
	SimpleQoL_Orig_Guard_CastSpell(id, bookType);
end


--------------------------------------------------------------------------------
-- Auto Track: keeps Find Herbs / Minerals / Treasure running. With AlphaUI
-- installed too, this one wins: AlphaUI's Always Track is paused for the
-- session (only its running state; its own setting is not changed), so the
-- two never cast against each other. Works in Stealth, since tracking does
-- not break it. Each spell has its own setting (off until you turn it on, in
-- the options window next to the spells you have); /qol autotrack turns all
-- of yours on, or all off when one is on.
--------------------------------------------------------------------------------
SimpleQoL_AutoTrackTime = 0;

-- key (saved as trk_<key>), spell, label
SIMPLEQOL_TRACK_KINDS = {
	{ "herbs", "Find Herbs", "Herbs", 40 },
	{ "ores", "Find Minerals", "Ores", 34 },
	{ "treasure", "Find Treasure", "Treasure", 58 },
};
SimpleQoL_TrackOn = {};            -- spell name -> 1
SimpleQoL_TrackCount = 0;          -- how many are on

function SimpleQoL_TrackRecount()
	local n, i = 0;
	for i = 1, getn(SIMPLEQOL_TRACK_KINDS) do
		if ( SimpleQoL_TrackOn[SIMPLEQOL_TRACK_KINDS[i][2]] ) then
			n = n + 1;
		end
	end
	SimpleQoL_TrackCount = n;
	SimpleQoL_AutoTrackTime = 0;       -- look at once after a change
end

function SimpleQoL_TrackSet(i, on)
	local kind = SIMPLEQOL_TRACK_KINDS[i];
	SimpleQoL_TrackOn[kind[2]] = on and 1 or nil;
	if ( SimpleSave_Set ) then
		SimpleSave_Set("SimpleQoL", "trk_"..kind[1], on and "1" or nil);
	end
	SimpleQoL_TrackRecount();
end

-- AlphaUI's Always Track: paused while it is running (looked at again with
-- each Auto Track check, in case AlphaUI starts it again).
function SimpleQoL_PauseAlphaTrack()
	if ( not Main or not Main.GetModule or not Main.IsModuleEnabled or not Main.IsModuleEnabled("always_track") ) then
		return;
	end
	local module = Main.GetModule("always_track");
	if ( module and module.runtimeEnabled ~= false ) then
		module.runtimeEnabled = false;
		if ( module.Disable ) then
			module:Disable();
		end
	end
end

function SimpleQoL_AutoTrackActive()
	return SimpleQoL_TrackCount > 0;
end

-- Spells of the three that are in the spell book: list of kind numbers.
function SimpleQoL_TrackKnown()
	local known = {};
	local list = SimpleQoL_TrackSlotList();
	local i, k;
	for i = 1, getn(SIMPLEQOL_TRACK_KINDS) do
		for k = 1, getn(list) do
			if ( list[k][3] == SIMPLEQOL_TRACK_KINDS[i][2] ) then
				tinsert(known, i);
				break
			end
		end
	end
	return known;
end

function SimpleQoL_AutoTrackToggle()
	local known = SimpleQoL_TrackKnown();
	if ( getn(known) == 0 ) then
		SimpleQoL_Print("you have no tracking spell.");
		return;
	end
	local on = SimpleQoL_TrackCount < 1;
	local i;
	for i = 1, getn(known) do
		SimpleQoL_TrackSet(known[i], on);
	end
	SimpleQoL_Print("Auto Track is "..(on and "on." or "off."));
	if ( SimpleQoL_TrackOptionsUpdate ) then
		SimpleQoL_TrackOptionsUpdate();
	end
end

-- Options window: "Auto Track" with one check box for each spell you have,
-- packed from the left so there is no gap when you have only some of them.
function SimpleQoL_TrackOptionsUpdate()
	local known = SimpleQoL_TrackKnown();
	local x = 20;
	local shown = {};
	local i, n, check, kind, text;
	for n = 1, getn(known) do
		shown[known[n]] = x;
		x = x + 26 + SIMPLEQOL_TRACK_KINDS[known[n]][4] + 6;
	end
	for i = 1, getn(SIMPLEQOL_TRACK_KINDS) do
		kind = SIMPLEQOL_TRACK_KINDS[i];
		check = getglobal("SimpleQoLTrack"..i);
		if ( check ) then
			if ( shown[i] ) then
				check:ClearAllPoints();
				check:SetPoint("TOPLEFT", "SimpleQoLOptionsFrame", "TOPLEFT", shown[i], -484);
				text = getglobal("SimpleQoLTrack"..i.."Text");
				if ( text ) then
					text:SetText(kind[3]);
					text:SetTextColor(1.0, 0.82, 0);
				end
				check:SetChecked(SimpleQoL_TrackOn[kind[2]] and 1 or 0);
				check:Enable();
				check:Show();
			else
				check:Hide();
			end
		end
	end
	if ( SimpleQoLOptionsTrackHeader ) then
		if ( getn(known) > 0 ) then
			SimpleQoLOptionsTrackHeader:Show();
		else
			SimpleQoLOptionsTrackHeader:Hide();
		end
	end
end

function SimpleQoLTrack_Toggle(i)
	local check = getglobal("SimpleQoLTrack"..i);
	SimpleQoL_TrackSet(i, check:GetChecked());
end

function SimpleQoLTrack_OnEnter(i)
	SimpleTooltip_SetOwner(this);
	local kind = SIMPLEQOL_TRACK_KINDS[i];
	GameTooltip:SetText("Auto Track "..kind[3]);
	GameTooltip:AddLine("|cffffffffKeeps "..kind[2].." on. Works together with the other tracking spells.|r");
	GameTooltip:Show();
end

-- Everything off (Defaults).
function SimpleQoL_TrackReset()
	local i;
	for i = 1, getn(SIMPLEQOL_TRACK_KINDS) do
		SimpleQoL_TrackSet(i, nil);
	end
end

local SimpleQoL_ActiveList = {};

local function SimpleQoL_ActiveTextures()
	local active = SimpleQoL_ActiveList;
	local i, k;
	for k in active do
		active[k] = nil;
	end
	for i = 0, 31 do
		local buffIndex = GetPlayerBuff(i, "HELPFUL|PASSIVE");
		if ( buffIndex and buffIndex >= 0 ) then
			local texture = GetPlayerBuffTexture(buffIndex);
			if ( texture ) then
				-- The seconds left when the client knows them, else true.
				local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(buffIndex);
				active[texture] = (left and left > 0) and left or true;
			end
		end
	end
	return active;
end

-- The next check waits for the buffs: while every tracking spell is on, the
-- next look is when the first one runs out, but never more than 15 seconds
-- away (also when the time is not known). Right after a cast, or while the check is
-- stopped (dead, blocked), it looks again in 2 seconds.
SIMPLEQOL_AUTOTRACK_SOON = 2;
SIMPLEQOL_AUTOTRACK_MAX = 15;
-- Gap between casting one missing tracking spell and trying the next: the
-- client counts a cast as briefly "in progress" even for these, so casting
-- two in the same look fails with "Another action is in progress". The same
-- gap AlphaUI's own Always Track uses.
SIMPLEQOL_AUTOTRACK_RETRY = 0.2;
SimpleQoL_AutoTrackWait = 2;

-- Fixed cast order when more than one is missing at once: Find Treasure,
-- then Find Herbs, then Find Minerals.
SIMPLEQOL_TRACK_ORDER = { "Find Treasure", "Find Herbs", "Find Minerals" };

-- A change in the buffs (a tracking buff taken away or run out) makes the
-- next look come within half a second, so it does not have to wait for the
-- schedule. Only moves a later look closer, never makes looks more often
-- than twice a second.
function SimpleQoL_AutoTrackEvent()
	if ( not SimpleQoL_AutoTrackActive() ) then
		return;
	end
	local now = GetTime();
	if ( SimpleQoL_AutoTrackTime + SimpleQoL_AutoTrackWait - now > 0.5 ) then
		SimpleQoL_AutoTrackTime = now;
		SimpleQoL_AutoTrackWait = 0.5;
	end
end

-- Sitting: the cast was refused ("You need to be standing up"). No sit API in
-- 0.5.3, so wait until the position changes (the character stood up and
-- moved); without a position, try again every 30 seconds.
function SimpleQoL_AutoTrackPos()
	if ( GetPlayerMapPosition ) then
		local x, y = GetPlayerMapPosition("player");
		return x, y;
	end
	return nil, nil;
end

function SimpleQoL_AutoTrackSitPause()
	SimpleQoL_SitX, SimpleQoL_SitY = SimpleQoL_AutoTrackPos();
	SimpleQoL_SitTime = GetTime();
	SimpleQoL_SitPaused = 1;
end

function SimpleQoL_AutoTrackSitCheck()
	local x, y = SimpleQoL_AutoTrackPos();
	if ( (x and (x ~= SimpleQoL_SitX or y ~= SimpleQoL_SitY) and (x ~= 0 or y ~= 0))
			or GetTime() - SimpleQoL_SitTime > 30 ) then
		SimpleQoL_SitPaused = nil;
		return nil;
	end
	return 1;
end

function SimpleQoL_AutoTrackUpdate()
	if ( not SimpleQoL_Loaded or GetTime() - SimpleQoL_AutoTrackTime < SimpleQoL_AutoTrackWait ) then
		return;
	end
	SimpleQoL_AutoTrackTime = GetTime();
	if ( SimpleQoL_SitPaused and SimpleQoL_AutoTrackSitCheck() ) then
		SimpleQoL_AutoTrackWait = 2;
		return;
	end
	SimpleQoL_AutoTrackWait = SIMPLEQOL_AUTOTRACK_SOON;
	SimpleQoL_PauseAlphaTrack();
	if ( not SimpleQoL_AutoTrackActive() ) then
		-- Nothing turned on: a switch sets the time to 0.
		SimpleQoL_AutoTrackWait = SIMPLEQOL_AUTOTRACK_MAX;
		return;
	end
	if ( not GetSpellName or not GetSpellTexture or not GetPlayerBuff or not GetPlayerBuffTexture ) then
		return;
	end
	if ( (UnitIsDead and UnitIsDead("player")) or (UnitIsGhost and UnitIsGhost("player")) or SimpleQoL_TrackingBlocked() ) then
		return;
	end
	local active;
	local list = SimpleQoL_TrackSlotList();
	local now = GetTime();
	local k, entry, texture;
	local wait = SIMPLEQOL_AUTOTRACK_MAX;
	local missing = {};
	for k = 1, getn(list) do
		entry = list[k];
		texture = SimpleQoL_TrackOn[entry[3]] and GetSpellTexture(entry[1], entry[2]);
		active = active or (texture and SimpleQoL_ActiveTextures());
		if ( texture ) then
			local state = active[texture];
			if ( not state ) then
				-- Not on. Look again soon, and it is a candidate to cast below
				-- (unless it was just tried and may still be settling).
				wait = min(wait, SIMPLEQOL_AUTOTRACK_RETRY);
				if ( now - (SimpleQoL_TrackLast[texture] or -100) >= SIMPLEQOL_AUTOTRACK_RETRY ) then
					missing[entry[3]] = entry;
				end
			elseif ( state ~= true ) then
				-- On with seconds left: look again shortly before it runs out,
				-- then right after.
				if ( state > 3 ) then
					wait = min(wait, state - 1);
				else
					wait = min(wait, state + 0.1);
				end
			end
		end
	end
	-- Cast at most one missing spell per look, in a fixed order (Find
	-- Treasure, then Find Herbs, then Find Minerals): the client still counts
	-- a cast as briefly "in progress" even though these have no cooldown or
	-- GCD, so casting a second one in the same look fails with "Another
	-- action is in progress".
	local p, name, toCast;
	for p = 1, getn(SIMPLEQOL_TRACK_ORDER) do
		name = SIMPLEQOL_TRACK_ORDER[p];
		if ( missing[name] ) then
			toCast = missing[name];
			break
		end
	end
	if ( toCast ) then
		SimpleQoL_TrackLast[GetSpellTexture(toCast[1], toCast[2])] = now;
		CastSpell(toCast[1], toCast[2]);
		SimpleQoL_AutoTrackWait = SIMPLEQOL_AUTOTRACK_RETRY;
		return;
	end
	SimpleQoL_AutoTrackWait = wait;
end

SimpleQoL_TrackLast = {};

-- The tracking spells in the spell book (slot, book). Found once and again
-- when the spell book changes (SPELLS_CHANGED), not every two seconds.
SimpleQoL_TrackSlots = nil;
SimpleQoL_TrackSlotsTime = 0;
function SimpleQoL_TrackSlotList()
	if ( SimpleQoL_TrackSlots ) then
		-- An empty list (spell book not ready yet, or no tracking spells) is
		-- looked for again after 30 seconds.
		if ( getn(SimpleQoL_TrackSlots) > 0 or GetTime() - SimpleQoL_TrackSlotsTime < 30 ) then
			return SimpleQoL_TrackSlots;
		end
	end
	local list = {};
	local books = { BOOKTYPE_SPELL or "spell", BOOKTYPE_ABILITY or "ability" };
	local b, slot, name, empty;
	-- A spell book can have empty slots between spells (racials such as Find
	-- Treasure can come after them): only 64 empty slots in a row end the search.
	for b = 1, 2 do
		empty = 0;
		for slot = 1, 1024 do
			name = GetSpellName(slot, books[b]);
			if ( not name or name == "" ) then
				empty = empty + 1;
				if ( empty >= 64 ) then
					break
				end
			else
				empty = 0;
				if ( SimpleQoL_IsTrackingSpell(name) ) then
					tinsert(list, { slot, books[b], name });
				end
			end
		end
	end
	SimpleQoL_TrackSlots = list;
	SimpleQoL_TrackSlotsTime = GetTime();
	return list;
end

function SimpleQoL_AutoTrackLoad()
	local i, kind;
	for i = 1, getn(SIMPLEQOL_TRACK_KINDS) do
		kind = SIMPLEQOL_TRACK_KINDS[i];
		SimpleQoL_TrackOn[kind[2]] = (SimpleSave_Get and SimpleSave_Get("SimpleQoL", "trk_"..kind[1]) == "1") and 1 or nil;
	end
	SimpleQoL_TrackRecount();
	SimpleQoL_PauseAlphaTrack();
end



--------------------------------------------------------------------------------
-- Cooldown numbers on the items in the bags (the same numbers as on the
-- action bars: seconds, or minutes from a minute up). The bag code (the
-- stock bags and AlphaUI's merged bag) calls ContainerFrame_UpdateCooldown for
-- every item button; each button seen there is remembered and its number is
-- kept up to date here. Ready number frames are handed out to the buttons
-- that have a cooldown.
--------------------------------------------------------------------------------
SIMPLEQOL_BAGCD_FRAMES = 12;
SimpleQoL_BagCDButtons = {};       -- button name -> bag id
SimpleQoL_BagCDTime = 0;

if ( ContainerFrame_UpdateCooldown ) then
	SimpleQoL_Orig_UpdateCooldown = ContainerFrame_UpdateCooldown;
	function ContainerFrame_UpdateCooldown(container, button)
		SimpleQoL_Orig_UpdateCooldown(container, button);
		if ( button and button.GetName and button:GetName() and container ) then
			SimpleQoL_BagCDButtons[button:GetName()] = container;
		end
	end
end

function SimpleQoL_BagCDString(remaining)
	if ( remaining >= 60 ) then
		return ceil(remaining / 60).."m";
	end
	return ceil(remaining);
end

SimpleQoL_BagCDOwner = {};

-- The number frames and their texts, looked up once by name (not every 0.25
-- seconds: that made a dozen new strings each time for the garbage collector).
SimpleQoL_BagCDFrames = {};
SimpleQoL_BagCDTexts = {};
function SimpleQoL_BagCDFrame(k)
	local f = SimpleQoL_BagCDFrames[k];
	if ( not f ) then
		f = getglobal("SimpleQoLBagCD"..k);
		SimpleQoL_BagCDFrames[k] = f;
		SimpleQoL_BagCDTexts[k] = getglobal("SimpleQoLBagCD"..k.."Text");
	end
	return f;
end

function SimpleQoL_BagCDUpdate()
	-- Every call: numbers whose item button is no longer shown (bag closed)
	-- go away at once.
	local k;
	for k = 1, (SimpleQoL_BagCDUsed or 0) do
		local f = SimpleQoL_BagCDFrame(k);
		local owner = SimpleQoL_BagCDOwner[k] and getglobal(SimpleQoL_BagCDOwner[k]);
		if ( f:IsVisible() and (not owner or not owner:IsVisible()) ) then
			f:Hide();
		end
	end
	local now = GetTime();
	if ( now - SimpleQoL_BagCDTime < 0.25 ) then
		return;
	end
	SimpleQoL_BagCDTime = now;
	local used = 0;
	if ( not (ActionBars_Loaded and not ActionBars_CooldownText) and GetContainerItemCooldown ) then
		local name, bag;
		for name, bag in SimpleQoL_BagCDButtons do
			local button = getglobal(name);
			if ( button and button:IsVisible() and used < SIMPLEQOL_BAGCD_FRAMES ) then
				local start, duration, enable = GetContainerItemCooldown(bag, button:GetID());
				if ( start and duration and start > 0 and duration > 1.6 and enable and enable > 0 ) then
					local remaining = start + duration - now;
					if ( remaining > 0 ) then
						used = used + 1;
						local frame = SimpleQoL_BagCDFrame(used);
						SimpleQoL_BagCDOwner[used] = name;
						frame:ClearAllPoints();
						frame:SetPoint("CENTER", name, "CENTER", 0, 0);
						frame:SetFrameLevel(button:GetFrameLevel() + 3);
						SimpleQoL_BagCDTexts[used]:SetText(SimpleQoL_BagCDString(remaining));
						frame:Show();
					end
				end
			end
		end
	end
	SimpleQoL_BagCDUsed = used;
	local i;
	for i = used + 1, SIMPLEQOL_BAGCD_FRAMES do
		local frame = SimpleQoL_BagCDFrame(i);
		if ( frame:IsVisible() ) then
			frame:Hide();
		end
	end
end

--------------------------------------------------------------------------------
-- The older Interface\Bindings.xml (053-AddOns) hides "ChatFrameCopyButton"
-- when the interface is toggled (Toggle UI key), a frame that no addon here
-- has. A stand-in with empty Hide and Show stops the error "attempt to index
-- global ChatFrameCopyButton". The real copy buttons are children of UIParent
-- and hide by themselves.
--------------------------------------------------------------------------------
if ( not ChatFrameCopyButton ) then
	ChatFrameCopyButton = {};
	function ChatFrameCopyButton.Hide() end
	function ChatFrameCopyButton.Show() end
end


--------------------------------------------------------------------------------
-- Herbs and ore on the minimap (Find Herbs, Find Minerals): the name in the
-- tooltip turns red when your Herbalism or Mining skill is too low for it.
-- The skill needed per node is from the server database (gameobject_template
-- with Lock.dbc); a node that is not in this list keeps the normal colour.
--------------------------------------------------------------------------------
SIMPLEQOL_NODE_SKILL = {
	["Bruiseweed"] = { "Herbalism", 100 },
	["Common Magebloom"] = { "Herbalism", 50 },
	["Copper Vein"] = { "Mining", 0 },
	["Crownroyal"] = { "Herbalism", 125 },
	["Earthroot"] = { "Herbalism", 15 },
	["Fadeleaf"] = { "Herbalism", 160 },
	["Firebloom"] = { "Herbalism", 205 },
	["Gold Vein"] = { "Mining", 125 },
	["Goldthorn"] = { "Herbalism", 215 },
	["Grave Moss"] = { "Herbalism", 120 },
	["Incendicite Mineral Vein"] = { "Mining", 65 },
	["Indurium Mineral Vein"] = { "Mining", 150 },
	["Iron Deposit"] = { "Mining", 100 },
	["Khadgar's Whisker"] = { "Herbalism", 185 },
	["Lesser Bloodstone Deposit"] = { "Mining", 75 },
	["Liferoot"] = { "Herbalism", 150 },
	["Mageroyal"] = { "Herbalism", 50 },
	["Mithril Deposit"] = { "Mining", 125 },
	["Ooze Covered Gold Vein"] = { "Mining", 125 },
	["Ooze Covered Mithril Deposit"] = { "Mining", 125 },
	["Ooze Covered Silver Vein"] = { "Mining", 75 },
	["Peacebloom Flower"] = { "Herbalism", 0 },
	["Silver Vein"] = { "Mining", 75 },
	["Silverleaf"] = { "Herbalism", 0 },
	["Silverleaf Bush"] = { "Herbalism", 0 },
	["Snakeroot"] = { "Herbalism", 15 },
	["Thornroot"] = { "Herbalism", 70 },
	["Tin Vein"] = { "Mining", 65 },
	["Wild Steelbloom"] = { "Herbalism", 115 },
	["Wintersbite"] = { "Herbalism", 195 },
};
SIMPLEQOL_SKILL_TYPES = { "class", "spec", "racial", "secondary", "proficiency" };
SimpleQoL_NodeText = nil;
SimpleQoL_NodeTime = -10;
SimpleQoL_NodeRed = nil;

-- Your rank in a skill (by name), or nil.
function SimpleQoL_SkillRank(skill)
	if ( not GetSkillLineInfo or not GetSkillByIndex ) then
		return nil;
	end
	local counts = { GetSkillLineInfo() };
	local i, j;
	for i = 1, getn(SIMPLEQOL_SKILL_TYPES) do
		for j = 1, (counts[i] or 0) do
			local name, level, rank = GetSkillByIndex(SIMPLEQOL_SKILL_TYPES[i], j);
			if ( name == skill ) then
				return rank;
			end
		end
	end
	return nil;
end

-- The client paints the minimap tooltip bright green and keeps repainting it,
-- so it is hidden (alpha 0) and our own dark one is shown in its place.
function SimpleQoL_NodeTip(visible)
	local tip = SimpleQoLNodeTip;
	if ( not tip ) then
		return;
	end
	if ( not visible ) then
		if ( SimpleQoL_NodeTipOn ) then
			SimpleQoL_NodeTipOn = nil;
			tip:Hide();
			MinimapTooltip:SetAlpha(1);
		end
		return;
	end
	SimpleQoL_NodeTipOn = 1;
	MinimapTooltip:SetAlpha(0);
	local text = MinimapTooltipText:GetText() or "";
	SimpleQoLNodeTipText:SetText(text);
	if ( SimpleQoL_NodeRed ) then
		SimpleQoLNodeTipText:SetTextColor(1.0, 0.1, 0.1);
	else
		SimpleQoLNodeTipText:SetTextColor(1.0, 0.82, 0.0);
	end
	local w = (SimpleQoLNodeTipText.GetStringWidth and SimpleQoLNodeTipText:GetStringWidth()) or MinimapTooltip:GetWidth();
	local lines = 1;
	local pos = 1;
	while ( strfind(text, "\n", pos, 1) ) do
		pos = strfind(text, "\n", pos, 1) + 1;
		lines = lines + 1;
	end
	tip:SetWidth(max(w, 20) + 18);
	tip:SetHeight(lines * 14 + 12);
	tip:ClearAllPoints();
	tip:SetPoint("CENTER", "MinimapTooltip", "CENTER", 0, 0);
	tip:Show();
end

-- Called from the main update: colours the minimap tooltip.
function SimpleQoL_NodeColor()
	if ( not MinimapTooltip or not MinimapTooltip:IsVisible() ) then
		SimpleQoL_NodeText = nil;
		SimpleQoL_NodeTip(nil);
		return;
	end
	local text = MinimapTooltipText:GetText();
	if ( not text ) then
		return;
	end
	local now = GetTime();
	if ( text == SimpleQoL_NodeText and now - SimpleQoL_NodeTime < 2 ) then
		SimpleQoL_NodeTip(1);
		return;
	end
	SimpleQoL_NodeText = text;
	SimpleQoL_NodeTime = now;
	local known, low = 0, 0;
	local pos = 1;
	while ( pos <= strlen(text) + 1 ) do
		local s = strfind(text, "\n", pos, 1);
		local line = strsub(text, pos, (s or (strlen(text) + 1)) - 1);
		local node = SIMPLEQOL_NODE_SKILL[line];
		if ( node ) then
			local rank = SimpleQoL_SkillRank(node[1]);
			if ( rank ) then
				known = known + 1;
				if ( rank < node[2] ) then
					low = low + 1;
				end
			end
		end
		if ( not s ) then
			break
		end
		pos = s + 1;
	end
	if ( known > 0 and low == known ) then
		SimpleQoL_NodeRed = 1;
	else
		SimpleQoL_NodeRed = nil;
	end
	SimpleQoL_NodeTip(1);
end


--------------------------------------------------------------------------------
-- Sell price while comparing: when an item is hovered at a vendor the client
-- also shows the equipped item beside it, and the price line of the hovered
-- item went missing (only the equipped item showed a price). The tooltips
-- clear each other's money line; here the line is put back for the tooltip
-- whose item did not change.
--------------------------------------------------------------------------------
SimpleQoL_MoneyMemo = {};

--------------------------------------------------------------------------------
-- "Sells for:" line on bag and loot items away from a vendor. The client only
-- gives the price at a vendor; the prices come from a list of the server's
-- items (SimpleQoL_Prices.lua), and prices seen at a vendor win over it.
--------------------------------------------------------------------------------
SimpleQoL_Prices = nil;            -- item name -> copper per item
SimpleQoL_PricesKeep = {};         -- names whose price differs from the list: only these are saved
SimpleQoL_PriceCount = nil;        -- stack size of the item in GameTooltip

-- Item name of GameTooltip. This client puts a line like 0xF1300000000000F5
-- (the object number) first; the name is then on the second line.
function SimpleQoL_TipName()
	local line = getglobal("GameTooltipTextLeft1");
	local name = line and line:GetText();
	if ( name and strfind(name, "^0x%x+$") ) then
		line = getglobal("GameTooltipTextLeft2");
		name = line and line:GetText();
	end
	return name;
end

function SimpleQoL_PricesLoad()
	if ( SimpleQoL_Prices ) then
		return;
	end
	SimpleQoL_Prices = {};
	local text = SimpleSave_Get and SimpleSave_Get("SimpleQoL", "Prices", "") or "";
	local s, e, name, price;
	local pos = 1;
	while ( pos <= strlen(text) ) do
		s, e, name, price = strfind(text, "^([^=;]+)=(%d+);", pos);
		if ( not s ) then
			break
		end
		SimpleQoL_Prices[name] = tonumber(price);
		SimpleQoL_PricesKeep[name] = 1;
		pos = e + 1;
	end
	-- Older versions saved every price seen: prices equal to the built-in
	-- list are not needed and are removed from the save.
	local list = SIMPLEQOL_PRICE_NAME;
	if ( list ) then
		local drop = {};
		foreach(SimpleQoL_Prices, function(n, p)
			if ( list[n] == p ) then
				tinsert(drop, n);
			end
		end);
		local i;
		for i = 1, getn(drop) do
			SimpleQoL_Prices[drop[i]] = nil;
			SimpleQoL_PricesKeep[drop[i]] = nil;
		end
		if ( getn(drop) > 0 ) then
			SimpleQoL_PricesSave();
		end
	end
end

-- Saves only the prices that differ from the built-in list (corrections).
function SimpleQoL_PricesSave()
	if ( not SimpleSave_Set ) then
		return;
	end
	local text = "";
	foreach(SimpleQoL_PricesKeep, function(name)
		if ( SimpleQoL_Prices[name] ) then
			text = text..name.."="..SimpleQoL_Prices[name]..";";
		end
	end);
	if ( text == "" ) then
		text = nil;
	end
	SimpleSave_Set("SimpleQoL", "Prices", text);
end

function SimpleQoL_LearnPrice(money)
	local count = SimpleQoL_PriceCount;
	local name = SimpleQoL_TipName();
	if ( not name or not count or count < 1 or not money or money < 1 ) then
		return;
	end
	SimpleQoL_PricesLoad();
	local unit = floor(money / count);
	if ( unit > 0 and not strfind(name, "[=;]") ) then
		local builtin = SIMPLEQOL_PRICE_NAME and SIMPLEQOL_PRICE_NAME[name];
		if ( builtin == unit ) then
			-- Same as the list: nothing to remember (a saved correction goes).
			SimpleQoL_Prices[name] = nil;
			if ( SimpleQoL_PricesKeep[name] ) then
				SimpleQoL_PricesKeep[name] = nil;
				SimpleQoL_PricesSave();
			end
		elseif ( SimpleQoL_Prices[name] ~= unit ) then
			SimpleQoL_Prices[name] = unit;
			-- An item missing in the list is remembered for this session only.
			if ( builtin ) then
				SimpleQoL_PricesKeep[name] = 1;
				SimpleQoL_PricesSave();
			end
		end
	end
end

function SimpleQoL_MoneyText(copper)
	local g = floor(copper / 10000);
	local sv = floor(copper / 100) - g * 100;
	local c = copper - g * 10000 - sv * 100;
	local text = "";
	if ( g > 0 ) then
		text = text..g.."|cffffd700g|r ";
	end
	if ( g > 0 or sv > 0 ) then
		text = text..sv.."|cffc7c7cfs|r ";
	end
	return text..c.."|cffeda55fc|r";
end

-- Price per item: learned at a vendor first, then the database list (by
-- item number when the link has it, else by name).
function SimpleQoL_UnitPrice(name, link)
	SimpleQoL_PricesLoad();
	if ( SimpleQoL_Prices[name] ) then
		return SimpleQoL_Prices[name];
	end
	if ( link ) then
		local s, e, id = strfind(link, "item:(%d+)");
		if ( id and SIMPLEQOL_PRICE_ID and SIMPLEQOL_PRICE_ID[tonumber(id)] ) then
			return SIMPLEQOL_PRICE_ID[tonumber(id)];
		end
	end
	return SIMPLEQOL_PRICE_NAME and SIMPLEQOL_PRICE_NAME[name];
end

function SimpleQoL_PriceHook(method, countFunc, linkFunc)
	local orig = GameTooltip[method];
	if ( not orig ) then
		return;
	end
	GameTooltip[method] = function(self, a, b, c)
		local count = self == GameTooltip and countFunc(a, b);
		if ( self == GameTooltip ) then
			SimpleQoL_PriceCount = count;
		end
		local r1, r2 = orig(self, a, b, c);
		if ( self ~= GameTooltip ) then
			return r1, r2;
		end
		local name = SimpleQoL_TipName();
		if ( not name or not count ) then
			return r1, r2;
		end
		if ( not (MerchantFrame and MerchantFrame:IsVisible()) ) then
			local unit = SimpleQoL_UnitPrice(name, linkFunc and linkFunc(a, b));
			if ( unit ) then
				self:AddLine("|cffa0a0a0Sells for: |r"..SimpleQoL_MoneyText(unit * count));
				self:Show();
			end
		end
		return r1, r2;
	end;
end

SimpleQoL_PriceHook("SetBagItem", function(bag, slot)
	local texture, count = GetContainerItemInfo(bag, slot);
	if ( texture ) then
		return count or 1;
	end
	return nil;
end, function(bag, slot)
	return GetContainerItemLink(bag, slot);
end);
SimpleQoL_PriceHook("SetLootItem", function(slot)
	local texture, name, quantity = GetLootSlotInfo(slot);
	if ( texture ) then
		return quantity or 1;
	end
	return nil;
end, function(slot)
	return GetLootSlotLink and GetLootSlotLink(slot);
end);

-- Quest rewards (quest window) and quest log rewards.
SimpleQoL_PriceHook("SetQuestItem", function(kind, index)
	local name, texture, count = GetQuestItemInfo(kind, index);
	if ( name ) then
		return count or 1;
	end
	return nil;
end, function(kind, index)
	return GetQuestItemLink and GetQuestItemLink(kind, index);
end);
SimpleQoL_PriceHook("SetQuestLogItem", function(kind, index)
	local name, texture, count;
	if ( kind == "choice" and GetQuestLogChoiceInfo ) then
		name, texture, count = GetQuestLogChoiceInfo(index);
	elseif ( GetQuestLogRewardInfo ) then
		name, texture, count = GetQuestLogRewardInfo(index);
	end
	if ( name ) then
		return count or 1;
	end
	return nil;
end, function(kind, index)
	return GetQuestLogItemLink and GetQuestLogItemLink(kind, index);
end);

-- Bank items: the bank slots are inventory slots; their tooltip comes from
-- SetInventoryItem (bag items of the bank bags too).
SimpleQoL_BankSlots = nil;
function SimpleQoL_IsBankSlot(slot)
	if ( not BankButtonIDToInvSlotID ) then
		return nil;
	end
	if ( not SimpleQoL_BankSlots ) then
		SimpleQoL_BankSlots = {};
		local i;
		for i = 1, (NUM_BANKGENERIC_SLOTS or 24) do
			SimpleQoL_BankSlots[BankButtonIDToInvSlotID(i)] = 1;
		end
		for i = 1, (NUM_BANKBAGSLOTS or 6) do
			SimpleQoL_BankSlots[BankButtonIDToInvSlotID(i, 1)] = 1;
		end
	end
	return SimpleQoL_BankSlots[slot];
end

SimpleQoL_PriceHook("SetInventoryItem", function(unit, slot)
	if ( unit == "player" and slot and SimpleQoL_IsBankSlot(slot) and GetInventoryItemTexture("player", slot) ) then
		return (GetInventoryItemCount and GetInventoryItemCount("player", slot)) or 1;
	end
	return nil;
end, function(unit, slot)
	return GetInventoryItemLink and GetInventoryItemLink("player", slot);
end);

-- Item links clicked in the chat open ItemRefTooltip: the same line there.
if ( ItemRefTooltip and ItemRefTooltip.SetHyperlink ) then
	SimpleQoL_Orig_SetHyperlink = ItemRefTooltip.SetHyperlink;
	ItemRefTooltip.SetHyperlink = function(self, link, a, b)
		local r1, r2 = SimpleQoL_Orig_SetHyperlink(self, link, a, b);
		if ( self ~= ItemRefTooltip or not link or strsub(link, 1, 5) ~= "item:" ) then
			return r1, r2;
		end
		local line = getglobal("ItemRefTooltipTextLeft1");
		local name = line and line:GetText();
		if ( name and strfind(name, "^0x%x+$") ) then
			line = getglobal("ItemRefTooltipTextLeft2");
			name = line and line:GetText();
		end
		if ( name and not (MerchantFrame and MerchantFrame:IsVisible()) ) then
			local unit = SimpleQoL_UnitPrice(name, link);
			if ( unit ) then
				self:AddLine("|cffa0a0a0Sells for: |r"..SimpleQoL_MoneyText(unit));
				self:Show();
			end
		end
		return r1, r2;
	end;
end

SimpleQoL_Orig_TooltipOnEvent = GameTooltip_OnEvent;
function GameTooltip_OnEvent()
	local name = this:GetName();
	if ( event == "TOOLTIP_ADD_MONEY" ) then
		-- No sell price on the item you wear (the comparison tooltips).
		if ( strsub(name or "", 1, 15) == "ShoppingTooltip" ) then
			return;
		end
		if ( arg1 == name ) then
			if ( name == "GameTooltip" and arg2 ) then
				SimpleQoL_LearnPrice(arg2);
			end
			local line = getglobal(name.."TextLeft1");
			SimpleQoL_MoneyMemo[name] = { arg2, line and line:GetText(), GetTime() };
		end
	elseif ( event == "CLEAR_TOOLTIP" ) then
		if ( arg1 and arg1 ~= name ) then
			return;
		end
		SimpleQoL_Orig_TooltipOnEvent();
		local memo = SimpleQoL_MoneyMemo[name];
		local line = getglobal(name.."TextLeft1");
		if ( not arg1 and memo and this:IsVisible() and GetTime() - memo[3] < 0.5 and line and line:GetText() == memo[2] ) then
			local moneyFrame = getglobal(name.."MoneyFrame");
			moneyFrame:SetPoint("LEFT", name.."TextLeft"..this:NumLines(), "LEFT", 4, 0);
			moneyFrame:Show();
			RefreshMoneyFrame(moneyFrame:GetName(), memo[1], 1, 1);
		else
			SimpleQoL_MoneyMemo[name] = nil;
		end
		return;
	end
	SimpleQoL_Orig_TooltipOnEvent();
end
