----------------------------------------------------------------------------------------
--	Debug Target Info
----------------------------------------------------------------------------------------
SetCVar("debugTargetInfo", EsUI.C.Tooltips.debug_target_info and 1 or 0)

----------------------------------------------------------------------------------------
--	GUID
----------------------------------------------------------------------------------------
SetCVar("showGUIDs", EsUI.C.Tooltips.debug_target_info and 1 or 0)

----------------------------------------------------------------------------------------
--	Add ID
----------------------------------------------------------------------------------------
local types = {
	spell		= "SpellID: ",
	item		= "ItemID: ",
	quest		= "QuestID: ",
	talent		= "TalentID: ",
}

--[[
local function addLine(tooltip, id, type)
	if not tooltip.Addline then return end

	local found = false

	-- Check if we already added to this tooltip. Happens on the talent frame
	for i = 1, 15 do
		local frame = getglobal(tooltip:GetName() .. "TextLeft" .. i)
		local text
		if frame then text = frame:GetText() end
		if text and text == type then found = true break end
	end

	if not found then
		for i = 1, 15 do
			local frame = getglobal(tooltip:GetName() .. "TextLeft" .. i)
			local text
			if frame then text = frame:GetText() end
			if not text or text == "" then
				tooltip:AddLine(TEXT(type .. "|cffffffff" .. id .. "|r"))
				break
			end
		end

		tooltip:Show()
	end
end

local originalSetItemRef = SetItemRef
local originalGameTooltipSetHyperlink = GameTooltip.SetHyperlink

function SetItemRef(link)
	originalSetItemRef(link)

	local _, _, type, id = strfind(link, "^(%a+):(%d+)")
	if not type or not id then return end

	if type == "spell" or type == "enchant" or type == "trade" then
		addLine(this, id, types.spell)
	elseif type == "talent" then
		addLine(this, id, types.talent)
	elseif type == "quest" then
		addLine(this, id, types.quest)
	elseif type == "item" then
		addLine(this, id, types.item)
	end
end
--]]

local originalGameTooltipSetPlayerBuff = GameTooltip.SetPlayerBuff
local originalGameTooltipSetSpell = GameTooltip.SetSpell
local originalGameTooltipSetCraftSpell = GameTooltip.SetCraftSpell
local originalGameTooltipSetAction = GameTooltip.SetAction

local originalGameTooltipSetBagItem = GameTooltip.SetBagItem -- GetContainerItemLink
local originalGameTooltipSetCraftItem = GameTooltip.SetCraftItem
local originalGameTooltipSetInventoryItem = GameTooltip.SetInventoryItem -- GetInventoryItemLink
local originalGameTooltipSetLootItem = GameTooltip.SetLootItem -- GetLootSlotLink
local originalGameTooltipSetMerchantItem = GameTooltip.SetMerchantItem -- GetMerchantItemLink
local originalGameTooltipSetQuestLogItem = GameTooltip.SetQuestLogItem
local originalGameTooltipSetTradeTargetItem = GameTooltip.SetTradeTargetItem -- GetTradeTargetItemLink
local originalGameTooltipSetTradePlayerItem = GameTooltip.SetTradePlayerItem -- GetTradePlayerItemLink
local originalGameTooltipSetTradeSkillItem = GameTooltip.SetTradeSkillItem -- GetTradeSkillItemLink

local originalGameTooltipSetTrainerService = GameTooltip.SetTrainerService
local originalGameTooltipSetUnit = GameTooltip.SetUnit

--[[
-- Spells
hooksecurefunc(GameTooltip, "SetPlayerBuff", function(self, ...)
	local id = select(11, UnitBuff(...))
	if id then addLine(self, id, types.spell) end
end)

hooksecurefunc("SetItemRef", function(link, ...)
	local id = tonumber(link:match("spell:(%d+)"))
	if id then addLine(ItemRefTooltip, id, types.spell) end
end)

GameTooltip:HookScript("SetSpell", function(self)
	local id = select(3, self:GetSpell())
	if id then addLine(self, id, types.spell) end
end)

-- Items
local function attachItemTooltip(self)
	local link = select(2, self:GetItem())
	if link then
		local id = string.match(link, "item:(%d*)")
		if (id == "" or id == "0") and TradeSkillFrame ~= nil and TradeSkillFrame:IsVisible() and GetMouseFocus().reagentIndex then
			local selectedRecipe = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
			for i = 1, 8 do
				if GetMouseFocus().reagentIndex == i then
					id = C_TradeSkillUI.GetRecipeReagentItemLink(selectedRecipe, i):match("item:(%d+):") or nil
					break
				end
			end
		end
		if id then
			addLine(self, id, types.item)
		end
	end
end

GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
-- ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
-- ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
--]]