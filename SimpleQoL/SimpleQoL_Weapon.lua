--------------------------------------------------------------------------------
-- SimpleQoL, part 5: the weapon buff timer (sharpening stones, poisons, oils)
-- next to the buffs, like the 1.12 temporary enchant buttons. (Walk to Spot
-- is now its own addon, SimpleWalk.)
--------------------------------------------------------------------------------
-- Weapon buff timer: the temporary enchant line of the weapon tooltip,
-- e.g. "Sharpened +2 (30 min)" (tested), read with a hidden tooltip.
--------------------------------------------------------------------------------

SIMPLEQOL_WEAPON_SLOTS = { "MainHandSlot", "SecondaryHandSlot" };
SimpleQoL_WeaponTime = 0;
SimpleQoL_WeaponBuffs = {};           -- index -> { slot id, text, expires }

-- Returns the buff line and its seconds left, or nil.
function SimpleQoL_WeaponScan(slotId)
	SimpleQoLScanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	if ( not SimpleQoLScanTooltip:SetInventoryItem("player", slotId) ) then
		return nil;
	end
	local i;
	for i = 2, SimpleQoLScanTooltip:NumLines() do
		local text = getglobal("SimpleQoLScanTooltipTextLeft"..i):GetText();
		if ( text ) then
			local s, e, name, amount, unit = strfind(text, "^(.+) %((%d+) (%a+)%)$");
			if ( name ) then
				unit = strlower(unit);
				if ( strsub(unit, 1, 3) == "min" ) then
					return name, amount * 60;
				elseif ( strsub(unit, 1, 3) == "sec" ) then
					return name, amount + 0;
				elseif ( strsub(unit, 1, 4) == "hour" ) then
					return name, amount * 3600;
				end
			end
		end
	end
	return nil;
end

function SimpleQoL_WeaponText(seconds)
	if ( seconds >= 3600 ) then
		return ceil(seconds / 3600).."h";
	elseif ( seconds >= 60 ) then
		return ceil(seconds / 60).."m";
	end
	return max(0, floor(seconds)).."s";
end

-- Frame names and frames looked up once (not new strings every second: the
-- buff row is checked all the time and again at every aura change).
SimpleQoL_BuffNames = {};            -- "BuffButton"..i
SimpleQoL_BuffButtons = {};
SimpleQoL_BuffTimeFrames = {};
SimpleQoL_BuffTimeTexts = {};
SimpleQoL_WeaponBuffFrames = {};
SimpleQoL_WeaponBuffIcons = {};
SimpleQoL_WeaponBuffDurations = {};
function SimpleQoL_BuffName(i)
	local name = SimpleQoL_BuffNames[i];
	if ( not name ) then
		name = "BuffButton"..i;
		SimpleQoL_BuffNames[i] = name;
	end
	return name;
end
function SimpleQoL_BuffButton(i)
	local button = SimpleQoL_BuffButtons[i];
	if ( not button ) then
		button = getglobal(SimpleQoL_BuffName(i));
		SimpleQoL_BuffButtons[i] = button;
	end
	return button;
end
function SimpleQoL_BuffTimeFrame(i)
	local frame = SimpleQoL_BuffTimeFrames[i];
	if ( not frame ) then
		frame = getglobal("SimpleQoLBuffTime"..i);
		if ( frame ) then
			SimpleQoL_BuffTimeFrames[i] = frame;
			SimpleQoL_BuffTimeTexts[i] = getglobal("SimpleQoLBuffTime"..i.."Text");
		end
	end
	return frame;
end
function SimpleQoL_WeaponBuffFrame(i)
	local frame = SimpleQoL_WeaponBuffFrames[i];
	if ( not frame ) then
		frame = getglobal("SimpleQoLWeaponBuff"..i);
		SimpleQoL_WeaponBuffFrames[i] = frame;
		SimpleQoL_WeaponBuffIcons[i] = getglobal("SimpleQoLWeaponBuff"..i.."Icon");
		SimpleQoL_WeaponBuffDurations[i] = getglobal("SimpleQoLWeaponBuff"..i.."Duration");
	end
	return frame;
end

-- The weapon buffs sit left of the last buff that is shown, so they never
-- cover a buff (the buff row grows to the left).
function SimpleQoL_WeaponPlace()
	SimpleQoL_WeaponPlaceDirty = nil;
	if ( not BuffButton0 or not SimpleQoLWeaponBuff1 ) then
		return;
	end
	local last = SimpleQoL_BuffName(0);
	local i;
	for i = 1, 23 do
		local button = SimpleQoL_BuffButton(i);
		if ( button and button:IsVisible() ) then
			last = SimpleQoL_BuffName(i);
		end
	end
	local empty = last == "BuffButton0" and not BuffButton0:IsVisible();
	local key = last;
	if ( empty ) then
		key = "none";
	end
	if ( key == SimpleQoL_WeaponAnchor ) then
		return;
	end
	SimpleQoL_WeaponAnchor = key;
	SimpleQoLWeaponBuff1:ClearAllPoints();
	if ( empty ) then
		SimpleQoLWeaponBuff1:SetPoint("TOPRIGHT", "BuffButton0", "TOPRIGHT", 0, 0);
	else
		SimpleQoLWeaponBuff1:SetPoint("TOPRIGHT", last, "TOPLEFT", -6, 0);
	end
end

-- Time left under every buff and debuff that runs out (the stock buttons show
-- none). Minutes from a minute up, hours from an hour up, else seconds.
SimpleQoL_BuffTimeUsed = {};

function SimpleQoL_BuffTimeUpdate()
	-- AlphaUI's Buff Durations already draws the same numbers: then not twice.
	local on = SimpleQoL_On["weapontimer"] and GetPlayerBuffTimeLeft and not (SimpleQoL_AlphaUIHas and SimpleQoL_AlphaUIHas("buff_durations"));
	local i;
	for i = 0, 23 do
		local button = SimpleQoL_BuffButton(i);
		local frame = SimpleQoL_BuffTimeFrame(i);
		if ( frame ) then
			local text = nil;
			if ( on and button and button:IsVisible() and button.buffIndex and button.untilCancelled ~= 1 ) then
				local left = GetPlayerBuffTimeLeft(button.buffIndex);
				if ( left and left > 0 ) then
					text = SimpleQoL_WeaponText(left);
				end
			end
			if ( text ) then
				if ( SimpleQoL_BuffTimeUsed[i] ~= "b" ) then
					SimpleQoL_BuffTimeUsed[i] = "b";
					frame:ClearAllPoints();
					frame:SetPoint("TOP", SimpleQoL_BuffName(i), "BOTTOM", 0, 0);
				end
				SimpleQoL_BuffTimeTexts[i]:SetText(text);
				frame:Show();
			elseif ( frame:IsVisible() ) then
				SimpleQoL_BuffTimeUsed[i] = nil;
				frame:Hide();
			end
		end
	end
end

function SimpleQoL_WeaponUpdate(force)
	local now = GetTime();
	if ( SimpleQoL_WeaponPlaceDirty or now - (SimpleQoL_WeaponPlaceTime or 0) > 1 ) then
		SimpleQoL_WeaponPlaceTime = now;
		SimpleQoL_WeaponPlace();
	end
	if ( not force and now - SimpleQoL_WeaponTime < 1 ) then
		return;
	end
	local rescan = force or now - (SimpleQoL_WeaponScanTime or 0) > 20;
	SimpleQoL_WeaponTime = now;
	SimpleQoL_BuffTimeUpdate();
	local shown = 0;
	local i;
	for i = 1, 2 do
		local slotId = GetInventorySlotInfo(SIMPLEQOL_WEAPON_SLOTS[i]);
		local buff = SimpleQoL_WeaponBuffs[i];
		if ( rescan ) then
			local name, seconds = nil, nil;
			if ( SimpleQoL_On["weapontimer"] and slotId ) then
				name, seconds = SimpleQoL_WeaponScan(slotId);
			end
			-- The tooltip only gives whole minutes: keep counting down between scans.
			if ( name and not ( buff and buff.name == name and buff.expires - now <= seconds and buff.expires - now > seconds - 60 ) ) then
				buff = { slot = slotId, name = name, expires = now + seconds };
			elseif ( not name ) then
				buff = nil;
			end
			SimpleQoL_WeaponBuffs[i] = buff;
		end
		if ( buff and SimpleQoL_On["weapontimer"] and buff.expires > now ) then
			shown = shown + 1;
			local button = SimpleQoL_WeaponBuffFrame(shown);
			button.slot = buff.slot;
			SimpleQoL_WeaponBuffIcons[shown]:SetTexture(GetInventoryItemTexture("player", buff.slot));
			SimpleQoL_WeaponBuffDurations[shown]:SetText(SimpleQoL_WeaponText(buff.expires - now));
			button:Show();
		end
	end
	if ( rescan ) then
		SimpleQoL_WeaponScanTime = now;
	end
	for i = shown + 1, 2 do
		SimpleQoL_WeaponBuffFrame(i):Hide();
	end
end

function SimpleQoL_WeaponBuff_OnEnter()
	if ( not this.slot ) then
		return;
	end
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetInventoryItem("player", this.slot);
	GameTooltip:Show();
end


--------------------------------------------------------------------------------
-- Events and update (SimpleQoLWeaponFrame)
--------------------------------------------------------------------------------

function SimpleQoL_Weapon_OnLoad()
	this:RegisterEvent("UNIT_INVENTORY_CHANGED");
	this:RegisterEvent("PLAYER_AURAS_CHANGED");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
end

function SimpleQoL_Weapon_OnEvent(event)
	if ( event == "PLAYER_AURAS_CHANGED" ) then
		SimpleQoL_WeaponPlaceDirty = 1;
		if ( SimpleQoL_AutoTrackEvent ) then
			SimpleQoL_AutoTrackEvent();
		end
	elseif ( event == "PLAYER_ENTERING_WORLD" or arg1 == "player" ) then
		SimpleQoL_WeaponNeedScan = 1;
	end
end

function SimpleQoL_Weapon_OnUpdate()
	if ( not SimpleQoL_Loaded ) then
		return;
	end
	if ( SimpleQoL_WeaponNeedScan ) then
		SimpleQoL_WeaponNeedScan = nil;
		SimpleQoL_WeaponUpdate(1);
	else
		SimpleQoL_WeaponUpdate();
	end
end
