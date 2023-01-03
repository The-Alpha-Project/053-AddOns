MinimapZoomIn:Hide()
MinimapZoomOut:Hide()
GameTimeFrame:Hide()

-- TimeManagerClockButton
function TimeManagerClockButton_OnLoad()
	this:SetFrameLevel(this:GetFrameLevel() + 2)
	TimeManagerClockButton_Update()
end

function TimeManagerClockButton_Update()
	local currentText = TimeManagerClockTicker:GetText()
	local newText = GameTime_GetTime()
	if strlen(newText) > 5 then
		newText = strsub(newText, 1, -4) -- remove AM/PM
	end
	if currentText ~= newText then
		TimeManagerClockTicker:SetText(newText)
	end
end

function TimeManagerClockButton_OnUpdate(elapsed)
	TimeManagerClockButton_Update()
end
