----------------------------------------------------------------------------------------
--	Aura Durations
----------------------------------------------------------------------------------------
SHOW_BUFF_DURATIONS = EsUI.C.Auras.show_durations and "1" or "0"
BUFF_DURATION_WARNING_TIME = 60

function EsUIBuffFrame_OnLoad()
	for i = 1, 24 do
		getglobal("BuffButton" .. (i - 1) .. "Duration"):SetPoint("TOP", "BuffButton" .. (i - 1), "BOTTOM", 0, 0)
	end
end

local originalBuffButtonUpdate = BuffButton_Update
BuffButton_Update = function()
	originalBuffButtonUpdate()

	local buffIndex = GetPlayerBuff(this:GetID(), this.buffFilter)
	local buffDuration = getglobal(this:GetName() .. "Duration")

	if buffIndex < 0 then
		buffDuration:Hide()
	else
		if SHOW_BUFF_DURATIONS == "1" then
			buffDuration:Show()
		else
			buffDuration:Hide()
		end
	end
end

local originalBuffButtonOnUpdate = BuffButton_OnUpdate
BuffButton_OnUpdate = function()
	originalBuffButtonOnUpdate()

	local buffDuration = getglobal(this:GetName() .. "Duration")
	if this.untilCancelled == 1 then
		buffDuration:Hide()
		return
	end

	local buffIndex = this.buffIndex
	local timeLeft = GetPlayerBuffTimeLeft(buffIndex)

	-- Update duration
	BuffFrame_UpdateDuration(this, timeLeft)
end

function BuffFrame_UpdateDuration(BuffButton, timeLeft)
	local duration = getglobal(BuffButton:GetName() .. "Duration")
	if SHOW_BUFF_DURATIONS == "1" and timeLeft then
		duration:SetText(SecondsToTimeAbbrev(timeLeft))
		if timeLeft < BUFF_DURATION_WARNING_TIME then
			duration:SetVertexColor(1.0, 0.82, 0)
		else
			duration:SetVertexColor(1.0, 1.0, 1.0)
		end

		duration:Show()
	else
		duration:Hide()
	end
end
