-- TODO: Try working at this again later. Can't seem to find a good way of doing this in the 0.5.3 client
--[[
function SetViewport()
	-- WorldFrame:SetPoint("TOPLEFT", EsUI.C.Viewport.left * EsUI.Scale, -(EsUI.C.Viewport.top * EsUI.Scale))
	-- WorldFrame:SetPoint("BOTTOMRIGHT", -(EsUI.C.Viewport.right * EsUI.Scale), EsUI.C.Viewport.bottom * EsUI.Scale)
end

SlashCmdList.VIEWPORT = function(msg)
	msg = strlower(msg)

	local _, _, cmd, val = strfind(msg, "^(%S*)%s*(.-)$")

	if cmd == "reset" then
		EsUI.C.Viewport.top = 0
		EsUI.C.Viewport.bottom = 0
		EsUI.C.Viewport.left = 0
		EsUI.C.Viewport.right = 0
	elseif (cmd == "top" or cmd == "bottom" or cmd == "left" or cmd == "right") and tonumber(val) then
		EsUI.C.Viewport[cmd] = val
	else
		print("|cffffff00".."/vp reset - Resets values to 0.".."|r")
		print("|cffffff00".."/vp position # - top/bottom/left/right".."|r")
		print("|cffffff00".."e.g. /vp bottom 100".."|r")
	end

	SetViewport()
end
SLASH_VIEWPORT1 = "/vp"
SLASH_VIEWPORT2 = "/viewport"
--]]
