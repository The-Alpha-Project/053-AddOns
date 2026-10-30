--------------------------------------------------------------------------------
-- SimpleQoL, game menu: order of the buttons, Reload UI, the Addons window
-- and "Nameplates Always On".
--
-- Menu order: Options, Sound Options, Addons, (GM Panel, GMs only), Reload UI, Logout, Quit,
-- Continue. With AlphaUI its own Addons button (and its Reload UI button, when
-- that module is on) is kept and moved into this order; without AlphaUI we add
-- both buttons. A click on Addons opens a small window with one button per
-- addon: AlphaUI (if installed), SimpleQoL and ActionBars (if it runs).
-- SimpleMacros (if installed) gets its own menu button under Addons.
-- Key Bindings stay in Options, as in 0.5.3.
--------------------------------------------------------------------------------

-- Re-anchors the menu buttons. Runs every time the menu is shown, so it has
-- the last word after AlphaUI's own Main_AdjustGameMenu.
function SimpleQoL_AdjustGameMenu()
	if ( not GameMenuFrame or not GameMenuButtonOptions or not SimpleQoLMenuAddons or not SimpleQoLMenuReload ) then
		return;
	end
	-- AlphaUI's Addons button opens AlphaUI only: its click now opens our
	-- window (which lists AlphaUI too).
	if ( MainGameMenuButtonAddons_OnClick and not SIMPLEQOL_AUI_CLICK ) then
		SIMPLEQOL_AUI_CLICK = MainGameMenuButtonAddons_OnClick;
		MainGameMenuButtonAddons_OnClick = SimpleQoLAddons_AuiClick;
	end
	local addons = SimpleQoLMenuAddons;
	if ( MainGameMenuButtonAddons ) then
		addons = MainGameMenuButtonAddons;
		SimpleQoLMenuAddons:Hide();
	else
		SimpleQoLMenuAddons:Show();
	end
	local gm = nil;
	if ( SimpleGM_State == 1 and SimpleGMMenuButton ) then
		gm = SimpleGMMenuButton;
		gm:Show();
	elseif ( SimpleGMMenuButton ) then
		SimpleGMMenuButton:Hide();
	end
	local reload = SimpleQoLMenuReload;
	if ( MainGameMenuButtonReload and Main and Main.IsModuleEnabled and Main.IsModuleEnabled("reload_button") ) then
		reload = MainGameMenuButtonReload;
		SimpleQoLMenuReload:Hide();
	else
		SimpleQoLMenuReload:Show();
		if ( MainGameMenuButtonReload ) then
			MainGameMenuButtonReload:Hide();
		end
	end
	GameMenuButtonOptions:ClearAllPoints();
	GameMenuButtonOptions:SetPoint("CENTER", "GameMenuFrame", "TOP", 0, -37);
	GameMenuButtonSoundOptions:ClearAllPoints();
	GameMenuButtonSoundOptions:SetPoint("TOP", "GameMenuButtonOptions", "BOTTOM", 0, -1);
	addons:ClearAllPoints();
	addons:SetPoint("TOP", "GameMenuButtonSoundOptions", "BOTTOM", 0, -1);
	local above = addons;
	local macros = nil;
	if ( SimpleMacrosMenuButton ) then
		macros = SimpleMacrosMenuButton;
		macros:Show();
		macros:ClearAllPoints();
		macros:SetPoint("TOP", addons:GetName(), "BOTTOM", 0, -1);
		above = macros;
	end
	if ( gm ) then
		gm:ClearAllPoints();
		gm:SetPoint("TOP", above:GetName(), "BOTTOM", 0, -1);
		above = gm;
	end
	reload:ClearAllPoints();
	reload:SetPoint("TOP", above:GetName(), "BOTTOM", 0, -1);
	GameMenuButtonLogout:ClearAllPoints();
	GameMenuButtonLogout:SetPoint("TOP", reload:GetName(), "BOTTOM", 0, -1);
	local height = 222;
	if ( gm ) then
		height = height + 22;
	end
	if ( macros ) then
		height = height + 22;
	end
	GameMenuFrame:SetHeight(height);
end

-- AlphaUI's Addons button.
function SimpleQoLAddons_AuiClick()
	if ( PlaySound ) then
		PlaySound("igMainMenuOption");
	end
	SimpleQoLAddons_Open();
end

-- Opens the Addons window (or the only addon there is).
function SimpleQoLAddons_Open()
	local list = {};
	if ( SIMPLEQOL_AUI_CLICK and MainManagerFrame ) then
		tinsert(list, { "AlphaUI", "alphaui" });
	end
	tinsert(list, { "SimpleQoL", "simpleqol" });
	if ( ActionBarsOptionsFrame and not ActionBars_Off ) then
		tinsert(list, { "ActionBars", "actionbars" });
	end
	SimpleQoLAddons_List = list;
	if ( getn(list) == 1 ) then
		HideUIPanel(GameMenuFrame);
		SimpleQoLAddons_Go(list[1][2]);
		return;
	end
	local i;
	for i = 1, 4 do
		local button = getglobal("SimpleQoLAddonsButton"..i);
		if ( list[i] ) then
			button:SetText(list[i][1]);
			button:Show();
		else
			button:Hide();
		end
	end
	SimpleQoLAddonsFrame:SetHeight(getn(list) * 22 + 81);
	HideUIPanel(GameMenuFrame);
	SimpleQoLAddonsFrame:Show();
end

function SimpleQoLAddons_Click(index)
	local item = SimpleQoLAddons_List and SimpleQoLAddons_List[index];
	if ( not item ) then
		return;
	end
	if ( PlaySound ) then
		PlaySound("igMainMenuOption");
	end
	SimpleQoLAddonsFrame:Hide();
	SimpleQoLAddons_Go(item[2]);
end

function SimpleQoLAddons_Go(key)
	if ( key == "alphaui" ) then
		ShowUIPanel(MainManagerFrame);
	elseif ( key == "simpleqol" ) then
		SimpleQoLOptionsFrame:Show();
	elseif ( key == "actionbars" ) then
		ActionBarsOptionsFrame:Show();
	end
end

-- "Nameplates Always On": the name plates the V key shows, on from login.
-- changed = 1 when the box was just clicked (then off means hide again).
function SimpleQoL_NameplatesApply(changed)
	if ( not ShowNameplates or not HideNameplates ) then
		return;
	end
	if ( SimpleQoL_On["nameplates"] ) then
		ShowNameplates();
		NAMEPLATES_ON = 1;
	elseif ( changed ) then
		HideNameplates();
		NAMEPLATES_ON = nil;
	end
end
