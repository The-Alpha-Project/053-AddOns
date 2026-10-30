--------------------------------------------------------------------------------
-- SimpleQoL guild tab for WoW 0.5.3.
-- Layout and behaviour ported from AlphaUI's Guild Frame by Devwar (used with
-- his permission). It is only added when AlphaUI's own guild tab is not active.
-- The roster comes from SimpleQoL's addon API code in SimpleQoL_Extra.lua
-- (SimpleQoL_Guild), which also gives the online / offline chat messages.
--------------------------------------------------------------------------------

SIMPLEQOL_GUILD_MAX_ROWS = 12;
SIMPLEQOL_GUILD_ROW_HEIGHT = 16;
SIMPLEQOL_GUILD_REFRESH_TIMEOUT = 3.5;
SIMPLEQOL_GUILD_ACTION_LEFT = 21;
SIMPLEQOL_GUILD_ACTION_RIGHT = 341;
SIMPLEQOL_GUILD_ACTION_BOTTOM = 107;
SIMPLEQOL_GUILD_ACTION_WIDTH = 60;

SIMPLEQOL_RANK_NAMES = { [0] = "Guild Master", [1] = "Officer", [2] = "Veteran", [3] = "Member", [4] = "Initiate" };
SIMPLEQOL_CLASS_NAMES = { [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue", [5] = "Priest", [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [11] = "Druid" };
SIMPLEQOL_CLASS_COLORS = {
	[1] = { 0.78, 0.61, 0.43 },
	[2] = { 0.96, 0.55, 0.73 },
	[3] = { 0.67, 0.83, 0.45 },
	[4] = { 1.00, 0.96, 0.41 },
	[5] = { 1.00, 1.00, 1.00 },
	[7] = { 0.00, 0.44, 0.87 },
	[8] = { 0.41, 0.80, 0.94 },
	[9] = { 0.58, 0.51, 0.79 },
	[11] = { 1.00, 0.49, 0.04 },
};

SimpleQoL_GuildTabActive = nil;
SimpleQoL_GuildHooked = nil;
SimpleQoL_GuildSortField = "rank";
SimpleQoL_GuildSortAsc = 1;
SimpleQoL_GuildShowOffline = nil;
SimpleQoL_GuildScroll = 0;
SimpleQoL_GuildFiltered = {};
SimpleQoL_GuildSelected = nil;
SimpleQoL_GuildPending = nil;      -- GetTime() when a roster change was asked for

-- AlphaUI's guild tab is used when AlphaUI is installed and its module is on.
function SimpleQoL_AlphaUIGuild()
	if ( not getglobal("MainGuildFrame") ) then
		return nil;
	end
	if ( Main and Main.IsModuleEnabled ) then
		return Main.IsModuleEnabled("guild_frame");
	end
	return 1;
end

function SimpleQoL_GuildClassName(classId)
	return SIMPLEQOL_CLASS_NAMES[classId] or "Unknown";
end

function SimpleQoL_GuildRankName(rank)
	return SIMPLEQOL_RANK_NAMES[rank] or ("Rank "..rank);
end

-- Roster members as tables { name, level, classId, rank, online }.
function SimpleQoL_GuildMembers()
	local list = {};
	local members = SimpleQoL_Guild and SimpleQoL_Guild.members;
	local i;
	if ( members ) then
		for i = 1, getn(members) do
			local m = members[i];
			tinsert(list, { name = m[1], level = m[2], classId = m[3], rank = m[4], online = m[5] });
		end
	end
	return list;
end

function SimpleQoL_GuildPlayerRank()
	local me = UnitName("player");
	local members = SimpleQoL_Guild and SimpleQoL_Guild.members;
	local i;
	if ( members and me ) then
		for i = 1, getn(members) do
			if ( members[i][1] == me ) then
				return members[i][4];
			end
		end
	end
	return 99;
end

function SimpleQoL_GuildSelectedMember()
	local i;
	if ( not SimpleQoL_GuildSelected ) then
		return nil;
	end
	for i = 1, getn(SimpleQoL_GuildFiltered) do
		if ( SimpleQoL_GuildFiltered[i].name == SimpleQoL_GuildSelected ) then
			return SimpleQoL_GuildFiltered[i];
		end
	end
	return nil;
end

function SimpleQoL_GuildSortValue(member, field)
	if ( field == "level" ) then
		return member.level or 0;
	elseif ( field == "class" ) then
		return SimpleQoL_GuildClassName(member.classId);
	elseif ( field == "rank" ) then
		return member.rank or 99;
	elseif ( field == "online" ) then
		if ( member.online ) then
			return 0;
		end
		return 1;
	end
	return member.name or "";
end

function SimpleQoL_GuildLess(left, right)
	local a = SimpleQoL_GuildSortValue(left, SimpleQoL_GuildSortField);
	local b = SimpleQoL_GuildSortValue(right, SimpleQoL_GuildSortField);
	if ( a == b ) then
		-- Secondary order: rank, then name.
		local lr = left.rank or 99;
		local rr = right.rank or 99;
		if ( lr ~= rr ) then
			return lr < rr;
		end
		return (left.name or "") < (right.name or "");
	end
	if ( SimpleQoL_GuildSortAsc ) then
		return a < b;
	end
	return a > b;
end

function SimpleQoL_GuildFilterAndSort()
	local all = SimpleQoL_GuildMembers();
	local list = {};
	local i, j;
	for i = 1, getn(all) do
		if ( SimpleQoL_GuildShowOffline or all[i].online ) then
			-- Insertion sort: guild rosters are small.
			j = getn(list);
			tinsert(list, all[i]);
			while ( j > 0 and SimpleQoL_GuildLess(list[j + 1], list[j]) ) do
				list[j], list[j + 1] = list[j + 1], list[j];
				j = j - 1;
			end
		end
	end
	SimpleQoL_GuildFiltered = list;
end

function SimpleQoL_GuildUpdateHeader()
	local guildName = GetGuildInfo and GetGuildInfo("player");
	if ( not guildName or guildName == "" ) then
		guildName = (SimpleQoL_Guild and SimpleQoL_Guild.name) or "Guild";
		if ( guildName == "" ) then
			guildName = "Guild";
		end
	end
	FriendsFrameTitleText:SetText(guildName);
	SimpleQoLGuildFrameMotdLabel:SetText("Guild Message Of The Day:");
	SimpleQoLGuildFrameMotd:SetText((SimpleQoL_Guild and SimpleQoL_Guild.motd) or "");
	if ( SimpleQoL_GuildNoAPI ) then
		SimpleQoLGuildFrameTotalText:SetText("|cffff8080This server has no guild roster for addons.|r");
	elseif ( not SimpleQoL_Guild or not SimpleQoL_Guild.loaded ) then
		SimpleQoLGuildFrameTotalText:SetText("Loading the guild roster...");
	else
		local total = SimpleQoL_Guild.total or 0;
		local online = SimpleQoL_Guild.online or 0;
		local word = "Guild Members";
		if ( total == 1 ) then
			word = "Guild Member";
		end
		SimpleQoLGuildFrameTotalText:SetText("|cffffffff"..total.."|r "..word.." (|cffffffff"..online.."|r |cff33ff33Online|r)");
	end
end

-- Officer buttons are spread evenly over the row above Whisper / Group Invite.
function SimpleQoL_GuildLayoutOfficerButtons(buttons)
	local count = getn(buttons);
	local left = SIMPLEQOL_GUILD_ACTION_LEFT;
	local total = SIMPLEQOL_GUILD_ACTION_RIGHT - left;
	local gap = 0;
	local i;
	if ( count <= 0 ) then
		return;
	end
	if ( count > 1 ) then
		gap = (total - count * SIMPLEQOL_GUILD_ACTION_WIDTH) / (count - 1);
	else
		left = left + (total - SIMPLEQOL_GUILD_ACTION_WIDTH) / 2;
	end
	for i = 1, count do
		buttons[i]:ClearAllPoints();
		buttons[i]:SetPoint("BOTTOMLEFT", "SimpleQoLGuildFrame", "BOTTOMLEFT", left + (i - 1) * (SIMPLEQOL_GUILD_ACTION_WIDTH + gap), SIMPLEQOL_GUILD_ACTION_BOTTOM);
	end
end

function SimpleQoL_GuildSetButton(button, show, enable, list)
	if ( not show ) then
		button:Hide();
		return;
	end
	button:Show();
	tinsert(list, button);
	if ( enable and not SimpleQoL_GuildPending ) then
		button:Enable();
	else
		button:Disable();
	end
end

function SimpleQoL_GuildUpdateButtons()
	local myRank = SimpleQoL_GuildPlayerRank();
	local selected = SimpleQoL_GuildSelectedMember();
	local isSelf = selected and selected.name == UnitName("player");
	local other = selected and not isSelf;
	-- Fixed rank rights in alpha-core: Officer or GM manage members, GM sets the MOTD.
	local canManage = myRank <= 1;
	local list = {};
	SimpleQoL_GuildSetButton(SimpleQoLGuildFramePromoteButton, canManage, other and selected.rank > myRank + 1, list);
	SimpleQoL_GuildSetButton(SimpleQoLGuildFrameDemoteButton, canManage, other and selected.rank > myRank and selected.rank < 4, list);
	SimpleQoL_GuildSetButton(SimpleQoLGuildFrameRemoveButton, canManage, other and selected.rank > myRank, list);
	SimpleQoL_GuildSetButton(SimpleQoLGuildFrameInviteButton, canManage, 1, list);
	SimpleQoL_GuildSetButton(SimpleQoLGuildFrameSetMotdButton, myRank == 0, 1, list);
	SimpleQoL_GuildLayoutOfficerButtons(list);
	if ( other and selected.online ) then
		SimpleQoLGuildFrameWhisperButton:Enable();
		SimpleQoLGuildFrameGroupInviteButton:Enable();
	else
		SimpleQoLGuildFrameWhisperButton:Disable();
		SimpleQoLGuildFrameGroupInviteButton:Disable();
	end
end

function SimpleQoL_GuildUpdateRows()
	local i;
	for i = 1, SIMPLEQOL_GUILD_MAX_ROWS do
		local prefix = "SimpleQoLGuildRow"..i;
		local row = getglobal(prefix);
		local member = SimpleQoL_GuildFiltered[SimpleQoL_GuildScroll + i];
		if ( member ) then
			local color = SIMPLEQOL_CLASS_COLORS[member.classId] or { 0.5, 0.5, 0.5 };
			local r, g, b = color[1], color[2], color[3];
			if ( not member.online ) then
				r, g, b = 0.5, 0.5, 0.5;
			end
			getglobal(prefix.."Name"):SetText(member.name);
			getglobal(prefix.."Name"):SetTextColor(r, g, b);
			getglobal(prefix.."Level"):SetText(""..(member.level or ""));
			getglobal(prefix.."Class"):SetText(SimpleQoL_GuildClassName(member.classId));
			getglobal(prefix.."Class"):SetTextColor(r, g, b);
			getglobal(prefix.."Rank"):SetText(SimpleQoL_GuildRankName(member.rank or 99));
			if ( member.online ) then
				getglobal(prefix.."Online"):SetText("Online");
				getglobal(prefix.."Online"):SetTextColor(0.2, 1.0, 0.2);
			else
				getglobal(prefix.."Online"):SetText("Offline");
				getglobal(prefix.."Online"):SetTextColor(0.5, 0.5, 0.5);
			end
			if ( SimpleQoL_GuildSelected == member.name ) then
				row:LockHighlight();
			else
				row:UnlockHighlight();
			end
			row:Show();
		else
			row:UnlockHighlight();
			row:Hide();
		end
	end
end

function SimpleQoL_GuildUpdateScrollBar()
	local total = getn(SimpleQoL_GuildFiltered);
	local maxScroll = max(0, total - SIMPLEQOL_GUILD_MAX_ROWS);
	SimpleQoL_GuildScroll = min(max(SimpleQoL_GuildScroll, 0), maxScroll);
	FauxScrollFrame_Update(SimpleQoLGuildFrameScrollFrame, total, SIMPLEQOL_GUILD_MAX_ROWS, SIMPLEQOL_GUILD_ROW_HEIGHT);
	FauxScrollFrame_SetOffset(SimpleQoLGuildFrameScrollFrame, SimpleQoL_GuildScroll);
	SimpleQoLGuildFrameScrollFrameScrollBar:SetValue(SimpleQoL_GuildScroll * SIMPLEQOL_GUILD_ROW_HEIGHT);
end

function SimpleQoL_GuildRefresh()
	SimpleQoL_GuildFilterAndSort();
	SimpleQoL_GuildUpdateHeader();
	SimpleQoL_GuildUpdateScrollBar();
	SimpleQoL_GuildUpdateRows();
	SimpleQoL_GuildUpdateButtons();
end

-- Called by the roster code when a new roster arrived (or the API is missing).
function SimpleQoL_GuildFrame_Update()
	SimpleQoL_GuildPending = nil;
	if ( SimpleQoLGuildFrame and SimpleQoLGuildFrame:IsVisible() ) then
		SimpleQoL_GuildRefresh();
	end
end

-- Ask the roster code for a new roster as soon as possible.
function SimpleQoL_GuildRequestSoon(delay)
	SimpleQoL_GuildNextTime = GetTime() + (delay or 0);
end

-- After promote / demote / remove / MOTD: buttons wait for the new roster.
function SimpleQoL_GuildChanged()
	if ( SimpleQoLGuildFrame and SimpleQoLGuildFrame:IsVisible() ) then
		SimpleQoL_GuildPending = GetTime();
		SimpleQoL_GuildRequestSoon(0.5);
		SimpleQoL_GuildUpdateButtons();
	end
end

function SimpleQoL_GuildSetSort(field, ascending)
	if ( SimpleQoL_GuildSortField == field ) then
		if ( SimpleQoL_GuildSortAsc ) then
			SimpleQoL_GuildSortAsc = nil;
		else
			SimpleQoL_GuildSortAsc = 1;
		end
	else
		SimpleQoL_GuildSortField = field;
		SimpleQoL_GuildSortAsc = ascending;
	end
	SimpleQoL_GuildRefresh();
end

function SimpleQoLGuildFrameScrollFrame_OnVerticalScroll()
	FauxScrollFrame_OnVerticalScroll(SIMPLEQOL_GUILD_ROW_HEIGHT, SimpleQoL_GuildScrolled);
end

function SimpleQoL_GuildScrolled()
	SimpleQoL_GuildScroll = FauxScrollFrame_GetOffset(SimpleQoLGuildFrameScrollFrame) or 0;
	SimpleQoL_GuildUpdateRows();
end

function SimpleQoLGuildFrame_OnMouseWheel(delta)
	if ( not SimpleQoLGuildFrameScrollFrame:IsVisible() ) then
		return;
	end
	local bar = SimpleQoLGuildFrameScrollFrameScrollBar;
	if ( delta > 0 ) then
		bar:SetValue(bar:GetValue() - SIMPLEQOL_GUILD_ROW_HEIGHT);
	else
		bar:SetValue(bar:GetValue() + SIMPLEQOL_GUILD_ROW_HEIGHT);
	end
end

function SimpleQoLGuildRow_OnClick()
	local member = SimpleQoL_GuildFiltered[SimpleQoL_GuildScroll + this:GetID()];
	if ( member ) then
		SimpleQoL_GuildSelected = member.name;
	else
		SimpleQoL_GuildSelected = nil;
	end
	SimpleQoL_GuildUpdateRows();
	SimpleQoL_GuildUpdateButtons();
end

function SimpleQoLGuildFrameSortName_OnClick()
	SimpleQoL_GuildSetSort("name", 1);
end

function SimpleQoLGuildFrameSortLevel_OnClick()
	SimpleQoL_GuildSetSort("level", nil);
end

function SimpleQoLGuildFrameSortClass_OnClick()
	SimpleQoL_GuildSetSort("class", 1);
end

function SimpleQoLGuildFrameSortRank_OnClick()
	SimpleQoL_GuildSetSort("rank", 1);
end

function SimpleQoLGuildFrameSortOnline_OnClick()
	SimpleQoL_GuildSetSort("online", 1);
end

function SimpleQoLGuildFrameOnlineToggle_OnClick()
	if ( SimpleQoL_GuildShowOffline ) then
		SimpleQoL_GuildShowOffline = nil;
	else
		SimpleQoL_GuildShowOffline = 1;
	end
	SimpleQoL_GuildScroll = 0;
	SimpleQoL_GuildRefresh();
end

function SimpleQoLGuildFrameWhisperButton_OnClick()
	if ( SimpleQoL_GuildSelected ) then
		ChatFrameEditBox:Show();
		ChatFrameEditBox:SetText("/w "..SimpleQoL_GuildSelected.." ");
	end
end

function SimpleQoLGuildFrameGroupInviteButton_OnClick()
	if ( SimpleQoL_GuildSelected and InviteByName ) then
		InviteByName(SimpleQoL_GuildSelected);
	end
end

function SimpleQoLGuildFrameInviteButton_OnClick()
	ChatFrameEditBox:Show();
	ChatFrameEditBox:SetText("/ginvite ");
end

function SimpleQoLGuildFrameRemoveButton_OnClick()
	if ( SimpleQoL_GuildSelected and GuildUninviteByName ) then
		GuildUninviteByName(SimpleQoL_GuildSelected);
		SimpleQoL_GuildChanged();
	end
end

function SimpleQoLGuildFramePromoteButton_OnClick()
	if ( SimpleQoL_GuildSelected and GuildPromoteByName ) then
		GuildPromoteByName(SimpleQoL_GuildSelected);
		SimpleQoL_GuildChanged();
	end
end

function SimpleQoLGuildFrameDemoteButton_OnClick()
	if ( SimpleQoL_GuildSelected and GuildDemoteByName ) then
		GuildDemoteByName(SimpleQoL_GuildSelected);
		SimpleQoL_GuildChanged();
	end
end

function SimpleQoLGuildFrameSetMotdButton_OnClick()
	if ( SimpleQoL_GuildPlayerRank() ~= 0 ) then
		SimpleQoL_Print("only the Guild Master can set the MOTD.");
		return;
	end
	ChatFrameEditBox:Show();
	ChatFrameEditBox:SetText("/gmotd ");
end

function SimpleQoLGuildFrame_OnLoad()
	if ( this.EnableMouseWheel ) then
		this:EnableMouseWheel(1);
	end
	SimpleQoLGuildFrameOnlineToggleText:SetText("Show Offline Members");
	this:Hide();
end

function SimpleQoLGuildFrame_OnShow()
	SimpleQoL_GuildScroll = 0;
	SimpleQoL_GuildSelected = nil;
	SimpleQoL_GuildPending = nil;
	SimpleQoL_GuildRequestSoon(0);
	SimpleQoL_GuildRefresh();
end

function SimpleQoLGuildFrame_OnHide()
	SimpleQoL_GuildPending = nil;
	SimpleQoL_GuildSelected = nil;
end

function SimpleQoLGuildFrame_OnEvent(event)
end

function SimpleQoLGuildFrame_OnUpdate(elapsed)
	-- No new roster after an action: enable the buttons again.
	if ( SimpleQoL_GuildPending and GetTime() - SimpleQoL_GuildPending > SIMPLEQOL_GUILD_REFRESH_TIMEOUT ) then
		SimpleQoL_GuildPending = nil;
		SimpleQoL_GuildUpdateButtons();
	end
end

-- Hook the Friends window once: tab 4 shows the guild frame.
-- AlphaUI's Guild tab (FriendsFrameTab4) is shown even without a guild;
-- hide it then, and show it again after joining one.
function SimpleQoL_AlphaUIGuildTabCheck()
	if ( not SimpleQoL_AlphaUIGuild() or not FriendsFrame or not FriendsFrameTab4 or FriendsFrameTab4 == SimpleQoLGuildTab ) then
		return;
	end
	if ( SimpleQoL_InGuild() ) then
		if ( SimpleQoL_AUITabHidden ) then
			SimpleQoL_AUITabHidden = nil;
			PanelTemplates_SetNumTabs(FriendsFrame, 4);
			FriendsFrameTab4:Show();
			PanelTemplates_UpdateTabs(FriendsFrame);
		end
		return;
	end
	if ( FriendsFrameTab4:IsVisible() or not SimpleQoL_AUITabHidden ) then
		SimpleQoL_AUITabHidden = 1;
		FriendsFrameTab4:Hide();
		PanelTemplates_SetNumTabs(FriendsFrame, 3);
		if ( FriendsFrame.selectedTab == 4 ) then
			FriendsFrame.selectedTab = 1;
			if ( FriendsFrame:IsVisible() ) then
				FriendsFrame_Update();
			end
		end
		PanelTemplates_UpdateTabs(FriendsFrame);
	end
end

function SimpleQoL_SetupGuildTab()
	if ( SimpleQoL_AlphaUIGuild() or not FriendsFrame or not FriendsFrame_Update ) then
		SimpleQoLGuildTab:Hide();
		-- Check AlphaUI's tab whenever the Friends window is drawn.
		if ( SimpleQoL_AlphaUIGuild() and FriendsFrame_Update and not SimpleQoL_AUIGuildHooked ) then
			SimpleQoL_AUIGuildHooked = 1;
			SimpleQoL_Orig_AUI_FriendsFrame_Update = FriendsFrame_Update;
			FriendsFrame_Update = function()
				SimpleQoL_AlphaUIGuildTabCheck();
				SimpleQoL_Orig_AUI_FriendsFrame_Update();
			end;
		end
		return;
	end
	if ( not SimpleQoL_GuildHooked ) then
		SimpleQoL_GuildHooked = 1;
		SimpleQoL_Orig_FriendsFrame_Update = FriendsFrame_Update;
		FriendsFrame_Update = function()
			-- The Guild tab is only there while you are in a guild.
			if ( SimpleQoL_GuildTabActive ) then
				if ( SimpleQoL_InGuild() ) then
					PanelTemplates_SetNumTabs(FriendsFrame, 4);
					SimpleQoLGuildTab:Show();
				else
					PanelTemplates_SetNumTabs(FriendsFrame, 3);
					SimpleQoLGuildTab:Hide();
					if ( FriendsFrame.selectedTab == 4 ) then
						FriendsFrame.selectedTab = 1;
					end
				end
				PanelTemplates_UpdateTabs(FriendsFrame);
			end
			if ( SimpleQoL_GuildTabActive and FriendsFrame.selectedTab == 4 ) then
				FriendsFrameTopLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft");
				FriendsFrameTopRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight");
				FriendsFrameBottomLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft");
				FriendsFrameBottomRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight");
				FriendsListFrame:Hide();
				IgnoreListFrame:Hide();
				WhoFrame:Hide();
				SimpleQoLGuildFrame:Show();
				return;
			end
			SimpleQoLGuildFrame:Hide();
			SimpleQoL_Orig_FriendsFrame_Update();
		end;
	end
	SimpleQoL_ApplyGuildTab();
end

function SimpleQoL_ApplyGuildTab()
	if ( SimpleQoL_AlphaUIGuild() or not SimpleQoL_GuildHooked ) then
		return;
	end
	if ( SimpleQoL_On["guildtab"] ) then
		SimpleQoL_GuildTabActive = 1;
		-- The stock tab code finds tabs as FriendsFrameTab1..N.
		FriendsFrameTab4 = SimpleQoLGuildTab;
		if ( SimpleQoL_InGuild() ) then
			PanelTemplates_SetNumTabs(FriendsFrame, 4);
			SimpleQoLGuildTab:Show();
		else
			PanelTemplates_SetNumTabs(FriendsFrame, 3);
			SimpleQoLGuildTab:Hide();
		end
	else
		SimpleQoL_GuildTabActive = nil;
		PanelTemplates_SetNumTabs(FriendsFrame, 3);
		SimpleQoLGuildTab:Hide();
		SimpleQoLGuildFrame:Hide();
		if ( FriendsFrame.selectedTab == 4 ) then
			FriendsFrame.selectedTab = 1;
			if ( FriendsFrame:IsVisible() ) then
				FriendsFrame_Update();
			end
		end
	end
	PanelTemplates_UpdateTabs(FriendsFrame);
end
