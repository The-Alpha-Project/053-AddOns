-- TODO: Try working at this again later. Can't seem to find a good way of doing this in the 0.5.3 client
--[[
EsUI.Scale = min(2, max(0.20, 768 / EsUI.ScreenHeight))
if EsUI.ScreenHeight >= 2400 then
	EsUI.Scale = EsUI.Scale * 3
elseif EsUI.ScreenHeight >= 1600 then
	EsUI.Scale = EsUI.Scale * 2
end
EsUI.Scale = tonumber(strsub(EsUI.Scale, 0, 5))

if EsUI.ScreenWidth <= 1024 and GetCVar("gxMonitor") == "0" then
	-- ConsoleExec("scaleui 1") -- doesn't exist :(
else
	if EsUI.Scale > 1.28 then EsUI.Scale = 1.28 end

	-- Set our uiScale
	-- ConsoleExec("scaleui " .. EsUI.Scale) -- doesn't exist :(

	-- Hack for 4K and WQHD Resolution
	if EsUI.Scale < 0.64 then
		UIParent:SetScale(EsUI.Scale) -- does nothing?
	end
end
--]]
