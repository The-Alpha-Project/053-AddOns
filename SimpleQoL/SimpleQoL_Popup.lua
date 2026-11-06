--------------------------------------------------------------------------------
-- SimpleQoL: "Follow" in the right-click menu of a player (only when you are
-- near enough to follow, like /follow), and the full spell tooltip on action
-- buttons (the stock action tooltip only shows name and rank).
--------------------------------------------------------------------------------

-- Follow in the unit menu. Distance 4 is the follow distance of
-- CheckInteractDistance; the stock menu code greys the entry out when you are
-- too far away, like Trade, Inspect and Duel.
function SimpleQoL_Popup_AddFollow(which)
	if ( not UnitPopupMenus or not UnitPopupButtons or not which ) then
		return;
	end
	if ( which ~= "PARTY" and which ~= "PLAYER" ) then
		return;
	end
	local old = UnitPopupMenus[which];
	if ( not old ) then
		return;
	end
	local i;
	for i = 1, getn(old) do
		if ( old[i] == "FOLLOW" ) then
			return;
		end
	end
	UnitPopupButtons["FOLLOW"] = { text = "Follow", dist = 0 };
	local new = { };
	local n = 0;
	for i = 1, getn(old) do
		n = n + 1;
		new[n] = old[i];
		if ( old[i] == "DUEL" ) then
			n = n + 1;
			new[n] = "FOLLOW";
		end
	end
	if ( n == getn(old) ) then
		return;
	end
	-- the stock frame has UNITPOPUP_NUMBUTTONS buttons only
	if ( n > UNITPOPUP_NUMBUTTONS ) then
		return;
	end
	UnitPopupMenus[which] = new;
end

SimpleQoL_Popup_AddFollow("PARTY");
SimpleQoL_Popup_AddFollow("PLAYER");

-- Done again each time a menu opens, in case the menus were replaced later.
SimpleQoL_Orig_Popup_ShowMenu = UnitPopup_ShowMenu;
function UnitPopup_ShowMenu(which, unit)
	SimpleQoL_Popup_AddFollow(which);
	SimpleQoL_Orig_Popup_ShowMenu(which, unit);
end

-- Is the unit near enough to follow? Distance code 4 (follow) is not known to
-- every client, so several checks are tried: 4, then the AlphaUI distance text
-- for your target (28 yards or less), then the trade and duel distances.
function SimpleQoL_FollowInRange(unit)
	if ( not unit or not UnitExists(unit) ) then
		return nil;
	end
	if ( CheckInteractDistance ) then
		if ( CheckInteractDistance(unit, 4) ) then
			return 1;
		end
		if ( CheckInteractDistance(unit, 2) or CheckInteractDistance(unit, 3) ) then
			return 1;
		end
	end
	if ( MainTargetDistanceText and MainTargetDistanceText.GetText and UnitIsUnit(unit, "target") ) then
		local text = MainTargetDistanceText:GetText();
		if ( text ) then
			local _, _, yards = strfind(text, "(%d+)");
			if ( yards and tonumber(yards) <= 28 ) then
				return 1;
			end
		end
	end
	return nil;
end

-- The stock OnUpdate enables every button; Follow is then greyed by us.
SimpleQoL_Orig_Popup_OnUpdate = UnitPopup_OnUpdate;
function UnitPopup_OnUpdate(elapsed)
	SimpleQoL_Orig_Popup_OnUpdate(elapsed);
	if ( not UnitPopup or not UnitPopup:IsVisible() ) then
		return;
	end
	local menu = UnitPopupMenus[UnitPopup.which];
	if ( not menu ) then
		return;
	end
	local index, value;
	local count = 0;
	for index, value in menu do
		if ( UnitPopupShown[index] == 1 ) then
			count = count + 1;
			if ( value == "FOLLOW" ) then
				local button = getglobal("UnitPopupButton"..count);
				if ( button ) then
					if ( SimpleQoL_FollowInRange(UnitPopup.unit) ) then
						button:Enable();
					else
						button:Disable();
					end
				end
			end
		end
	end
end

SimpleQoL_Orig_Popup_OnClick = UnitPopup_OnClick;
function UnitPopup_OnClick(index)
	local menu = UnitPopup and UnitPopupMenus[UnitPopup.which];
	if ( menu and menu[index] == "FOLLOW" ) then
		FollowUnit(UnitPopup.unit);
		UnitPopup:Hide();
		return;
	end
	SimpleQoL_Orig_Popup_OnClick(index);
end

-- Full tooltip for spells on the action bars: the stock one shows two lines;
-- the same spell in the spellbook gives the whole text, so that is shown.
SimpleQoL_Orig_SetAction = GameTooltip.SetAction;
GameTooltip.SetAction = function(self, id)
	local result = SimpleQoL_Orig_SetAction(self, id);
	if ( not result or not GetSpellName ) then
		return result;
	end
	local line = getglobal("GameTooltipTextLeft1");
	local name = line and line:GetText();
	if ( not name or (self.NumLines and self:NumLines() > 2) ) then
		return result;
	end
	local rankLine = getglobal("GameTooltipTextLeft2");
	local rank = rankLine and rankLine:GetText();
	local i = 1;
	local spell, spellRank = GetSpellName(i, BOOKTYPE_SPELL);
	while ( spell ) do
		if ( spell == name and (not rank or rank == "" or spellRank == rank) ) then
			self:SetSpell(i, BOOKTYPE_SPELL);
			return result;
		end
		i = i + 1;
		spell, spellRank = GetSpellName(i, BOOKTYPE_SPELL);
	end
	return result;
end
