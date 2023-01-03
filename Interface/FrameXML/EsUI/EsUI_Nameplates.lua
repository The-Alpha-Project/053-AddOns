----------------------------------------------------------------------------------------
--	Show Nameplates by Default
----------------------------------------------------------------------------------------
-- Reverse nameplate display logic for clients older than 0.5.5
if tonumber(EsUI.GameBuild) < 3494 and EsUI.C.Nameplates.reverse_display then
	ShowNameplates()
	local originalShowNameplates = ShowNameplates
	local originalHideNameplates = HideNameplates

	function ShowNameplates()
		originalHideNameplates()
		ESUI_NAMEPLATES_SHOWN = true
	end

	function HideNameplates()
		originalShowNameplates()
		ESUI_NAMEPLATES_SHOWN = false
	end
end
