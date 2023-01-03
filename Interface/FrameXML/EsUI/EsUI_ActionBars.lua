function EsUI.MoveActionBars()
	for i = 0, 3 do -- for loop, hides MainMenuBarTexture (0-3)
		getglobal("MainMenuBarTexture" .. i):Hide()
	end

	ActionBarArt:Show()
	MainMenuBar:EnableMouse(0)

	-- Repositioning
	ActionButton1:ClearAllPoints()
	ActionButton1:SetPoint("BOTTOMLEFT", "MainMenuBarArtFrame", "BOTTOMLEFT", 8, 7)

	SlidingActionBarTexture0:SetPoint("TOPLEFT", "PetActionBarFrame", "TOPLEFT", 0, 0) -- pet bar texture (displayed when bottom left bar is hidden)
	PetActionButton1:ClearAllPoints()
	PetActionButton1:SetPoint("TOP", "PetActionBarFrame", "LEFT", 51, 9)

	ShapeshiftBarLeft:SetPoint("BOTTOMLEFT", "ShapeshiftBarFrame", "BOTTOMLEFT", 0, 0) -- stance bar texture for when Bottom Left Bar is hidden
	ShapeshiftButton1:ClearAllPoints()
	ShapeshiftButton1:SetPoint("TOP", "ShapeshiftBarLeft", "LEFT", 25, 7)

	if EsUI.C.ActionBars.hide_gryphons then
		MainMenuBarLeftEndCap:Hide()
		MainMenuBarRightEndCap:Hide()
	else
		MainMenuBarLeftEndCap:ClearAllPoints()
		MainMenuBarLeftEndCap:SetPoint("LEFT", "ActionBarArt", "LEFT", -96, 0)
		MainMenuBarRightEndCap:ClearAllPoints()
		MainMenuBarRightEndCap:SetPoint("RIGHT", "ActionBarArt", "RIGHT", 96, 0)
	end

	ActionBarUpButton:SetPoint("CENTER", "MainMenuBarArtFrame", "TOPLEFT", 521, -19)
	ActionBarDownButton:SetPoint("CENTER", "MainMenuBarArtFrame", "TOPLEFT", 521, -38)
	-- MainMenuBarPageNumber:SetPoint("CENTER", "MainMenuBarArtFrame", "CENTER", 29, -5)

	MainMenuExpBar:SetWidth(542)
	MainMenuExpBar:SetHeight(10)
	MainMenuExpBar:ClearAllPoints()
	MainMenuExpBar:SetPoint("BOTTOM", "UIParent", "BOTTOM", 0, 0)

	-- reposition ALL actionbars (right bars not affected)
	MainMenuBar:SetPoint("BOTTOM", "UIParent", "BOTTOM", 237, 11)

	-- xp bar background (the one I made)
	XPBarBackground:SetWidth(542)
	XPBarBackground:SetHeight(10)
	XPBarBackground:SetPoint("BOTTOM", "MainMenuBar", "BOTTOM", -237, -10)
end

function EsUI.MoveMicroButtons()
	-- Artwork
	MicroMenuArt:Show()

	-- MicroMenu Buttons
	for i = 1, getn(MICRO_BUTTONS) do
		local button, previousButton = MICRO_BUTTONS[i], MICRO_BUTTONS[i-1]

		getglobal(button):ClearAllPoints()
		getglobal(button):SetFrameLevel(0)

		if i == 1 then
			getglobal(button):SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -198, 4)
		else
			getglobal(button):SetPoint("BOTTOMRIGHT", previousButton, "BOTTOMRIGHT", 28, 0)
		end
	end

	-- Latency Bar
	MainMenuBarPerformanceBarFrame:SetFrameLevel(6)
	MainMenuBarPerformanceBarFrame:SetWidth(28)
	MainMenuBarPerformanceBarFrame:SetHeight(6)
	MainMenuBarPerformanceBarFrame:ClearAllPoints()
	MainMenuBarPerformanceBarFrame:SetPoint("BOTTOM", "MainMenuMicroButton", "BOTTOM", 2, 2)

	MainMenuBarPerformanceBar:SetWidth(56)
	MainMenuBarPerformanceBar:SetHeight(10)
	MainMenuBarPerformanceBar:ClearAllPoints()
	MainMenuBarPerformanceBar:SetPoint("CENTER", "MainMenuBarPerformanceBarFrame", "CENTER", 0, 0)

	-- Bags
	CONTAINER_OFFSET = 88

	MainMenuBarBackpackButton:SetWidth(40)
	MainMenuBarBackpackButton:SetHeight(40)
	MainMenuBarBackpackButton:ClearAllPoints()
	MainMenuBarBackpackButton:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -4, 44)
	for i = 0, 3 do
		local bagFrame, previousBag = "CharacterBag" .. i .. "Slot", "CharacterBag" .. i - 1 .. "Slot"

		getglobal(bagFrame):SetWidth(30)
		getglobal(bagFrame):SetHeight(30)
		getglobal(bagFrame):ClearAllPoints()

		getglobal(bagFrame):SetNormalTexture("")

		getglobal(bagFrame .. "NormalTexture"):Hide()
		getglobal(bagFrame .. "NormalTexture").Show = nil

		if i == 0 then
			getglobal(bagFrame):SetPoint("BOTTOMRIGHT", "MainMenuBarBackpackButton", "BOTTOMLEFT", -3, 1)
		else
			getglobal(bagFrame):SetPoint("BOTTOMRIGHT", previousBag, "BOTTOMLEFT", i < 2 and -3 or -2, 0)
		end
	end
end

if EsUI.C.ActionBars.alternative_style then
	-- Chat Frame Positioning
	local originalShapeshiftBar_Update = ShapeshiftBar_Update
	function ShapeshiftBar_Update()
		originalShapeshiftBar_Update()
		ChatFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 32, 94)
	end

	local originalShowPetActionBar = ShowPetActionBar
	function ShowPetActionBar()
		originalShowPetActionBar()
		ChatFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 32, 94)
	end

	local originalHidePetActionBar = HidePetActionBar
	function HidePetActionBar()
		originalHidePetActionBar()
		ChatFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 32, 94)
	end

	CombatLog:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -32, 94)

	-- Prevent texture reassignment on bags
	local originalPaperDollItemSlotButtonUpdateLock = PaperDollItemSlotButton_UpdateLock
	function PaperDollItemSlotButton_UpdateLock()
		if strfind(this:GetName(), "CharacterBag") then return end

		originalPaperDollItemSlotButtonUpdateLock()
	end

	local originalMainMenuExpBarUpdate = MainMenuExpBar_Update
	function MainMenuExpBar_Update()
		originalMainMenuExpBarUpdate()
		MainMenuExpBar:SetFrameLevel(0) -- TODO: Find a better way of fixing this
	end

	-- Ensure MicroButtons stay put
	local originalUpdateMicroButtons = UpdateMicroButtons
	function UpdateMicroButtons()
		originalUpdateMicroButtons()
		EsUI.MoveMicroButtons()
	end

	-- Reposition tooltip for MicroButtons and Latency Info
	local originalGameTooltipSetOwner = GameTooltip.SetOwner
	function GameTooltip.SetOwner(this, frame, anchor)
		if frame == MainMenuBarPerformanceBarFrame or strfind(frame:GetName(), "MicroButton") then
			originalGameTooltipSetOwner(this, frame, "ANCHOR_LEFT")
		else
			originalGameTooltipSetOwner(this, frame, anchor or "ANCHOR_RIGHT")
		end
	end
end
