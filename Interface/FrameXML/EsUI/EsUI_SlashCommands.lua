----------------------------------------------------------------------------------------
--	ReloadUI Slash Command
----------------------------------------------------------------------------------------
SlashCmdList.RELOADUI = ReloadUI
SLASH_RELOADUI1 = "/reloadui"
SLASH_RELOADUI2 = "/reload"
SLASH_RELOADUI3 = "/rl"
SLASH_RELOADUI4 = "//"
SLASH_RELOADUI5 = "/."

----------------------------------------------------------------------------------------
--	Disband Group Slash Command
----------------------------------------------------------------------------------------
local function DisbandGroup()
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then
		SendChatMessage(EsUI.L.DISBAND_CHAT, "RAID")
		for i = 1, GetNumRaidMembers() do
			local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
			if online and name ~= EsUI.Name then
				UninviteFromRaid(name)
			end
		end
		LeaveParty()
	elseif GetPartyMember(1) then
		SendChatMessage(EsUI.L.DISBAND_CHAT, "PARTY")
		for i = MAX_PARTY_MEMBERS, 1, -1 do
			if GetPartyMember(i) then
				UninviteFromParty("party" .. i)
			end
		end
		LeaveParty()
	end
end

StaticPopupDialogs.DISBAND_GROUP = {
	text = EsUI.L.DISBAND_POPUP,
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = DisbandGroup,
	timeout = 0,
	whileDead = 1,
}

SlashCmdList.GROUPDISBAND = function()
	if InCombatLockdown() then return print(ERR_CLIENT_LOCKED_OUT) end

	StaticPopup_Show("DISBAND_GROUP")
end
SLASH_GROUPDISBAND1 = "/gd"
SLASH_GROUPDISBAND2 = "/pd"
SLASH_GROUPDISBAND3 = "/rd"

----------------------------------------------------------------------------------------
--	Copy Chat Slash Command
----------------------------------------------------------------------------------------
SlashCmdList.COPYCHAT = function() return ToggleFrame(EsUIChatCopyFrame) end
SLASH_COPYCHAT1 = "/copychat"
SLASH_COPYCHAT2 = "/copy"
SLASH_COPYCHAT3 = "/cc"
