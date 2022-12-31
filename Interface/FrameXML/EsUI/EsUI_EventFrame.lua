----------------------------------------------------------------------------------------
--	Event Frame
----------------------------------------------------------------------------------------
function EsUIEventFrame_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("PLAYER_LEVEL_UP")
	this:RegisterEvent("PLAYER_REGEN_DISABLED")
	this:RegisterEvent("PLAYER_REGEN_ENABLED")

	if EsUI.C.Loot.auto_loot then
		this:RegisterEvent("LOOT_OPENED")
	end

	this:RegisterEvent("CHAT_MSG_COMBAT_LOG_ENEMY")
	this:RegisterEvent("CHAT_MSG_COMBAT_LOG_SELF")
	this:RegisterEvent("CHAT_MSG_COMBAT_LOG_PARTY")
	this:RegisterEvent("CHAT_MSG_COMBAT_LOG_ERROR")
	this:RegisterEvent("CHAT_MSG_COMBAT_LOG_MISC_INFO")

	if tonumber(EsUI.GameBuild) < 3494 and EsUI.C.UnitFrames.track_auras then
		this:RegisterEvent("CHAT_MSG_CHANNEL")
		this:RegisterEvent("PLAYER_TARGET_CHANGED")
	end
end

-- AURAADDEDOTHERHARMFUL = "%s is afflicted by %s."; -- Combat log text for aura events
-- AURAADDEDOTHERHELPFUL = "%s gains %s."; -- Combat log text for aura events
-- AURAADDEDSELFHARMFUL = "You are afflicted by %s."; -- Combat log text for aura events
-- AURAADDEDSELFHELPFUL = "You gain %s."; -- Combat log text for aura events
-- AURACHANGEDOTHER = "%s replaces %s with %s."; -- Combat log text for aura events
-- AURACHANGEDSELF = "You replace %s with %s."; -- Combat log text for aura events
-- AURAREMOVEDOTHER = "%s fades from %s."; -- Combat log text for aura events
-- AURAREMOVEDSELF = "%s fades from you."; -- Combat log text for aura events
local unitDied = gsub(gsub(format(UNITDIESOTHER, ""), "%.", ""), "%s+", "")
local unitGainsBuff = gsub(format(AURAADDEDOTHERHELPFUL, "", ""), "%.", "")
local unitGainsDebuff = gsub(format(AURAADDEDOTHERHARMFUL, "", ""), "%.", "")
local unitLosesAura = gsub(format(AURAREMOVEDOTHER, "", ""), "%.", "")
local playerGainsBuff = gsub(format(AURAADDEDSELFHELPFUL, ""), "%.", "")
local playerGainsDebuff = gsub(format(AURAADDEDSELFHARMFUL, ""), "%.", "")
local playerLosesAura = gsub(format(AURAREMOVEDSELF, ""), "%.", "")

function EsUIEventFrame_OnEvent(event)
	-- Setup
	if event == "PLAYER_ENTERING_WORLD" then
		RefreshEsUIVariables()

		if tonumber(EsUI.GameBuild) < 3494 and EsUI.C.UnitFrames.track_auras then
			EsUI.QueryServerForAuraInformation()
		end

		print("|cffffff00" .. EsUI.L.WELCOME .. EsUI.Version .. ", " .. EsUI.Name .. ".|r")

		if EsUI.C.Quests.instant_quest_text then
			QUEST_FADING_ENABLE = nil
			QuestFrameDetailPanel.fadingProgress = 1024
		end

		-- Reposition QuestLogMicroButton because of the addition of TalentMicroButton
		QuestLogMicroButton:ClearAllPoints()
		QuestLogMicroButton:SetPoint("BOTTOMLEFT", "TalentMicroButton", "BOTTOMRIGHT", -2, 0)

		return
	end

	if event == "PLAYER_TARGET_CHANGED" then
		EsUI.QueryServerForAuraInformation("target")
	end

	if event == "CHAT_MSG_CHANNEL" then
		local msg, sender, language, channel, receiver, playerFlag = arg1, arg2, arg3, arg4, arg5, arg6

		if msg and channel and strfind(channel, "Addonauras") then
			if strsub(msg, 1, 2) == "-2" then -- NO_DATA
				local error, unitID = strsplit(", ", msg) -- Space needed here for now
				EsUI.AuraInfo.units[unitID] = {
					buffs = {},
					debuffs = {},
				}
				if (unitID == "target" or UnitIsUnit(unitID, "player")) and UnitExists("target") then
					TargetDebuffButton_Update()
				end
			elseif tonumber(strlen(msg)) <= 2 then
				EsUI.AuraInfo.count = tonumber(msg)
				EsUI.AuraInfo.refresh = true
			else
				local unitID, spellName, harmful, texture, remaining = strsplit(",", msg)

				if remaining and EsUI.AuraInfo.count > 0 then
					if EsUI.AuraInfo.refresh or not EsUI.AuraInfo.units[unitID] then
						EsUI.AuraInfo.units[unitID] = {
							buffs = {},
							debuffs = {},
						}
						EsUI.AuraInfo.refresh = false
					end

					-- harmful is 1 / helpful is 0
					if harmful == "0" then
						for i = 1, 40 do -- FIXME: This is asinine way of doing things but 0.5.3 client is dumb
							local exists = EsUI.AuraInfo.units[unitID].buffs[i - 1]
							if not exists then
								EsUI.AuraInfo.units[unitID].buffs[i - 1] = {name = spellName, icon = EsUI.GetSpellTextureByID(texture), timeLeft = tonumber(remaining)}
								break
							end
						end
					else
						for i = 1, 40 do -- FIXME: This is asinine way of doing things but 0.5.3 client is dumb
							local exists = EsUI.AuraInfo.units[unitID].debuffs[i - 1]
							if not exists then
								EsUI.AuraInfo.units[unitID].debuffs[i - 1] = {name = spellName, icon = EsUI.GetSpellTextureByID(texture), timeLeft = tonumber(remaining)}
								break
							end
						end
					end

					EsUI.AuraInfo.count = EsUI.AuraInfo.count - 1

					if EsUI.AuraInfo.count <= 0 and UnitExists("target") then
						TargetDebuffButton_Update()
					end
				end
			end
		end
	end

	if strsub(event, 1, 19) == "CHAT_MSG_COMBAT_LOG" then
		local type = strsub(event, 21)

		-- Hide nameplates for dead units
		if type == "SELF" or type == "ENEMY" then
			if strfind(arg1, unitDied) then
				if ESUI_NAMEPLATES_SHOWN then
					HideNameplates()
					ShowNameplates()
				else
					ShowNameplates()
					HideNameplates()
				end
			end
		end

		if tonumber(EsUI.GameBuild) < 3494 and EsUI.C.UnitFrames.track_auras then
			-- Aura tracking
			if type == "ENEMY" then
				-- Find relevant information from specific combat log entries
				local currentTarget = UnitName("target")
				local target, spell, string
				if strfind(arg1, unitGainsBuff) then
					string = gsub(arg1, unitGainsBuff, "`")
					target, spell = strsplit("`", strsub(string, 1, -2))
				elseif strfind(arg1, unitGainsDebuff) then
					string = gsub(arg1, unitGainsDebuff, "`")
					target, spell = strsplit("`", strsub(string, 1, -2))
				elseif strfind(arg1, unitLosesAura) then
					string = gsub(arg1, unitLosesAura, "`")
					spell, target = strsplit("`", strsub(string, 1, -2))
				end

				if target == currentTarget then
					EsUI.QueryServerForAuraInformation("target")
				end
				return
			elseif type == "SELF" then
				-- Only update for auras
				local spell
				if strfind(arg1, playerGainsBuff) then
					spell = gsub(gsub(arg1, playerGainsBuff, ""), "%.", "")
				elseif strfind(arg1, playerGainsDebuff) then
					spell = gsub(gsub(arg1, playerGainsDebuff, ""), "%.", "")
				elseif strfind(arg1, playerLosesAura) then
					spell = gsub(gsub(arg1, playerLosesAura, ""), "%.", "")
				end

				EsUI.QueryServerForAuraInformation("player")
				if spell and UnitIsUnit("target", "player") then
					EsUI.QueryServerForAuraInformation("target")
				end
				return
			elseif type == "PARTY" then
				-- TODO: Later
				return
			end
		end
	end

	-- AutoLoot
	if event == "LOOT_OPENED" then
		if EsUI.C.Loot.auto_loot then
			for i = 1, LootFrame.numLootItems or 0 do
				LootSlot(i, 0)
			end
		end
		return
	end

	-- Update EsUI.Level
	if event == "PLAYER_LEVEL_UP" then
		EsUI.Level = UnitLevel("player")
		return
	end

	-- InCombatLockdown
	if event == "PLAYER_REGEN_DISABLED" then
		ESUI_IN_COMBAT_LOCKDOWN = true
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		ESUI_IN_COMBAT_LOCKDOWN = false
		return
	end
end
