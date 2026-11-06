--------------------------------------------------------------------------------
-- SimpleQoL: right-click moves items between your bags and the bank while the
-- bank window is open (always on). Right-click in the bank: into your bags;
-- right-click in your bags: into the bank. Hold Shift, Ctrl or Alt for the
-- normal behaviour.
--------------------------------------------------------------------------------

function SimpleQoL_BankOpen()
	return BankFrame and BankFrame:IsVisible();
end

-- First empty slot in the bank ("bank") or in your bags ("bags"): bag, slot.
-- Bag -1 is the bank's own slots. Ammo and special bags are skipped.
function SimpleQoL_BankFreeSlot(target)
	local bag, slot;
	local first, last = 0, NUM_BAG_SLOTS or 4;
	if ( target == "bank" ) then
		for slot = 1, (NUM_BANKGENERIC_SLOTS or 24) do
			if ( not GetInventoryItemTexture("player", BankButtonIDToInvSlotID(slot)) ) then
				return -1, slot;
			end
		end
		first, last = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6);
	end
	for bag = first, last do
		if ( not (SimpleQoL_AmmoBagKind and SimpleQoL_AmmoBagKind(bag)) ) then
			local count = GetContainerNumSlots(bag) or 0;
			for slot = 1, count do
				if ( not GetContainerItemInfo(bag, slot) ) then
					return bag, slot;
				end
			end
		end
	end
	return nil;
end

-- Moves the item of one slot to the other side (bank <-> bags).
function SimpleQoL_BankMove(bag, slot)
	local texture, count, locked = SimpleQoL_SortInfo(bag, slot);
	if ( not texture or locked ) then
		return;
	end
	local toBank = bag >= 0 and bag <= (NUM_BAG_SLOTS or 4);
	local toBag, toSlot = SimpleQoL_BankFreeSlot(toBank and "bank" or "bags");
	if ( not toBag ) then
		SimpleQoL_Print(toBank and "the bank is full." or "your bags are full.");
		return;
	end
	SimpleQoL_SortPickup(bag, slot);
	if ( CursorHasItem and CursorHasItem() ) then
		SimpleQoL_SortPickup(toBag, toSlot);
		if ( CursorHasItem() ) then
			SimpleQoL_SortPickup(bag, slot);     -- did not fit: put it back
		end
	end
end

function SimpleQoL_BankPlain()
	return not (CursorHasItem and CursorHasItem()) and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown();
end

-- Right-click on an item in your bags or in a bank bag. arg1 is the mouse
-- button only in a click handler, so automatic uses (clams and so on) are left alone.
SimpleQoL_Orig_Bank_UseContainerItem = UseContainerItem;
function UseContainerItem(bag, slot)
	if ( SpellIsTargeting and SpellIsTargeting() ) then
		SimpleQoL_Orig_Bank_UseContainerItem(bag, slot);
		return;
	end
	if ( arg1 == "RightButton" and not SimpleQoL_Internal and SimpleQoL_BankOpen() and SimpleQoL_BankPlain() ) then
		SimpleQoL_BankMove(bag, slot);
		return;
	end
	SimpleQoL_Orig_Bank_UseContainerItem(bag, slot);
end

-- Right-click on one of the bank's own slots.
if ( BankFrameItemButtonGeneric_OnClick ) then
	SimpleQoL_Orig_BankClick = BankFrameItemButtonGeneric_OnClick;
	function BankFrameItemButtonGeneric_OnClick(button)
		if ( button == "RightButton" and this and not this.isBag and SimpleQoL_BankPlain() ) then
			SimpleQoL_BankMove(-1, this:GetID());
			return;
		end
		SimpleQoL_Orig_BankClick(button);
	end
end
