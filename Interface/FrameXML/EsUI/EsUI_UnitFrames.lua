----------------------------------------------------------------------------------------
--	StatusBar Text
----------------------------------------------------------------------------------------
SetCVar("statusBarText", EsUI.C.UnitFrames.statusbar_text and 1 or 0)

----------------------------------------------------------------------------------------
--	Reposition
----------------------------------------------------------------------------------------
if EsUI.C.UnitFrames.reposition then
	PlayerFrame:ClearAllPoints()
	PlayerFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", EsUI.C.UnitFrames.x_offset, EsUI.C.UnitFrames.y_offset)

	TargetFrame:ClearAllPoints()
	TargetFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", -EsUI.C.UnitFrames.x_offset, EsUI.C.UnitFrames.y_offset)
end

----------------------------------------------------------------------------------------
--	Class Icon Portraits
----------------------------------------------------------------------------------------
if EsUI.C.UnitFrames.class_portraits then
	local function UpdatePortrait()
		local class = UnitClass(this.unit)
		if class then
			local texCoords = class and CLASS_ICON_TCOORDS[strupper(class)]

			if texCoords then
				local minX, maxX, minY, maxY = texCoords[1], texCoords[2], texCoords[3], texCoords[4]
				this.portrait:SetTexture("Interface\\FrameXML\\EsUI\\Media\\UI-Classes-Circles")
				this.portrait:SetTexCoord(minX, maxX, minY, maxY)
			end
		else
			this.portrait:SetTexCoord(0, 1, 0, 1)
		end
	end

	local originalUnitFrameOnEvent = UnitFrame_OnEvent
	local originalUnitFrameUpdate = UnitFrame_Update

	function UnitFrame_OnEvent(event)
		originalUnitFrameOnEvent(event)

		if event == "UNIT_PORTRAIT_UPDATE" and arg1 == this.unit then
			UpdatePortrait()
		end
	end

	function UnitFrame_Update()
		originalUnitFrameUpdate()
		UpdatePortrait()
	end
end

----------------------------------------------------------------------------------------
--	Alternative Style
----------------------------------------------------------------------------------------
if EsUI.C.UnitFrames.alternative_style then
	-- Change Texture
	PlayerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	PlayerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

	PlayerFrame:UnregisterEvent("UNIT_MAXMANA") -- UI-TargetingFrame-NoMana
	PlayerFrame:UnregisterEvent("PLAYER_ENTER_COMBAT")
	PlayerFrame:UnregisterEvent("PLAYER_LEAVE_COMBAT")

	PlayerFrameTexture:SetTexture("Interface\\FrameXML\\EsUI\\Media\\UI-TargetingFrame")
	PlayerFrameTexture:SetTexCoord(1, 0, 0, 1)
	PlayerFrameTexture:SetHeight(128)
	PlayerFrameTexture:SetWidth(256)
	PlayerFrameTexture:ClearAllPoints()
	PlayerFrameTexture:SetPoint("CENTER", "PlayerFrame", "CENTER", -5, -18)

	local originalPlayerFrameOnEvent = PlayerFrame_OnEvent

	function PlayerFrame_OnEvent(event)
		originalPlayerFrameOnEvent(event)

		if event == "PLAYER_REGEN_DISABLED" then
			PlayerAttackModeTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0)
			PlayerAttackModeTexture:Show()
			return
		end

		if event == "PLAYER_REGEN_ENABLED" then
			PlayerAttackModeTexture:Hide()
			return
		end
	end

	PlayerAttackModeTexture:SetTexture("Interface\\FrameXML\\EsUI\\Media\\UI-Player-Status")
	PlayerAttackModeTexture:SetTexCoord(0, 1, 0, 1)
	PlayerAttackModeTexture:SetHeight(128)
	PlayerAttackModeTexture:SetWidth(256)
	PlayerAttackModeTexture:ClearAllPoints() PlayerAttackModeTexture:SetPoint("CENTER", "PlayerFrame", "CENTER", 30, -27)

	TargetFrameTexture:SetTexture("Interface\\FrameXML\\EsUI\\Media\\UI-TargetingFrame")
	TargetFrameTexture:SetTexCoord(0, 1, 0, 1)
	TargetFrameTexture:SetHeight(128)
	TargetFrameTexture:SetWidth(256)
	TargetFrameTexture:ClearAllPoints()
	TargetFrameTexture:SetPoint("CENTER", "TargetFrame", "CENTER", 5, -18)

	-- Reposition Elements
	PlayerName:ClearAllPoints()
	PlayerName:SetPoint("TOP", "PlayerFrame", "TOP", 34, -2)
	PlayerName:SetWidth(120)

	PlayerFrameHealthBar:SetHeight(28)
	PlayerFrameHealthBar:ClearAllPoints()
	PlayerFrameHealthBar:SetPoint("TOPRIGHT", "PlayerFrame", "TOPRIGHT", -2, -16)

	TargetName:ClearAllPoints()
	TargetName:SetPoint("TOP", "TargetFrame", "TOP", -34, -2)
	TargetName:SetWidth(120)

	TargetFrameNameBackground:Hide()
	TargetFrameHealthBar:SetHeight(28)
	TargetFrameHealthBar:ClearAllPoints()
	TargetFrameHealthBar:SetPoint("TOPLEFT", "TargetFrame", "TOPLEFT", 2, -16)

	-- Change StatusBar Color
	-- TODO

	-- Change StatusBar Text
	SetTextStatusBarTextPrefix(PlayerFrameHealthBar)
	PlayerFrameHealthBarText:SetTextHeight(13)
	PlayerFrameHealthBarText:ClearAllPoints()
	PlayerFrameHealthBarText:SetPoint("CENTER", "PlayerFrame", "CENTER", 34, 8)

	PlayerFrameManaBarText:SetTextHeight(12)

	local originalTargetFrameOnLoad = TargetFrame_OnLoad
	function TargetFrame_OnLoad()
		originalTargetFrameOnLoad()

		SetTextStatusBarTextPrefix(TargetFrameHealthBar)
		TargetFrameHealthBarText:SetTextHeight(13)
		TargetFrameHealthBarText:ClearAllPoints()
		TargetFrameHealthBarText:SetPoint("CENTER", "TargetFrame", "CENTER", -34, 8)

		TargetFrameManaBarText:SetTextHeight(12)
	end

	PetFrameHealthBarText:SetTextHeight(12)
	PetFrameHealthBarText:ClearAllPoints()
	PetFrameHealthBarText:SetPoint("CENTER", "PetFrame", "CENTER", 15, 2)

	PetFrameManaBarText:SetTextHeight(12)
	PetFrameManaBarText:ClearAllPoints()
	PetFrameManaBarText:SetPoint("CENTER", "PetFrame", "CENTER", 15, -8)

	local originalUnitFrameUpdateManaType = UnitFrame_UpdateManaType
	function UnitFrame_UpdateManaType()
		originalUnitFrameUpdateManaType()
		SetTextStatusBarTextPrefix(this.manabar)
		local maxValue = UnitManaMax(this.unit)
		local ManaBarText = getglobal(this:GetName() .. "ManaBarText")
		if not maxValue or maxValue == 0 then
			ManaBarText:Hide()
		else
			ManaBarText:Show()
		end
	end
end

----------------------------------------------------------------------------------------
--	Target Auras
----------------------------------------------------------------------------------------
-- Only add auras for clients older than 0.5.5
if tonumber(EsUI.GameBuild) < 3494 and EsUI.C.UnitFrames.track_auras then
	local originalTargetFrameUpdate = TargetFrame_Update
	function TargetFrame_Update()
		originalTargetFrameUpdate()

		if UnitExists("target") then
			TargetDebuffButton_Update()
			UnitFrameManaBar_Update(TargetFrameManaBar, "target")
		end
	end

	function TargetDebuffButton_Update()
		local auraInfo = UnitIsUnit("target", "player") and EsUI.AuraInfo.units.player.debuffs or EsUI.AuraInfo.units.target.debuffs
		local name, description, cooldown, fullDuration, start, duration
		local debuff, debuffButton, buff, buffButton
		local buffCount = 0
		local debuffCount = 1
		local button
		for i = 1, MAX_TARGET_DEBUFFS do
			debuff = auraInfo[i - 1] and auraInfo[i - 1].icon
			debuffButton = getglobal("TargetFrameDebuff" .. i):GetName()
			cooldown = getglobal(debuffButton .."Cooldown")
			if debuff then
				-- Name
				name = auraInfo[i - 1].name
				description = EsUI.GetSpellDescription(name)

				-- Duration
				fullDuration = (EsUI.GetSpellDuration(name) or 0) / 1000
				if fullDuration > 0 then
					start, duration = GetTime() - (fullDuration - (auraInfo[i - 1].timeLeft / 1000)), fullDuration, 1
				else
					start, duration = GetTime(), auraInfo[i - 1].timeLeft / 1000, 1
				end
				getglobal(debuffButton).name = name
				getglobal(debuffButton).description = description
				getglobal(debuffButton).start = start
				getglobal(debuffButton).duration = duration


				-- Tooltip
				getglobal(debuffButton).tooltip = function()
					if this.description and this.description ~= "" then
						return this.name .. "\n|cffffffff" .. this.description .. "|r\n" .. EsUI.DurationText(this.start + this.duration - GetTime()) .. EsUI.L.REMAINING
					else
						return this.name .. "\n" .. EsUI.DurationText(this.start + this.duration - GetTime()) .. EsUI.L.REMAINING
					end
				end

				-- Icon Texture
				getglobal(debuffButton .. "Icon"):SetTexture(debuff)

				-- Cooldown Animation
				CooldownFrame_SetTimer(cooldown, start, duration, 1)

				getglobal(debuffButton):Show()
			else
				getglobal(debuffButton).tooltip = nil
				getglobal(debuffButton .. "Icon"):SetTexture("")
				CooldownFrame_SetTimer(cooldown, 0, 0, 0)
				getglobal(debuffButton):Hide()
			end
		end
	end
else
	local originalTargetFrameOnLoad = TargetFrame_OnLoad
	function TargetFrame_OnLoad()
		originalTargetFrameOnLoad()

		for i = 1, MAX_TARGET_DEBUFFS do
			getglobal("TargetFrameDebuff" .. i):Hide()
		end
	end
end

function TargetDebuffButtonTemplate_OnUpdate(elapsed)
	if not this.updateTooltip then
		return
	end

	this.updateTooltip = this.updateTooltip - elapsed
	if this.updateTooltip > 0 then
		return
	end

	if GameTooltip:IsOwned(this) then
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(this.tooltip and this.tooltip() or "")
		GameTooltip:SetBackdropColor(this.r, this.g, this.b)
	else
		this.updateTooltip = nil
	end
end